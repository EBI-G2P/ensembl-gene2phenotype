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
  my (
    $genomic_feature_disease_id,
    $genomic_feature_id,
    $disease_id,
    $original_allelic_requirement,
    $original_allelic_requirement_attrib,
    $allelic_requirement,
    $allelic_requirement_attrib,
    $cross_cutting_modifier,
    $cross_cutting_modifier_attrib,
    $original_mutation_consequence,
    $original_mutation_consequence_attrib,
    $mutation_consequence,
    $mutation_consequence_attrib,
    $mutation_consequence_flag,
    $mutation_consequence_flag_attrib,
    $restricted_mutation_set,
    $adaptor) =
  rearrange([
    'genomic_feature_disease_id',
    'genomic_feature_id',
    'disease_id',
    'original_allelic_requirement',
    'original_allelic_requirement_attrib',
    'allelic_requirement',
    'allelic_requirement_attrib',
    'cross_cutting_modifier',
    'cross_cutting_modifier_attrib',
    'original_mutation_consequence',
    'original_mutation_consequence_attrib',
    'mutation_consequence',
    'mutation_consequence_attrib',
    'mutation_consequence_flag',
    'mutation_consequence_flag_attrib',
    'restricted_mutation_set',
    'adaptor'], @_);

  my $self = bless {
    'dbID' => $genomic_feature_disease_id,
    'adaptor' => $adaptor,
    'genomic_feature_disease_id' => $genomic_feature_disease_id,
    'genomic_feature_id' => $genomic_feature_id,
    'disease_id' => $disease_id,
    'original_allelic_requirement' => $original_allelic_requirement,
    'original_allelic_requirement_attrib' => $original_allelic_requirement_attrib,
    'allelic_requirement_attrib' => $allelic_requirement_attrib,
    'allelic_requirement' => $allelic_requirement,
    'cross_cutting_modifier' => $cross_cutting_modifier,
    'cross_cutting_modifier_attrib' => $cross_cutting_modifier_attrib,
    'original_mutation_consequence' => $original_mutation_consequence,
    'original_mutation_consequence_attrib' => $original_mutation_consequence_attrib,
    'mutation_consequence_attrib' => $mutation_consequence_attrib,
    'mutation_consequence' => $mutation_consequence,
    'mutation_consequence_flag' => $mutation_consequence_flag,
    'mutation_consequence_flag_attrib' => $mutation_consequence_flag_attrib,
    'restricted_mutation_set' => $restricted_mutation_set,
  }, $class;
  return $self;
}

sub dbID {
  my $self = shift;
  $self->{genomic_feature_disease_id} = shift if ( @_ );
  return $self->{genomic_feature_disease_id};
}

sub genomic_feature_disease_id {
  my $self = shift;
  $self->{genomic_feature_disease_id} = shift if @_;
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

sub original_allelic_requirement {
  my $self = shift;
  my $original_allelic_requirement = shift;
  my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;

  if ($original_allelic_requirement) {
    $self->{original_allelic_requirement_attrib} = $attribute_adaptor->get_attrib('allelic_requirement', $original_allelic_requirement);
    $self->{original_allelic_requirement} = $original_allelic_requirement;
  } else {
    if (!$self->{original_allelic_requirement} && $self->{original_allelic_requirement_attrib}) {
      $self->{original_allelic_requirement} = $attribute_adaptor->get_value('original_allelic_requirement', $self->{original_allelic_requirement_attrib});
    }
  }
  return $self->{original_allelic_requirement};
}

sub original_allelic_requirement_attrib {
  my $self = shift;
  $self->{original_allelic_requirement_attrib} = shift if @_;
  return $self->{original_allelic_requirement_attrib};
}

sub allelic_requirement {
  my $self = shift;
  my $allelic_requirement = shift;
  my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;

  if ($allelic_requirement) {
    $self->{allelic_requirement_attrib} = $attribute_adaptor->get_attrib('allelic_requirement', $allelic_requirement);
    $self->{allelic_requirement} = $allelic_requirement;
  } else {
    if (!$self->{allelic_requirement} && $self->{allelic_requirement_attrib}) {
      $self->{allelic_requirement} = $attribute_adaptor->get_value('allelic_requirement', $self->{allelic_requirement_attrib});
    }
  }
  return $self->{allelic_requirement};
}

sub allelic_requirement_attrib {
  my $self = shift;
  $self->{allelic_requirement_attrib} = shift if @_;
  return $self->{allelic_requirement_attrib};
}

sub cross_cutting_modifier {
  my $self = shift;
  my $allelic_requirement = shift;
  my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;

  if ($cross_cutting_modifier) {
    $self->{cross_cutting_modifier_attrib} = $attribute_adaptor->get_attrib('cross_cutting_modifier', $cross_cutting_modifier);
    $self->{cross_cutting_modifier} = $cross_cutting_modifier;
  } else {
    if (!$self->{cross_cutting_modifier} && $self->{cross_cutting_modifier_attrib}) {
      $self->{cross_cutting_modifier} = $attribute_adaptor->get_value('cross_cutting_modifier', $self->{cross_cutting_modifier_attrib});
    }
  }
  return $self->{cross_cutting_modifier};
}

sub cross_cutting_modifier_attrib {
  my $self = shift;
  $self->{cross_cutting_modifier_attrib} = shift if @_;
  return $self->{cross_cutting_modifier_attrib};
}

sub original_mutation_consequence {
  my $self = shift;
  my $original_mutation_consequence = shift;
  my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
  if ($original_mutation_consequence) {
    $self->{original_mutation_consequence_attrib} = $attribute_adaptor->get_attrib('original_mutation_consequence', $original_mutation_consequence);
    $self->{original_mutation_consequence} = $original_mutation_consequence;
  } else { 
    if (!$self->{original_mutation_consequence} && $self->{original_mutation_consequence_attrib}) {
      $self->{original_mutation_consequence} = $attribute_adaptor->get_value('original_mutation_consequence', $self->{original_mutation_consequence_attrib});
    }
  }
  return $self->{original_mutation_consequence};
}

sub original_mutation_consequence_attrib {
  my $self = shift;
  $self->{original_mutation_consequence_attrib} = shift if @_;
  return $self->{original_mutation_consequence_attrib};
}

sub mutation_consequence {
  my $self = shift;
  my $mutation_consequence = shift;
  my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
  if ($mutation_consequence) {
    $self->{mutation_consequence_attrib} = $attribute_adaptor->get_attrib('mutation_consequence', $mutation_consequence);
    $self->{mutation_consequence} = $mutation_consequence;
  } else { 
    if (!$self->{mutation_consequence} && $self->{mutation_consequence_attrib}) {
      $self->{mutation_consequence} = $attribute_adaptor->get_value('mutation_consequence', $self->{mutation_consequence_attrib});
    }
  }
  return $self->{mutation_consequence};
}

sub mutation_consequence_attrib {
  my $self = shift;
  $self->{mutation_consequence_attrib} = shift if @_;
  return $self->{mutation_consequence_attrib};
}

sub mutation_consequence_flag {
  my $self = shift;
  my $mutation_consequence_flag = shift;
  my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;

  if ($mutation_consequence_flag) {
    $self->{mutation_consequence_flag_attrib} = $attribute_adaptor->get_attrib('mutation_consequence_flag', $mutation_consequence_flag);
    $self->{mutation_consequence_flag} = $mutation_consequence_flag;
  } else {
    if (!$self->{mutation_consequence_flag} && $self->{mutation_consequence_flag_attrib}) {
      $self->{mutation_consequence_flag} = $attribute_adaptor->get_value('mutation_consequence_flag', $self->{mutation_consequence_flag_attrib});
    }
  }
  return $self->{mutation_consequence_flag};
}

sub mutation_consequence_flag_attrib {
  my $self = shift;
  $self->{mutation_consequence_flag_attrib} = shift if @_;
  return $self->{mutation_consequence_flag_attrib};
}

sub restricted_mutation_set {
  my $self = shift;
  $self->{restricted_mutation_set} = shift if ( @_ );
  return $self->{restricted_mutation_set};
}

sub add_gfd_disease_synonym_id {
  my $self = shift;
  my $gfd_disease_synonym_id = shift;
  throw("id is required") if(!$gfd_disease_synonym_id);
  if (! grep { $gfd_disease_synonym_id == $_ } @{$self->{gfd_disease_synonym_id}}) {
    push @{$self->{gfd_disease_synonym_id}}, $gfd_disease_synonym_id;
  }
}

sub add_panel {
  my $self = shift;
  my $panel = shift;
  throw("panel is required") if(!$panel);
  if (! grep { $panel eq $_ } @{$self->{panels}}) {
    push @{$self->{panels}}, $panel;
  }
}

sub panels {
  my $self = shift;
  if (defined $self->{panels}) {
    return $self->{panels};
  } else {
    return [];
  }
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

sub get_all_GFDPanels {
  my $self = shift;
  my $GFD_panel_adaptor = $self->{adaptor}->db->get_GenomicFeatureDiseasePanelAdaptor;
  return $GFD_panel_adaptor->fetch_all_by_GenomicFeatureDisease($self);
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
