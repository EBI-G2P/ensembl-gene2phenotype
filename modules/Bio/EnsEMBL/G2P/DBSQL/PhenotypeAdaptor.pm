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

package Bio::EnsEMBL::G2P::DBSQL::PhenotypeAdaptor;

use Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::G2P::Phenotype;
our @ISA = ('Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor');

=head2 store

  Arg [1]    : Bio::EnsEMBL::G2P::Phenotype $phenotype
  Example    : $phenotype = Bio::EnsEMBL::G2P::Phenotype->new(...);
               $phenotype = $phenotype_adaptor->store($phenotype);
  Description: This stores a Phenotype in the database.
  Returntype : Bio::EnsEMBL::G2P::Phenotype
  Exceptions : Throw error if $phenotype is not a Bio::EnsEMBL::G2P::Phenotype
  Caller     :
  Status     : Stable

=cut

sub store {
  my $self = shift;
  my $phenotype = shift;  

  if (!ref($phenotype) || !$phenotype->isa('Bio::EnsEMBL::G2P::Phenotype')) {
    die('Bio::EnsEMBL::G2P::Phenotype arg expected');
  }

  my $dbh = $self->dbc->db_handle;

  my $sth = $dbh->prepare(q{
    INSERT INTO phenotype (
      stable_id,
      name,
      description,
      source
    ) VALUES (?,?,?,?);
  });
  $sth->execute(
    $phenotype->stable_id || undef,
    $phenotype->name || undef,
    $phenotype->description || undef,
    $phenotype->source || undef,
  );

  $sth->finish();

  # get dbID
  my $dbID = $dbh->last_insert_id(undef, undef, 'phenotype', 'phenotype_id');
  $phenotype->{phenotype_id} = $dbID;
  return $phenotype;
}

sub update {
  my $self = shift;
  my $phenotype = shift;
  my $dbh = $self->dbc->db_handle;

  if (!ref($phenotype) || !$phenotype->isa('Bio::EnsEMBL::G2P::Phenotype')) {
    die('Bio::EnsEMBL::G2P::Phenotype arg expected');
  }

  my $sth = $dbh->prepare(q{
    UPDATE phenotype
      SET stable_id = ?,
          name = ?,
          description = ?,
          source = ?
      WHERE phenotype_id = ? 
  });
  $sth->execute(
    $phenotype->{stable_id},
    $phenotype->{name},
    $phenotype->{description},
    $phenotype->{source},
    $phenotype->dbID
  );
  $sth->finish();

  return $phenotype;
}

sub fetch_by_phenotype_id {
  my $self = shift;
  my $phenotype_id = shift;
  $self->fetch_by_dbID($phenotype_id);
}

sub fetch_by_dbID {
  my $self = shift;
  my $phenotype_id = shift;
  return $self->SUPER::fetch_by_dbID($phenotype_id);
}

sub fetch_by_stable_id {
  my $self = shift;
  my $stable_id = shift;
  my $constraint = "p.stable_id='$stable_id'";
  my $result = $self->generic_fetch($constraint);
  return $result->[0];
}

sub fetch_by_stable_id_source {
  my $self = shift;
  my $stable_id = shift;
  my $source = shift;
  my $constraint = "p.stable_id='$stable_id' AND p.source='$source'";
  my $result = $self->generic_fetch($constraint);
  return $result->[0];
}

sub fetch_by_name {
  my $self = shift;
  my $name = shift;
  my $constraint = "p.name='$name'";
  my $result = $self->generic_fetch($constraint);
  return $result->[0]; 
}

sub fetch_by_name_substring {
  my $self = shift;
  my $name = shift;
  my $constraint = "p.name LIKE '%$name%'";
  my $result = $self->generic_fetch($constraint);
  return $result;
}

sub fetch_all_by_name_list_source {
  my $self = shift;
  my $names = shift;
  my $source = shift;
  my $names_concat = join(',', map {"'$_'"} @$names);
  my $constraint = "p.name IN ($names_concat)";
  return $self->generic_fetch($constraint);
}

sub fetch_all_by_stable_ids_source {
  my $self = shift;
  my $stable_ids = shift;
  my $source = shift;
  my $stable_ids_concat = join(',', map {"'$_'"} @$stable_ids);
  my $constraint = "p.stable_id IN ($stable_ids_concat) AND p.source='$source'";
  return $self->generic_fetch($constraint);
}

sub fetch_all {
  my $self = shift;
  return $self->generic_fetch();
}

sub fetch_all_by_substring {
  my $self = shift;
  my $substring = shift;
  my $constraint = "d.name LIKE '%$substring%' LIMIT 20";
  return $self->generic_fetch($constraint);
}

sub _columns {
  my $self = shift;
  my @cols = (
    'p.phenotype_id',
    'p.stable_id',
    'p.name',
    'p.description',
    'p.source',
  );
  return @cols;
}

sub _tables {
  my $self = shift;
  my @tables = (
    ['phenotype', 'p'],
  );
  return @tables;
}

=head2 _objs_from_sth

  Arg [1]    : StatementHandle $sth
  Description: Responsible for the creation of Phenotypes
  Returntype : listref of Bio::EnsEMBL::G2P::Phenotype
  Exceptions : None
  Caller     : Internal
  Status     : Stable

=cut

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my ($phenotype_id, $stable_id, $name, $description, $source);
  $sth->bind_columns(\($phenotype_id, $stable_id, $name, $description, $source));

  my @objs;
  while ($sth->fetch()) {
    my $obj = Bio::EnsEMBL::G2P::Phenotype->new(
      -phenotype_id => $phenotype_id,
      -stable_id => $stable_id,
      -name => $name, 
      -description => $description,
      -source => $source,
      -adaptor => $self,
    );
    push(@objs, $obj);
  }
  return \@objs;
}

1;
