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

package Bio::EnsEMBL::G2P::DBSQL::GenomicFeatureDiseaseLogAdaptor;

use Bio::EnsEMBL::G2P::GenomicFeatureDiseaseLog;
use Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor;
use DBI qw(:sql_types);

our @ISA = ('Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor');

=head2 store

  Arg [1]    : Bio::EnsEMBL::G2P::GenomicFeatureDiseaseLog $gfd_log
  Example    : $gfd_log = Bio::EnsEMBL::G2P::GenomicFeatureDiseaseLog->new(...);
               $gfd_log = $gfd_log_adaptor->store($gfd_log);
  Description: This stores a GenomicFeatureDiseaseLog in the database.
  Returntype : Bio::EnsEMBL::G2P::GenomicFeatureDiseaseLog
  Exceptions : - Throw error if $gfd_log is not a
                 Bio::EnsEMBL::G2P::GenomicFeatureDiseaseLog
  Caller     : Bio::EnsEMBL::G2P::GenomicFeatureDiseaseAdaptor::update_log
  Status     : Stable

=cut

sub store {
  my $self = shift;
  my $gfd_log = shift;
  my $dbh = $self->dbc->db_handle;

  if (!ref($gfd_log) || !$gfd_log->isa('Bio::EnsEMBL::G2P::GenomicFeatureDiseaseLog')) {
    die('Bio::EnsEMBL::G2P::GenomicFeatureDiseaseLog arg expected');
  }

  my $sth = $dbh->prepare(q{
    INSERT INTO genomic_feature_disease_log(
      genomic_feature_disease_id,
      genomic_feature_id,
      disease_id,
      original_allelic_requirement_attrib,
      allelic_requirement_attrib,
      cross_cutting_modifier_attrib,
      original_mutation_consequence_attrib,
      mutation_consequence_attrib,
      allelic_requirement_attrib,
      mutation_consequence_attrib,
      mutation_consequence_flag_attrib,
      created,
      user_id,
      action
    ) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, ?)
  });

  $sth->execute(
    $gfd_log->{genomic_feature_disease_id},
    $gfd_log->{genomic_feature_id},
    $gfd_log->{disease_id},
    $gfd_log->{original_allelic_requirement_attrib},
    $gfd_log->{allelic_requirement_attrib},
    $gfd_log->{cross_cutting_modifier_attrib},
    $gfd_log->{original_mutation_consequence_attrib},
    $gfd_log->{mutation_consequence_attrib},
    $gfd_log->{mutation_consequence_flag_attrib},
    $gfd_log->user_id,
    $gfd_log->action,
  );

  $sth->finish();
  
  # get dbID
  my $dbID = $dbh->last_insert_id(undef, undef, 'genomic_feature_disease_log', 'genomic_feature_disease_log_id'); 
  $gfd_log->{genomic_feature_disease_log_id} = $dbID;

  return $gfd_log;
}

sub fetch_by_dbID {
  my $self = shift;
  my $dbID = shift;
  return $self->SUPER::fetch_by_dbID($dbID);
}

sub fetch_all_by_GenomicFeatureDisease {
  my $self = shift;
  my $gfd = shift;
  my $gfd_id = $gfd->dbID;
  my $constraint = "gfdl.genomic_feature_disease_id=$gfd_id";
  return $self->generic_fetch($constraint);
}

sub fetch_all_by_most_recent {
  my $self = shift;
  my $limit = shift;
  my $action = shift;
  $limit ||= 10;
  $action ||= 'create';
  my $constraint = "gfdl.action='$action'";
  $constraint .= " ORDER BY created DESC limit $limit";
  return $self->generic_fetch($constraint);
}

sub _columns {
  my $self = shift;
  my @cols = (
    'gfdl.genomic_feature_disease_log_id',
    'gfdl.genomic_feature_disease_id',
    'gfdl.genomic_feature_id',
    'gfdl.disease_id',
    'gfdl.original_allelic_requirement_attrib',
    'gfdl.allelic_requirement_attrib',
    'gfdl.cross_cutting_modifier_attrib',
    'gfdl.original_mutation_consequence_attrib',
    'gfdl.mutation_consequence_attrib',
    'gfdl.mutation_consequence_flag_attrib',
    'gfdl.created',
    'gfdl.user_id',
    'gfdl.action',
  );
  return @cols;
}

sub _tables {
  my $self = shift;
  my @tables = (
    ['genomic_feature_disease_log', 'gfdl'],
    ['genomic_feature_disease', 'gfd'],
  );
  return @tables;
}

sub _left_join {
  my $self = shift;

  my @left_join = (
    ['genomic_feature_disease', 'gfdl.genomic_feature_disease_id = gfd.genomic_feature_disease_id'],
  );
  return @left_join;
}

=head2 _objs_from_sth

  Arg [1]    : StatementHandle $sth
  Description: Responsible for the creation of GenomicFeatureDiseaseLogs
  Returntype : listref of Bio::EnsEMBL::G2P::GenomicFeatureDiseaseLog
  Exceptions : None
  Caller     : Internal
  Status     : Stable

=cut

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my (
    $genomic_feature_disease_log_id,
    $genomic_feature_disease_id,
    $genomic_feature_id,
    $disease_id,
    $original_allelic_requirement_attrib,
    $allelic_requirement_attrib,
    $cross_cutting_modifier_attrib,
    $original_mutation_consequence_attrib,
    $mutation_consequence_attrib,
    $mutation_consequence_flag_attrib,
    $created,
    $user_id,
    $action,
  );
  $sth->bind_columns(\(
    $genomic_feature_disease_log_id,
    $genomic_feature_disease_id,
    $genomic_feature_id,
    $disease_id,
    $original_allelic_requirement_attrib,
    $allelic_requirement_attrib,
    $cross_cutting_modifier_attrib,
    $original_mutation_consequence_attrib,
    $mutation_consequence_attrib,
    $mutation_consequence_flag_attrib,
    $created,
    $user_id,
    $action,
  ));

  my @objs;

  while ($sth->fetch()) {
    my $obj = Bio::EnsEMBL::G2P::GenomicFeatureDiseaseLog->new(
      -genomic_feature_disease_log_id => $genomic_feature_disease_log_id,
      -genomic_feature_disease_id => $genomic_feature_disease_id,
      -genomic_feature_id => $genomic_feature_id,
      -disease_id => $disease_id,
      -original_allelic_requirement_attrib => $original_allelic_requirement_attrib,
      -allelic_requirement_attrib => $allelic_requirement_attrib,
      -original_mutation_consequence_attrib => $original_mutation_consequence_attrib,
      -mutation_consequence_attrib => $mutation_consequence_attrib,
      -mutation_consequence_flag_attrib => $mutation_consequence_flag_attrib,
      -created => $created,
      -user_id => $user_id,
      -action => $action,
      -adaptor => $self,
    );
    push(@objs, $obj);
  }
  return \@objs;
}

1;
