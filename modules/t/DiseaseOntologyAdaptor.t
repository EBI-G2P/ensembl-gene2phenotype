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

use Test::More;
use Test::Exception;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');

my $g2pdb = $multi->get_DBAdaptor('gene2phenotype');

my $doa = $g2pdb->get_DiseaseOntologyAdaptor;
my $disease_adaptor = $g2pdb->get_DiseaseOntologyAdaptor;
my $ontology_adaptor = $g2pdb->get_OntologyTermAdaptor;

ok($doa && $doa->isa('Bio::EnsEMBL::G2P::DBSQL::DiseaseOntologyAdaptor'), 'isa DiseaseOntologyAdaptor');
#store 
#update
#fetch_all
#fetch_by_dbID
#fetch_by_disease
#fetch_by_ontology

my $disease_ontology = Bio::EnsEMBL::G2P::DiseaseOntology->new(
    -disease_id => 900,
    -ontology_accession_id => 200,
    -adaptor => $doa,
);
throws_ok{ $doa->store($disease_ontology);} qr/ mapped by attrib or mapped_by is required/, 'Die on missing mapped_by';


$multi->hide('gene2phenotype', 'disease_ontology_mapping');

$disease_ontology = Bio::EnsEMBL::G2P::DiseaseOntologyMapping->new(
    -disease_id => 900,
    -ontology_accesion_id => 500,
    -mapped_by_attrib => 438,
    -adaptor => $doa,
);

$disease_ontology = $doa->store($disease_ontology);

ok($disease_ontology->disease_id == 900, 'stored disease_id');
ok($disease_ontology->ontology_accesion_id == 500, 'stored ontology accession');
ok($disease_ontology->mapped_by_attrib == 438, ' stored mapped_by_attriib')

$disease_ontology->ontology_accesion_id('600');
$disease_ontology = $doa->update($disease_ontology);
ok($disease_ontology->ontology_accession_id == 600, 'update_done');

$disease_ontology = $doa->fetch_by_dbid($disease_ontology->dbID);
ok($disease_ontology->disease_id == 900, "fetched by dbID");

$disease_ontology = $doa->fetch_by_disease(900);
ok($disease_ontology->ontology_accession == 900, 'fetched by disease' );

$disease_ontology = $doa->fetch_by_ontology(600);
ok($disease_ontology->disease_id == 900, 'Fetched by omtology');

done_testing();

1;

