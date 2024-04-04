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
use Bio::EnsEMBL::G2P::GenomicFeatureDisease;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');

my $g2pdb = $multi->get_DBAdaptor('gene2phenotype');

my $gfdpa = $g2pdb->get_GenomicFeatureDiseasePhenotypeAdaptor;
my $gfda = $g2pdb->get_GenomicFeatureDiseaseAdaptor;

my $pa = $g2pdb->get_PhenotypeAdaptor;
my $ua = $g2pdb->get_UserAdaptor;
ok($gfdpa && $gfdpa->isa('Bio::EnsEMBL::G2P::DBSQL::GenomicFeatureDiseasePhenotypeAdaptor'), 'isa GenomicFeatureDiseasePhenotypeAdaptor');

my $GFDP_id = 2118;

my $GFDP = $gfdpa->fetch_by_dbID($GFDP_id);
ok($GFDP->dbID == $GFDP_id, 'fetch_by_dbID');

my $GFD_id = 133;
my $phenotype_id = 2282;
$GFDP = $gfdpa->fetch_by_GFD_id_phenotype_id($GFD_id, $phenotype_id);
ok($GFDP->dbID == $GFDP_id, 'fetch_by_GFD_id_phenotype_id');

my $GFD = $gfda->fetch_by_dbID($GFD_id);
my $GFDPs = $gfdpa->fetch_all_by_GenomicFeatureDisease($GFD);
ok(scalar @$GFDPs == 20, 'fetch_all_by_GenomicFeatureDisease');

my $phenotype = Bio::EnsEMBL::G2P::Phenotype->new(
  -stable_id => 'HP:0000218',
  -name => 'High palate',
);

$pa->store($phenotype);
$phenotype_id = $phenotype->{phenotype_id};

$GFDP = Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype->new(
  -genomic_feature_disease_id => 133,
  -phenotype_id => $phenotype_id,
  -adaptor => $gfdpa
);
my $username = 'user1';
my $user = $ua->fetch_by_username($username);

ok($gfdpa->store($GFDP, $user), 'store');
$GFDP_id = $GFDP->{genomic_feature_disease_phenotype_id};

my $dbh = $gfda->dbc->db_handle;
$dbh->do(qq{DELETE FROM phenotype WHERE phenotype_id=$phenotype_id;}) or die $dbh->errstr;
$dbh->do(qq{DELETE FROM genomic_feature_disease_phenotype WHERE genomic_feature_disease_phenotype_id=$GFDP_id;}) or die $dbh->errstr;

my $GFDPs2 = $gfdpa->fetch_all_by_phenotype_ids([971,4744,982,453,1570,443,506,2583,1783]);
ok(scalar @$GFDPs2 == 82, 'fetch_all_by_phenotype_ids');

done_testing();
1;
