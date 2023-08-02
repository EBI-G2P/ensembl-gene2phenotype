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

package Bio::EnsEMBL::G2P::DBSQL::GenomicFeatureDiseasePhenotypeAdaptor;

use Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype;

our @ISA = ('Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor');

=head2 store

  Arg [1]    : Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype $GFD_phenotype
  Arg [2]    : Bio::EnsEMBL::G2P::User $user
  Example    : $GFD_phenotype = Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype->new(...);
               $GFD_phenotype = $GFD_phenotype_adaptor->store($GFD_phenotype, $user);
  Description: This stores a GenomicFeatureDiseasePhenotype in the database.
  Returntype : Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype
  Exceptions : - Throw error if $GFD_phenotype is not a
                 Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype
               - Throw error if $user is not a Bio::EnsEMBL::G2P::User
  Caller     :
  Status     : Stable

=cut

sub store {
  my $self = shift;
  my $GFD_phenotype = shift;  
  my $user = shift;

  if (!ref($GFD_phenotype) || !$GFD_phenotype->isa('Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype')) {
    die('Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype arg expected');
  }

  if (!ref($user) || !$user->isa('Bio::EnsEMBL::G2P::User')) {
    die('Bio::EnsEMBL::G2P::User arg expected');
  }

  my $dbh = $self->dbc->db_handle;

  my $sth = $dbh->prepare(q{
    INSERT INTO genomic_feature_disease_phenotype (
      genomic_feature_disease_id,
      phenotype_id
    ) VALUES (?,?);
  });
  $sth->execute(
    $GFD_phenotype->get_GenomicFeatureDisease()->dbID(),
    $GFD_phenotype->get_Phenotype()->dbID()
  );

  $sth->finish();

  my $dbID = $dbh->last_insert_id(undef, undef, 'genomic_feature_disease_phenotype', 'genomic_feature_disease_phenotype_id');
  $GFD_phenotype->dbID($dbID);
  $self->update_log($GFD_phenotype, $user, 'create');
  return $GFD_phenotype;
}

sub delete {
  my $self = shift;
  my $GFDP = shift; 
  my $user = shift;
  my $dbh = $self->dbc->db_handle;

  if (!ref($GFDP) || !$GFDP->isa('Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype')) {
    die ('Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype arg expected');
  }
  
  if (!ref($user) || !$user->isa('Bio::EnsEMBL::G2P::User')) {
    die ('Bio::EnsEMBL::G2P::User arg expected');
  }

  my $GFDPhenotypeCommentAdaptor = $self->db->get_GFDPhenotypeCommentAdaptor;
  foreach my $GFDPhenotypeComment (@{$GFDP->get_all_GFDPhenotypeComments}) {
    $GFDPhenotypeCommentAdaptor->delete($GFDPhenotypeComment, $user);
  }

  my $sth = $dbh->prepare(q{
    INSERT INTO genomic_feature_disease_phenotype_deleted SELECT * FROM genomic_feature_disease_phenotype WHERE genomic_feature_disease_phenotype_id = ?;
  });
  $sth->execute($GFDP->dbID);

  $sth = $dbh->prepare(q{
    DELETE FROM genomic_feature_disease_phenotype WHERE genomic_feature_disease_phenotype_id = ?;
  });

  $sth->execute($GFDP->dbID);
  $sth->finish();
}

sub update_log {
  my $self = shift;
  my $gfdp = shift;
  my $user = shift;
  my $action = shift;
  my $gfd_phenotype_log_adaptor = $self->db->get_GFDPhenotypeLogAdaptor;
  my $gfdl = Bio::EnsEMBL::G2P::GFDPhenotypeLog->new(
    -genomic_feature_disease_phenotype_id => $gfdp->dbID,
    -genomic_feature_disease_id => $gfdp->genomic_feature_disease_id,
    -phenotype_id => $gfdp->phenotype_id,
    -user_id => $user->dbID,
    -action => $action, 
    -adaptor => $gfd_phenotype_log_adaptor,
  );
  $gfd_phenotype_log_adaptor->store($gfdl);
}


sub fetch_by_dbID {
  my $self = shift;
  my $dbID = shift;
  return $self->SUPER::fetch_by_dbID($dbID);
}

sub fetch_by_GFD_id_phenotype_id {
  my $self = shift;
  my $GFD_id = shift;
  my $phenotype_id = shift;
  my $constraint = "gfdp.genomic_feature_disease_id=$GFD_id AND gfdp.phenotype_id=$phenotype_id";
  my $result = $self->generic_fetch($constraint);
  return $result->[0]; 
}

sub fetch_all_by_phenotype_ids {
  my $self = shift;
  my $phenotype_ids = shift;
  my $ids = join(',', @{$phenotype_ids});
  my $constraint = "gfdp.phenotype_id IN ($ids)";
  my $result = $self->generic_fetch($constraint);
  return $result;
}

sub fetch_all_by_phenotype_id {
  my $self = shift;
  my $phenotype_id = shift;
  my $constraint = "gfdp.phenotype_id LIKE '%$phenotype_id%'";
  my $result = $self->generic_fetch($constraint);

  return $result;
}

sub fetch_all_by_GenomicFeatureDisease {
  my $self = shift;
  my $GFD = shift;
  if (!ref($GFD) || !$GFD->isa('Bio::EnsEMBL::G2P::GenomicFeatureDisease')) {
    die('Bio::EnsEMBL::G2P::GenomicFeatureDisease arg expected');
  }
  my $GFD_id = $GFD->dbID;
  my $constraint = "gfdp.genomic_feature_disease_id=$GFD_id"; 
  return $self->generic_fetch($constraint);
}

sub _columns {
  my $self = shift;
  my @cols = (
    'gfdp.genomic_feature_disease_phenotype_id',
    'gfdp.genomic_feature_disease_id',
    'gfdp.phenotype_id',
  );
  return @cols;
}

sub _tables {
  my $self = shift;
  my @tables = (
    ['genomic_feature_disease_phenotype', 'gfdp'],
  );
  return @tables;
}

=head2 _objs_from_sth

  Arg [1]    : StatementHandle $sth
  Description: Responsible for the creation of GenomicFeatureDiseasePhenotypes
  Returntype : listref of Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype
  Exceptions : None
  Caller     : Internal
  Status     : Stable

=cut

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my ($GFD_phenotype_id, $genomic_feature_disease_id, $phenotype_id);
  $sth->bind_columns(\($GFD_phenotype_id, $genomic_feature_disease_id, $phenotype_id));

  my @objs;

  while ($sth->fetch()) {
    my $obj = Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype->new(
      -genomic_feature_disease_phenotype_id => $GFD_phenotype_id,
      -genomic_feature_disease_id => $genomic_feature_disease_id,
      -phenotype_id => $phenotype_id,
      -adaptor => $self,
    );
    push(@objs, $obj);
  }
  return \@objs;
}

1;
