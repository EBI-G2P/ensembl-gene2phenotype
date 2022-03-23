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

use Test::Exception;
use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Data::Dumper;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');

my $g2pdb = $multi->get_DBAdaptor('gene2phenotype');

my $aa = $g2pdb->get_AttributeAdaptor;

ok($aa && $aa->isa('Bio::EnsEMBL::G2P::DBSQL::AttributeAdaptor'), 'isa AttributeAdaptor');

my $g2p_panel_attribs =  {
  'Cancer' => 42,
  'PaedNeuro' => 48,
  'ALL' => 36,
  'Eye' => 40,
  'DD' => 38,
  'Skin' => 41,
  'Cardiac' => 37,
  'Prenatal' => 43,
  'Rapid_PICU_NICU' => 47,
  'Demo' => 46,
  'NeonatalRespiratory' => 45,
  'Ear' => 39,
  'Skeletal' => 83,
};

my $attribs = $aa->get_values_by_type('g2p_panel');
is_deeply($attribs, $g2p_panel_attribs, 'get_attribs_by_type - g2p_panel');
ok($aa->get_attrib('g2p_panel', 'DD') == $g2p_panel_attribs->{DD}, 'get_attrib');
ok($aa->get_value('g2p_panel', 42) eq 'Cancer', 'get_value');

throws_ok { $aa->get_attrib('g2p_panel', 'DDD'); } qr/Could not get attrib for value/, 'get_attrib - wrong value';
throws_ok { $aa->get_attrib('panel', 'DD'); } qr/Could not get attrib for value/, 'get_attrib - wrong type';
throws_ok { $aa->get_value('g2p_panel', '388'); } qr/Could not get value for attrib/, 'get_value - wrong value';
throws_ok { $aa->get_value('panel', '38'); } qr/Could not get value for attrib/, 'get_value - wrong type';


done_testing();
1;
