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
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');

my $g2pdb = $multi->get_DBAdaptor('gene2phenotype');

my $do = $g2pdb->get_DiseaseOntologyAdaptor;

my $disease_id = 500;
my $ontology_accession_id = 600;
my $mapped_by = "OLS exact";

my $do_term = Bio::EnsEMBL::G2P::DiseaseOntology->new(
    -disease_id => $disease_id,
    -ontology_accession_id => $ontology_accession_id,
    -mapped_by => $mapped_by,
    -adaptor => $do,
);

ok($do_term->disease_id == $disease_id, 'disease_id');
ok($do_term->ontology_accession_id == $ontology_accession_id, 'ontology_accession_id');
ok($do_term->mapped_by eq $mapped_by, 'mapped_by');
ok($do_term->mapped_by_attrib == 438, 'mapped_by_attrib');

my $dbID = 456;
$do_term = $do->fetch_by_dbID($dbID);
ok($do_term->dbID == $dbID, 'fetched by dbID');
ok($do_term->disease_ontology_mapping_id == $dbID, 'fetched by disease ontology mapping id' );

done_testing();
1;