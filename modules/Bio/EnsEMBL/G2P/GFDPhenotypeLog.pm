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

package Bio::EnsEMBL::G2P::GFDPhenotypeLog;

use Bio::EnsEMBL::Storable;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use base qw(Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype);

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;

  my ($gfd_phenotype_log_id, $genomic_feature_disease_phenotype_id, $genomic_feature_disease_id, $phenotype_id, $created, $user_id, $action, $adaptor) = rearrange(['GFD_phenotype_log_id', 'genomic_feature_disease_phenotype_id', 'genomic_feature_disease_id', 'phenotype_id', 'created', 'user_id', 'action', 'adaptor'], @_);
  my $self = $class->SUPER::new(@_);
  $self->{'GFD_phenotype_log_id'} = $gfd_phenotype_log_id;
  $self->{'genomic_feature_disease_phenotype_id'} = $genomic_feature_disease_phenotype_id;
  $self->{'phenotype_id'} = $phenotype_id;
  $self->{'genomic_feature_disease_id'} = $genomic_feature_disease_id;
  $self->{'created'} = $created;
  $self->{'user_id'} = $user_id;
  $self->{'action'} = $action;
  $self->{'adaptor'} = $adaptor;

  return $self;
}

sub dbID {
  my $self = shift;
  $self->{GFD_phenotype_log_id} = shift if @_;
  return $self->{GFD_phenotype_log_id};
}

sub genomic_feature_disease_phenotype_id {
  my $self = shift;
  $self->{'genomic_feature_disease_phenotype_id'} = shift if ( @_);
  return $self->{'genomic_feature_disease_phenotype_id'};
}

sub created {
  my $self = shift;
  $self->{created} = shift if ( @_ );
  return $self->{created};
}

sub user_id {
  my $self = shift;
  $self->{user_id} = shift if ( @_ );
  return $self->{user_id};
}

sub action {
  my $self = shift;
  $self->{action} = shift if ( @_ );
  return $self->{action};
}

1;
