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
use Bio::EnsEMBL::G2P::GFDPhenotypeComment;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');

my $g2pdb = $multi->get_DBAdaptor('gene2phenotype');

my $gfdpca = $g2pdb->get_GFDPhenotypeCommentAdaptor;
my $gfdpa = $g2pdb->get_GenomicFeatureDiseasePhenotypeAdaptor;
my $ua = $g2pdb->get_UserAdaptor;

ok($gfdpca && $gfdpca->isa('Bio::EnsEMBL::G2P::DBSQL::GFDPhenotypeCommentAdaptor'), 'isa GFDPhenotypeCommentAdaptor');

my $gfdpc = $gfdpca->fetch_by_dbID(1);
ok($gfdpc->comment_text eq 'Only in a proportion of cases', 'comment text');

my $gfdp = $gfdpa->fetch_by_dbID(30248);
my $gfdps = $gfdpca->fetch_all_by_GenomicFeatureDiseasePhenotype($gfdp);
ok(scalar @$gfdps == 1, 'fetch_all_by_GenomicFeatureDiseasePhenotype');

my $user = $ua->fetch_by_dbID(1);

my $GFD_phenotype_id = 44130;
my $comment_text = 'comment';

$gfdpc = Bio::EnsEMBL::G2P::GFDPhenotypeComment->new(
  -genomic_feature_disease_phenotype_id => $GFD_phenotype_id,
  -comment_text => $comment_text,    
  -adaptor => $gfdpca,
);

ok($gfdpca->store($gfdpc, $user), 'store');

$gfdpc = $gfdpca->fetch_by_dbID($gfdpc->{GFD_phenotype_comment_id});

ok($gfdpc && $gfdpc->isa('Bio::EnsEMBL::G2P::GFDPhenotypeComment'), 'isa GFDPhenotypeComment');

ok($gfdpca->delete($gfdpc, $user), 'delete');

done_testing();
1;
