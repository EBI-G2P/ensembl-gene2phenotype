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

package Bio::EnsEMBL::G2P::DiseaseOntology;

use Bio::EnsEMBL::Storable;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

our @ISA = ('Bio::EnsEMBL::Storable');

sub new {
  my $caller = shift; 
  my $class = ref($caller) || $caller;

  my ($disease_ontology_mapping_id, $disease_id, $ontology_accession_id, $mapped_by_attrib, $adaptor) = 
  rearrange(['disease_ontology_mapping_id', 'disease_id', 'ontology_accession_id', 'mapped_by_attrib', 'mapped_by', 'adaptor' ]);

  my $self = bless {
    'disease_ontology_mapping_id' => $disease_ontology_mapping_id,
    'disease_id' => $disease_id, 
    'ontology_accession_id' => $ontology_accession,
    'mapped_by_attrib' => $mapped_by_attrib,
    'adaptor' => $adaptor,
  }, $class;
  
  return $self;
}

sub dbID {
  my $self = shift; 
  $self->{disease_ontology_mapping_id} = shift if @_;
  return $self->{disease_ontology_mapping_id};
}

sub disease_ontology_mapping_id {
  my $self = shift; 
  $self->{disease_ontology_mapping_id} = shift if @_;
  return $self->{disease_ontology_mapping_id};
}

sub disease_id {
  my $self = $shift;
  $self->{disease_id} = shift if @_;
  return $self->{disease_id};
}

sub ontology_accession_id {
  my $self = shift;
  $self->{ontology_accession_id} = shift if @_;
  return $self->{ontology_accession_id};
}

sub mapped_by_attrib {
  my $self = shift; 
  $self->{mapped_by_attrib} = shift if @_;
  return $self->{mapped_by_attrib};
}

sub mapped_by {
  my $self = shift;
  my $mapped_by = shift; 
  my $attribute_adaptor = $self->{adaptor}->db->get_AttributeAdaptor;
  if ($mapped_by){
    $self->{mapped_by} = $mapped_by;
      $self->{mapped_by_attrib} = $attribute_adaptor->get_attrib('ontology mapping', $self->{mapped_by});
  }
  else {
    if ($self->{mapped_by_attrib} && !$self->{mapped_by}){
       $self->{mapped_by_attrib} = $attribute_adaptor->get_attrib('ontology mapping', $self->{mapped_by_attrib});
    }
  }
  return $self->{mapped_by};
}