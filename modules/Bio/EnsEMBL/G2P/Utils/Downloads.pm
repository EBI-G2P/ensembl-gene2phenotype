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

package Bio::EnsEMBL::G2P::Utils::Downloads;
use strict;
use warnings;
use Text::CSV;
use Bio::EnsEMBL::Registry;
use base qw(Exporter);
our @EXPORT_OK = qw( download_data );

my $gfd_attributes = {};
my $gfd_panel_create_dates = {};
my $gfid2synonyms = {};
my $comments_text = {};
my $confidence_category_attribs = {};
my $allelic_requirement_attribs = {};
my $cross_cutting_modifier_attribs = {};
my $mutation_consequence_attribs = {};
my $mutation_consequence_flag_attribs = {};


=head2 download_data
  Arg [1]    : String $downloads_dir - download file to this directory
  Arg [2]    : String $file_name - name of download file
  Arg [3]    : String $registry_file - for connecting to the G2P database
  Arg [4]    : Boolean $is_logged_in - stores if the user is logged in
  Arg [5]    : String $panel_name - download data for this panel
  Description: Download all GenomicFeatureDisease entries for the panel
  Returntype : Boolean 1
  Exceptions : - Throw error if there is problem during creation of Text::CSV 
               - Throw error if file cannot be compressed
  Caller     : gene2phenotype_app/lib/Gene2phenotype.pm
  Status     : Stable
=cut

sub download_data {
  my $downloads_dir = shift;
  my $file_name = shift;
  my $registry_file = shift;
  my $is_logged_in = shift;
  my $panel_name = shift;
  my $registry = 'Bio::EnsEMBL::Registry';
  $registry->load_all($registry_file);

  my $file = "$downloads_dir/$file_name";
  
  my $GFD_adaptor = $registry->get_adaptor('human', 'gene2phenotype', 'genomicfeaturedisease');
  my $attribute_adaptor = $registry->get_adaptor('human', 'gene2phenotype', 'attribute');
  my $panel_adaptor = $registry->get_adaptor('human', 'gene2phenotype', 'panel');

  my @g2p_panels;
  if ($is_logged_in) {
    @g2p_panels = map {$_->name} @{$panel_adaptor->fetch_all};
  } else {
    @g2p_panels = map {$_->name} @{$panel_adaptor->fetch_all_visible};
  }

  # get hashes which map attrib id to value for all supported values in each category:
  # confidence_category, allelic_requirement and mutation_consequence  
  $confidence_category_attribs = $attribute_adaptor->get_attribs_by_type('confidence_category');  
  $allelic_requirement_attribs = $attribute_adaptor->get_attribs_by_type('allelic_requirement');
  $cross_cutting_modifier_attribs = $attribute_adaptor->get_attribs_by_type('cross_cutting_modifier');
  $mutation_consequence_attribs = $attribute_adaptor->get_attribs_by_type('mutation_consequence');
  $mutation_consequence_flag_attribs = $attribute_adaptor->get_attribs_by_type('mutation_consequence_flag');

  my $dbh = $GFD_adaptor->dbc->db_handle;

  my $csv = Text::CSV->new ( { binary => 1, eol => "\r\n" } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
  open my $fh, ">:encoding(utf8)", "$file" or die "$file: $!";

  # Write header to file
  $csv->print($fh, ['gene symbol', 'gene mim', 'disease name', 'disease mim', 'confidence category', 'allelic requirement', 'mutation consequence', 'phenotypes', 'organ specificity list', 'pmids', 'panel', 'prev symbols', 'hgnc id', 'gene disease pair entry date', 'cross cutting modifier', 'mutation consequence flag', 'confidence value flag', 'comments']);

  $csv->eol ("\r\n");

  # preload phenotypes, organs and publications for all GenomicFeatureDiseases in the database 
  my $gfd_attribute_tables = {
    phenotype => {sql => 'SELECT gfdp.genomic_feature_disease_id, p.stable_id FROM genomic_feature_disease_phenotype gfdp, phenotype p WHERE gfdp.phenotype_id = p.phenotype_id;'},
    organ => {sql => 'SELECT gfdo.genomic_feature_disease_id, o.name FROM genomic_feature_disease_organ gfdo, organ o WHERE gfdo.organ_id = o.organ_id'},
    publication => {sql => 'SELECT gfdp.genomic_feature_disease_id, p.pmid FROM genomic_feature_disease_publication gfdp, publication p WHERE gfdp.publication_id = p.publication_id;'},
  };
   
  foreach my $table (keys %$gfd_attribute_tables) {
    my $sql = $gfd_attribute_tables->{$table}->{sql};
    my $sth = $dbh->prepare($sql);
    $sth->execute() or die 'Could not execute statement: ' . $sth->errstr;
    while (my $row = $sth->fetchrow_arrayref()) {
      my ($id, $value) = @$row;
      $gfd_attributes->{$id}->{$table}->{$value} = 1;
    }
  }

  # $gfd_attributes = {
  #    $gfd_id => {
  #       phenotype => {
  #        'HP:0000007' => 1,
  #         ...
  #       },
  #       organ => {
  #        'Eye' => 1,
  #        ...
  #       },
  #       publication => {
  #         18423520 => 1,
  #         ...
  #       }
  #    },
  #   
  #
  # }


  # For each genomic feature preload all genomic feature synonyms.
  # The synonyms will be stored as prev symbols in the download file

  my $sth = $dbh->prepare('SELECT genomic_feature_id, name FROM genomic_feature_synonym;');
  $sth->execute() or die 'Could not execute statement: ' . $sth->errstr;
  while (my $row = $sth->fetchrow_arrayref()) {
    my ($id, $value) = @$row;
    $gfid2synonyms->{$id}->{$value} = 1;
  }

  # Retrieve the date when the entry was created, when the GenomicFeatureDisease was added to the panel
  # This information needs to be extracted from the genomic_feature_disease_panel_log table

  $sth = $dbh->prepare(q{SELECT genomic_feature_disease_panel_id, created FROM genomic_feature_disease_panel_log WHERE action='create';});
  $sth->execute() or die 'Could not execute statement: ' . $sth->errstr;
  while (my $row = $sth->fetchrow_arrayref()) {
    my ($gfd_panel_id, $created) = @$row;
    $gfd_panel_create_dates->{$gfd_panel_id} = $created;
  }
  $sth->finish();

  $sth = $dbh->prepare(q{SELECT genomic_feature_disease_comment_id, comment_text from genomic_feature_disease_comment WHERE is_public = 1;});
  $sth->execute() or die 'Could not execute statement: ' . $sth->errstr;
  while (my $row = $sth->fetchrow_arrayref()) {
    my ($gfd_comment_id, $text) = @$row;
    $comments_text->{$gfd_comment_id} = $text;
  }
  $sth->finish();

  my $where;
  if ($panel_name eq 'ALL') {
    foreach my $panel (@g2p_panels) {
      if ($is_logged_in) {
        $where = "WHERE a.value = '$panel'"; # user is logged in and can see all entries, we don't need to restrict to visible only
      } else {
        $where = "WHERE a.value = '$panel' AND gfdp.is_visible = 1";
      }
      write_data($dbh, $csv, $fh, $where);
    }
  } else {
    if ($is_logged_in) {
      $where = "WHERE a.value = '$panel_name'"; # user is logged in and can see all entries, we don't need to restrict to visible only
    } else {
      $where = "WHERE a.value = '$panel_name' AND gfdp.is_visible = 1";
    }
    write_data($dbh, $csv, $fh, $where);
  }

  close $fh or die "$csv: $!";
  system("/usr/bin/gzip $file");
  return 1;
}

=head2 write_data
  Arg [1]    : DBI database handle $dbh - used for the database connection 
  Arg [2]    : Text::CSV $csv - for writing CSV file 
  Arg [3]    : FileHandle $fh - for writing CSV file
  Arg [4]    : String $where - where clause to define which panel to download
               and if only visible entries
  Description: Write data for the given panel to file
  Returntype : None
  Exceptions : Throw error if query cannot be executed. 
  Caller     : Bio::EnsEMBL::G2P::Utils::Downloads::download_data 
  Status     : Stable
=cut

sub write_data {
  my $dbh = shift;
  my $csv = shift;
  my $fh = shift;
  my $where = shift;

  # get all GenomicFeatureDisease entries for the given panel
  # only select visible entries if constraint is given in the where clause 

  my $sth = $dbh->prepare(qq{
    SELECT gfd.genomic_feature_disease_id, gfdp.genomic_feature_disease_panel_id, gf.gene_symbol, gf.hgnc_id, gf.mim, d.name, d.mim, gfdp.confidence_category_attrib, gfd.allelic_requirement_attrib, gfd.mutation_consequence_attrib, a.value, gf.genomic_feature_id, gfd.cross_cutting_modifier_attrib, gfd.mutation_consequence_flag_attrib, gfdp.clinical_review, gfdc.genomic_feature_disease_comment_id
    FROM genomic_feature_disease gfd
    LEFT JOIN genomic_feature_disease_panel gfdp ON gfd.genomic_feature_disease_id = gfdp.genomic_feature_disease_id
    LEFT JOIN genomic_feature gf ON gfd.genomic_feature_id = gf.genomic_feature_id
    LEFT JOIN disease d ON gfd.disease_id = d.disease_id
    LEFT JOIN attrib a ON gfdp.panel_attrib = a.attrib_id
    LEFT JOIN genomic_feature_disease_comment gfdc ON gfd.genomic_feature_disease_id = gfdc.genomic_feature_disease_id 
    $where;
  });
  $sth->execute() or die 'Could not execute statement: ' . $sth->errstr;

  my ($gfd_id, $gfd_panel_id, $gene_symbol, $hgnc_id, $gene_mim, $disease_name, $disease_mim, $confidence_category_attrib, $ar_attrib, $mc_attrib, $panel, $gfid, $prev_symbols, $created, $ccm_attrib, $mcf_attrib, $clinical_review, $gfdc_id);
  # Bind values from SQL query to variables
  # it is important that the order is kept as defined in the SQL query
  $sth->bind_columns(\($gfd_id, $gfd_panel_id, $gene_symbol, $hgnc_id, $gene_mim, $disease_name, $disease_mim, $confidence_category_attrib, $ar_attrib, $mc_attrib, $panel, $gfid, $ccm_attrib, $mcf_attrib, $clinical_review, $gfdc_id));

  while ( $sth->fetch ) {
    $gene_symbol ||= 'No gene symbol';
    $hgnc_id ||= 'No hgnc id';
    $gene_mim ||= 'No gene mim';
    $disease_name ||= 'No disease name';
    $disease_mim ||= 'No disease mim';

    # map attrib ids to values
    my $confidence_category = ($confidence_category_attrib) ? $confidence_category_attribs->{$confidence_category_attrib} : 'No confidence category';
    my $allelic_requirement = ($ar_attrib) ? $allelic_requirement_attribs->{$ar_attrib} : undef;
    my $mutation_consequence = ($mc_attrib) ? $mutation_consequence_attribs->{$mc_attrib} : undef;
    my $cross_cutting_modifier = ($ccm_attrib) ? join(' ; ', map{$cross_cutting_modifier_attribs->{$_} } split(',', $ccm_attrib) ): undef;
    my $mutation_consequence_flag = ($mcf_attrib) ? $mutation_consequence_flag_attribs->{$mcf_attrib} : undef;
    my $clinical_review_flag = ($clinical_review && $clinical_review == 1) ? "Requires clinical review" : undef;
    # get all annotations for a GenomicFeatureDisease
    # The order (phenotype organ publication) is the same as in the download file header
    # and needs to be kept
    my @annotations = ();
    if ($gfd_attributes->{$gfd_id}) {
      foreach my $table (qw/phenotype organ publication/) {
        if ($gfd_attributes->{$gfd_id}->{$table}) {
          push @annotations, join(';', keys %{$gfd_attributes->{$gfd_id}->{$table}});
        } else {
          push @annotations, undef;
        }
      }
    } else {
      push @annotations, (undef, undef, undef);
    }
    $prev_symbols = undef; 
    if ($gfid2synonyms->{$gfid})  {
      $prev_symbols = join(';', keys %{$gfid2synonyms->{$gfid}});
    }  

    $created = $gfd_panel_create_dates->{$gfd_panel_id} || 'No date';
    my $comments = ($gfdc_id && $comments_text->{$gfdc_id}) ? $comments_text->{$gfdc_id} : "No comment";
    # The order is important and corresponds to the order of the fields in the header row 
    my @row = ($gene_symbol, $gene_mim, $disease_name, $disease_mim, $confidence_category, $allelic_requirement, $mutation_consequence, @annotations, $panel, $prev_symbols, $hgnc_id, $created, $cross_cutting_modifier, $mutation_consequence_flag, $clinical_review_flag, $comments);

    $csv->print ($fh, \@row);
  }
  $sth->finish;

}

1;
