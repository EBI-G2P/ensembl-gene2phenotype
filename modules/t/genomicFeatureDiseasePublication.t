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

my $gfdpa = $g2pdb->get_GenomicFeatureDiseasePublicationAdaptor;

ok($gfdpa && $gfdpa->isa('Bio::EnsEMBL::G2P::DBSQL::GenomicFeatureDiseasePublicationAdaptor'), 'isa GenomicFeatureDiseasePublicationAdaptor');

my $GFDP_id = 4083;
my $GFD_id = 2028;
my $publication_id = 24954;

my $GFDP = Bio::EnsEMBL::G2P::GenomicFeatureDiseasePublication->new(
  -genomic_feature_disease_publication_id => $GFDP_id,
  -genomic_feature_disease_id => $GFD_id,
  -publication_id => $publication_id,
  -adaptor => $gfdpa,
);

my $GFD = $GFDP->get_GenomicFeatureDisease();
ok($GFD->dbID == $GFD_id, 'get_GenomicFeatureDisease');
my $publication = $GFDP->get_Publication();
ok($publication->dbID == $publication_id, 'get_Publication');
my $GFDPComments = $GFDP->get_all_GFDPublicationComments();
ok(scalar @$GFDPComments == 1, 'get_all_GFDPublicationComments');

done_testing();
1;
