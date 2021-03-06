=head1 LICENSE
 
See the NOTICE file distributed with this work for additional information
regarding copyright ownership.
 
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0
 
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 
=cut
use strict;
use warnings;

package Bio::EnsEMBL::G2P::GenomicFeatureDisease;

use Bio::EnsEMBL::Storable;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

our @ISA = ('Bio::EnsEMBL::Storable');

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;
  my ($genomic_feature_disease_id, $genomic_feature_id, $disease_id, $allelic_requirement, $allelic_requirement_attrib, $mutation_consequence, $mutation_consequence_attrib, $confidence_category, $confidence_category_attrib, $is_visible, $panel, $panel_attrib, $restricted_mutation_set, $adaptor) =
    rearrange(['genomic_feature_disease_id', 'genomic_feature_id', 'disease_id', 'allelic_requirement', 'allelic_requirement_attrib', 'mutation_consequence', 'mutation_consequence_attrib', 'confidence_category', 'confidence_category_attrib', 'is_visible', 'panel', 'panel_attrib', 'restricted_mutation_set', 'adaptor'], @_);

  my $self = bless {
    'dbID' => $genomic_feature_disease_id,
    'adaptor' => $adaptor,
    'genomic_feature_disease_id' => $genomic_feature_disease_id,
    'genomic_feature_id' => $genomic_feature_id,
    'disease_id' => $disease_id,
    'allelic_requirement_attrib' => $allelic_requirement_attrib,
    'allelic_requirement' => $allelic_requirement,
    'mutation_consequence_attrib' => $mutation_consequence_attrib,
    'mutation_consequence' => $mutation_consequence,
    'confidence_category' => $confidence_category,
    'confidence_category_attrib' => $confidence_category_attrib,
    'is_visible' => $is_visible,
    'panel' => $panel,
    'panel_attrib' => $panel_attrib,
    'restricted_mutation_set' => $restricted_mutation_set,
  }, $class;
  return $self;
}

sub dbID {
  my $self = shift;
  $self->{genomic_feature_disease_id} = shift if ( @_ );
  return $self->{genomic_feature_disease_id};
}

sub genomic_feature_id {
  my $self = shift;
  $self->{genomic_feature_id} = shift if ( @_ );
  return $self->{genomic_feature_id};
}

sub disease_id {
  my $self = shift;
  $self->{disease_id} = shift if ( @_ );
  return $self->{disease_id};
}

sub allelic_requirement {
  my $self = shift;
  my $allelic_requirement = shift;
  my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;

  if ($allelic_requirement) {
    my @values = split(',', $allelic_requirement); 
    my @ids = ();
    foreach my $value (@values) {
      push @ids, $attribute_adaptor->attrib_id_for_value($value);
    }        
    $self->{allelic_requirement_attrib} = join(',', sort @ids);
    $self->{allelic_requirement} = $allelic_requirement;
  } else {
    if (!$self->{allelic_requirement} && $self->{allelic_requirement_attrib} ) {
      my @ids = split(',', $self->{allelic_requirement_attrib});
      my @values = ();
      foreach my $id (@ids) {
        push @values, $attribute_adaptor->attrib_value_for_id($id);
      }
      $self->{allelic_requirement} = join(',', sort @values);
    }
  }
  return $self->{allelic_requirement};
}

sub allelic_requirement_attrib {
  my $self = shift;
  $self->{allelic_requirement_attrib} = shift if @_;
  return $self->{allelic_requirement_attrib};
}

sub mutation_consequence {
  my $self = shift;
  my $mutation_consequence = shift;
  my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
  if ($mutation_consequence) {
    $self->{mutation_consequence_attrib} = $attribute_adaptor->attrib_id_for_value($mutation_consequence);
    $self->{mutation_consequence} = $mutation_consequence;
  } else { 
    if (!$self->{mutation_consequence} && $self->{mutation_consequence_attrib}) {
      $self->{mutation_consequence} = $attribute_adaptor->attrib_value_for_id($self->{mutation_consequence_attrib});
    }
  }
  return $self->{mutation_consequence};
}

sub mutation_consequence_attrib {
  my $self = shift;
  $self->{mutation_consequence_attrib} = shift if @_;
  return $self->{mutation_consequence_attrib};
}

sub confidence_category {
  my $self = shift;
  my $confidence_category = shift;
  if ($confidence_category) {
    my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
    my $confidence_category_attrib = $attribute_adaptor->attrib_id_for_value($confidence_category);
    die "Could not get confidence category attrib id for value $confidence_category\n" unless ($confidence_category_attrib);
    $self->{confidence_category} = $confidence_category;
    $self->{confidence_category_attrib} = $confidence_category_attrib;
  } else {
    if ($self->{confidence_category_attrib} && !$self->{confidence_category}) {
      my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
      my $confidence_category = $attribute_adaptor->attrib_value_for_id($self->{confidence_category_attrib});
      $self->{confidence_category} = $confidence_category;
    }   
    die "No confidence_category" unless ($self->{confidence_category} );
  }
  return $self->{confidence_category};
}

sub confidence_category_attrib {
  my $self = shift;
  my $confidence_category_attrib = shift;
  if ($confidence_category_attrib) {
    my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
    my $confidence_category = $attribute_adaptor->attrib_value_for_id($confidence_category_attrib);
    die "Could not get confidence category for value $confidence_category_attrib\n" unless ($confidence_category);
    $self->{confidence_category} = $confidence_category;
    $self->{confidence_category_attrib} = $confidence_category_attrib;
  } else {
    die "No confidence_category_attrib" unless ($self->{confidence_category_attrib});
  }
  return $self->{confidence_category_attrib};
}

sub is_visible {
  my $self = shift;
  $self->{is_visible} = shift if ( @_ );
  return $self->{is_visible};
}

sub panel {
  my $self = shift;
  my $panel = shift;
  if ($panel) {
    my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
    my $panel_attrib = $attribute_adaptor->attrib_id_for_value($panel);
    die "Could not get panel attrib id for value $panel\n" unless ($panel_attrib);
    $self->{panel} = $panel;
    $self->{panel_attrib} = $panel_attrib;
  } else {
    die "No panel" unless ($self->{panel});
  }
  return $self->{panel};
}

sub panel_attrib {
  my $self = shift;
  my $panel_attrib = shift;
  if ($panel_attrib) {
    my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
    my $panel = $attribute_adaptor->attrib_value_for_id($panel_attrib);
    die "Could not get panel for value $panel_attrib\n" unless ($panel);
    $self->{panel} = $panel;
    $self->{panel_attrib} = $panel_attrib;
  } else {
    die "No panel_attrib" unless ($self->{panel_attrib});
  }
  return $self->{panel_attrib};
}

sub restricted_mutation_set {
  my $self = shift;
  $self->{restricted_mutation_set} = shift if ( @_ );
  return $self->{restricted_mutation_set};
}

sub get_all_GenomicFeatureDiseaseActions {
  my $self = shift;
  my $GFDA_adaptor = $self->{adaptor}->db->get_GenomicFeatureDiseaseActionAdaptor;
  return $GFDA_adaptor->fetch_all_by_GenomicFeatureDisease($self);       
}

sub get_GenomicFeature {
  my $self = shift;
  my $GF_adaptor = $self->{adaptor}->db->get_GenomicFeatureAdaptor;
  return $GF_adaptor->fetch_by_dbID($self->genomic_feature_id);
}

sub get_Disease {
  my $self = shift;
  my $disease_adaptor = $self->{adaptor}->db->get_DiseaseAdaptor;
  return $disease_adaptor->fetch_by_dbID($self->disease_id);
}

sub get_all_Variations {
  my $self = shift;
}

sub get_all_GFDPublications {
  my $self = shift;
  my $GFD_publication_adaptor = $self->{adaptor}->db->get_GenomicFeatureDiseasePublicationAdaptor;
  return $GFD_publication_adaptor->fetch_all_by_GenomicFeatureDisease($self);
}

sub get_all_GFDPhenotypes {
  my $self = shift;
  my $GFD_phenotype_adaptor = $self->{adaptor}->db->get_GenomicFeatureDiseasePhenotypeAdaptor;
  return $GFD_phenotype_adaptor->fetch_all_by_GenomicFeatureDisease($self);
}

sub get_all_GFDOrgans {
  my $self = shift;
  my $GFD_organ_adaptor = $self->{adaptor}->db->get_GenomicFeatureDiseaseOrganAdaptor;
  return $GFD_organ_adaptor->fetch_all_by_GenomicFeatureDisease($self);
}

sub get_all_GFDComments {
  my $self = shift;
  my $GFD_comment_adaptor = $self->{adaptor}->db->get_GenomicFeatureDiseaseCommentAdaptor;
  return $GFD_comment_adaptor->fetch_all_by_GenomicFeatureDisease($self);
}

sub get_all_GFDDiseaseSynonyms {
  my $self = shift;
  my $GFD_disease_synonym_adaptor = $self->{adaptor}->db->get_GFDDiseaseSynonymAdaptor;
  return $GFD_disease_synonym_adaptor->fetch_all_by_GenomicFeatureDisease($self);
}

1;
