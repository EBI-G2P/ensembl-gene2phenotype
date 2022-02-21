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

package Bio::EnsEMBL::G2P::GenomicFeatureDiseaseComment;

use Bio::EnsEMBL::Storable;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

our @ISA = ('Bio::EnsEMBL::Storable');

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;

  my ($genomic_feature_disease_comment_id, $genomic_feature_disease_id, $comment_text, $is_public, $created, $user_id, $adaptor) =
    rearrange(['genomic_feature_disease_comment_id', 
      'genomic_feature_disease_id', 
      'comment_text',
      'is_public', 
      'created', 
      'user_id', 
      'adaptor'], @_);

  my $self = bless {
    'genomic_feature_disease_comment_id' => $genomic_feature_disease_comment_id,
    'genomic_feature_disease_id' => $genomic_feature_disease_id,
    'comment_text' => $comment_text,
    'is_public' => $is_public,
    'created' => $created,
    'user_id' => $user_id,
    'adaptor' => $adaptor,
  }, $class;

  return $self;
}

sub dbID {
  my $self = shift;
  return $self->{genomic_feature_disease_comment_id};
}

sub GFD_id {
  my $self = shift;
  $self->{'genomic_feature_disease_id'} = shift if ( @_ );
  return $self->{'genomic_feature_disease_id'};
}

sub comment_text {
  my $self = shift;
  $self->{'comment_text'} = shift if ( @_ );
  return $self->{'comment_text'};
}

sub is_public {
  my $self = shift;
  $self->{is_public} = shift if ( @_ );
  return $self->{is_public};
}

sub created {
  my $self = shift;
  $self->{'created'} = shift if ( @_ );
  return $self->{'created'};
}

sub get_User {
  my $self = shift;
  my $user_adaptor = $self->{adaptor}->db->get_UserAdaptor;
  return $user_adaptor->fetch_by_dbID($self->{user_id});
}

sub get_GenomicFeatureDisease {
  my $self = shift;
  my $gfd_adaptor = $self->{adaptor}->db->get_GenomicFeatureDiseaseAdaptor;
  return $gfd_adaptor->fetch_by_dbID($self->{genomic_feature_disease_id});
}

1;
