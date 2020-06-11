=head1 LICENSE
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::G2P::DBSQL::GFDPhenotypeLogAdaptor;

use Bio::EnsEMBL::G2P::GFDPhenotypeLog;
use Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor;
use DBI qw(:sql_types);

our @ISA = ('Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor');

sub store {
  my $self = shift;
  my $gfd_phenotype_log = shift;
  my $dbh = $self->dbc->db_handle;

  if (!ref($gfd_phenotype_log) || !$gfd_phenotype_log->isa('Bio::EnsEMBL::G2P::GFDPhenotypeLog')) {
    die('Bio::EnsEMBL::G2P::GFDPhenotypeLog arg expected');
  }

  my $sth = $dbh->prepare(q{
    INSERT INTO GFD_phenotype_log(
      genomic_feature_disease_phenotype_id,
      genomic_feature_disease_id,
      phenotype_id,
      is_visible,
      panel_attrib,
      created,
      user_id,
      action
    ) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, ?)
  });

  $sth->execute(
    $gfd_phenotype_log->{genomic_feature_disease_phenotype_id},
    $gfd_phenotype_log->{genomic_feature_disease_id},
    $gfd_phenotype_log->{phenotype_id},
    $gfd_phenotype_log->{is_visible},
    $gfd_phenotype_log->{panel_attrib},
    $gfd_phenotype_log->user_id,
    $gfd_phenotype_log->action,
  );

  $sth->finish();
  
  # get dbID
  my $dbID = $dbh->last_insert_id(undef, undef, 'gfd_phenotype_log', 'GFD_phenotype_log_id'); 
  $gfd_phenotype_log->{GFD_phenotype_log_id} = $dbID;

  return $gfd_phenotype_log;
}

sub fetch_by_dbID {
  my $self = shift;
  my $genomic_feature_disease_phenotype_id = shift;
  return $self->SUPER::fetch_by_dbID($genomic_feature_disease_phenotype_id);
}

sub fetch_all_by_GenomicFeatureDisease {
  my $self = shift;
  my $gfd = shift;
  my $gfd_id = $gfd->dbID;
  my $constraint = "gfdpl.genomic_feature_disease_id=$gfd_id";
  return $self->generic_fetch($constraint);
}

sub fetch_latest_updates {
  my $self = shift;
  my $panel = shift;
  my $limit = shift; # 10
  my $is_visible_only = shift;
  my $aa = $self->db->get_AttributeAdaptor;
  my $panel_attrib = $aa->attrib_id_for_type_value('g2p_panel', $panel);
  my $constraint = "gfd.panel_attrib='$panel_attrib' AND gfdpl.action='create'";
  if ($is_visible_only) {
    $constraint .= " AND gfd.is_visible = 1";
  }
  $constraint .= " ORDER BY created DESC limit $limit";
  return $self->generic_fetch($constraint);
}

sub _columns {
  my $self = shift;
  my @cols = (
    'gfdpl.gfd_phenotype_log_id',
    'gfdpl.genomic_feature_disease_phenotype_id',
    'gfdpl.genomic_feature_disease_id',
    'gfdpl.phenotype_id',
    'gfd.is_visible',
    'gfd.panel_attrib',
    'gfdpl.created',
    'gfdpl.user_id',
    'gfdpl.action'
  );
  return @cols;
}

sub _tables {
  my $self = shift;
  my @tables = (
    ['gfd_phenotype_log', 'gfdpl'],
    ['genomic_feature_disease', 'gfd']
  );
  return @tables;
}

sub _left_join {
  my $self = shift;

  my @left_join = (
    ['genomic_feature_disease', 'gfdpl.genomic_feature_disease_id = gfd.genomic_feature_disease_id'],
  );
  return @left_join;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my ($gfd_phenotype_log_id, $genomic_feature_disease_phenotype_id, $genomic_feature_disease_id, $phenotype_id, $is_visible, $panel_attrib, $created, $user_id, $action);

  $sth->bind_columns(\($gfd_phenotype_log_id, $genomic_feature_disease_phenotype_id, $genomic_feature_disease_id, $phenotype_id, $is_visible, $panel_attrib, $created, $user_id, $action));

  my @objs;

  while ($sth->fetch()) {
    my $obj = Bio::EnsEMBL::G2P::GFDPhenotypeLog->new(
      -GFD_phenotype_log_id => $gfd_phenotype_log_id,
      -genomic_feature_disease_phenotype_id => $genomic_feature_disease_phenotype_id,
      -genomic_feature_disease_id => $genomic_feature_disease_id,
      -phenotype_id => $phenotype_id,
      -is_visible => $is_visible,
      -panel_attrib => $panel_attrib,
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