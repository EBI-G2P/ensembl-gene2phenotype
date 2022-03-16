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

package Bio::EnsEMBL::G2P::DBSQL::DiseaseOntologyAdaptor;

use Bio::EnsEMBL::G2P::DiseaseOntology;
use Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor;
use DBI qw(:sql_types);

our @ISA = ('Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor');


sub store {
  my $self = shift;
  my $DO = shift;
  
  my $dbh = $self->dbc->db_handle;
  
  if (!ref($DO) || $DO->isa('Bio::EnsEMBL::G2P::DiseaseOntology')){
    die("Bio::EnsEMBL::G2P::DiseaseOntology arg expected");
  }
  
  my $attribute_adaptor = $self->db->get_AttributeAdaptor;
  
  if (defined $DO->{mapped_by} && ! defined $DO->{mapped_by_attrib}){
    $DO->mapped_by_attrib = $attribute_adaptor->get_attrib('ontology_mapping', $DO->{mapped_by});
  }

  if (defined $DO->{mapped_by_attrib} && ! defined $DO->{mapped_by}){
    $DO->mapped_by = $attribute_adaptor->get_value('ontology_mapping', $DO->{mapped_by_attrib});
  }
  
  my $sth = $dbh->prepare(q{
    INSERT INTO disease_ontology_mapping (
      disease_id,
      ontology_accession_id, 
      mapped_by_attrib
    ) VALUES (?, ?, ?)
  });

  $sth->execute(
    $DO->{disease_id},
    $DO->{ontology_accession_id},
    $DO->{mapped_by_attrib}
  );

  $sth->finish();

  my $dbID  = $dbh->last_insert_id(undef, undef, 'disease_ontology_mapping', 'disease_ontology_mapping_id');
  $DO->{disease_ontology_mapping_id} = $dbID;

  return $DO;

}

sub update {
  my $self = shift;
  my $DO = shift;
  my $dbh = $self->dbc->db_handle;
  if (!ref($DO) || $DO->isa('Bio::EnsEMBL::G2P::DiseaseOntology')){
    die("Bio::EnsEMBL::G2P::DiseaseOntology arg expected");
  }

  my $sth = $dbh->prepare(q{
    UPDATE disease_ontology_mapping
    SET 
      mapped_by_attrib = ?
    WHERE disease_ontology_mapping_id = ?;
  });

  $sth->execute(
    $DO->mapped_by_attrib,
    $DO->dbID
  );
  
  $sth->finish();

  return $DO;

}

sub fetch_all {
  my $self = shift;
  return $self->generic_fetch();
}

sub fetch_by_dbID {
  my $self = shift;
  my $disease_ontology_mapping_id = shift;
  return $self->SUPER::fetch_by_dbID($disease_ontology_mapping_id);
}

sub fetch_by_disease {
 my $self = shift;
 my $disease = shift;
 my $disease_id = $disease->dbID;
 my $constraint = "DO.disease_id=$disease_id;";
 return $self->generic_fetch($constraint);
}

sub fetch_by_ontology {
  my $self = shift;
  my $ontolgy = shift;
  my $ontology_accession_id = $ontology->ontology_accession_id;
  my $constraint = "DO.ontology_accession_id=$ontology_accession_id";
  return $self->generic_fetch($constraint);
}

sub _columns {
  my $self = shift;
  my @cols = (
    'DO.disease_ontology_mapping_id',
    'DO.disease_id',
    'DO.disease_ontology_id',
    'DO.mapped_by_attrib',
  );
  return @cols;
}

sub _tables {
  my $self = shift;
  my @tables = (
    ['disease_ontology_mapping', 'DO'],
  );
  return @tables;
}


sub _objs_from_sth {
  my $self = shift;
  my $sth = shift;

  my (
    $disease_ontology_mapping_id,
    $disease_id,
    $ontology_accession_id,
    $mapped_by_attrib
  );

  $sth->bind_columns(\(
    $disease_ontology_mapping_id,
    $disease_id,
    $ontology_accession_id,
    $mapped_by_attrib,   
  ));

  my @objs;

  my $attribute_adaptor = $self->db->get_AttributeAdaptor;

  while ($sth->fetch()){
    my $
  }
}