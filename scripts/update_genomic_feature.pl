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

use DBI;
use FileHandle;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
# perl update_publication.pl -registry_file registry
# perl update_publication.pl >out 2>err
my $config = {};

GetOptions(
  $config,
  'registry_file=s',
  'working_dir=s',
  'version=s'
) or die "Error: Failed to parse command line arguments\n";

my $version = $config->{version};
die ('version must be defiend (--version)') unless defined($version);

die ('A registry_file file is required (--registry_file)') unless (defined($config->{registry_file}));
die ('A working_dir must be defiened (--working_dir)') unless (defined($config->{working_dir}));
my $working_dir = $config->{working_dir};

`wget -P $working_dir https://storage.googleapis.com/public-download-files/hgnc/tsv/tsv/hgnc_complete_set.txt`;
if (! -e "$working_dir/hgnc_complete_set.txt") {
  die("File ($working_dir/hgnc_complete_set.txt) doesn't exist.");
}
$config->{hgnc_mapping_file} = "$working_dir/hgnc_complete_set.txt";

`wget -P $working_dir https://ftp.ensembl.org/pub/release-$version/gtf/homo_sapiens/Homo_sapiens.GRCh38.$version.chr.gtf.gz`;
if (! -e "$working_dir/Homo_sapiens.GRCh38.$version.chr.gtf.gz") {
  die("File ($working_dir/Homo_sapiens.GRCh38.$version.chr.gtf.gz) doesn't exist.");
}
`gunzip $working_dir/Homo_sapiens.GRCh38.$version.chr.gtf.gz`;
$config->{gtf_file} = "$working_dir/Homo_sapiens.GRCh38.$version.chr.gtf";

my $registry = 'Bio::EnsEMBL::Registry';
my $registry_file = $config->{registry_file};
$registry->load_all($registry_file);

my $dbh = $registry->get_DBAdaptor('human', 'gene2phenotype')->dbc->db_handle;

my $gfa = $registry->get_adaptor('human', 'gene2phenotype', 'genomicfeature');
my $gfda = $registry->get_adaptor('human', 'gene2phenotype', 'genomicfeaturedisease');

# exclude biotypes
my @exclude_biotypes = qw/pseudogene misc_RNA/;

# find all tables with genomic_feature_id

my @G2P_tables_with_genomic_feature_id_link = qw/
genomic_feature_disease
genomic_feature_disease_deleted
genomic_feature_disease_log
genomic_feature_disease_log_deleted
genomic_feature_statistic/;

my $old_g2p_gene_symbols = get_g2p_gene_symbols();

genomic_feature_id_foreign_key_check();
# - check each table with genomic_feature_id column if all data in that column exists in the genomic_feature table
my $gene_xrefs_before_update = get_gene_xrefs_for_GFD();

my $fh_db_updates = FileHandle->new($config->{working_dir} . "/DB_udpdates_" . $config->{version} . ".txt", 'w');

load_latest_geneset_from_gtf();
# - parse line with gene_name, gene_id and gene_biotype from GTF file
# - a gene_symbol can have more than one ensembl_stable_id mappings, if that is the case we choose the lowest ENSG identifier
# - exlcude genes with certain biotypes
# - print mapping counts and biotype counts to file
update_to_new_gene_symbol();
# - join genomic_feature_update table with genomic_feature on ensembl_stable_id where gene_symbol is not the same
# - update gene_symbol
# - don't update gene_symbol where readable gene_symbol has been replaced by e.g. AC080038.1 and gene_symbol is used by G2P
# - otherwise update gene_symbol
load_new_ensembl_genes();
# - get new ensembl_stable_ids and their mapped gene_symbol and load them into the genomic_feature table
# - if the gene_symbol is already present in the genomic_feature table only update the ensembl_stable_id

delete_outdated_genomic_features();
# - delete everything from genomic_feature which is not in genomic_feature_update and is also not used by any G2P table
# - clean up everything from genomic_feature_synonym which is not linked to genomic_feature

update_xrefs();
# - use HGNC file for updating HGNC ids and previouse gene symbols
# - update works by mapping the gene_symbol

update_search();
# - repopulate search table with new gene_symbols

cleanup();
# - drop genomic_feature_update

healthchecks();
# foreign key checks for all tables which use genomic_feature_id

my $gene_xrefs_after_update = get_gene_xrefs_for_GFD();

foreach my $panel (keys %$gene_xrefs_after_update) {
  foreach my $gfd_id (keys %{$gene_xrefs_after_update->{$panel}}) {
    my $xrefs_before = $gene_xrefs_before_update->{$panel}->{$gfd_id};
    my $xrefs_after = $gene_xrefs_after_update->{$panel}->{$gfd_id};
    if ($xrefs_before->{'gene_symbol'} ne $xrefs_after->{'gene_symbol'} ) {
      print STDERR "$panel Changed gene_symbol after update $gfd_id ", $xrefs_before->{'gene_symbol'}, ' => ', $xrefs_after->{'gene_symbol'}, "\n";
    }
    if ($xrefs_before->{'mim'} ne $xrefs_after->{'mim'} ) {
      my $gene_symbol = $xrefs_after->{'gene_symbol'};
      print STDERR "$panel Changed gene mim after update $gfd_id, $gene_symbol ", $xrefs_before->{'mim'}, ' => ', $xrefs_after->{'mim'}, "\n";
    }
  }
}

sub get_g2p_gene_symbols {
  my $g2p_gene_symbols = {};
  my $sth = $dbh->prepare(q{
    SELECT gf.gene_symbol FROM genomic_feature_disease gfd
    LEFT JOIN genomic_feature gf ON gfd.genomic_feature_id = gf.genomic_feature_id;
  });
  $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
  while (my $row = $sth->fetchrow_arrayref()) {
    my ($gene_symbol) = @$row;
    $g2p_gene_symbols->{$gene_symbol} = 1;
  }
  $sth->finish();
  return $g2p_gene_symbols;
}

sub genomic_feature_id_foreign_key_check {
  foreach my $table (@G2P_tables_with_genomic_feature_id_link) {
    my $sth = $dbh->prepare(qq{
      SELECT count(t.genomic_feature_id) FROM $table t
      LEFT JOIN genomic_feature gf ON t.genomic_feature_id = gf.genomic_feature_id
      WHERE gf.genomic_feature_id IS NULL;
    });
    $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
    my ($count) = $sth->fetchrow_array();
    if ($count) {
      die "Found $count unlinked entries in table $table after genomic_feature_id foreign key check\n";
    }
  }
}

sub get_gene_xrefs_for_GFD {
  my $gene_attribs = {};
  my $sth = $dbh->prepare(q{
    SELECT gf.genomic_feature_id, a.value, gf.gene_symbol, gf.mim FROM genomic_feature_disease gfd
    LEFT JOIN genomic_feature gf ON gfd.genomic_feature_id = gf.genomic_feature_id
    LEFT JOIN genomic_feature_disease_panel gfdp ON gfd.genomic_feature_disease_id = gfdp.genomic_feature_disease_id
    LEFT JOIN attrib a ON gfdp.panel_attrib = a.attrib_id
  });
  $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
  while (my $row = $sth->fetchrow_arrayref()) {
    my ($gf_id, $panel, $gene_symbol, $mim) = @$row;
    $gene_attribs->{$panel}->{$gf_id}->{'gene_symbol'} = $gene_symbol;
    $gene_attribs->{$panel}->{$gf_id}->{'mim'} = $mim || 'NA';
  }
  $sth->finish();
  return $gene_attribs;
}

sub load_latest_geneset_from_gtf {
  my $gene_symbol_2_ensembl_stable_id_from_GTF = read_from_gtf(); 
  $dbh->do(qq{DROP TABLE IF EXISTS genomic_feature_update;}) or die $dbh->errstr;
  $dbh->do(qq{CREATE TABLE genomic_feature_update LIKE genomic_feature;}) or die $dbh->errstr;
  while (my ($gene_symbol, $stable_id) = each %$gene_symbol_2_ensembl_stable_id_from_GTF) {
    $dbh->do(qq{INSERT INTO genomic_feature_update(gene_symbol, ensembl_stable_id) values("$gene_symbol", "$stable_id");}) or die $dbh->errstr;
  }
}

sub read_from_gtf {
  my $gtf_file = $config->{'gtf_file'};
  my $fh = FileHandle->new($gtf_file, 'r');
  my $gene_symbol_2_stable_id = {};
  my $count_biotypes = {};
  my $stable_id_2_gene_symbol = {};
  while (<$fh>) {
    next if(/^#/); #ignore header
    chomp;
    my @values = split/\t/;
    my $attributes = $values[8];
    my @add_attributes = split(";", $attributes);
    # store ids and additional information in second hash
    my %attribs = ();
    foreach my $attr ( @add_attributes ) {
      if ($attr =~ /gene_id/ || $attr =~ /gene_name/ || $attr =~ /gene_biotype/) {
        next unless $attr =~ /^\s*(.+)\s(.+)$/;
        my $type  = $1;
        my $value = $2;
        if ($type  && $value){
          $attribs{$type} = $value;
        }
      }
    }
    my $gene_symbol = $attribs{gene_name};
    $gene_symbol =~ s/"//g;
    my $stable_id = $attribs{gene_id};
    $stable_id =~ s/"//g;
    my $biotype = $attribs{gene_biotype};
    $biotype =~ s/"//g;
    next unless ($gene_symbol && $stable_id && $biotype);
    $count_biotypes->{$biotype}->{$stable_id} = 1;
    my $exclude = 0;
    foreach my $exlcude_biotype (@exclude_biotypes) {
      if ($biotype =~ /$exlcude_biotype/) {
        $exclude = 1;
        last;
      }
    } 
    $gene_symbol_2_stable_id->{$gene_symbol}->{$stable_id} = 1 if (!$exclude);
  }
  $fh->close();
  `rm $gtf_file`;
  # count how many gene symbols have more than 1 stable id mappings
  # count how many stable ids have more than 1 gene symbol mappings
  _print_biotype_counts($count_biotypes);
  _print_counts($stable_id_2_gene_symbol, 'stable_id_mappings_counts.txt');
  _print_counts($gene_symbol_2_stable_id, 'gene_symbol_mappings_counts.txt');

  my $unique_gene_symbol_2_stable_id = {};

  foreach my $gene_symbol (keys %$gene_symbol_2_stable_id) {
    my @stable_ids = sort keys %{$gene_symbol_2_stable_id->{$gene_symbol}};
    if (scalar @stable_ids > 1) {
      print STDERR "More than one stable id for $gene_symbol: ", join(', ', @stable_ids), "\n";
    }
    my $stable_id = $stable_ids[0];
    $unique_gene_symbol_2_stable_id->{$gene_symbol} = $stable_id;
  }
   
  my $out_file = $config->{working_dir} . '/ensembl_genes_grch38.txt';
  my $fh_out = FileHandle->new($out_file, 'w');
  while (my ($gene_symbol, $stable_id) = each %$unique_gene_symbol_2_stable_id) {
    print $fh_out "$stable_id\t$gene_symbol\n";
  }
  $fh_out->close();

  return $unique_gene_symbol_2_stable_id;

}

sub _print_counts {
  my $mappings = shift;
  my $file_name = shift;
  my $count_mappings = {};

  foreach my $id (keys %$mappings) {
    my $counts = scalar keys %{$mappings->{$id}};
    $count_mappings->{$counts}++;
  }

  my $out_file = $config->{working_dir} . '/' . $file_name;
  my $fh_out = FileHandle->new($out_file, 'w');
  while (my ($mapping, $count) = each %$count_mappings) {
    print $fh_out "$count\t$mapping\n";
  }
  $fh_out->close();
}

sub _print_biotype_counts {
  my $count_biotypes = shift;
  my $out_file = $config->{working_dir} . '/biotype_counts.txt';
  my $fh_out = FileHandle->new($out_file, 'w');
  my $total_count = 0;
  my $total_count_after_filter = 0;
  foreach my $biotype (sort keys %$count_biotypes) {
    print $fh_out $biotype, ' ', scalar keys %{$count_biotypes->{$biotype}}, "\n";
    $total_count += scalar keys %{$count_biotypes->{$biotype}};
    if ($biotype !~ m/pseudogene/ && $biotype ne 'misc_RNA') {
      $total_count_after_filter += scalar keys %{$count_biotypes->{$biotype}};
    }
  }
  print $fh_out "total_count $total_count\n";
  print $fh_out "total_count_after_filter $total_count_after_filter\n";

  $fh_out->close();
}

sub delete_outdated_genomic_features {
  # check if G2P tables are using outdated genomic_feature_ids

  foreach my $table (@G2P_tables_with_genomic_feature_id_link) {
    my $sth = $dbh->prepare(qq{
      SELECT gf.genomic_feature_id FROM genomic_feature gf
      LEFT JOIN genomic_feature_update new ON gf.ensembl_stable_id = new.ensembl_stable_id
      WHERE new.ensembl_stable_id IS NULL
      AND gf.genomic_feature_id IN (SELECT genomic_feature_id from $table);
    });
    my $outdated_gf_in_GFD = {};
    $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
    while (my $row = $sth->fetchrow_arrayref()) {
      $outdated_gf_in_GFD->{$row->[0]} = 1;
    }
    $sth->finish();
    print $fh_db_updates "delete_outdated_genomic_features Count outdated GF in $table: " . scalar keys %$outdated_gf_in_GFD, "\n";
  }

  $dbh->do(qq{DROP TABLE IF EXISTS genomic_feature_ids;}) or die $dbh->errstr;
  $dbh->do(qq{CREATE TABLE genomic_feature_ids LIKE genomic_feature_disease;}) or die $dbh->errstr;
  $dbh->do(qq{ALTER TABLE genomic_feature_ids DROP disease_id;}) or die $dbh->errstr;

  foreach my $table (@G2P_tables_with_genomic_feature_id_link) {
     $dbh->do(qq{INSERT INTO genomic_feature_ids(genomic_feature_id) SELECT genomic_feature_id from $table;}) or die $dbh->errstr;
  }

  # Find outdated genomic_feature IDs used in G2P panels:
  my $sth = $dbh->prepare(qq{
    SELECT gf.genomic_feature_id, gf.gene_symbol FROM genomic_feature gf
    LEFT JOIN genomic_feature_update new ON gf.ensembl_stable_id = new.ensembl_stable_id
    WHERE new.ensembl_stable_id IS NULL
    AND gf.genomic_feature_id IN (SELECT genomic_feature_id from genomic_feature_ids);
  }) or die $dbh->errstr;
  $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
  while (my $row = $sth->fetchrow_arrayref()) {
    print STDERR "Outdated genomic_features used in G2P: ", join(',', @$row), "\n";
  }
  $sth->finish();

  $dbh->do(qq{
    DELETE gf.* FROM genomic_feature gf
    LEFT JOIN genomic_feature_update new ON gf.ensembl_stable_id = new.ensembl_stable_id
    WHERE new.ensembl_stable_id IS NULL
    AND gf.genomic_feature_id NOT IN (SELECT genomic_feature_id from genomic_feature_ids);
  }) or die $dbh->errstr;

  $dbh->do(qq{
    DELETE gfs.* FROM genomic_feature_synonym gfs
    LEFT JOIN genomic_feature gf ON gfs.genomic_feature_id = gf.genomic_feature_id
    WHERE gf.genomic_feature_id IS NULL;
  }) or die $dbh->errstr;

  $dbh->do(qq{DROP TABLE IF EXISTS genomic_feature_ids;}) or die $dbh->errstr;

}

sub update_to_new_gene_symbol {
  # store old gene_symbol as synonym
  my $updates = {}; 
  my $sth = $dbh->prepare(q{
    SELECT new.gene_symbol, old.genomic_feature_id, old.gene_symbol FROM genomic_feature_update new
    LEFT JOIN genomic_feature old ON new.ensembl_stable_id = old.ensembl_stable_id
    WHERE new.gene_symbol != old.gene_symbol;
  });
  $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
  while (my $row = $sth->fetchrow_arrayref()) {
    my ($new_gene_symbol, $old_genomic_feature_id, $old_gene_symbol) = @$row;
    $updates->{$old_genomic_feature_id}->{$old_gene_symbol} = $new_gene_symbol;
  }
  $sth->finish();

  foreach my $genomic_feature_id (keys %$updates) {
    foreach my $old_gene_symbol (keys %{$updates->{$genomic_feature_id}}) {
      my $new_gene_symbol = $updates->{$genomic_feature_id}->{$old_gene_symbol};
      if (looks_like_identifier($new_gene_symbol) && !looks_like_identifier($old_gene_symbol) && $old_g2p_gene_symbols->{$old_gene_symbol}) {
        print STDERR "update_to_new_gene_symbol Don't update to new_gene_symbol $old_gene_symbol -> $new_gene_symbol\n";
        $dbh->do(qq{
          INSERT IGNORE INTO genomic_feature_synonym(genomic_feature_id, name) VALUES($genomic_feature_id, "$new_gene_symbol");
        }) or die $dbh->errstr;
      } else {
        print $fh_db_updates "update_to_new_gene_symbol UPDATE genomic_feature SET gene_symbol=\"$new_gene_symbol\" WHERE genomic_feature_id=$genomic_feature_id;\n";
        $dbh->do(qq{
          UPDATE genomic_feature SET gene_symbol="$new_gene_symbol" WHERE genomic_feature_id=$genomic_feature_id;
        }) or die $dbh->errstr;
      }
    }
  }
}

sub looks_like_identifier {
  my $symbol = shift;
  return ($symbol =~ /^[A-Z]+[0-9]+\.[0-9]+/);  
}

sub load_new_ensembl_genes {
  my $new_gene_symbols;
  my $sth = $dbh->prepare(q{
    SELECT new.gene_symbol, new.ensembl_stable_id FROM genomic_feature_update new
    LEFT JOIN genomic_feature old ON new.ensembl_stable_id = old.ensembl_stable_id
    WHERE old.ensembl_stable_id IS NULL;
  });
  $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
  while (my $row = $sth->fetchrow_arrayref()) {
    my ($new_gene_symbol, $ensembl_stable_id) = @$row;
    $new_gene_symbols->{$new_gene_symbol} = $ensembl_stable_id;
  }
  $sth->finish();

  my $gene_symbols_already_in_use = {};
  $sth = $dbh->prepare(q{
    SELECT gene_symbol FROM genomic_feature;
  });
  $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
  while (my $row = $sth->fetchrow_arrayref()) {
    $gene_symbols_already_in_use->{$row->[0]} = 1;
  }
  $sth->finish();

  while (my ($gene_symbol, $ensembl_stable_id) = each %$new_gene_symbols) {
    if ($gene_symbols_already_in_use->{$gene_symbol}) {
      print STDERR "load_new_ensembl_genes Stable ID has changed for gene symbol $gene_symbol\n";  
      $dbh->do(qq{
        UPDATE genomic_feature SET ensembl_stable_id="$ensembl_stable_id" WHERE gene_symbol="$gene_symbol";
      }) 
  } else {
      print $fh_db_updates "load_new_ensembl_genes INSERT INTO genomic_feature(gene_symbol, ensembl_stable_id) VALUES(\"$gene_symbol\", \"$ensembl_stable_id\")\n";  
      $dbh->do(qq{
        INSERT INTO genomic_feature(gene_symbol, ensembl_stable_id) VALUES("$gene_symbol", "$ensembl_stable_id");
      }) or die $dbh->errstr;
    }
  }
}

sub update_xrefs {
  my $working_dir = shift;
  my $hgnc_mapping_file = $config->{hgnc_mapping_file};

  my $fh_hgnc = FileHandle->new($hgnc_mapping_file, 'r');
  my $hgnc_mappings = {};
  my $symbol2id_mappings = {};

  my $mappings = {};
  my @header = ();
  while (<$fh_hgnc>) {
    chomp;
    if (/^hgnc_id/) {
      @header = split/\t/;
    } else {
      my @values = split/\t/;
      my %data = map {$header[$_] => $values[$_]} (0..$#header);
      my $symbol = $data{'symbol'};
      next if (!$symbol);
      foreach my $id_type (qw/hgnc_id prev_symbol ncbi_id ensembl_gene_id omim_id/) {
        next if (!$data{$id_type});
        my $id = $data{$id_type};
        $id =~ s/"|HGNC://g; # remove prefix HGNC: e.g. HGNC:123 -> 123, remove " e.g. "123|345" -> 123|345
        if ($id =~ /\|/) {
          foreach (split('\|', $id)) {
            $mappings->{$symbol}->{$id_type}->{$_} = 1;
          }
        } else {
          $mappings->{$symbol}->{$id_type}->{$id} = 1;
        }
      }
    }
  }
  $fh_hgnc->close();
  `rm $hgnc_mapping_file`;

  my $GFs = $gfa->fetch_all;

  my $gene_symbols = {};

  foreach my $gf (@$GFs) {
    my $genomic_feature_id = $gf->dbID;
    my @gf_synonyms = @{$gf->get_all_synonyms};
    my $gene_symbol = $gf->gene_symbol;

    if (!$gene_symbol) {
      print STDERR 'update_xrefs -- no gene_symbol for ', $gf->dbID, "\n";
    } else {
      update_xref_id('hgnc_id', $gf, $mappings->{$gene_symbol}->{hgnc_id}); 
      update_xref_id('ncbi_id', $gf, $mappings->{$gene_symbol}->{ncbi_id}); 
      update_xref_id('mim', $gf, $mappings->{$gene_symbol}->{omim_id}); 

      if (scalar keys %{$mappings->{$gene_symbol}->{prev_symbol}} > 0) {
        foreach my $prev_gene_symbol (keys %{$mappings->{$gene_symbol}->{prev_symbol}}) {
          if (! grep( /^$prev_gene_symbol$/, @gf_synonyms ) ) {
            print $fh_db_updates "update_xrefs Update prev gene symbols: INSERT INTO genomic_feature_synonym(genomic_feature_id, name) VALUES($genomic_feature_id, '$prev_gene_symbol');\n";
           $dbh->do(qq{INSERT IGNORE INTO genomic_feature_synonym(genomic_feature_id, name) VALUES($genomic_feature_id, '$prev_gene_symbol');}) or die $dbh->errstr;
          }
        }
      }
    }
  }
}

sub update_xref_id {
  my $xref_name = shift;
  my $gf = shift;
  my $mappings = shift;
  my @xref_values = keys %$mappings;
  if (scalar @xref_values > 1) {
    print STDOUT "update_xrefs More than one mapping for xref $xref_name: ", join(',',  @xref_values), " Gene symbol: ", $gf->gene_symbol, "\n";
    return;
  }
  return if (scalar @xref_values == 0);
  my $xref_value = $xref_values[0];
  if ($xref_value && (!$gf->$xref_name || ($gf->$xref_name && $gf->$xref_name != $xref_value)) ) {
    update_xrefs_sql($xref_name, $xref_value, $gf->dbID);
  }
}

sub update_xrefs_sql {
  my $column_name = shift;
  my $column_value = shift;
  my $genomic_feature_id = shift;
    print $fh_db_updates "update_xrefs UPDATE genomic_feature SET $column_name=$column_value WHERE genomic_feature_id=$genomic_feature_id;\n";
    $dbh->do(qq{UPDATE genomic_feature SET $column_name=$column_value WHERE genomic_feature_id=$genomic_feature_id;}) or die $dbh->errstr;
}

sub update_search {
  $dbh->do(qq{CREATE TABLE search_update LIKE search});
  $dbh->do(qq{INSERT IGNORE INTO search_update SELECT distinct gene_symbol from genomic_feature;}) or die $dbh->errstr;
  $dbh->do(qq{INSERT IGNORE INTO search_update SELECT distinct name from disease;}) or die $dbh->errstr;
  $dbh->do(qq{INSERT IGNORE INTO search_update SELECT distinct name from genomic_feature_synonym;}) or die $dbh->errstr;

  my $sth = $dbh->prepare(q{
    SELECT distinct * FROM search_update;
  });
  $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
  my @new_search_terms = ();
  while (my $row = $sth->fetchrow_arrayref()) {
    my ($term) = @$row;
    push @new_search_terms, $term if (!looks_like_identifier($term));
  }
  $sth->finish();
  $dbh->do(qq{TRUNCATE search;}) or die $dbh->errstr;
  foreach my $term (@new_search_terms) {
    $dbh->do(qq{INSERT search(search_term) values("$term");}) or die $dbh->errstr;
  }
}

sub cleanup {
  $dbh->do(qq{DROP TABLE IF EXISTS genomic_feature_update;}) or die $dbh->errstr;
  $dbh->do(qq{DROP TABLE IF EXISTS search_update;}) or die $dbh->errstr;
}

sub healthchecks {
  foreach my $table (qw/genomic_feature_disease genomic_feature_disease_deleted genomic_feature_disease_log genomic_feature_disease_log_deleted genomic_feature_statistic genomic_feature_synonym/) {
    my $sth = $dbh->prepare(qq{
      SELECT count(*) FROM $table t
      LEFT JOIN genomic_feature gf ON t.genomic_feature_id = gf.genomic_feature_id
      WHERE gf.genomic_feature_id IS NULL;
    });
    $sth->execute() or die 'Could not execute statement ' . $sth->errstr;
    my ($count) = $sth->fetchrow_array();
    print STDERR "healthchecks foreign key check $table $count\n";
    $sth->finish();
  }
}

