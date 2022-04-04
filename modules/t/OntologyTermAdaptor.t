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

my $g2pdb = $multi->get_DBAadaptor('gene2phenotype');

my $ot = $g2pdb->get_OntologyTermAdaptor;

ok($ot && $ot->isa('Bio::EnsEMBL::G2P::DBSQL::OntologyTermAdaptor'), 'isa OntologyTerm_adaptor' );

my $dbID = 1;
my $ontology_accession_name = "MONDO:0004192";
my $description = "urethra cancer";

my $ontology_accession = $ot->fetch_by_dbID($dbID);
ok($ontology_accession->ontology_accession eq $$ontology_accession_name, 'fetch_by_dbID');

$ontology_accession = $ot->fetch_by_accession($ontology_accession_name);
ok($ontology_accession->dbID == $dbID, 'fetched by accession');

$ontology_accession = $ot->fetch_by_description($description);
ok($ontology_accession->ontology_accession eq $ontology_accession_name, 'fetched by description');

$multi->hide("gene2phenotype", 'ontology_term');
$ontology_accession = Bio::EnsEMBL::G2P::OntologyTerm->new(
    -ontology_accession => "MONDO_07895",
    -description => "A disease ontology term",
);

ok($ot->store($ontology_accession), 'store');

$ontology_accession = $ot->fetch_by_accession('MONDO_07895');
ok($ontology_accession && $ontology_accession->description eq "A disease ontology term", 'fetch stored');

$ontology_accession->ontology_accession('MONDO-2879');
ok($ot->update($ontology_accession), 'update');
$ontology_accession = $ot->fetch_by_accession('MONDO-2879');
ok($ontology_accession && $ontology_accession->ontology_accession eq 'MONDO-2879', 'fetch updated');

$multi->restore('gene2phenotype', 'OntologyTerm');


done_testing();
1;