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

package Bio::EnsEMBL::G2P::DBSQL::GenomicFeatureDiseaseAdaptor;

use Bio::EnsEMBL::G2P::GenomicFeatureDisease;
use Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::G2P::GFDDiseaseSynonym;
use DBI qw(:sql_types);

our @ISA = ('Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor');

=head2 store

  Arg [1]    : Bio::EnsEMBL::G2P::GenomicFeatureDisease
  Arg [2]    : Bio::EnsEMBL::G2P::User
  Example    : $gfd = Bio::EnsEMBL::G2P::GenomicFeatureDisease->new(...);
               $gfd = $disease_adaptor->store($gfd, $user);
  Description: This stores a GenomicFeatureDisease in the database.
               We check first if the GenomicFeatureDisease already exists
               in the database and if it does return the exisiting GenomicFeatureDisease.
  Returntype : Bio::EnsEMBL::G2P::GenomicFeatureDisease
  Exceptions : - Throw error if $gfd is not a Bio::EnsEMBL::G2P::GenomicFeatureDisease
               - Throw error if $user is not a Bio::EnsEMBL::G2P::User
               - Throw error if neither allelic_requirement nor allelic_requirement_attrib
                 is provided
               - Throw error if neither mutation_consequence nor mutation_consequence_attrib
                 is provided
               - Throw error if attrib value couldn't be mapped to attrib id
               - Throw error if attrib id couldn't be mapped to attrib value
  Caller     :
  Status     : Stable

=cut

sub store {
  my $self = shift;
  my $gfd = shift;
  my $user = shift;
  my $dbh = $self->dbc->db_handle;

  if (!ref($gfd) || !$gfd->isa('Bio::EnsEMBL::G2P::GenomicFeatureDisease')) {
    die('Bio::EnsEMBL::G2P::GenomicFeatureDisease arg expected');
  }

  if (!ref($user) || !$user->isa('Bio::EnsEMBL::G2P::User')) {
    die('Bio::EnsEMBL::G2P::User arg expected');
  }

  if (! (defined $gfd->{allelic_requirement} || defined $gfd->{allelic_requirement_attrib})) {
    die "allelic_requirement or allelic_requirement_attrib is required\n";
  }

  if (! (defined $gfd->{mutation_consequence} || defined $gfd->{mutation_consequence_attrib})) {
    die "mutation_consequence or mutation_consequence_attrib is required\n";
  }
  
  my $attribute_adaptor = $self->db->get_AttributeAdaptor;

  foreach my $key (qw/allelic_requirement mutation_consequence/)  {

    if (defined $gfd->{$key} && ! defined $gfd->{"$key\_attrib"}) {
      my $attrib = $attribute_adaptor->get_attrib($key, $gfd->{$key});
      if (!$attrib) {
        die "Could not get $key attrib id for value ", $gfd->{$key}, "\n";
      }
      $gfd->{"$key\_attrib"} = $attrib;
    }

    if (defined $gfd->{"$key\_attrib"} && ! defined $gfd->{$key}) {
      my $value = $attribute_adaptor->get_value($key, $gfd->{"$key\_attrib"});
      if (!$value) {
        die "Could not get $key value for attrib id ", $gfd->{"$key\_attrib"}, "\n";
      }
      $gfd->{$key} = $value;
    }
  }

  # Check if GFD already exists
  my $gfds = $self->fetch_all_by_GenomicFeatureDisease($gfd);
  if (scalar @$gfds > 0) {
    return $gfds->[0];
  }

  my $sth = $dbh->prepare(q{
    INSERT INTO genomic_feature_disease(
      genomic_feature_id,
      disease_id,
      allelic_requirement_attrib,
      mutation_consequence_attrib,
      restricted_mutation_set
    ) VALUES (?, ?, ?, ?, ?)
  });

  $sth->execute(
    $gfd->{genomic_feature_id},
    $gfd->{disease_id},
    $gfd->{allelic_requirement_attrib},
    $gfd->{mutation_consequence_attrib},
    $gfd->restricted_mutation_set || 0
  );

  $sth->finish();
  
  # get dbID
  my $dbID = $dbh->last_insert_id(undef, undef, 'genomic_feature_disease', 'genomic_feature_disease_id'); 
  $gfd->{genomic_feature_disease_id} = $dbID;

  $self->update_log($gfd, $user, 'create');

  return $gfd;
}

sub update {
  my $self = shift;
  my $gfd = shift;
  my $user = shift;
  my $dbh = $self->dbc->db_handle;

  if (!ref($gfd) || !$gfd->isa('Bio::EnsEMBL::G2P::GenomicFeatureDisease')) {
    die('Bio::EnsEMBL::G2P::GenomicFeatureDisease arg expected');
  }

  if (!ref($user) || !$user->isa('Bio::EnsEMBL::G2P::User')) {
    die('Bio::EnsEMBL::G2P::User arg expected');
  }

  my $sth = $dbh->prepare(q{
    UPDATE genomic_feature_disease
    SET
      genomic_feature_id = ?,
      disease_id = ?,
      allelic_requirement_attrib = ?,
      mutation_consequence_attrib = ?,
      restricted_mutation_set = ?
    WHERE genomic_feature_disease_id = ? 
  });

  $sth->execute(
    $gfd->genomic_feature_id,
    $gfd->disease_id,
    $gfd->allelic_requirement_attrib,
    $gfd->mutation_consequence_attrib,
    $gfd->restricted_mutation_set || 0,
    $gfd->dbID
  );
  $sth->finish();

  $self->update_log($gfd, $user, 'update');

  return $gfd;
}

sub update_log {
  my $self = shift;
  my $gfd = shift;
  my $user = shift;
  my $action = shift;

  my $GFD_log_adaptor = $self->db->get_GenomicFeatureDiseaseLogAdaptor;

  my $gfdl = Bio::EnsEMBL::G2P::GenomicFeatureDiseaseLog->new(
    -genomic_feature_disease_id => $gfd->dbID,
    -disease_id => $gfd->disease_id,
    -genomic_feature_id => $gfd->genomic_feature_id,
    -allelic_requirement_attrib => $gfd->allelic_requirement_attrib,
    -mutation_consequence_attrib => $gfd->mutation_consequence_attrib,
    -user_id => $user->dbID,
    -action => $action, 
    -adaptor => $GFD_log_adaptor,
  );
  $GFD_log_adaptor->store($gfdl);
}

sub fetch_by_dbID {
  my $self = shift;
  my $genomic_feature_disease_id = shift;
  my $panels = shift;
  my $is_authorised = shift;
  if (defined $panels && defined $is_authorised) {
    my @constraints = ();
    push @constraints, "gfd.genomic_feature_disease_id=$genomic_feature_disease_id";
    my $attribute_adaptor = $self->db->get_AttributeAdaptor;
    my @panel_attribs = ();
    foreach my $panel (@$panels) {
      push @panel_attribs, "'" . $attribute_adaptor->get_attrib('g2p_panel', $panel) . "'"; 
    }
    push @constraints, "gfdp.panel_attrib IN (". join(',', @panel_attribs) . ")";
    if (!$is_authorised) {
      push @constraints, "gfdp.is_visible=1"; 
    }
    my $result = $self->generic_fetch(join(" AND ",  @constraints));
    if ($result) {
      return $result->[0];
    } else {
      return undef;
    }
  } else {
    return $self->SUPER::fetch_by_dbID($genomic_feature_disease_id);
  }
}

sub fetch_all_by_GenomicFeatureDisease {
  my $self = shift;
  my $gfd = shift;  
  my @constraints = ();
  my $genomic_feature = $gfd->get_GenomicFeature;
  my $disease_id = $gfd->get_Disease->dbID;
  my $allelic_requirement = $gfd->allelic_requirement;
  my $mutation_consequence = $gfd->mutation_consequence;
  return $self->fetch_all_by_GenomicFeature_constraints($genomic_feature, {
    allelic_requirement => $allelic_requirement,
    mutation_consequence => $mutation_consequence,
    disease_id => $disease_id,
  });
}

sub fetch_all_by_Disease {
  my $self = shift;
  my $disease = shift;
  my $disease_id = $disease->dbID;
  my $constraint = "(gfd.disease_id=$disease_id OR gfdds.disease_id=$disease_id);";
  return $self->generic_fetch($constraint);
}

sub fetch_all_by_Disease_panels {
  my $self = shift;
  my $disease = shift;
  my $panels = shift;
  my $is_authorised = shift;
  my $disease_id = $disease->dbID;

  my $attribute_adaptor = $self->db->get_AttributeAdaptor;
  my @constraints = ();
  push @constraints, "(gfd.disease_id=$disease_id OR gfdds.disease_id=$disease_id)";
  if ($panels) {
    my @panel_attribs = ();
    foreach my $panel (@$panels) {
      push @panel_attribs, "'" . $attribute_adaptor->get_attrib('g2p_panel', $panel) . "'"; 
    }
    push @constraints, "gfdp.panel_attrib IN (". join(',', @panel_attribs) . ")";
  }
  if (!$is_authorised) {
    push @constraints, "gfdp.is_visible=1"; 
  }
  return $self->generic_fetch(join(" AND ",  @constraints));
}

sub fetch_all_by_GenomicFeature {
  my $self = shift;
  my $genomic_feature = shift;
  my $genomic_feature_id = $genomic_feature->dbID;
  my $constraint = "gfd.genomic_feature_id=$genomic_feature_id";
  return $self->generic_fetch($constraint);
}

sub fetch_all_by_GenomicFeature_panels {
  my $self = shift;
  my $genomic_feature = shift;
  my $panels = shift;
  my $is_authorised = shift;
  my $genomic_feature_id = $genomic_feature->dbID;

  my $attribute_adaptor = $self->db->get_AttributeAdaptor;
  my @constraints = ();
  push @constraints, "gfd.genomic_feature_id=$genomic_feature_id";
  if ($panels) {
    my @panel_attribs = ();
    foreach my $panel (@$panels) {
      push @panel_attribs, "'" . $attribute_adaptor->get_attrib('g2p_panel', $panel) . "'"; 
    }
    push @constraints, "gfdp.panel_attrib IN (". join(',', @panel_attribs) . ")";
  }
  if (!$is_authorised) {
    push @constraints, "gfdp.is_visible=1"; 
  }
  return $self->generic_fetch(join(" AND ",  @constraints));
}

sub fetch_all_by_GenomicFeature_constraints {
  my $self = shift;
  my $genomic_feature = shift;
  my $constraints_hash = shift;
  my @constraints = ();
  my $attribute_adaptor = $self->db->get_AttributeAdaptor;

  while ( my ($key, $value) = each (%$constraints_hash)) {
    if ($key eq 'allelic_requirement') {
      my $allelic_requriement_attrib = $attribute_adaptor->get_attrib('allelic_requirement', $value);
      push @constraints, "gfd.allelic_requirement_attrib='$allelic_requriement_attrib'";
    } elsif ($key eq 'allelic_requirement_attrib') {
      push @constraints, "gfd.allelic_requirement_attrib='$value'";
    } elsif ($key eq 'mutation_consequence') {
      my $mutation_consequence_attrib = $attribute_adaptor->get_attrib('mutation_consequence', $value); 
      push @constraints, "gfd.mutation_consequence_attrib='$mutation_consequence_attrib'";
    } elsif ($key eq 'mutation_consequence_attrib') {
      push @constraints, "gfd.mutation_consequence_attrib='$value'";
    } elsif ($key eq 'disease_id') {
      push @constraints, "(gfd.disease_id=$value OR gfdds.disease_id=$value)";
    } else {
      die "Did not recognise constraint: $key. Supported constraints are: allelic_requirement, allelic_requirement_attrib, mutation_consequence, mutation_consequence_attrib, disease_id\n";
    }
  }

  my $genomic_feature_id = $genomic_feature->dbID;
  push @constraints, "gfd.genomic_feature_id=$genomic_feature_id";
  return $self->generic_fetch(join(' AND ', @constraints));
}

sub fetch_all_by_GenomicFeature_Disease {
  my $self = shift;
  my $genomic_feature = shift;
  my $disease = shift;
  my $genomic_feature_id = $genomic_feature->dbID;
  my $disease_id = $disease->dbID;
  my $constraint = "(gfd.disease_id=$disease_id OR gfdds.disease_id=$disease_id ) AND gfd.genomic_feature_id=$genomic_feature_id;";
  return $self->generic_fetch($constraint);
} 

sub fetch_all {
  my $self = shift;
  return $self->generic_fetch();
}

sub _columns {
  my $self = shift;
  my @cols = (
    'gfd.genomic_feature_disease_id',
    'gfd.genomic_feature_id',
    'gfd.disease_id',
    'gfdds.GFD_disease_synonym_id AS gfd_disease_synonym_id',
    'gfd.allelic_requirement_attrib',
    'gfd.mutation_consequence_attrib',
    'gfd.restricted_mutation_set',
    'gfdp.panel_attrib',
  );
  return @cols;
}

sub _tables {
  my $self = shift;
  my @tables = (
    ['genomic_feature_disease', 'gfd'],
    ['genomic_feature_disease_panel', 'gfdp'],
    ['GFD_disease_synonym', 'gfdds'],
  );
  return @tables;
}

sub _left_join {
  my $self = shift;

  my @left_join = (
    ['GFD_disease_synonym', 'gfd.genomic_feature_disease_id = gfdds.genomic_feature_disease_id'],
    ['genomic_feature_disease_panel', 'gfd.genomic_feature_disease_id = gfdp.genomic_feature_disease_id'],
  );

  return @left_join;
}

=head2 _objs_from_sth

  Arg [1]    : StatementHandle $sth
  Description: Responsible for the creation of GenomicFeatureDiseases
  Returntype : listref of Bio::EnsEMBL::G2P::GenomicFeatureDisease
  Exceptions : None
  Caller     : Internal
  Status     : Stable

=cut

sub _objs_from_sth {
  my ($self, $sth) = @_;
  my %row;
  $sth->bind_columns( \( @row{ @{$sth->{NAME_lc} } } ));
  while ($sth->fetch) {
    # we don't actually store the returned object because
    # the _obj_from_row method stores them in a temporary
    # hash _temp_objs in $self
    $self->_obj_from_row(\%row);
  }
  # Get the created objects from the temporary hash
  my @objs = values %{ $self->{_temp_objs} };
  delete $self->{_temp_objs};
  return \@objs;
}

sub _obj_from_row {
  my ($self, $row) = @_;

  my $attribute_adaptor = $self->db->get_AttributeAdaptor;

  my $obj = $self->{_temp_objs}{$row->{genomic_feature_disease_id}};

  unless (defined($obj)) {
    my $allelic_requirement;
    my $mutation_consequence;

    if (defined $row->{allelic_requirement_attrib}) {
      $allelic_requirement = $attribute_adaptor->get_value('allelic_requirement', $row->{allelic_requirement_attrib});
    }

    if (defined $row->{mutation_consequence_attrib}) {
      $mutation_consequence = $attribute_adaptor->get_value('mutation_consequence', $row->{mutation_consequence_attrib});
    }

    my $obj = Bio::EnsEMBL::G2P::GenomicFeatureDisease->new(
      -genomic_feature_disease_id => $row->{genomic_feature_disease_id},
      -genomic_feature_id => $row->{genomic_feature_id},
      -disease_id => $row->{disease_id},
      -allelic_requirement_attrib => $row->{allelic_requirement_attrib},
      -allelic_requirement => $allelic_requirement,
      -mutation_consequence_attrib => $row->{mutation_consequence_attrib},
      -mutation_consequnece => $mutation_consequence,
      -restricted_mutation_set => $row->{restricted_mutation_set},
      -adaptor => $self,
    );
    $self->{_temp_objs}{$row->{genomic_feature_disease_id}} = $obj;
    if (defined $row->{gfd_disease_synonym_id}) {
      $obj->add_gfd_disease_synonym_id($row->{gfd_disease_synonym_id});
    }
    if (defined $row->{panel_attrib}) {
      my $panel = $attribute_adaptor->get_value('g2p_panel', $row->{panel_attrib});
      $obj->add_panel($panel);
    }
  } else {
    if (defined $row->{gfd_disease_synonym_id}) {
      $obj->add_gfd_disease_synonym_id($row->{gfd_disease_synonym_id});
    }
    if (defined $row->{panel_attrib}) {
      my $panel = $attribute_adaptor->get_value('g2p_panel', $row->{panel_attrib});
      $obj->add_panel($panel);
    }
  }
}

1;
