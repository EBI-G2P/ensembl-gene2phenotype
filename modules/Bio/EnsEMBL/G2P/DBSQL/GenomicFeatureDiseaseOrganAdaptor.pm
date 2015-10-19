=head1 LICENSE
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::G2P::DBSQL::GenomicFeatureDiseaseOrganAdaptor;

use Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan;
our @ISA = ('Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor');

sub fetch_by_dbID {
  my $self = shift;
  my $GFD_organ_id = shift;
  my $constraint = "gfdo.GFD_organ_id=$GFD_organ_id"; 
  my $result = $self->generic_fetch($constraint);
  return $result->[0];
}

sub fetch_by_GFD_id_organ_id {
  my $self = shift;
  my $GFD_id = shift;
  my $organ_id = shift;
  my $constraint = "gfdo.genomic_feature_disease_id=$GFD_id AND gfdo.organ_id=$organ_id";
  my $result = $self->generic_fetch($constraint);
  return $result->[0];
}

sub fetch_all_by_GenomicFeatureDisease {
  my $self = shift;
  my $GFD = shift;
  if (!ref($GFD) || !$GFD->isa('Bio::EnsEMBL::G2P::GenomicFeatureDisease')) {
    die('Bio::EnsEMBL::G2P::GenomicFeatureDisease arg expected');
  }
  my $GFD_id = $GFD->dbID;
  my $constraint = "gfdo.genomic_feature_disease_id=$GFD_id"; 
  return $self->generic_fetch($constraint);
}

sub _columns {
  my $self = shift;
  my @cols = (
    'gfdo.GFD_organ_id',
    'gfdo.genomic_feature_disease_id',
    'gfdo.organ_id',
  );
  return @cols;
}

sub _tables {
  my $self = shift;
  my @tables = (
    ['genomic_feature_disease_organ', 'gfdo'],
  );
  return @tables;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my ($GFD_organ_id, $genomic_feature_disease_id, $organ_id);
  $sth->bind_columns(\($GFD_organ_id, $genomic_feature_disease_id, $organ_id));

  my @objs;

  while ($sth->fetch()) {
    my $obj = Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan->new(
      -GFD_organ_id => $GFD_organ_id,
      -genomic_feature_disease_id => $genomic_feature_disease_id,
      -organ_id => $organ_id,
      -adaptor => $self,
    );
    push(@objs, $obj);
  }
  return \@objs;
}

1;