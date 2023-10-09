# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use DBI;
use FileHandle;
use Getopt::Long;
use Pod::Usage qw(pod2usage);

use Data::Dumper;

my $args = scalar @ARGV;
my $config = {};
GetOptions(
  $config,
  'help|h',
  'registry_file=s',
  'entry_1=s',
  'entry_2=s',
  'dryrun',
) or die "Error: Failed to parse command line arguments\n";

pod2usage(1) if ($config->{'help'} || !$args);

foreach my $param (qw/registry_file entry_1 entry_2/) {
  die ("Argument --$param is required. The entry IDs are the GDF dbID.") unless (defined($config->{$param}));
}

my $registry = 'Bio::EnsEMBL::Registry';
my $registry_file = $config->{registry_file};
$registry->load_all($registry_file);

my $species = 'human';
my $attrib_adaptor = $registry->get_adaptor($species, 'gene2phenotype', 'Attribute');
my $gf_adaptor     = $registry->get_adaptor($species, 'gene2phenotype', 'GenomicFeature');
my $gfd_adaptor    = $registry->get_adaptor($species, 'gene2phenotype', 'GenomicFeatureDisease');

# Get the GenomicFeatureDisease from the IDs
my $gfd_1 = get_genomic_feature_disease($config->{entry_1});
my $gfd_2 = get_genomic_feature_disease($config->{entry_2});

# Check if they are the same entry
my $type = check_entries($gfd_1, $gfd_2);

print "Entry type: $type\n";

if($type ne "same_entry") {
  merge_entries($gfd_1, $gfd_2, $type);
}


sub get_genomic_feature_disease {
  my $entry_id = shift;

  my $gfd = $gfd_adaptor->fetch_by_dbID($entry_id);

  if(!defined $gfd) {
    die("ERROR: Could not find GenomicFeatureDisease dbID = $entry_id\n");
  }

  return $gfd;
}

sub check_entries {
  my $gfd_1 = shift;
  my $gfd_2 = shift;

  my $type;

  my $gf_1 = $gfd_1->genomic_feature_id();
  my $gf_2 = $gfd_2->genomic_feature_id();

  my $disease_1 = $gfd_1->disease_id();
  my $disease_2 = $gfd_2->disease_id();
  
  my $allele_requirement_1 = $gfd_1->allelic_requirement();
  my $allele_requirement_2 = $gfd_2->allelic_requirement();
  
  my $mutation_consequence_1 = $gfd_1->mutation_consequence();
  my $mutation_consequence_2 = $gfd_2->mutation_consequence();
  
  if($gf_1 eq $gf_2 && $disease_1 eq $disease_2 && $allele_requirement_1 eq $allele_requirement_2 && $mutation_consequence_1 eq $mutation_consequence_2) {
    print "Match: entries are the same. Going to check the original allelic requirement and mutation consequence\n";
    
    my $o_allele_requirement_1 = $gfd_1->original_allelic_requirement();
    my $o_allele_requirement_2 = $gfd_2->original_allelic_requirement();
    
    my $o_mutation_consequence_1 = $gfd_1->original_mutation_consequence();
    my $o_mutation_consequence_2 = $gfd_2->original_mutation_consequence();
    
    my $flag = 0;
    
    if($o_allele_requirement_1 eq $o_allele_requirement_2) {
      print " original allelic requirement is the same\n";
    }
    else {
      $flag = 1;
      print " original allelic requirement is not the same\n";
    }
    
    if($o_mutation_consequence_1 eq $o_mutation_consequence_2) {
      print " original mutation consequence is the same\n";
    }
    else {
      $flag = 1;
      print " original mutation consequence is not the same\n";
    }
    
    # entry is exactly the same
    # this is not supposed to happen - database does not allow this scenario
    if($flag == 0) {
      $type = "same_entry";
    }
    # entry is the same but it has different original allelic requirement or original mutation consequence
    # the entry has to be merged
    else {
      $type = "same_entry_dif_original";
    }
  }
  
  return $type;
}

# check some attribs in genomic_feature_disease
# check:
#   cross_cutting_modifier_attrib
#   mutation_consequence_flag_attrib
#   variant_consequence_attrib
#   restricted_mutation_set
#
# Output: new values to be used in the 'new' entry
sub check_gfd_other {
  my $gfd_1 = shift;
  my $gfd_2 = shift;

  my $ccm_1 = $gfd_1->cross_cutting_modifier_attrib();
  my $ccm_2 = $gfd_2->cross_cutting_modifier_attrib();
  
  my $mcf_1 = $gfd_1->mutation_consequence_flag_attrib();
  my $mcf_2 = $gfd_2->mutation_consequence_flag_attrib();
  
  my $vc_1 = $gfd_1->variant_consequence_attrib();
  my $vc_2 = $gfd_2->variant_consequence_attrib();
  
  # restricted_mutation_set is not used anymore
  my $rms_1 = $gfd_1->restricted_mutation_set();
  my $rms_2 = $gfd_2->restricted_mutation_set();
  
  # count number of values for each entry
  # to see which one has more values
  my $count_1 = 0;
  my $count_2 = 0;
  
  if(defined $ccm_1) {
    $count_1 += 1;
  }
  if(defined $mcf_1) {
    $count_1 += 1;
  }
  if(defined $vc_1) {
    $count_1 += 1;
  }
  
  if(defined $ccm_2) {
    $count_2 += 1;
  }
  if(defined $mcf_2) {
    $count_2 += 1;
  }
  if(defined $vc_2) {
    $count_2 += 1;
  }
  
  my $gfd_id_to_keep;
  my %merged_gfd;
  
  if($count_1 >= $count_2) {
    $gfd_id_to_keep = $gfd_1->dbID();
    print "Which entry has more data in GFD? GFD_id = ", $gfd_1->dbID(), "\n";
  }
  else {
    $gfd_id_to_keep = $gfd_2->dbID();
    print "Which entry has more data in GFD? GFD_id = ", $gfd_2->dbID(), "\n";
  }
  
  $merged_gfd{$gfd_id_to_keep}{"cross_cutting_modifier"} = merge_values($ccm_1, $ccm_2);
  $merged_gfd{$gfd_id_to_keep}{"mutation_consequence_flag"} = merge_values($mcf_1, $mcf_2);
  $merged_gfd{$gfd_id_to_keep}{"variant_consequence"} = merge_values($vc_1, $vc_2);

  return \%merged_gfd;
}

sub merge_entries {
  my $gfd_1 = shift;
  my $gfd_2 = shift;
  my $type = shift;

  my $gfd_to_keep;
  my $gfd_to_del;
  my $partial_merged_gfd;

  # we are going to choose one entry to keep
  # first we have to check:
  #   cross_cutting_modifier_attrib
  #   mutation_consequence_flag_attrib
  #   variant_consequence_attrib
  #   restricted_mutation_set - we don't use this anymore
  if($type eq "same_entry_dif_original") {
    # $merged_gfd includes the new values:
    #  cross_cutting_modifier
    #  mutation_consequence_flag
    #  variant_consequence
    $partial_merged_gfd = check_gfd_other($gfd_1, $gfd_2);
    
    # the other GFD values are the same
  }
  
  if(defined $partial_merged_gfd) {
    my @gfd_ids = keys %{$partial_merged_gfd};
    $gfd_to_keep = $gfd_ids[0];
    $gfd_to_del = $gfd_to_keep == $gfd_1->dbID() ? $gfd_2->dbID() : $gfd_1->dbID();
  }
  
  if(defined $gfd_to_keep) {
    print "Going to keep GFD_id = $gfd_to_keep\n\nAnalysing other tables...";
    # check where GFD_id is used in other tables
    # we are going to keep only one gfd_id
    
    # genomic_feature_disease_comment
    my $gfd_1_comments = $gfd_1->get_all_GFDComments();
    my $gfd_2_comments = $gfd_2->get_all_GFDComments();
    my $merged_comments = merge_objects($gfd_1_comments, $gfd_2_comments);
    
    # merge comments
    # different GFDComments could be from the same user and have the same text
    
    
    # genomic_feature_disease_organ
    my $gfd_1_organs = $gfd_1->get_all_GFDOrgans(); # returns a list of GenomicFeatureDiseaseOrgan
    my $gfd_2_organs = $gfd_2->get_all_GFDOrgans(); # returns a list of GenomicFeatureDiseaseOrgan
    my $merged_organs = merge_objects($gfd_1_organs, $gfd_2_organs);
    
    # genomic_feature_disease_panel - important
    my $gfd_1_panels = $gfd_1->get_all_GFDPanels();
    my $gfd_2_panels = $gfd_2->get_all_GFDPanels();
    my $merged_panels = merge_objects($gfd_1_panels, $gfd_2_panels);
    
    # genomic_feature_disease_phenotype
    my $gfd_1_phenotypes = $gfd_1->get_all_GFDPhenotypes();
    my $gfd_2_phenotypes = $gfd_2->get_all_GFDPhenotypes();
    my $merged_phenotypes = merge_objects($gfd_1_phenotypes, $gfd_2_phenotypes);

    # GFD_phenotype_comment - this is part of the object comment
    
    
    # genomic_feature_disease_publication
    my $gfd_1_publications = $gfd_1->get_all_GFDPublications();
    my $gfd_2_publications = $gfd_2->get_all_GFDPublications();
    my $merged_publications = merge_objects($gfd_1_publications, $gfd_2_publications);

    # GFD_publication_comment - this is part of the object publication
    
    # genomic_feature_statistic - not sure about this data
    # genomic_feature_statistic_attrib - not sure about this data
    
    # GFD_disease_synonym - important
    my $gfd_1_synonyms = $gfd_1->get_all_GFDDiseaseSynonyms();
    my $gfd_2_synonyms = $gfd_2->get_all_GFDDiseaseSynonyms();
    my $merged_synonyms = merge_objects($gfd_1_synonyms, $gfd_2_synonyms);
    
    print "\ndone!\n";
    print "\nGoing to update genomic_feature_disease for GFD_id = $gfd_to_keep with merged data\n";
    if(defined $partial_merged_gfd) {
      print Dumper($partial_merged_gfd);
    }
    # Update the GFD
    my $update_gfd_vc = "UPDATE genomic_feature_disease SET variant_consequence_attrib = ? WHERE genomic_feature_disease_id = ?";
    my $update_gfd_mc = "UPDATE genomic_feature_disease SET mutation_consequence_flag_attrib = ? WHERE genomic_feature_disease_id = ?";
    my $update_gfd_ccm = "UPDATE genomic_feature_disease SET cross_cutting_modifier_attrib = ? WHERE genomic_feature_disease_id = ?";
    
    if(scalar @{$merged_comments} > 0) {
      print "  Update comments for GFD_id = $gfd_to_keep\n";
      my $update_gfdcomments = "UPDATE genomic_feature_disease_comment SET genomic_feature_disease_id = ? WHERE genomic_feature_disease_comment_id = ?";
      foreach my $comments (@{$merged_comments}) {
        if($comments->get_GenomicFeatureDisease->dbID() == $gfd_to_del) {
          my $id = $comments->dbID();
          print "  -> Run: UPDATE genomic_feature_disease_comment SET genomic_feature_disease_id = $gfd_to_keep WHERE genomic_feature_disease_comment_id = $id\n";
        }
      }
    }
    
    if(scalar @{$merged_organs} > 0) {
      print "  Update organs for GFD_id = $gfd_to_keep\n";
      my $update_gfdorgan = "UPDATE genomic_feature_disease_organ SET genomic_feature_disease_id = ? WHERE genomic_feature_disease_organ_id = ?";
      foreach my $organ (@{$merged_organs}) {
        if($organ->get_GenomicFeatureDisease->dbID() == $gfd_to_del) {
          my $id = $organ->dbID();
          print "  -> Run: UPDATE genomic_feature_disease_organ SET genomic_feature_disease_id = $gfd_to_keep WHERE genomic_feature_disease_organ_id = $id\n";
        }
      }
    }
    
    if(scalar @{$merged_phenotypes} > 0) {
      print "  Update phenotypes for GFD_id = $gfd_to_keep\n";
      my $update_gfdpheno = "UPDATE genomic_feature_disease_phenotype SET genomic_feature_disease_id = ? WHERE genomic_feature_disease_phenotype_id = ?";
      foreach my $phenotype (@{$merged_phenotypes}) {
        if($phenotype->get_GenomicFeatureDisease->dbID() == $gfd_to_del) {
          my $id = $phenotype->dbID();
          print "  -> Run: UPDATE genomic_feature_disease_phenotype SET genomic_feature_disease_id = $gfd_to_keep WHERE genomic_feature_disease_phenotype_id = $id\n";
        }
      }
    }
    
    if(scalar @{$merged_publications} > 0) {
      print "  Update publications for GFD_id = $gfd_to_keep\n";
      my $update_gfdpublication = "UPDATE genomic_feature_disease_publication SET genomic_feature_disease_id = ? WHERE genomic_feature_disease_publication_id = ?";
      foreach my $publication (@{$merged_publications}) {
        if($publication->get_GenomicFeatureDisease->dbID() == $gfd_to_del) {
          my $id = $publication->dbID();
          print "  -> Run: UPDATE genomic_feature_disease_publication SET genomic_feature_disease_id = $gfd_to_keep WHERE genomic_feature_disease_publication_id = $id\n";
        }
      }
    }
    
    if(scalar @{$merged_synonyms} > 0) {
      print "  Update synonyms for GFD_id = $gfd_to_keep\n";
      my $update_gfd_synonyms = "UPDATE GFD_disease_synonym SET genomic_feature_disease_id = ? WHERE GFD_disease_synonym_id = ?";
      foreach my $synonyms (@{$merged_synonyms}) {
        if($synonyms->genomic_feature_disease_id == $gfd_to_del) {
          my $id = $synonyms->dbID();
          print "  -> Run: UPDATE GFD_disease_synonym SET genomic_feature_disease_id = $gfd_to_keep WHERE GFD_disease_synonym_id = $id\n";
        }
      }
    }
    
    if(scalar @{$merged_panels} > 0) {
      print "  Update panels for GFD_id = $gfd_to_keep\n";
      my $update_gfd_panels = "UPDATE genomic_feature_disease_panel SET genomic_feature_disease_id = ? WHERE genomic_feature_disease_panel_id = ?";
      foreach my $panels (@{$merged_panels}) {
        if($panels->genomic_feature_disease_id == $gfd_to_del) {
          my $id = $panels->dbID();
          print "  -> Run: UPDATE genomic_feature_disease_panel SET genomic_feature_disease_id = $gfd_to_keep WHERE genomic_feature_disease_panel_id = $id\n";
        }
      }
    }
    
    # Remove the GFD
    print "\nGoing to delete GFD_id = $gfd_to_del from genomic_feature_disease\n";
    my $del_gfd = "DELETE FROM genomic_feature_disease WHERE genomic_feature_disease_id = ?";
    print "  -> Run: DELETE FROM genomic_feature_disease WHERE genomic_feature_disease_id = $gfd_to_del\n";
    
  }
  else {
    print "Cannot proceed. No GFD_id to keep was found.\n";
  }
}

# Input 1: string
# Input 2: string
# Return: string of merged strings without duplicates
sub merge_values {
  my $value_1 = shift;
  my $value_2 = shift;
  
  my $new_value;
  
  if(defined $value_1 && defined $value_2 && $value_1 eq $value_2) {
    $new_value = $value_1;
  }
  elsif(defined $value_1 && defined $value_2 && $value_1 ne $value_2) {
    my @values_1 = split(",", $value_1);
    my @values_2 = split(",", $value_2);
    
    my %values_list;
    
    foreach my $value (@values_1) {
      $values_list{$value} = 1 if(!$values_list{$value});
    }
    foreach my $value (@values_2) {
      $values_list{$value} = 1 if(!$values_list{$value});
    }
    
    $new_value = join(",", keys %values_list);
  }
  elsif(defined $value_1 && !defined $value_2) {
    $new_value = $value_1;
  }
  elsif(!defined $value_1 && defined $value_2) {
    $new_value = $value_2;
  }
  else {
    $new_value = undef;
  }
  
  return $new_value;
}

# Input 1: array of objects
# Input 2: array of objects
# Return: array of merged objects without duplicates
sub merge_objects {
  my $list_1 = shift;
  my $list_2 = shift;
  
  my %final_list;
  
  if(scalar(@{$list_1}) > 0) {
    foreach my $element (@{$list_1}) {
      if(ref($element) eq "Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan") {
        $final_list{$element->organ_id} = $element if(!$final_list{$element->organ_id});
      }
      elsif(ref($element) eq "Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype") {
        $final_list{$element->phenotype_id} = $element if(!$final_list{$element->phenotype_id});
      }
      elsif(ref($element) eq "Bio::EnsEMBL::G2P::GenomicFeatureDiseaseComment") {
        $final_list{$element->comment_text} = $element if(!$final_list{$element->comment_text});
      }
      elsif(ref($element) eq "Bio::EnsEMBL::G2P::GenomicFeatureDiseasePublication") {
        $final_list{$element->get_Publication->dbID()} = $element if(!$final_list{$element->get_Publication->dbID()});
      }
      elsif(ref($element) eq "Bio::EnsEMBL::G2P::GFDDiseaseSynonym") {
        $final_list{$element->disease_id."-".$element->genomic_feature_disease_id} = $element if(!$final_list{$element->disease_id."-".$element->genomic_feature_disease_id});
      }
      elsif(ref($element) eq "Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel") {
        $final_list{$element->panel_attrib} = $element if(!$final_list{$element->panel_attrib});
      }
    }
  }
  if(scalar(@{$list_2}) > 0) {
    foreach my $element (@{$list_2}) {
      if(ref($element) eq "Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan") {
        $final_list{$element->organ_id} = $element if(!$final_list{$element->organ_id});
      }
      elsif(ref($element) eq "Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype") {
        $final_list{$element->phenotype_id} = $element if(!$final_list{$element->phenotype_id});
      }
      elsif(ref($element) eq "Bio::EnsEMBL::G2P::GenomicFeatureDiseaseComment") {
        $final_list{$element->comment_text} = $element if(!$final_list{$element->comment_text});
      }
      elsif(ref($element) eq "Bio::EnsEMBL::G2P::GenomicFeatureDiseasePublication") {
        $final_list{$element->get_Publication->dbID()} = $element if(!$final_list{$element->get_Publication->dbID()});
      }
      elsif(ref($element) eq "Bio::EnsEMBL::G2P::GFDDiseaseSynonym") {
        $final_list{$element->disease_id} = $element if(!$final_list{$element->disease_id});
      }
      elsif(ref($element) eq "Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel") {
        $final_list{$element->panel_attrib} = $element if(!$final_list{$element->panel_attrib});
      }
    }
  }

  my @result = values %final_list;
  
  return \@result;
}
