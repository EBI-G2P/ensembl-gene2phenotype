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

my $ontology_accession = "MONDO_0006700";
my $description = "Cancer";

my $ot = Bio::EnsEMBL::G2P::OntologyTerm->new(
  -ontology_accession => $ontology_accession,
  -description => $description,
);

ok($ot->ontology_accession eq $ontology_accession, 'ontology_accession');
ok($ot->description eq $description, 'description');

done_testing();
1;