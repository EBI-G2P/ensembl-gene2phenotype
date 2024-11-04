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
use HTTP::Tiny;
use Pod::Usage qw(pod2usage);
use List::MoreUtils qw(uniq);
use JSON;
use Encode qw(decode encode);

use Data::Dumper;

=pod
  Options:
        --registry <file> : registry file pointing to G2P db
        --file <file>     : input file with variants to merge
        --dryrun          : test the script without running the commands on the db

  Usage:
        perl merge_entries_from_file.pl \
          --registry_file ensembl.registry \
          --file entries_to_merge.txt

        perl merge_entries_from_file.pl \
          --registry_file ensembl.registry \
          --file entries_to_merge.txt \
          --dryrun
=cut

my $args = scalar @ARGV;
my $config = {};

GetOptions(
  $config,
  'help|h',
  'registry_file=s',
  'file=s',
  'dryrun',
) or die "Error: Failed to parse command line arguments\n";

pod2usage(1) if ($config->{'help'} || !$args);

foreach my $param (qw/registry_file file/) {
  die ("Argument --$param is required.") unless (defined($config->{$param}));
}

my $dryrun;
if(defined($config->{'dryrun'})) {
  $dryrun = 1;
}

# Connect to DB
my $registry = 'Bio::EnsEMBL::Registry';
my $registry_file = $config->{registry_file};
$registry->load_all($registry_file);

my $dbh = $registry->get_DBAdaptor('human', 'gene2phenotype')->dbc->db_handle; 

my $species = 'human';
my $attrib_adaptor = $registry->get_adaptor($species, 'gene2phenotype', 'Attribute');
my $gf_adaptor     = $registry->get_adaptor($species, 'gene2phenotype', 'GenomicFeature');
my $gfd_adaptor    = $registry->get_adaptor($species, 'gene2phenotype', 'GenomicFeatureDisease');
my $publication_adaptor = $registry->get_adaptor($species, 'gene2phenotype', 'Publication');
my $disease_adaptor = $registry->get_adaptor($species, 'gene2phenotype', 'Disease');

my %panels_list = (dd => 1, cancer => 1, skin => 1, skeletal => 1,
                   cardiac => 1, eye => 1, ear => 1, prenatal => 1,
                   neonatal => 1, rapid_picu_nicu => 1, paedneuro => 1);

# Read input file
# This file has all the entries to be merged
my $data_to_merge = read_file($config->{file});

# Process the data that is going to be merged
process_data($data_to_merge, \%panels_list);

### Methods ###

# Read input file which has entries to be merged
sub read_file {
    my $file = shift;

    my %data_to_merge;
    my $key;
    my $line_number = 1; # header

    open(my $fh, '<', $file) or die $!;

    while(my $line = <$fh>) {
        next if($line =~ /Summary new record/);

        $line = $line =~ s/"//rg;

        chomp $line;

        my @data = split("\t", $line);
        # the first column has the instructions on how to merge the entries
        # "Merge <panels> into <panels>"
        my $id = $data[0];
        my %merge_rules;
        if(defined $id && $id ne "") {
            $line_number += 1;
            $key = $id . " " . $line_number;
            my @list_rules = ($id =~ /Merge (.*) into (.*)/);

            # more complex strings have 'to keep' at the end to indicated the gfd_id to keep
            if($list_rules[1] =~ /; to keep/) {
              my @gfd_id_keep = ($list_rules[1] =~ /; to keep: (.*)/);
              $merge_rules{'keep'} = $gfd_id_keep[0];
            }

            $merge_rules{'from'} = $list_rules[0];
            $merge_rules{'to'} = $list_rules[1];
        }

        if(defined $data_to_merge{$key}) {
          my %data = (
            gfd_id => $data[1],
            gene => $data[2],
            ar => $data[3],
            disease => $data[4],
            mc => $data[5],
            panels => $data[6],
            new_disease => $data[7],
            new_ar => $data[8],
            new_mc => $data[9],
            new_panels => $data[10],
            new_mc_flag => $data[11],
            new_var_cons => $data[12],
            new_pmids => $data[13],
            new_confidence => $data[14]
            );

          push @{$data_to_merge{$key}{'entries'}}, \%data;
        }
        else {
          my %data = (
            gfd_id => $data[1],
            gene => $data[2],
            ar => $data[3],
            disease => $data[4],
            mc => $data[5],
            panels => $data[6],
            new_disease => $data[7],
            new_ar => $data[8],
            new_mc => $data[9],
            new_panels => $data[10],
            new_mc_flag => $data[11],
            new_var_cons => $data[12],
            new_pmids => $data[13],
            new_confidence => $data[14]
            );

          my $new_confidence = $data[14] =~ s/\s+//rg;
          my %new_data = (
            new_disease => $data[7],
            new_ar => $data[8],
            new_mc => $data[9],
            new_panels => $data[10],
            new_mc_flag => $data[11],
            new_var_cons => $data[12],
            new_pmids => $data[13],
            new_confidence => $new_confidence
          );

          my @data_list = (\%data);

          $data_to_merge{$key}{'rules'} = \%merge_rules;
          $data_to_merge{$key}{'entries'} = \@data_list;
          $data_to_merge{$key}{'new_data'} = \%new_data;
        }
    }

    close($fh);

    return \%data_to_merge;
}

# Process the data hash to be merged
# This method calls the method to merge the entries
sub process_data {
  my $data_to_merge = shift;
  my $panels_list = shift;

  for my $key (keys %{$data_to_merge}) {
    print "\n\n$key\n";
    print "Data to merge: ", Dumper($data_to_merge->{$key});

    # Check the rules
    # Some rules have the disease name while others only have the panels
    # Example:
    # 'rules' => {
    #                    'to' => 'DD (monoallelic_X_hem)',
    #                    'from' => 'DD (monoallelic_X_het)'
    #                  }
    # 'rules' => {
    #                    'to' => 'DD-PROGRESSIVE MYOCLONIC EPILEPSY TYPE 3',
    #                    'from' => 'DD-NEURONAL CEROID LIPOFUSCINOSIS'
    #                  }
    # 'rules' => {
    #                    'to' => 'DD (COFFIN-LOWRY SYNDROME)',
    #                    'from' => 'Skin,DD (Coffin-Lowry Syndrome 2 RPS6KA3 XLR)'
    #                  }
    # 'rules' => {
    #                    'to' => 'Eye',
    #                    'from' => 'Skin (both)'
    #                  }
    # 'rules' => {
    #                    'to' => 'DD, Skeletal',
    #                    'from' => 'Eye and Shprintzen-Goldberg craniosynostosis syndrome (DD,Skeletal,Skin)'
    #                  }
    my @rule_from = split /\,\s*/, lc $data_to_merge->{$key}->{'rules'}->{'from'};
    my @rule_to = split /\,\s*/, lc $data_to_merge->{$key}->{'rules'}->{'to'};

    # Check if it only has panel names
    my $not_found = 0;
    for my $panel (@rule_from) {
      if(!defined $panels_list{$panel}) {
        $not_found = 1;
      }
    }
    for my $panel (@rule_to) {
      if(!defined $panels_list{$panel}) {
        $not_found = 1;
      }
    }

    my $gfd_to_keep;

    # The rules only have panel names
    # The merge is simple
    if(!$not_found) {
      $gfd_to_keep = get_final_gfd($data_to_merge->{$key}->{'entries'}, $data_to_merge->{$key}->{'rules'}->{'to'}, \@rule_from);
    }
    # In this case the rules are not so simple
    # it can include the disease names or other types of data
    # sometimes two entries have the same panel with a different disease name
    elsif(defined $data_to_merge->{$key}->{'rules'}->{'keep'}) {
      $gfd_to_keep = get_final_gfd($data_to_merge->{$key}->{'entries'}, $data_to_merge->{$key}->{'rules'}->{'to'}, \@rule_from, $data_to_merge->{$key}->{'rules'}->{'keep'});
    }
    else {
      die("ERROR: cannot merge entry '$key'\n");
    }

    merge_entries($data_to_merge->{$key}->{'entries'}, $gfd_to_keep, $data_to_merge->{$key}->{'new_data'});
  }

}

# Get the gfd_id to keep
sub get_final_gfd {
  my $entries = shift; # (list of hashes)
  my $merge_into = shift; # (string) merge into entry from these panels
  my $merge_from = shift; # (list) merge from these panels
  my $keep = shift;

  my $gfd_id_keep; # gfd_id to keep - entries are going to be merge into this one

  $gfd_id_keep = defined $keep ? $keep : undef;

  if(!defined $gfd_id_keep) {
    for my $entry (@{$entries}) {
      my $entry_panels = $entry->{'panels'} =~ s/\s*//rg;
      $merge_into = $merge_into =~ s/\s*//rg;

      # print "From ", lc($entry_panels), " to ", lc($merge_into), "\n";

      if(lc($entry_panels) eq lc($merge_into)) {
        $gfd_id_keep = $entry->{'gfd_id'};
      }
    }
  }

  # Check again if gfd_id is defined
  # At this point it should be defined
  if(!defined $gfd_id_keep) {
    die("ERROR: gfd_id to merge into not found ", Dumper($entries));
  }
  else {
    print "Keep: $gfd_id_keep\n";
  }

  return $gfd_id_keep;
}

sub merge_entries {
  my $entries = shift;
  my $gfd_to_keep = shift;
  my $new_data = shift;

  # Get the GenomicFeatureDisease
  my $gfd = get_genomic_feature_disease($gfd_to_keep);

  # One of the entries is the GFD to keep
  # The new data is stored in this entry
  for my $entry (@{$entries}) {
    # gfd to keep
      if($entry->{'gfd_id'} eq $gfd_to_keep) {

      }
      else {
        # these are the entries to be merged in gfd_to_keep
        # check if gfd_id match the entry data
        my $match = check_entry($entry->{'gfd_id'}, $entry->{'disease'}, $entry->{'ar'}, $entry->{'gene'}, $entry->{'mc'});

        if(!$match) {
          die("ERROR: gfd_id ", $entry->{'gfd_id'}, " does not match the entry data\n");
        }

        my $gfd_id_to_delete = $entry->{'gfd_id'};
        my $gfd_to_merge = get_genomic_feature_disease($entry->{'gfd_id'});

        ### Merge comments ###
        my $update_gfdcomments = "UPDATE genomic_feature_disease_comment SET genomic_feature_disease_id = ? WHERE genomic_feature_disease_comment_id = ?";
        my $gfd_to_merge_comments = $gfd_to_merge->get_all_GFDComments();
        
        for my $comment (@{$gfd_to_merge_comments}) {
          my $comment_id = $comment->dbID();
          
          print "RUN: UPDATE genomic_feature_disease_comment SET genomic_feature_disease_id = $gfd_to_keep WHERE genomic_feature_disease_comment_id = $comment_id\n";

          if(!$dryrun){
            my $sth_comments = $dbh->prepare($update_gfdcomments);
            $sth_comments->execute($gfd_to_keep, $comment_id) or die $dbh->errstr;
          }
        }

        ### Merge organs ###
        my $update_gfdorgan = "UPDATE genomic_feature_disease_organ SET genomic_feature_disease_id = ? WHERE genomic_feature_disease_organ_id = ?";
        my $gfd_keep_organs = $gfd->get_all_GFDOrgans(); # to keep
        my $gfd_to_merge_organs = $gfd_to_merge->get_all_GFDOrgans(); # returns a list of GenomicFeatureDiseaseOrgan

        # We have to make sure the organ is not already linked to the GFD
        my %current_organs;
        for my $organ (@{$gfd_keep_organs}) {
          $current_organs{$organ->organ_id()} = 1;
        }

        for my $gfd_organ (@{$gfd_to_merge_organs}) {
          my $gfd_organ_id = $gfd_organ->dbID();

          if(!defined $current_organs{$gfd_organ->organ_id()}){
            print "RUN: UPDATE genomic_feature_disease_organ SET genomic_feature_disease_id = $gfd_to_keep WHERE genomic_feature_disease_organ_id = $gfd_organ_id\n";

            if(!$dryrun){
              my $sth_organs = $dbh->prepare($update_gfdorgan);
              $sth_organs->execute($gfd_to_keep, $gfd_organ_id) or die $dbh->errstr;
            }
          }
        }

        ### Merge phenotypes ###
        my $update_gfdpheno = "UPDATE genomic_feature_disease_phenotype SET genomic_feature_disease_id = ? WHERE genomic_feature_disease_phenotype_id = ?";
        my $gfd_keep_phenos = $gfd->get_all_GFDPhenotypes(); # to keep
        my $gfd_to_merge_phenos = $gfd_to_merge->get_all_GFDPhenotypes();

        # We have to make sure the phenotype is not already linked to the GFD
        my %current_phenos;
        for my $pheno (@{$gfd_keep_phenos}) {
          $current_phenos{$pheno->phenotype_id()} = 1;
        }

        for my $gfd_pheno (@{$gfd_to_merge_phenos}) {
          my $gfd_pheno_id = $gfd_pheno->dbID();

          if(!defined $current_phenos{$gfd_pheno->phenotype_id()}){
            print "RUN: UPDATE genomic_feature_disease_phenotype SET genomic_feature_disease_id = $gfd_to_keep WHERE genomic_feature_disease_phenotype_id = $gfd_pheno_id\n";

            if(!$dryrun){
              my $sth_phenos = $dbh->prepare($update_gfdpheno);
              $sth_phenos->execute($gfd_to_keep, $gfd_pheno_id) or die $dbh->errstr;
            }
          }
        }

        ### Merge publications ###
        my $update_gfdpublication = "UPDATE genomic_feature_disease_publication SET genomic_feature_disease_id = ? WHERE genomic_feature_disease_publication_id = ?";
        my $gfd_keep_publications = $gfd->get_all_GFDPublications(); # to keep
        my $gfd_to_merge_publications = $gfd_to_merge->get_all_GFDPublications();

        # We have to make sure the publication is not already linked to the GFD
        my %current_publications;
        for my $publication (@{$gfd_keep_publications}) {
          $current_publications{$publication->get_Publication()->publication_id()} = 1;
        }

        for my $gfd_pub (@{$gfd_to_merge_publications}) {
          my $pub_id = $gfd_pub->get_Publication()->publication_id();
          my $gfd_pub_id = $gfd_pub->dbID();

          if(!defined $current_publications{$pub_id}){
            print "RUN: UPDATE genomic_feature_disease_publication SET genomic_feature_disease_id = $gfd_to_keep WHERE genomic_feature_disease_publication_id = $gfd_pub_id\n";

            if(!$dryrun){
              my $sth_pubs = $dbh->prepare($update_gfdpublication);
              $sth_pubs->execute($gfd_to_keep, $gfd_pub_id) or die $dbh->errstr;
              $current_publications{$pub_id} = 1;
            }
          }
        }

        ### Merge disease synonym ###
        my $update_gfd_synonyms = "UPDATE GFD_disease_synonym SET genomic_feature_disease_id = ? WHERE GFD_disease_synonym_id = ?";
        my $gfd_keep_ds = $gfd->get_all_GFDDiseaseSynonyms(); # to keep
        my $gfd_to_merge_ds = $gfd_to_merge->get_all_GFDDiseaseSynonyms();

        # We have to make sure the disease synonym is not already linked to the GFD
        my %current_ds;
        for my $ds (@{$gfd_keep_ds}) {
          $current_ds{$ds->disease_id()} = 1;
        }

        for my $gfd_ds (@{$gfd_to_merge_ds}) {
          my $gfd_ds_id = $gfd_ds->dbID();
          my $gfd_disease = $gfd_ds->disease_id();

          if(!defined $current_ds{$gfd_disease}){
            print "RUN: UPDATE GFD_disease_synonym SET genomic_feature_disease_id = $gfd_to_keep WHERE GFD_disease_synonym_id = $gfd_ds_id\n";

            if(!$dryrun){
              my $sth_ds = $dbh->prepare($update_gfd_synonyms);
              $sth_ds->execute($gfd_to_keep, $gfd_ds_id) or die $dbh->errstr;
            }
          }
        }

        ### Merge panel ###
        my $update_gfd_panels = "UPDATE genomic_feature_disease_panel SET genomic_feature_disease_id = ? WHERE genomic_feature_disease_panel_id = ?";
        my $gfd_keep_panels = $gfd->get_all_GFDPanels(); # to keep
        my $gfd_to_merge_panels = $gfd_to_merge->get_all_GFDPanels();

        # We have to make sure the panel is not already linked to the GFD
        my %current_panels;
        for my $panel (@{$gfd_keep_panels}) {
          $current_panels{$panel->panel_attrib()} = 1;
        }

        for my $gfd_panel (@{$gfd_to_merge_panels}) {
          my $gfd_panel_id = $gfd_panel->dbID();

          if(!defined $current_panels{$gfd_panel->panel_attrib()}){
            print "RUN: UPDATE genomic_feature_disease_panel SET genomic_feature_disease_id = $gfd_to_keep WHERE genomic_feature_disease_panel_id = $gfd_panel_id\n";

            if(!$dryrun){
              my $sth_panel = $dbh->prepare($update_gfd_panels);
              $sth_panel->execute($gfd_to_keep, $gfd_panel_id) or die $dbh->errstr;
            }
          }
        }

        # Merge variant_consequence + add new terms
        my $update_gfd_vc = "UPDATE genomic_feature_disease SET variant_consequence_attrib = ? WHERE genomic_feature_disease_id = ?";
        my $gfd_var_cons_keep = $gfd->variant_consequence(); # term
        my $gfd_var_cons_merge = $gfd_to_merge->variant_consequence(); # term

        my $new_var_cons = get_final_attribs($gfd_var_cons_keep, $gfd_var_cons_merge, $new_data->{'new_var_cons'}, "variant_consequence");

        if(defined $new_var_cons) {
          print "RUN: UPDATE genomic_feature_disease SET variant_consequence_attrib = ('$new_var_cons') WHERE genomic_feature_disease_id = $gfd_to_keep\n";

          if(!$dryrun){
            my $sth_vc = $dbh->prepare($update_gfd_vc);
            $sth_vc->execute($new_var_cons, $gfd_to_keep) or die $dbh->errstr;
          }
        }

        # Merge mutation consequence flag + add new terms
        my $update_gfd_mc = "UPDATE genomic_feature_disease SET mutation_consequence_flag_attrib = ? WHERE genomic_feature_disease_id = ?";
        my $gfd_mc_keep = $gfd->mutation_consequence_flag(); # terms
        my $gfd_mc_merge = $gfd_to_merge->mutation_consequence_flag(); # terms

        my $new_mc_flags = get_final_attribs($gfd_mc_keep, $gfd_mc_merge, $new_data->{'new_mc_flag'}, "mutation_consequence_flag");

        if(defined $new_mc_flags) {
          print "RUN: UPDATE genomic_feature_disease SET mutation_consequence_flag_attrib = ('$new_mc_flags') WHERE genomic_feature_disease_id = $gfd_to_keep\n";

          if(!$dryrun){
            my $sth_mc = $dbh->prepare($update_gfd_mc);
            $sth_mc->execute($new_mc_flags, $gfd_to_keep) or die $dbh->errstr;
          }
        }

        # Merge mutation consequence + add new terms
        my $update_gfd_mutation = "UPDATE genomic_feature_disease SET mutation_consequence_attrib = ? WHERE genomic_feature_disease_id = ?";
        my $gfd_mutation_keep = $gfd->mutation_consequence(); # terms
        my $gfd_mutation_merge = $gfd_to_merge->mutation_consequence(); # terms

        my $new_mutation = get_final_attribs($gfd_mutation_keep, $gfd_mutation_merge, $new_data->{'new_mc'}, "mutation_consequence");

        if(defined $new_mutation) {
          # Check if entry already exists
          my $found = check_duplicate_gfd($gfd, $new_mutation, "mutation_consequence_attrib");

          if($found == 1) {
            die("ERROR: gfd already exists. Check gfd_id $gfd_to_keep\n");
          }

          print "RUN: UPDATE genomic_feature_disease SET mutation_consequence_attrib = ('$new_mutation') WHERE genomic_feature_disease_id = $gfd_to_keep\n";

          if(!$dryrun){
            my $sth_mutation = $dbh->prepare($update_gfd_mutation);
            $sth_mutation->execute($new_mutation, $gfd_to_keep) or die $dbh->errstr;
          }
        }

        # Update allelic requeriment
        my $update_gfd_ar = "UPDATE genomic_feature_disease SET allelic_requirement_attrib = ? WHERE genomic_feature_disease_id = ?";
        my $gfd_ar_keep = $gfd->allelic_requirement(); # terms

        if(defined $new_data->{'new_ar'} && $new_data->{'new_ar'} ne "" && $gfd_ar_keep ne $new_data->{'new_ar'}) {
          my $ar_id = $attrib_adaptor->attrib_id_for_type_value("allelic_requirement", $new_data->{'new_ar'});

          if(!defined $ar_id) {
            die("ERROR: cannot find attrib_id for ", $new_data->{'new_ar'}, "\n");
          }

          my $found_2 = check_duplicate_gfd($gfd, $ar_id, "allelic_requirement_attrib");

          if($found_2 == 1) {
            die("ERROR: gfd already exists. Check gfd_id $gfd_to_keep\n");
          }

          print "RUN: UPDATE genomic_feature_disease SET allelic_requirement_attrib = ('$ar_id') WHERE genomic_feature_disease_id = $gfd_to_keep\n";

          if(!$dryrun){
            my $sth_ar = $dbh->prepare($update_gfd_ar);
            $sth_ar->execute($ar_id, $gfd_to_keep) or die $dbh->errstr;
          }
        }

        # Add panels
        my $add_gfd_panels = "INSERT INTO genomic_feature_disease_panel(genomic_feature_disease_id, confidence_category_attrib, clinical_review, is_visible, panel_attrib) VALUES(?,?,?,?,?)";
        my $gfd_panels_current = $gfd->get_all_GFDPanels();

        # Get current confidence
        my $confidence_current;
        for my $gfd_panel_obj (@{$gfd_panels_current}) {
          $confidence_current = $gfd_panel_obj->confidence_category_attrib();
        }

        if(!defined $confidence_current) {
          die("ERROR: cannot fetch a confidence value for gfd_id = $gfd_to_keep\n");
        }

        if(defined $new_data->{'new_panels'} && $new_data->{'new_panels'} ne "") {
          my $panel_attrib_id = $attrib_adaptor->attrib_id_for_type_value("g2p_panel", $new_data->{'new_panels'});

          if(!defined $panel_attrib_id) {
            die("ERROR: cannot find attrib_id for ", $new_data->{'new_panels'}, "\n");
          }

          print "RUN: $add_gfd_panels\n";

          if(!$dryrun){
            my $sth_panels = $dbh->prepare($add_gfd_panels);
            $sth_panels->execute($gfd_to_keep, $confidence_current, 0, 1, $panel_attrib_id) or die $dbh->errstr;
          }
        }

        # Update confidence
        if(defined $new_data->{'new_confidence'} && $new_data->{'new_confidence'} ne "") {
          my $update_gfd_panel_confidence = "UPDATE genomic_feature_disease_panel SET confidence_category_attrib = ?, clinical_review = ? WHERE genomic_feature_disease_id = ?";

          my $confidence_attrib_id = $attrib_adaptor->attrib_id_for_type_value("confidence_category", lc $new_data->{'new_confidence'});

          if(!defined $confidence_attrib_id) {
            die("ERROR: cannot find confidence ", lc $new_data->{'new_confidence'}, "\n");
          }

          # Set clinical review
          my $clinical_review;
          if($confidence_attrib_id eq "51") {
            $clinical_review = 1;
          }
          else {
            $clinical_review = 0;
          }

          print "RUN: UPDATE genomic_feature_disease_panel SET confidence_category_attrib = $confidence_attrib_id, clinical_review = $clinical_review WHERE genomic_feature_disease_id = $gfd_to_keep\n";

          if(!$dryrun){
            my $sth_gfd_confidence = $dbh->prepare($update_gfd_panel_confidence);
            $sth_gfd_confidence->execute($confidence_attrib_id, $clinical_review, $gfd_to_keep) or die $dbh->errstr;
          }
        }

        # Add publications
        my $query_by_pmid = 'https://www.ebi.ac.uk/europepmc/webservices/rest/search/query=ext_id:';
        my $add_publication = "INSERT INTO publication(pmid, title, source) VALUES(?,?,?)";
        my $add_gfd_publication = "INSERT INTO genomic_feature_disease_publication(genomic_feature_disease_id, publication_id) VALUES(?,?)";

        if(defined $new_data->{'new_pmids'} && $new_data->{'new_pmids'} ne "") {
          my @pmids = split /,|;\s*/, $new_data->{'new_pmids'};

          for my $pmid (@pmids) {
            my $g2p_publication = $publication_adaptor->fetch_by_PMID($pmid);

            if(!defined $g2p_publication) {
              my $query = $query_by_pmid.$pmid;
              $query =~ s/\s*//g;
              my $response = run_query($query);

              if(!defined $response) {
                die("ERROR: cannot fetch publication $pmid\n");
              }

              my $results = parse_publication_attribs($response);

              if(scalar(@{$results}) == 0) {
                die("ERROR: cannot parse publication $pmid\n");
              }

              foreach my $result (@$results) {
                my ($tmp_pmid, $title, $source) = @{$result};
                if ($title && $source) {
                  print "RUN: $add_publication ($pmid, $title, $source)\n";

                  if(!$dryrun){
                    my $sth_add_pub = $dbh->prepare($add_publication);
                    $sth_add_pub->execute($pmid, $title, $source) or die $dbh->errstr;
                  }
                }
                else {
                  die("ERROR: cannot find publication $pmid\n");
                }
              }
            }

            # Add gfd_publication
            # Fetch the publication inserted
            $g2p_publication = $publication_adaptor->fetch_by_PMID($pmid);

            # Check publications already linked to GFD
            $gfd_keep_publications = $gfd->get_all_GFDPublications(); # to keep

            for my $publication (@{$gfd_keep_publications}) {
              $current_publications{$publication->get_Publication()->publication_id()} = 1;
            }

            if(!$dryrun){
              # Only insert new gfd_publication if publication is not linked already
              if(defined $g2p_publication && !defined $current_publications{$g2p_publication->dbID()}) {
                print "RUN: $add_gfd_publication ($gfd_to_keep, ", $g2p_publication->dbID(), ")\n";
                my $sth_add_gfd_pub = $dbh->prepare($add_gfd_publication);
                $sth_add_gfd_pub->execute($gfd_to_keep, $g2p_publication->dbID()) or die $dbh->errstr;
              }
              else {
                print("WARNING: problem with publication $pmid\n");
              }
            }
          }
        }

        # Merge cross cutting modifier - the file does not include new terms
        my $update_gfd_ccm = "UPDATE genomic_feature_disease SET cross_cutting_modifier_attrib = ? WHERE genomic_feature_disease_id = ?";
        my $gfd_ccm_keep = $gfd->cross_cutting_modifier(); # terms
        my $gfd_ccm_merge = $gfd_to_merge->cross_cutting_modifier(); # terms

        my $new_ccm = get_final_attribs($gfd_ccm_keep, $gfd_ccm_merge, undef, "cross_cutting_modifier");

        if(defined $new_ccm) {
          print "RUN: UPDATE genomic_feature_disease SET cross_cutting_modifier_attrib = ('$new_ccm') WHERE genomic_feature_disease_id = $gfd_to_keep\n";

          if(!$dryrun){
            my $sth_ccm = $dbh->prepare($update_gfd_ccm);
            $sth_ccm->execute($new_ccm, $gfd_to_keep) or die $dbh->errstr;
          }
        }

        # Update disease name
        my $add_disease = "INSERT INTO disease(name, mim) VALUES(?, ?)";
        my $add_disease_ontology = "INSERT INTO disease_ontology_mapping(disease_id, ontology_term_id, mapped_by_attrib) VALUES(?,?,?)";
        my $add_gfd_disease_synonym = "INSERT INTO GFD_disease_synonym(genomic_feature_disease_id, disease_id) VALUES(?,?)";
        my $select_gfd_disease_synonym = "SELECT GFD_disease_synonym_id FROM GFD_disease_synonym WHERE genomic_feature_disease_id = ? and disease_id = ?";
        my $update_disease = "UPDATE genomic_feature_disease SET disease_id = ? WHERE genomic_feature_disease_id = ?";

        # We need the current disease id to add gfd_disease_synonym
        my $current_disease = $gfd->get_Disease();

        if(defined $new_data->{'new_disease'} && $new_data->{'new_disease'} ne "" && $new_data->{'new_disease'} ne $current_disease->name()) {
          my $current_disease_id = $current_disease->dbID();
          my $mim = $current_disease->mim();
          my $disease_ontology = $current_disease->get_DiseaseOntology();
          my $disease_ontology_to_merge = $gfd_to_merge->get_Disease()->get_DiseaseOntology();
          my %disease_ontology_added;

          my $disease = $disease_adaptor->fetch_by_name($new_data->{'new_disease'});

          # Insert new disease
          if(!defined $disease) {
            # Check mim
            if(!defined $mim) {
              $mim = $gfd_to_merge->get_Disease()->mim();
            }

            print "RUN: $add_disease (", $new_data->{'new_disease'}, ", $mim)\n";

            if(!$dryrun) {
              my $sth_disease = $dbh->prepare($add_disease);
              $sth_disease->execute($new_data->{'new_disease'}, $mim) or die $dbh->errstr;
            }
          }

          # Fetch disease again
          $disease = $disease_adaptor->fetch_by_name($new_data->{'new_disease'});

          if(defined $disease) {
            if(!$dryrun) {
              my $disease_id = $disease->dbID();

              # Update GFD disease
              print "RUN: UPDATE genomic_feature_disease SET disease_id = $disease_id WHERE genomic_feature_disease_id = $gfd_to_keep\n";

              my $sth_gfd_disease = $dbh->prepare($update_disease);
              $sth_gfd_disease->execute($disease_id, $gfd_to_keep) or die $dbh->errstr;

              # Insert GFD_disease_synonym
              # Check if entry already exists
              my $sth_sel_syn = $dbh->prepare($select_gfd_disease_synonym);
              $sth_sel_syn->execute($gfd_to_keep, $current_disease_id) or die $dbh->errstr;
              my $results = $sth_sel_syn->fetchall_arrayref();

              if(!defined $results || scalar(@{$results}) == 0) {
                print "RUN: $add_gfd_disease_synonym ($gfd_to_keep, $current_disease_id)\n";

                my $sth_gfd_disease_syn = $dbh->prepare($add_gfd_disease_synonym);
                $sth_gfd_disease_syn->execute($gfd_to_keep, $current_disease_id) or die $dbh->errstr;
              }

              # Insert disease ontology
              if(defined $disease_ontology && scalar(@{$disease_ontology} > 0)) {
                for my $ontology (@{$disease_ontology}){
                  my $mapped_by_attrib = $ontology->mapped_by_attrib();
                  my $ontology_term_id = $ontology->ontology_term_id();

                  print "RUN: $add_disease_ontology ($disease_id, $ontology_term_id, $mapped_by_attrib)\n";

                  my $sth_gfd_disease_ot = $dbh->prepare($add_disease_ontology);
                  $sth_gfd_disease_ot->execute($disease_id, $ontology_term_id, $mapped_by_attrib) or die $dbh->errstr;

                  $disease_ontology_added{$ontology_term_id} = 1;
                }
              }

              # Insert disease ontology from gfd to be merged
              if(defined $disease_ontology_to_merge && scalar(@{$disease_ontology_to_merge} > 0)) {
                for my $ontology (@{$disease_ontology_to_merge}){
                  my $mapped_by_attrib = $ontology->mapped_by_attrib();
                  my $ontology_term_id = $ontology->ontology_term_id();

                  if(!defined $disease_ontology_added{$ontology_term_id}) {
                    print "RUN: $add_disease_ontology ($disease_id, $ontology_term_id, $mapped_by_attrib)\n";

                    my $sth_gfd_disease_ot_2 = $dbh->prepare($add_disease_ontology);
                    $sth_gfd_disease_ot_2->execute($disease_id, $ontology_term_id, $mapped_by_attrib) or die $dbh->errstr;

                    $disease_ontology_added{$ontology_term_id} = 1;
                  }
                }
              }
            }
          }
          elsif(!$dryrun) {
            die("ERROR: problem with new disease: ", $new_data->{'new_disease'}, "\n");
          }
        }

        # Delete entry that was merged
        print "Message: start deleting data\n";
        my $del_gfd = "DELETE FROM genomic_feature_disease WHERE genomic_feature_disease_id = ?";
        print "RUN: DELETE FROM genomic_feature_disease WHERE genomic_feature_disease_id = $gfd_id_to_delete\n";

        if(!$dryrun) {
          my $sth_del = $dbh->prepare($del_gfd);
          $sth_del->execute($gfd_id_to_delete) or die $dbh->errstr;
        }

        # Check if there are entries still using the deleted GFD_id
        find_in_tables($gfd_id_to_delete);

      }
  }
}


### Utils ###
# Check if gfd_id match the data in the input file
sub check_entry {
  my $gfd_id = shift;
  my $disease_name = shift;
  my $allelic_requirement = shift;
  my $gene = shift;
  my $mutation_consequence = shift;

  my $match = 1;

  my $gfd = get_genomic_feature_disease($gfd_id);
  my $gfd_disease_name = $gfd->get_Disease()->name();
  my $gfd_ar = $gfd->allelic_requirement();
  my $gfd_mc = $gfd->mutation_consequence();
  my $gfd_gene = $gfd->get_GenomicFeature()->gene_symbol();

  $gfd_disease_name =~ s/^\s*(.*?)\s*$/$1/;

  if($disease_name eq $gfd_disease_name || $disease_name eq $gfd_gene."-related ".$gfd_disease_name || lc $disease_name eq lc $gfd_disease_name) {
    $match = 1;
  }
  else {
    $match = 0;
    print "WARNING: gfd_id $gfd_id disease name ($gfd_disease_name) does not match disease name from input file ($disease_name)\n";
  }

  if($gene ne $gfd_gene) {
    $match = 0;
    print "WARNING: gfd_id $gfd_id gene ($gfd_gene) does not match gene from input file ($gene)\n";
  }

  return $match;
}

# Check if future gfd already exists
sub check_duplicate_gfd {
  my $gfd_to_keep = shift;
  my $new_data = shift; # can be mutation consequence attribs, allelic requeriment attribs
  my $type = shift;

  my $gf = $gfd_to_keep->get_GenomicFeature();
  my $mc;
  my $ar;
  my $disease_id;
  my $found = 0;

  if($type eq "mutation_consequence_attrib") {
    $mc = $new_data;
    $ar = $gfd_to_keep->allelic_requirement_attrib();
    $disease_id = $gfd_to_keep->disease_id();
  }
  elsif($type eq "allelic_requirement_attrib") {
    $ar = $new_data;
    $mc = $gfd_to_keep->mutation_consequence_attrib();
    $disease_id = $gfd_to_keep->disease_id();
  }
  elsif($type eq "disease_id") {
    $disease_id = $new_data;
    $mc = $gfd_to_keep->mutation_consequence_attrib();
    $ar = $gfd_to_keep->allelic_requirement_attrib();
  }

  my $constraints = {
    'allelic_requirement_attrib' => $ar,
    'mutation_consequence_attrib' => $mc,
    'disease_id' => $disease_id
  };

  my $gfd_list = $gfd_adaptor->fetch_all_by_GenomicFeature_constraints($gf, $constraints);

  for my $found_gfd (@{$gfd_list}) {
    if($found_gfd->dbID() ne $gfd_to_keep->dbID()) {
      $found = 1;
    }
  }

  return $found;
}

sub get_final_attribs {
  my $gfd_var_cons_keep = shift;
  my $gfd_var_cons_merge = shift;
  my $new_var_cons = shift;
  my $type = shift;

  my @final_var_cons;
  my @final_var_cons_ids;
  my $final_ids;

  if(defined $gfd_var_cons_keep) {
    push @final_var_cons, split /\,\s*/, $gfd_var_cons_keep;
  }

  if(defined $gfd_var_cons_merge && $gfd_var_cons_merge ne "") {
    push @final_var_cons, split /\,\s*/, $gfd_var_cons_merge;
  }

  if(defined $new_var_cons && $new_var_cons ne "") {
    push @final_var_cons, split /\,\s*/, $new_var_cons;
  }

  # Convert terms to attrib_ids
  for my $cons (@final_var_cons) {
    # skip 'whole/partial deletion'
    if($cons eq "whole/partial deletion" || $cons eq "Whole/partial gene deletion") {
      next;
    }

    if($type eq "mutation_consequence") {
      $cons = lc $cons;
      $cons =~ s/_/ /g;
    }

    my $var_cons_id = $attrib_adaptor->attrib_id_for_type_value($type, $cons);

    if(!defined $var_cons_id) {
      die("ERROR: attrib_id not found: $cons\n");
    }

    push @final_var_cons_ids, $var_cons_id;
  }

  if(scalar(@final_var_cons_ids) > 0) {
    # delete duplicated values
    my @final_var_cons_ids_uniq = uniq @final_var_cons_ids;

    $final_ids = join(",", @final_var_cons_ids_uniq);
    return $final_ids;
  }
  else {
    return undef;
  }
}

sub get_genomic_feature_disease {
  my $entry_id = shift;

  my $gfd = $gfd_adaptor->fetch_by_dbID($entry_id);

  if(!defined $gfd) {
    die("ERROR: Could not find GenomicFeatureDisease dbID = $entry_id\n");
  }

  return $gfd;
}

sub run_query {
  my $query = shift;
  $query =~ s/\s+/+/g;
  $query =~ s/\?/%3F/g;

  my $http = HTTP::Tiny->new();
  my $response = $http->get($query.'&format=json');
  die "Failed !\n" unless $response->{success};
  return $response;
}

sub parse_publication_attribs {
  my $response = shift;
  my @results = ();
  if (length $response->{content}) {
    my $hash = decode_json($response->{content});
    foreach my $result (@{$hash->{resultList}->{result}}) {
      my ($pmid, $title, $source) = (undef, undef, undef);
      $pmid = $result->{pmid};
      $title = $result->{title};
      if ($title) {
        $title =~ s/'/\\'/g;
        $title = encode('utf8', $title);
      }
      my $journalTitle = $result->{journalTitle};
      my $journalVolume = $result->{journalVolume};
      my $pageInfo = $result->{pageInfo};
      my $pubYear = $result->{pubYear}; 
      $source .= "$journalTitle. " if ($journalTitle);
      $source .= "$journalVolume: " if ($journalVolume);
      $source .= "$pageInfo, " if ($pageInfo);
      $source .= "$pubYear." if ($pubYear);
      if ($source) {
        $source =~ s/'/\\'/g;
        $source = encode('utf8', $source);
      }
      $pmid = encode('utf8', $pmid);
      push  @results, [$pmid, $title, $source];
    }
  }

  return \@results;
}

# Checks if the GFD_ID is in any of the tables
# If found, deletes the entries from the table
sub find_in_tables {
  my $gfd_id = shift;

  my @tables = qw { genomic_feature_disease_comment genomic_feature_disease_organ genomic_feature_disease_panel
                   genomic_feature_disease_phenotype genomic_feature_disease_publication GFD_disease_synonym };

  foreach my $table (@tables) {
    my $select = "SELECT genomic_feature_disease_id FROM $table WHERE genomic_feature_disease_id = $gfd_id";
    my $sth_sel = $dbh->prepare($select);
    $sth_sel->execute() or die $dbh->errstr;
    my $results = $sth_sel->fetchall_arrayref();

    if(defined $results->[0]->[0]) {
      print "Going to delete GFD_id = $gfd_id from $table\n";
      my $del = "DELETE FROM $table WHERE genomic_feature_disease_id = $gfd_id";
      print "RUN: $del\n";

      if(!$dryrun) {
        my $sth_del = $dbh->prepare($del);
        $sth_del->execute() or die $dbh->errstr;
      }
    }
  }

  # Check extra table
  my $table = "genomic_feature_disease_panel_log";

  my $insert = "INSERT INTO genomic_feature_disease_panel_log_deleted(genomic_feature_disease_panel_id, genomic_feature_disease_id, original_confidence_category_attrib, confidence_category_attrib, clinical_review, is_visible, panel_attrib, created, user_id, action) VALUES(?,?,?,?,?,?,?,?,?,?)";
  my $delete = "DELETE FROM genomic_feature_disease_panel_log where genomic_feature_disease_panel_log_id = ?";

  my $select = "SELECT * FROM $table WHERE genomic_feature_disease_id = $gfd_id";
  my $sth_sel = $dbh->prepare($select);
  $sth_sel->execute() or die $dbh->errstr;
  my $results = $sth_sel->fetchall_arrayref();

  for my $result (@{$results}) {
    print "GFD_id = $gfd_id found in $table (", $result->[10], ")\n";

    print "INSERT INTO genomic_feature_disease_panel_log_deleted\n";
    my $sth_ins = $dbh->prepare($insert);
    $sth_ins->execute($result->[1], $result->[2], $result->[3], $result->[4], $result->[5], $result->[6], $result->[7], $result->[8], $result->[9], $result->[10]) or die $dbh->errstr;

    print "DELETE FROM genomic_feature_disease_panel_log\n";
    my $sth_del = $dbh->prepare($delete);
    $sth_del->execute($result->[0]) or die $dbh->errstr;
  }
}