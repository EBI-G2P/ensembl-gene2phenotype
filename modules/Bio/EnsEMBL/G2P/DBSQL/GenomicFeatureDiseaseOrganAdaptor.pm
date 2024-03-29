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

package Bio::EnsEMBL::G2P::DBSQL::GenomicFeatureDiseaseOrganAdaptor;

use Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan;
our @ISA = ('Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor');

=head2 store

  Arg [1]    : Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan $GFD_organ
  Example    : $GFD_organ = Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan->new(...);
               $GFD_organ = $GFD_organ_adaptor->store($GFD_organ);
  Description: This stores a GenomicFeatureDiseaseOrgan in the database.
  Returntype : Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan
  Exceptions : - Throw error if $GFD_organ is not a
                 Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan
  Caller     :
  Status     : Stable

=cut

sub store {
  my $self = shift;
  my $GFD_organ = shift;  

  if (!ref($GFD_organ) || !$GFD_organ->isa('Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan')) {
    die('Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan arg expected');
  }

  my $dbh = $self->dbc->db_handle;

  my $sth = $dbh->prepare(q{
    INSERT INTO genomic_feature_disease_organ (
      genomic_feature_disease_id,
      organ_id
    ) VALUES (?,?);
  });
  $sth->execute(
    $GFD_organ->get_GenomicFeatureDisease()->dbID(),
    $GFD_organ->get_Organ()->dbID()
  );

  $sth->finish();

  # get dbID
  my $dbID = $dbh->last_insert_id(undef, undef, 'genomic_feature_disease_organ', 'genomic_feature_disease_organ_id');
  $GFD_organ->{genomic_feature_disease_organ_id} = $dbID;
  return $GFD_organ;
}

sub update {
  my $self = shift;
  my $GFD_organ = shift;
  my $dbh = $self->dbc->db_handle;

  if (!ref($GFD_organ) || !$GFD_organ->isa('Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan')) {
    die('Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan arg expected');
  }

  my $sth = $dbh->prepare(q{
    UPDATE genomic_feature_disease_organ
    SET genomic_feature_disease_id = ?,
        organ_id = ?
    WHERE genomic_feature_disease_organ_id = ? 
  });
  $sth->execute(
    $GFD_organ->{genomic_feature_disease_id},
    $GFD_organ->organ_id,
    $GFD_organ->dbID
  );
  $sth->finish();

  return $GFD_organ;
}

sub delete {
  my $self = shift;
  my $GFDO = shift;
  my $user = shift;
  my $dbh = $self->dbc->db_handle;

  if (!ref($GFDO) || !$GFDO->isa('Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan')) {
    die ('Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan arg expected');
  }

  if (!ref($user) || !$user->isa('Bio::EnsEMBL::G2P::User')) {
    die ('Bio::EnsEMBL::G2P::User arg expected');
  }

  my $sth = $dbh->prepare(q{
    INSERT INTO genomic_feature_disease_organ_deleted SELECT * FROM genomic_feature_disease_organ WHERE genomic_feature_disease_organ_id = ?;
  });
  $sth->execute($GFDO->dbID);

  $sth = $dbh->prepare(q{
    DELETE FROM genomic_feature_disease_organ WHERE genomic_feature_disease_organ_id = ?;
  });

  $sth->execute($GFDO->dbID);

  $sth->finish();
}

sub fetch_by_dbID {
  my $self = shift;
  my $dbID = shift;
  return $self->SUPER::fetch_by_dbID($dbID);
}

sub fetch_by_GFD_id_organ_id {
  my $self = shift;
  my $GFD_id = shift;
  my $organ_id = shift;
  my $constraint = "gfdo.genomic_feature_disease_id=$GFD_id AND gfdo.organ_id=$organ_id";
  my $result = $self->generic_fetch($constraint);
  return $result->[0];
}

sub fetch_all {
  my $self = shift;
  return $self->generic_fetch();
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

sub fetch_all_by_Organ {
  my $self = shift;
  my $organ = shift;
  if (!ref($organ) || !$organ->isa('Bio::EnsEMBL::G2P::Organ')) {
    die('Bio::EnsEMBL::G2P::Organ arg expected');
  }
  my $organ_id = $organ->dbID;
  my $constraint = "gfdo.organ_id=$organ_id"; 
  return $self->generic_fetch($constraint);
}

sub delete_all_by_GFD_id {
  my $self = shift;
  my $GFD_id = shift;
  my $dbh = $self->dbc->db_handle;
  my $sth = $dbh->prepare("DELETE FROM genomic_feature_disease_organ WHERE genomic_feature_disease_id=$GFD_id");
  $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
  $sth->finish();
}

sub _columns {
  my $self = shift;
  my @cols = (
    'gfdo.genomic_feature_disease_organ_id',
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

=head2 _objs_from_sth

  Arg [1]    : StatementHandle $sth
  Description: Responsible for the creation of GenomicFeatureDiseaseOrgans
  Returntype : listref of Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan
  Exceptions : None
  Caller     : Internal
  Status     : Stable

=cut

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my ($GFD_organ_id, $genomic_feature_disease_id, $organ_id);
  $sth->bind_columns(\($GFD_organ_id, $genomic_feature_disease_id, $organ_id));

  my @objs;

  while ($sth->fetch()) {
    my $obj = Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan->new(
      -genomic_feature_disease_organ_id => $GFD_organ_id,
      -genomic_feature_disease_id => $genomic_feature_disease_id,
      -organ_id => $organ_id,
      -adaptor => $self,
    );
    push(@objs, $obj);
  }
  return \@objs;
}

1;
