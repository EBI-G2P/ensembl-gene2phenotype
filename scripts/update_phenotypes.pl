#!/software/bin/perl
use strict;
use warnings;

use DBI;
use FileHandle;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
# perl update_phenotypes.pl -registry_file registry
# perl update_phenotypes.pl >out 2>err
my $config = {};

GetOptions(
  $config,
  'registry_file=s',
  'working_dir=s',
  'new_ontology_db_name=s',
  'ignore_deprecated_phenotypes'
) or die "Error: Failed to parse command line arguments\n";

die ('A registry_file file is required (--registry_file)') unless (defined($config->{registry_file}));
die ('A working_dir must be defiened (--working_dir)') unless (defined($config->{working_dir}));

my $registry = 'Bio::EnsEMBL::Registry';
my $registry_file = $config->{registry_file};
die ("Registry file ($registry_file) doesn't exist") unless (-e $registry_file);
$registry->load_all($registry_file);
my $dbh = $registry->get_DBAdaptor('human', 'gene2phenotype')->dbc->db_handle;
my $gfda = $registry->get_adaptor('human', 'gene2phenotype', 'genomicfeaturedisease');
my $gfdpa = $registry->get_adaptor('human', 'gene2phenotype', 'genomicfeaturediseasephenotype');

check_for_deprecated_phenotypes($config) unless ($config->{'ignore_deprecated_phenotypes'});
dump_g2p_phenotypes($config, 'g2p_phenotypes_before_update');
load_new_phenotypes($config);
add_phenotype_id_mapping();
update_to_new_phenotype_id();
cleanup();
dump_g2p_phenotypes($config, 'g2p_phenotypes_after_update');
compare_phenotypes($config, 'g2p_phenotypes_before_update', 'g2p_phenotypes_after_update');
healthchecks();

sub check_for_deprecated_phenotypes {
  my $config = shift;
  my $new_ontology_db_name = $config->{new_ontology_db_name};
  # find deprecated phenotypes 
  my $sth = $dbh->prepare(qq{
    SELECT p.phenotype_id, p.stable_id, p.name FROM phenotype p
    LEFT JOIN $new_ontology_db_name.term t ON p.stable_id = t.accession
    LEFT JOIN $new_ontology_db_name.ontology o on t.ontology_id = o.ontology_id
    WHERE o.name = 'HP'
    AND p.stable_id IS NULL;
  });
  $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
  my @phenotype_ids = ();
  while (my $row = $sth->fetchrow_arrayref()) {
    my ($phenotype_id, $stable_id, $name) = @{$row};
    print STDERR "Removing deprecated phenotype: $stable_id, $name\n";
    push @phenotype_ids, $phenotype_id;
  }
  if (scalar @phenotype_ids > 0) {
    remove_deprecated_phenotypes(\@phenotype_ids);
  }
}

sub dump_g2p_phenotypes {
  my $config = shift;
  my $filename = shift;
  my $working_dir = $config->{working_dir};
  die ("Working directory ($working_dir) doesn't exist") unless (-d $working_dir);
  my $fh = FileHandle->new("$working_dir/$filename", 'w');
  my $gfds = $gfda->fetch_all();
  foreach my $gfd (@{$gfds}) {
    my $phenotypes = join(',', sort map {$_->get_Phenotype()->stable_id()} @{$gfd->get_all_GFDPhenotypes()});
    print $fh join(' ', $gfd->dbID, $phenotypes), "\n";
  }
  $fh->close();
}

sub load_new_phenotypes {
  my $config = shift;
  my $new_ontology_db_name = $config->{new_ontology_db_name};

  $dbh->do(qq{CREATE TABLE phenotype_old LIKE phenotype;}) or die $dbh->errstr;
  $dbh->do(qq{INSERT INTO phenotype_old SELECT * FROM phenotype;}) or die $dbh->errstr;

  $dbh->do(qq{TRUNCATE TABLE phenotype;}) or die $dbh->errstr;
  $dbh->do(qq{
    INSERT INTO phenotype(phenotype_id, stable_id, name, source)
    SELECT t.term_id, t.accession, t.name, 'HP' FROM $new_ontology_db_name.term t, $new_ontology_db_name.ontology o
    WHERE t.ontology_id = o.ontology_id
    AND o.name = 'HP'; 
  }) or die $dbh->errstr;
}

sub add_phenotype_id_mapping {
  $dbh->do(qq{ALTER TABLE phenotype ADD COLUMN old_phenotype_id int(10) AFTER source;}) or die $dbh->errstr;
  $dbh->do(qq{ALTER TABLE phenotype ADD INDEX `old_phenotype_id` (`old_phenotype_id`);}) or die $dbh->errstr;

  $dbh->do(qq{
    UPDATE phenotype p, phenotype_old p_old SET p.old_phenotype_id = p_old.phenotype_id WHERE p_old.stable_id=p.stable_id;
  }) or die $dbh->errstr;
}

sub update_to_new_phenotype_id {
  # Tables with phenotype_id
  for my $table (qw/genomic_feature_disease_phenotype genomic_feature_disease_phenotype_deleted GFD_phenotype_log/) {
    $dbh->do(qq{ UPDATE $table t, phenotype p SET t.phenotype_id = p.phenotype_id WHERE p.old_phenotype_id = t.phenotype_id; }) or die $dbh->errstr;  
  }
}

sub cleanup {
  $dbh->do(qq{ALTER TABLE phenotype DROP COLUMN old_phenotype_id;}) or die $dbh->errstr;
  $dbh->do(qq{DROP TABLE phenotype_old;}) or die $dbh->errstr;
}

sub compare_phenotypes {
  my $config = shift;
  my $g2p_phenotypes_before_update = shift;
  my $g2p_phenotypes_after_update = shift; 
  my $working_dir = $config->{working_dir};

  my $before_entries = _load_phenotype_file("$working_dir/$g2p_phenotypes_before_update");
  my $after_entries =  _load_phenotype_file("$working_dir/$g2p_phenotypes_after_update");

  foreach my $gfd_id (keys %{$after_entries}) {
    if (!exists $before_entries->{$gfd_id}) {
      print "GFD id ($gfd_id) is not in before update set, which shouldn't happen.\n";
    } else {
      if ($before_entries->{$gfd_id} ne $after_entries->{$gfd_id}) {
        print "Phenotypes changed after update for GFD id ($gfd_id):\n";
        print "    Before: " . $before_entries->{$gfd_id} . "\n";
        print "    After: " . $after_entries->{$gfd_id} . "\n";
      }
    }
  }
}

sub remove_deprecated_phenotypes {
  my $phenotype_ids = shift;
  my $gfdpa = $registry->get_adaptor('human', 'gene2phenotype', 'genomicfeaturediseasephenotype');
  my $gfd_phenotypes = $gfdpa->fetch_all_by_phenotype_ids($phenotype_ids);
  foreach my $gfd_phenotype (@{$gfd_phenotypes}) {
    my $gfdp_id = $gfd_phenotype->dbID; 
    foreach my $table (qw/genomic_feature_disease_phenotype GFD_phenotype_log GFD_phenotype_comment/) {
      _dump_rows_to_stderr(qq{SELECT * FROM $table WHERE genomic_feature_disease_phenotype_id=$gfdp_id;});
      $dbh->do(qq{DELETE FROM $table WHERE genomic_feature_disease_phenotype_id=$gfdp_id;}) or die $dbh->errstr;
    }
  }
  foreach my $phenotype_id (@{$phenotype_ids}) {
    foreach my $table (qw/genomic_feature_disease_phenotype_deleted phenotype/) {
      _dump_rows_to_stderr(qq{SELECT * FROM genomic_feature_disease_phenotype_deleted WHERE phenotype_id=$phenotype_id;});
      $dbh->do(qq{DELETE FROM $table WHERE phenotype_id=$phenotype_id;}) or die $dbh->errstr;
    }
  }
}

sub _dump_rows_to_stderr {
  my $query = shift;
  print STDERR "Run: $query\n";
  my $sth = $dbh->prepare($query);
  $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
  while (my $row = $sth->fetchrow_arrayref()) {
    print STDERR join(' ', @$row), "\n";
  }
  $sth->finish();
}

sub healthchecks {
  # foreig key check on phenotype_id
  foreach my $table (qw/genomic_feature_disease_phenotype genomic_feature_disease_phenotype_deleted GFD_phenotype_log/) {
    my $sth = $dbh->prepare(qq{
      SELECT count(*) FROM $table t
      LEFT JOIN phenotype p ON t.phenotype_id = p.phenotype_id
      WHERE p.phenotype_id IS NULL;
    });
    $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
    my ($count) = $sth->fetchrow_array();
    print STDERR "healthchecks foreign key check $table $count\n";
    $sth->finish();
  }
  
  foreach my $table (qw/GFD_phenotype_comment GFD_phenotype_comment_deleted/) {
    my $sth = $dbh->prepare(qq{
      SELECT count(*) FROM $table t
      LEFT JOIN genomic_feature_disease_phenotype gfdp ON t.genomic_feature_disease_phenotype_id = gfdp.genomic_feature_disease_phenotype_id
      WHERE gfdp.genomic_feature_disease_phenotype_id IS NULL;
    });
    $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
    my ($count) = $sth->fetchrow_array();
    print STDERR "healthchecks foreign key check $table $count\n";
    $sth->finish();
  }
}

sub _load_phenotype_file {
  my $file = shift;
  my $entries = {};
  my $fh = FileHandle->new($file, 'r');
  while (<$fh>) {
    chomp;
    my ($gfd_id, $phenotypes) = split(' ', $_);
    $entries->{$gfd_id} = $phenotypes;
  }
  $fh->close();
  return $entries;
}

sub _get_count_sql {
  my $query = shift;
  my $sth = $dbh->prepare($query);
  $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
  my ($count) = $sth->fetchrow_array();
  return $count;
}

