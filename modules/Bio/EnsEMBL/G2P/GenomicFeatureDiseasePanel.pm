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

package Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel;

use Bio::EnsEMBL::Storable;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

our @ISA = ('Bio::EnsEMBL::Storable');

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;
  my (
    $genomic_feature_disease_panel_id,
    $genomic_feature_disease_id,
    $original_confidence_category,
    $original_confidence_category_attrib,
    $confidence_category,
    $confidence_category_attrib,
    $clinical_review,
    $is_visible,
    $panel,
    $panel_attrib,
    $adaptor
  ) = rearrange([
    'genomic_feature_disease_panel_id',
    'genomic_feature_disease_id',
    'original_confidence_category',
    'original_confidence_category_attrib',
    'confidence_category',
    'confidence_category_attrib',
    'clinical_review',
    'is_visible',
    'panel',
    'panel_attrib',
    'adaptor'
  ], @_);

  my $self = bless {
    'genomic_feature_disease_panel_id' => $genomic_feature_disease_panel_id,
    'adaptor' => $adaptor,
    'genomic_feature_disease_id' => $genomic_feature_disease_id,
    'original_confidence_category' => $original_confidence_category,
    'original_confidence_category_attrib' => $original_confidence_category_attrib,
    'confidence_category' => $confidence_category,
    'confidence_category_attrib' => $confidence_category_attrib,
    'clinical_review' => $clinical_review,
    'is_visible' => $is_visible,
    'panel' => $panel,
    'panel_attrib' => $panel_attrib,
  }, $class;
  return $self;
}

sub dbID {
  my $self = shift;
  $self->{genomic_feature_disease_panel_id} = shift if ( @_ );
  return $self->{genomic_feature_disease_panel_id};
}

sub genomic_feature_disease_panel_id {
  my $self = shift;
  $self->{genomic_feature_disease_panel_id} = shift if ( @_ );
  return $self->{genomic_feature_disease_panel_id};
}

sub genomic_feature_disease_id {
  my $self = shift;
  $self->{genomic_feature_disease_id} = shift if ( @_ );
  return $self->{genomic_feature_disease_id};
}

sub original_confidence_category {
  my $self = shift;
  my $original_confidence_category = shift;
  if ($original_confidence_category) {
    $self->{original_confidence_category} = $original_confidence_category;
      my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
      $self->{original_confidence_category_attrib} = $attribute_adaptor->get_attrib('original_confidence_category', $self->{original_confidence_category});
  } else {
    if ($self->{original_confidence_category_attrib} && !$self->{original_confidence_category}) {
      my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
      $self->{original_confidence_category} = $attribute_adaptor->get_value('original_confidence_category', $self->{original_confidence_category_attrib});
    }   
    die "No original_confidence_category" unless ($self->{original_confidence_category});
  }
  return $self->{original_confidence_category};
}

sub original_confidence_category_attrib {
  my $self = shift;
  my $original_confidence_category_attrib = shift;
  if ($original_confidence_category_attrib) {
    $self->{original_confidence_category_attrib} = $original_confidence_category_attrib;
      my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
      $self->{original_confidence_category} = $attribute_adaptor->get_value('original_confidence_category', $self->{original_confidence_category_attrib});
  } else {
    if (!defined $self->{original_confidence_category_attrib} && defined $self->{original_confidence_category}) {
      my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
      $self->{original_confidence_category_attrib} = $attribute_adaptor->get_attrib('original_confidence_category', $self->{original_confidence_category});
    } 
  }
  if (!defined $self->{original_confidence_category_attrib}) {
    die "Original confidence category attrib not set\n";
  }
  return $self->{original_confidence_category_attrib};
}

sub confidence_category {
  my $self = shift;
  my $confidence_category = shift;
  if ($confidence_category) {
    $self->{confidence_category} = $confidence_category;
      my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
      $self->{confidence_category_attrib} = $attribute_adaptor->get_attrib('confidence_category', $self->{confidence_category});
  } else {
    if ($self->{confidence_category_attrib} && !$self->{confidence_category}) {
      my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
      $self->{confidence_category} = $attribute_adaptor->get_value('confidence_category', $self->{confidence_category_attrib});
    }   
    die "No confidence_category" unless ($self->{confidence_category});
  }
  return $self->{confidence_category};
}

sub confidence_category_attrib {
  my $self = shift;
  my $confidence_category_attrib = shift;
  if ($confidence_category_attrib) {
    $self->{confidence_category_attrib} = $confidence_category_attrib;
      my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
      $self->{confidence_category} = $attribute_adaptor->get_value('confidence_category', $self->{confidence_category_attrib});
  } else {
    if (!defined $self->{confidence_category_attrib} && defined $self->{confidence_category}) {
      my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
      $self->{confidence_category_attrib} = $attribute_adaptor->get_attrib('confidence_category', $self->{confidence_category});
    } 
  }
  if (!defined $self->{confidence_category_attrib}) {
    die "Confidence category attrib not set\n";
  }
  return $self->{confidence_category_attrib};
}

sub clinical_review {
  my $self = shift;
  $self->{clinical_review} = shift if ( @_ );
  return $self->{clinical_review};
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
    $self->{panel} = $panel;
  } else {
    if ($self->{panel_attrib} && !$self->{panel}) {
      my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
      my $panel = $attribute_adaptor->get_value('g2p_panel', $self->{panel_attrib});
      $self->{panel} = $panel;
    }   
    die "No panel" unless ($self->{panel});
  }
  return $self->{panel};
}

sub panel_attrib {
  my $self = shift;
  my $panel_attrib = shift;
  if ($panel_attrib) {
    $self->{panel_attrib} = $panel_attrib;
  } else {
    if (!defined $self->{panel_attrib} && defined $self->{panel}) {
      my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
      my $panel_attrib = $attribute_adaptor->get_attrib('g2p_panel', $self->{panel});
      $self->{panel_attrib} = $panel_attrib;
    } 
  }
  if (!defined $self->{panel_attrib}) {
    die "Panel attrib not set\n";
  }
  return $self->{panel_attrib};
}


1;
