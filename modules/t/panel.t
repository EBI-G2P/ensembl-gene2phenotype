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

my $pa = $g2pdb->get_PanelAdaptor;

my $panel_id = 1;
my $name = 'DD';
my $is_visible = 0;

my $panel = Bio::EnsEMBL::G2P::Panel->new(
  -panel_id => $panel_id,
  -name => $name,
  -is_visible => $is_visible,
  -adaptor => $pa,
);

ok($panel->dbID eq $panel_id, 'panel_id');
ok($panel->name eq $name, 'name');
ok($panel->is_visible eq $is_visible, 'is_visible');

$panel = $pa->fetch_by_name('Skin');
ok($panel->name eq 'Skin', 'Skin');
ok($panel->is_visible == 1, 'is_visible');
ok($panel->dbID == 4, 'dbID');

$panel = $pa->fetch_by_name('Ear');
ok($panel->is_visible == 0, 'is_visible');
# update is_visible
$panel->is_visible(1);
ok($panel->is_visible == 1, 'is_visible');
$pa->update($panel);

$panel = $pa->fetch_by_name('Ear');
ok($panel->is_visible == 1, 'is_visible');
# revert
$panel->is_visible(0);
ok($panel->is_visible == 0, 'is_visible');
$pa->update($panel);

my $panels = $pa->fetch_all_visible;
ok(scalar @$panels == 5, 'fetch_all_visible');

done_testing();
1;
