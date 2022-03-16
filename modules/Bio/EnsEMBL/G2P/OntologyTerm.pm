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

package Bio::EnsEMBL::G2P::OntologyTerm;

use Bio::EnsEMBL::Storable;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

our @ISA = ('Bio::EnsEMBL::Storable');

sub new {
  my $caller = shift; 
  my $class = ref($caller) || $caller;
  my ($ontology_accession_id, $ontology_accession, $description, $adaptor) = 
  rearrange(['ontology_accession_id', 'ontology_accession', 'description', 'adaptor']);

  my $self = bless {
    'dbID' => $ontology_accession_id,
    'ontology_accession_id' => $ontology_accession_id, 
    'ontology_accession' => $ontology_accession,
    'description' => $description, 
    'adaptor' => $adaptor,
  }, $class;

  return $self;
}

sub dbID {
  my $self = shift;
  $self->{ontology_accession_id} = shift if @_;
  return $self->{ontology_accession_id};
}

sub ontology_accession_id {
  my $self = shift;
  $self->{ontology_accession_id} = shift if @_;
  return $self->{ontology_accession_id};
}

sub ontology_accession {
  my $self = shift;
  $self->{ontology_accession} = shift if @_;
  return $self->{ontology_accession};
}

sub description {
  my $self = shift;
  $self->{description} = shift if @_;
  return $self->{description};
}