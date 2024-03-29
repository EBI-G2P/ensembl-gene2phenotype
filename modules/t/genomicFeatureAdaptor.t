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

my $gfa = $g2pdb->get_GenomicFeatureAdaptor;

ok($gfa && $gfa->isa('Bio::EnsEMBL::G2P::DBSQL::GenomicFeatureAdaptor'), 'isa genomic_feature_adaptor');

my $dbID = 2141;
my $mim = '614828';
my $gene_symbol = 'POMGNT2';
my $ensembl_stable_id = 'ENSG00000144647';
my $synonym = 'GTDC2'; 

my $gfs = $gfa->fetch_all;
ok(scalar @$gfs == 2573, 'fetch_all');

my $gf = $gfa->fetch_by_dbID($dbID);
ok($gf->dbID == $dbID, 'fetch_by_dbID');

$gf = $gfa->fetch_by_mim($mim);
ok($gf->mim eq $mim, 'fetch_by_mim');

$gf = $gfa->fetch_by_ensembl_stable_id($ensembl_stable_id);
ok($gf->ensembl_stable_id eq $ensembl_stable_id, 'fetch_by_ensembl_stable_id');

$gf = $gfa->fetch_by_gene_symbol($gene_symbol);
ok($gf->gene_symbol eq $gene_symbol, 'fetch_by_gene_symbol');

$gf = $gfa->fetch_by_synonym($synonym);
ok($gf->gene_symbol eq $gene_symbol, 'fetch_by_synonym');

$gfs = $gfa->fetch_all_by_substring('KM');
ok(scalar @$gfs == 6, 'fetch_all_by_substring');

$gf = Bio::EnsEMBL::G2P::GenomicFeature->new(
  -mim => '610142',
  -gene_symbol => 'RAB27A',
  -ensembl_stable_id => 'ENSG00000069974',
);

ok($gfa->store($gf), 'store');

$gf = $gfa->fetch_by_gene_symbol('RAB27A');
ok($gf && $gf->gene_symbol eq 'RAB27A', 'fetch stored');

done_testing();
