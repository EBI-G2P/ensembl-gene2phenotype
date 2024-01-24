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

package Bio::EnsEMBL::G2P::DBSQL::GenomicFeatureDiseasePanelAdaptor;

use Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel;
use Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor;
use DBI qw(:sql_types);

our @ISA = ('Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor');

=head2 store

  Arg [1]    : Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel $gfd_panel
  Arg [2]    : Bio::EnsEMBL::G2P::User $user
  Example    : $gfd_panel = Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel->new(...);
               $gfd_panel = $gfd_panel_adaptor->store($gfd_panel, $user);
  Description: This stores a GenomicFeatureDiseasePanel in the database.
  Returntype : Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel
  Exceptions : - Throw error if $gfd_panel is not a Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel
               - Throw error if $user is not a Bio::EnsEMBL::G2P::User
               - Throw error if neither panel nor panel_attrib
                 is provided
               - Throw error if neither confidence_category nor confidence_category_attrib
                 is provided
               - Throw error if attrib value couldn't be mapped to attrib id
               - Throw error if attrib id couldn't be mapped to attrib value
  Caller     :
  Status     : Stable

=cut

sub store {
  my $self = shift;
  my $gfd_panel = shift;
  my $user = shift;
  my $dbh = $self->dbc->db_handle;

  if (!ref($gfd_panel) || !$gfd_panel->isa('Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel')) {
    die('Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel arg expected');
  }

  if (!ref($user) || !$user->isa('Bio::EnsEMBL::G2P::User')) {
    die('Bio::EnsEMBL::G2P::User arg expected');
  }

  if (! (defined $gfd_panel->{panel} || defined $gfd_panel->{panel_attrib})) {
    die "panel or panel_attrib is required\n";
  }

  if (! (defined $gfd_panel->{confidence_category} || defined $gfd_panel->{confidence_category_attrib})) {
    die "confidence_category or confidence_category_attrib is required\n";
  }

  my $attribute_adaptor = $self->db->get_AttributeAdaptor;

  if (defined $gfd_panel->{panel} && ! defined $gfd_panel->{panel_attrib}) {
    $gfd_panel->{panel_attrib} = $attribute_adaptor->get_attrib('g2p_panel', $gfd_panel->{panel});
  }

  if (defined $gfd_panel->{confidence_category} && ! defined $gfd_panel->{confidence_category_attrib}) {
    $gfd_panel->{confidence_category_attrib} = $attribute_adaptor->get_attrib('confidence_category', $gfd_panel->{confidence_category});
  }
  # to check for the visibility 
  if ($gfd_panel->{confidence_category_attrib} == 88 || $gfd_panel->{confidence_category_attrib} == 89) {
    $gfd_panel->{is_visible} = 0;
  } 
  
  my $sth = $dbh->prepare(q{
    INSERT INTO genomic_feature_disease_panel(
      genomic_feature_disease_id,
      confidence_category_attrib,
      clinical_review,
      is_visible,
      panel_attrib
    ) VALUES (?, ?, ?, ?, ?)
  });

  $sth->execute(
    $gfd_panel->{genomic_feature_disease_id},
    $gfd_panel->{confidence_category_attrib},
    $gfd_panel->clinical_review,
    $gfd_panel->is_visible,
    $gfd_panel->{panel_attrib}
  );

  $sth->finish();
  
  my $dbID = $dbh->last_insert_id(undef, undef, 'genomic_feature_disease_panel', 'genomic_feature_disease_panel_id'); 
  $gfd_panel->{genomic_feature_disease_panel_id} = $dbID;

  $self->update_log($gfd_panel, $user, 'create');

  return $gfd_panel;
}

sub delete {
  my $self = shift;
  my $gfd_panel = shift;
  my $user = shift;
  my $dbh = $self->dbc->db_handle;

  if (!ref($gfd_panel) || !$gfd_panel->isa('Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel')) {
    die ('Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel arg expected');
  }

  if (!ref($user) || !$user->isa('Bio::EnsEMBL::G2P::User')) {
    die ('Bio::EnsEMBL::G2P::User arg expected');
  }

  my $gfd_panel_id = $gfd_panel->dbID; 

  my $sth = $dbh->prepare(q{
    INSERT INTO genomic_feature_disease_panel_deleted (
      genomic_feature_disease_panel_id,
      genomic_feature_disease_id,
      original_confidence_category_attrib,
      confidence_category_attrib,
      clinical_review,
      is_visible,
      panel_attrib,
      deleted,
      deleted_by_user_id
    ) VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?)
  });

  $sth->execute(
    $gfd_panel->dbID,
    $gfd_panel->genomic_feature_disease_id,
    $gfd_panel->original_confidence_category_attrib,
    $gfd_panel->confidence_category_attrib,
    $gfd_panel->clinical_review,
    $gfd_panel->is_visible,
    $gfd_panel->panel_attrib,
    $user->user_id
  );
  $sth->finish();

  foreach my $table (qw/genomic_feature_disease_panel genomic_feature_disease_panel_log/) {
    $sth = $dbh->prepare(qq{ DELETE FROM $table WHERE genomic_feature_disease_panel_id = ?;});
    $sth->execute($gfd_panel->dbID);
    $sth->finish();
  }
}

sub update {
  my $self = shift;
  my $gfd_panel = shift;
  my $user = shift;
  my $dbh = $self->dbc->db_handle;

  if (!ref($gfd_panel) || !$gfd_panel->isa('Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel')) {
    die('Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel arg expected');
  }

  if (!ref($user) || !$user->isa('Bio::EnsEMBL::G2P::User')) {
    die('Bio::EnsEMBL::G2P::User arg expected');
  }
  # to check for the visibility 
  if ($gfd_panel->{confidence_category_attrib} == 88 || $gfd_panel->{confidence_category_attrib} == 89) {
    $gfd_panel->{is_visible} = 0;
  }

  my $sth = $dbh->prepare(q{
    UPDATE genomic_feature_disease_panel
    SET
      confidence_category_attrib = ?,
      clinical_review = ?,
      is_visible = ?,
      panel_attrib = ?
    WHERE genomic_feature_disease_panel_id = ?;
  });
  $sth->execute(
    $gfd_panel->confidence_category_attrib,
    $gfd_panel->clinical_review,
    $gfd_panel->is_visible,
    $gfd_panel->panel_attrib,
    $gfd_panel->dbID
  );
  $sth->finish();

  $self->update_log($gfd_panel, $user, 'update');

  return $gfd_panel;
}

sub update_log {
  my $self = shift;
  my $gfd_panel = shift;
  my $user = shift;
  my $action = shift;

  my $gfd_panel_log_adaptor = $self->db->get_GenomicFeatureDiseasePanelLogAdaptor;
  my $gfd_panel_log = Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanelLog->new(
    -genomic_feature_disease_panel_id => $gfd_panel->dbID,
    -genomic_feature_disease_id => $gfd_panel->genomic_feature_disease_id,
    -original_confidence_category_attrib => $gfd_panel->original_confidence_category_attrib,
    -confidence_category_attrib => $gfd_panel->confidence_category_attrib,
    -panel_attrib => $gfd_panel->panel_attrib,
    -clinical_review => $gfd_panel->clinical_review,
    -is_visible => $gfd_panel->is_visible,
    -user_id => $user->dbID,
    -action => $action, 
    -adaptor => $gfd_panel_log_adaptor,
  );
  $gfd_panel_log_adaptor->store($gfd_panel_log);
}

sub get_statistics {
  my $self = shift;
  my $attribute_adaptor = $self->db->get_AttributeAdaptor;
  my $panel_adaptor = $self->db->get_PanelAdaptor;
  my @panel_names = map {$_->name} @{$panel_adaptor->fetch_all_visible};
  my @panel_attribs = ();
  foreach my $panel_name (@panel_names) {
    next if ($panel_name eq 'ALL');
    my $panel_attrib = $attribute_adaptor->get_attrib('g2p_panel', $panel_name);
    push @panel_attribs, $panel_attrib;
  }
  my $confidence_category_attribs = $attribute_adaptor->get_attribs_by_type('confidence_category');
  my $panel_attrib_ids = join(',', @panel_attribs);
  my $sth = $self->prepare(qq{
    select a.value, gfdp.confidence_category_attrib, count(*)
    from genomic_feature_disease_panel gfdp, attrib a
    where a.attrib_id = gfdp.panel_attrib
    AND gfdp.panel_attrib IN ($panel_attrib_ids)
    group by a.value, gfdp.confidence_category_attrib;
  });
  $sth->execute;

  my $hash = {};
  while (my ($panel, $confidence_category_attrib_id, $count) = $sth->fetchrow_array) {
    my $confidence_category_value = $confidence_category_attribs->{$confidence_category_attrib_id};
    $hash->{$panel}->{$confidence_category_value} = $count;
  }
  my @results = ();
  my @header = ('Panel', 'definitive', 'strong', 'moderate', 'limited' );
  push @results, \@header;
  foreach my $panel (sort keys %$hash) {
    my @row = ();
    push @row, $panel;
    for (my $i = 1; $i <= $#header; $i++) {
      push @row, ($hash->{$panel}->{$header[$i]} || 0) + 0;
    }
    push @results, \@row;
  }

  return \@results;
}

sub fetch_all {
  my $self = shift;
  return $self->generic_fetch();
}

sub fetch_all_by_panel {
  my $self = shift;
  my $panel = shift;
  if ($panel eq 'ALL') {
    return $self->fetch_all();
  } 
  my $attribute_adaptor = $self->db->get_AttributeAdaptor;
  my $panel_attrib = $attribute_adaptor->get_attrib('g2p_panel', $panel);
  my $constraint = "gfd_panel.panel_attrib=$panel_attrib";
  return $self->generic_fetch($constraint);
}

sub fetch_all_by_panel_restricted {
  my $self = shift;
  my $panel = shift;
  if ($panel eq 'ALL') {
    return $self->fetch_all();
  } 
  my $attribute_adaptor = $self->db->get_AttributeAdaptor;
  my $panel_attrib = $attribute_adaptor->get_attrib('g2p_panel', $panel);
  my $constraint = "gfd_panel.panel_attrib=$panel_attrib AND gfd_panel.is_visible = 0";
  return $self->generic_fetch($constraint);
}

sub fetch_by_dbID {
  my $self = shift;
  my $genomic_feature_disease_panel_id = shift;
  return $self->SUPER::fetch_by_dbID($genomic_feature_disease_panel_id);
}

sub fetch_all_by_GenomicFeatureDisease {
  my $self = shift;
  my $genomic_feature_disease = shift;
  my $gfd_id = $genomic_feature_disease->dbID;
  my $constraint = "gfd_panel.genomic_feature_disease_id=$gfd_id;";
  return $self->generic_fetch($constraint);
}

sub fetch_by_GenomicFeatureDisease_panel {
  my $self = shift;
  my $genomic_feature_disease = shift;
  my $panel = shift;
  if ($panel eq 'ALL') {
    warn "fetch_by_GenomicFeatureDisease_panel cannot be used with panel ALL\n";
    return undef;
  }
  my $gfd_id = $genomic_feature_disease->dbID;
  my $attribute_adaptor = $self->db->get_AttributeAdaptor;
  my $panel_attrib = $attribute_adaptor->get_attrib('g2p_panel', $panel);
  my $constraint = "gfd_panel.panel_attrib=$panel_attrib AND gfd_panel.genomic_feature_disease_id=$gfd_id;";
  my $result = $self->generic_fetch($constraint);
  return $result->[0];
}


sub _columns {
  my $self = shift;
  my @cols = (
    'gfd_panel.genomic_feature_disease_panel_id',
    'gfd_panel.genomic_feature_disease_id',
    'gfd_panel.original_confidence_category_attrib',
    'gfd_panel.confidence_category_attrib',
    'gfd_panel.clinical_review',
    'gfd_panel.is_visible',
    'gfd_panel.panel_attrib',
  );
  return @cols;
}

sub _tables {
  my $self = shift;
  my @tables = (
    ['genomic_feature_disease_panel', 'gfd_panel'],
  );
  return @tables;
}

=head2 _objs_from_sth

  Arg [1]    : StatementHandle $sth
  Description: Responsible for the creation of GenomicFeatureDiseasePanels
  Returntype : listref of Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel
  Exceptions : None
  Caller     : Internal
  Status     : Stable

=cut

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my (
    $genomic_feature_disease_panel_id,
    $genomic_feature_disease_id,
    $original_confidence_category_attrib,
    $confidence_category_attrib,
    $clinical_review,
    $is_visible,
    $panel_attrib,
    $restricted_mutation_set
  );
  $sth->bind_columns(\(
    $genomic_feature_disease_panel_id,
    $genomic_feature_disease_id,
    $original_confidence_category_attrib,
    $confidence_category_attrib,
    $clinical_review,
    $is_visible,
    $panel_attrib,
  ));

  my @objs;

  my $attribute_adaptor = $self->db->get_AttributeAdaptor;

  while ($sth->fetch()) {
    my $original_confidence_category = undef;
    my $confidence_category = undef; 
    my $panel = undef; 
    if ($original_confidence_category_attrib) {
      $original_confidence_category = $attribute_adaptor->get_value('original_confidence_category', $original_confidence_category_attrib);
    }

    if ($confidence_category_attrib) {
      $confidence_category = $attribute_adaptor->get_value('confidence_category', $confidence_category_attrib);
    }

    if ($panel_attrib) {
      $panel = $attribute_adaptor->get_value('g2p_panel', $panel_attrib);
    }

    my $obj = Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel->new(
      -genomic_feature_disease_panel_id => $genomic_feature_disease_panel_id,
      -genomic_feature_disease_id => $genomic_feature_disease_id,
      -original_confidence_category => $original_confidence_category,
      -original_confidence_category_attrib => $original_confidence_category_attrib,
      -confidence_category => $confidence_category, 
      -confidence_category_attrib => $confidence_category_attrib,
      -clinical_review => $clinical_review,
      -is_visible => $is_visible,
      -panel => $panel,
      -panel_attrib => $panel_attrib,
      -adaptor => $self,
    );
    push(@objs, $obj);
  }
  return \@objs;
}

1;
