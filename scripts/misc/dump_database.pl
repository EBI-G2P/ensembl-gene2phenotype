# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Getopt::Long;

my $config = {};
GetOptions(
  $config,
  'registry_file=s',
  'dump_name=s',
  'dump_dir=s',
);

if (!$config->{'dump_name'}) {
  die("Argument --dump_name NAME is required.");
}

my $registry_file = $config->{registry_file} || '/nfs/production/flicek/ensembl/variation/G2P/live_database/registry_file_live';
my $dump_name = $config->{dump_name};
my $dump_dir = $config->{dump_dir} || '/nfs/production/flicek/ensembl/variation/G2P/backups' ;

if (-e "$dump_dir/$dump_name.sql") {
  die "ERROR: A database dump with the name $dump_name already exists.\n";  
}

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($registry_file);
my $dba = $registry->get_DBAdaptor('human', 'gene2phenotype');
my $dbc = $dba->dbc;
my $host = $dbc->hostname;
my $port = $dbc->port;
my $dbname = $dbc->dbname;
my $user =  $dbc->user;
my $pwd = $dbc->password;

my $rc = system("mysqldump --single-transaction --column-statistics=0 -h $host -u $user -p'$pwd' -P $port $dbname > $dump_dir/$dump_name.sql");
if ($rc != 0) {
  die "Command failed\n";
}
