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

package Bio::EnsEMBL::G2P::DBSQL::OntologyTermAdaptor;

use Bio::EnsEMBL::G2P::OntologyTerm;
use Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor;
use DBI qw(:sql_types);

our @ISA = ('Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor');

sub store {
  my $self = shift;
  my $OntologyTerm = shift; 

  if (!ref($OntologyTerm) || !$OntologyTerm->isa('Bio::EnsEMBL::G2P::OntologyTerm')){
      die("Bio::EnsEMBL::G2P::OntologyTerm arg expected");
  }

  my $dbh = $self->dbc->db_handle;

  my $sth = $dbh->prepare(q{
    INSERT INTO ontology_term (
      ontology_accession, 
      description
    ) VALUES (?,?)
  });

  $sth->execute(
      $OntologyTerm->ontology_accession,
      $OntologyTerm->description || undef,
  );

  $sth->finish;

  #get dbID 
  my $dbID = $dbh->last_insert_id(undef, undef, 'OntologyTerm', 'ontology_accession_id' );
  $OntologyTerm->{ontology_accession_id} = $dbID;
  $OntologyTerm->{dbID} = $dbID;
  return $OntologyTerm;
}

sub update {
  my $self = shift;
  my $OntologyTerm = shift; 
  my $db = $self->dbc->db_handle;

  if (!ref($OntologyTerm) || !$OntologyTerm->isa('Bio::EnsEMBL::G2P::OntologyTerm')){
      die('Bio::EnsEMBL::G2P::OntologyTerm arg expecte');
  }

  my $sth = $db->prepare(q{
      UPDATE ontology_term 
        SET ontology_accession = ?,
          description = ?,
        WHERE ontology_accession_id = ?;
  }); 

  $sth->execute(
    $OntologyTerm->ontology_accession,
    $OntologyTerm->description,
  );

  $sth->finish();
  return $OntologyTerm;


}

sub fetch_all {
  my $self = shift;
  return $self->generic_fetch();
}

sub fetch_by_dbID {
  my $self = shift;
  my $ontology_accession_id = shift;
  return $self->SUPER::fetch_by_dbID($ontology_accession_id);
}

sub fetch_by_description {
  my $self = shift;
  my $description = shift; 
  $description = s/'/\\'/g;
  my $constraint = "OntologyTerm.description='$description'";
  my $result = $self->generic_fetch($constraint);
  return $result->[0];
}

sub fetch_all_by_description {
  my $self = shift;
  my $description = shift;
  $description =  s/'/\\'/g;
  my $constraint = "OntologyTerm.description='$description'";
  my $result = $self->generic_fetch($constraint);
  return $result; 
}

sub fetch_by_accession {
  my $self = shift;
  my $ontology_accession = shift;
  my $constraint = "OntologyTerm.ontology_accession='$ontology_accession'";
  my $result = $self->generic_fetch($constraint);
  return $result->[0]; 
}

sub _columns {
  my $self = shift;
  my @cols = (
    'OntologyTerm.ontology_accession_id',
    'OntologyTerm.ontology_accession',
    'OntologyTerm.description'
  );
  return @cols;
}

sub _tables {
  my $self = shift;
  my @tables = (
      ['ontology_term', 'OntologyTerm'],
  );
  return @tables;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my ($ontology_accession_id, $ontology_accession, $description);
  $sth->bind_columns(\($ontology_accession_id, $ontology_accession, $description));

  my @objs;
  while ($sth->fetch()){
    my $obj = Bio::EnsEMBL::G2P::OntologyTerm->new(
      -ontology_accession_id => $ontology_accession_id,
      -ontology_accession => $ontology_accession,
      -description => $description,
      -adaptor => $self,
    );
    push(@objs, $obj);    
  }
  return \@objs;
}

1;