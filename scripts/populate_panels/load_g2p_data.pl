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


=head1 NAME

load_g2p_data.pl 

=head1 DESCRIPTION

Imports new entries and annotations from a spreadsheet into the gene2phenotype database

=head1 SYNOPSIS

load_g2p_data.pl [arguments]

=head1 OPTIONS

=over 4

=item B<--help>

Displays this documentation

=item B<--email email>

Email of the curator who provided the import file.
Email address needs to be the same that is used when
logging in to the gene2phenotype website.

=item B<--panel panel>

G2P panel to which the new entries from the import
file are added.

=item B<--registry_file FILE >

Registry file which provides database connections
gene2phenotype database.

=item B<--report_file FILE>

A summary of the imported entries and annotations
is written to the report fil

=item B<--import_file FILE>

A spreadsheet which contains new entries and annotations
that will be imported into the gene2phenotype database
for the given panel.

=item B<--check_input_data>

The input data is checked for: missing data, wrong values
and existing entries in the database with the same gene symbol,
allelic requirement and mutation consequence.

The report is writted to STDERR. No data is imported into
the database.

Supported columns:
- gene symbol
- gene mim
- disease name
- disease mim
- confidence category
- allelic requirement
- cross cutting modifier
- mutation consequence
- mutation consequences flag 
- phenotypes
- organ specificity list
- pmids
- panel
- comments 
- public comments 
- other disease names
- add after review

=back

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use DBI;
use FileHandle;
use Getopt::Long;
use Pod::Usage qw(pod2usage);
use Spreadsheet::Read;
use Text::CSV;

my $args = scalar @ARGV;
my $config = {};
GetOptions(
  $config,
  'help|h',
  'registry_file=s',
  'email=s',
  'import_file=s',
  'panel=s',
  'report_file=s',
  'check_input_data',
) or die "Error: Failed to parse command line arguments\n";

pod2usage(1) if ($config->{'help'} || !$args);

foreach my $param (qw/registry_file email import_file panel report_file/) {
  die ("Argument --$param is required.") unless (defined($config->{$param}));
}

my $registry = 'Bio::EnsEMBL::Registry';
my $registry_file = $config->{registry_file};
$registry->load_all($registry_file);

my $species = 'human';
my $gf_adaptor                  = $registry->get_adaptor($species, 'gene2phenotype', 'GenomicFeature');
my $disease_adaptor             = $registry->get_adaptor($species, 'gene2phenotype', 'Disease');
my $gfd_adaptor                 = $registry->get_adaptor($species, 'gene2phenotype', 'GenomicFeatureDisease');
my $gfd_panel_adaptor           = $registry->get_adaptor($species, 'gene2phenotype', 'GenomicFeatureDiseasePanel');
my $gfd_disease_synonym_adaptor = $registry->get_adaptor($species, 'gene2phenotype', 'GFDDiseaseSynonym');
my $gfd_publication_adaptor     = $registry->get_adaptor($species, 'gene2phenotype', 'GenomicFeatureDiseasePublication');
my $gfd_organ_adaptor           = $registry->get_adaptor($species, 'gene2phenotype', 'GenomicFeatureDiseaseOrgan');
my $gfd_phenotype_adaptor       = $registry->get_adaptor($species, 'gene2phenotype', 'GenomicFeatureDiseasePhenotype');
my $publication_adaptor         = $registry->get_adaptor($species, 'gene2phenotype', 'Publication');
my $organ_adaptor               = $registry->get_adaptor($species, 'gene2phenotype', 'Organ');
my $phenotype_adaptor           = $registry->get_adaptor($species, 'gene2phenotype', 'Phenotype');
my $attrib_adaptor              = $registry->get_adaptor($species, 'gene2phenotype', 'Attribute');
my $user_adaptor                = $registry->get_adaptor($species, 'gene2phenotype', 'User');
my $gfd_comment_adaptor         = $registry->get_adaptor($species, 'gene2phenotype', 'GenomicFeatureDiseaseComment');

my $email = $config->{email};
my $user = $user_adaptor->fetch_by_email($email);
die "Couldn't fetch user for email $email" if (!defined $user);

# Add new entry to this panel
my $g2p_panel = $config->{panel};
my $panel_attrib_id = $attrib_adaptor->get_attrib('g2p_panel', $g2p_panel);
die "Couldn't fetch panel_attrib_id for panel $g2p_panel" if (!defined $g2p_panel);



my @required_fields = (
  'gene symbol',
  'disease name',
  'confidence category',
  'allelic requirement',
  'mutation consequence',
  'panel'
);

my $report_file = $config->{report_file};
my $import_stats = {};

my $fh_report = FileHandle->new($report_file, 'w');

my $file = $config->{import_file};
die "Data file $file doesn't exist" if (!-e $file);
my $book  = ReadData($file);
my $sheet = $book->[1];
my @rows = Spreadsheet::Read::rows($sheet);
my @header = ();

foreach my $row (@rows) {
  if ($row->[0] =~ /^gene symbol/) {
    @header = @$row;
    next;
  }
  my %data = map {$header[$_] => $row->[$_]} (0..$#header);

  my $gene_symbol = $data{'gene symbol'}; 
  my $gene_mim = $data{'gene mim'};
  my $disease_name = $data{'disease name'};
  my $disease_mim = $data{'disease mim'};
  my $confidence_category = $data{'confidence category'};
  my $allelic_requirement = $data{'allelic requirement'};
  my $cross_cutting_modifier = $data{'cross cutting modifier'};
  my $mutation_consequence = $data{'mutation consequence'};
  my $mutation_consequence_flag = $data{'mutation consequences flags'};
  my $panel = $data{'panel'};
  my $prev_symbols = $data{'prev symbols'};
  my $hgnc_id = $data{'hgnc id'};
  my $restricted_mutation_set = $data{'restricted mutation set'};
  my $add_after_review = $data{'add after review'};

  my $entry = "$gene_symbol Target panel: $g2p_panel";

  if (!$panel) {
    if ($config->{check_input_data}) {
      print STDERR "$entry\n";
      print STDERR "    ERROR: No panel information provided\n";
      print STDERR "    ERROR: Cannot proceed data checking for this entry\n";
      next;
    } else {
      die "ERROR: No panel information provided for $entry\n";
    }
  }
 
  next if (!add_new_entry_to_panel($panel));
  $entry = "Gene symbol: $gene_symbol; Disease name: $disease_name; Confidence category: $confidence_category; Allelic requirement: $allelic_requirement; Mutation consequence: $mutation_consequence; Target panel: $g2p_panel ";
  $entry = $entry . "Cross cutting modifier: $cross_cutting_modifier; " if $cross_cutting_modifier;
  $entry = $entry . "Mutation consequence flags: $mutation_consequence_flag; " if $mutation_consequence_flag;
  
  print STDERR "$entry\n" if ($config->{check_input_data});
  my $has_missing_data = 0;
  foreach my $field (@required_fields) {
    if (! $data{$field}) {
      $has_missing_data = 1;
      print STDERR "    ERROR: Data for required field ($field) is missing.\n" if ($config->{check_input_data});
    } 
  } 
  if ($config->{check_input_data} && $has_missing_data) {
    print STDERR "    ERROR: Cannot proceed data checking for this entry\n";
    next;
  }

  my $gf = get_genomic_feature($gene_symbol, $prev_symbols);

  if (!$gf) {
    die "ERROR: No genomic feature for $gene_symbol\n";
  }

  if (!$disease_name) {
    die "ERROR: No disease name for $gene_symbol, $allelic_requirement, $mutation_consequence\n";
  }

  my $disease = get_disease($disease_name, $disease_mim);

  my $confidence_attrib;
  my $allelic_requirement_attrib;
  my $cross_cutting_modifier_attrib;
  my $mutation_consequence_attrib; 
  my $mutation_consequence_flag_attrib;

  eval { $confidence_attrib = get_confidence_attrib($confidence_category) };
  if ($@) {
    if ($config->{check_input_data}) {
      print STDERR "    ERROR: There was a problem retrieving the confidence attrib $@";
      print STDERR "    ERROR: Cannot proceed data checking for this entry\n";
      next;
    } else {
      die "There was a problem retrieving the confidence attrib for entry $entry $@";
    }
  }

  eval { $allelic_requirement_attrib = get_allelic_requirement_attrib($allelic_requirement) };
  if ($@) {
    if ($config->{check_input_data}) {
      print STDERR "    ERROR: There was a problem retrieving the allelic requirement attrib $@";
      print STDERR "    ERROR: Cannot proceed data checking for this entry\n";
      next;
    } else {
      die "There was a problem retrieving the allelic requirement attrib for entry $entry $@";
    }
  }
  if ($cross_cutting_modifier){
    eval { $cross_cutting_modifier_attrib = get_cross_cutting_modifier_attrib($cross_cutting_modifier)};
    if ($@) {
      if ($config->{check_input_data}) {
        print STDERR "    ERROR: There was a problem retrieving the cross cutting modifier attrib $@";
        print STDERR "    ERROR: Cannot proceed data checking for this entry\n";
        next;
      } else {
        die "There was a problem retrieving the cross cutting modifier attrib for entry $entry $@";
      }
    }
  }
  eval { $mutation_consequence_attrib = get_mutation_consequence_attrib($mutation_consequence) };
  if ($@) {
    if ($config->{check_input_data}) {
      print STDERR "    ERROR: There was a problem retrieving the mutation consequence attrib $@";
      print STDERR "    ERROR: Cannot proceed data checking for this entry\n";
      next;
    } else {
      die "There was a problem retrieving the mutation consequence attrib for entry $entry $@";
    }
  }
  
  if ($mutation_consequence_flag){
    eval { $mutation_consequence_flag_attrib = get_mutation_consequence_flag_attrib($mutation_consequence_flag)};
    if ($@) {
      if ($config->{check_input_data}) {
        print STDERR "     ERROR: There was a problem retrieving the mutation consequence flag attrib $@";
        print STDERR "     ERROR: Cannot proceed data checking for this entry \n";
        next;
      } else {
        die "There was a problem retrieving the mutation consequence flag attrib for entry $entry $@";
      }
    }
  }

  # Try to get existing entries with same gene symbol, allelic requirement and mutation consequence
  my $gfds = $gfd_adaptor->fetch_all_by_GenomicFeature_constraints(
    $gf,
    {
      'allelic_requirement_attrib' => $allelic_requirement_attrib,
      'mutation_consequence_attrib' => $mutation_consequence_attrib,
    }
  );

  my @gfds_with_matching_disease_name = grep { $_->get_Disease->dbID eq $disease->dbID } @{$gfds};  

  if ($config->{check_input_data}) {
    if (scalar @$gfds == 0) {
      print STDERR "    Create new entry\n";
    } elsif (scalar @gfds_with_matching_disease_name == 1) {
      my $gfd = $gfds_with_matching_disease_name[0];
      my $gfd_panels = join(', ', @{$gfd->panels});
      print STDERR "    Entry exists already in panel(s): $gfd_panels\n";
    } else {
      print STDERR "    ERROR: Entries with same gene symbol, mutation consequence and allelic requirement already exist:\n";
      if (!$data{'add after review'}) {
        print STDERR "        The user must indicate if a new entry should be created (add 1 to 'add after review' column) or\n";
        print STDERR "        the disease name must match the disease name of the existing entry. Additional disease names can\n";
        print STDERR "        be added to the 'other disease names' column\n";
        print STDERR "        Existing entries:\n";
        foreach my $gfd (@$gfds) {
          my $gfd_panels = join(', ', @{$gfd->panels});
          print STDERR "        > ", join('; ', $gfd->get_GenomicFeature->gene_symbol, $gfd->get_Disease->name, $gfd->allelic_requirement, $gfd->mutation_consequence, $gfd_panels), "\n"; 
        }
      }
    }
  } else {
    if (scalar @$gfds == 0) { 
      # Entries with same gene symbol, allelic requirement and mutation consequence don't exist
      # Create new GenomicFeatureDiease and GenomicFeatureDiseasePanel
      my $gfd = create_gfd($gf, $disease, $allelic_requirement_attrib, $cross_cutting_modifier_attrib, $mutation_consequence_attrib, $mutation_consequence_flag_attrib);
      add_gfd_to_panel($gfd, $g2p_panel, $confidence_attrib);
      add_annotations($gfd, %data);
    } elsif (scalar @gfds_with_matching_disease_name == 1) {
      my $gfd = $gfds_with_matching_disease_name[0];
      my $is_already_in_target_panel = grep {$g2p_panel eq $_} @{$gfd->panels};
      if ($is_already_in_target_panel) {
        update_gfd_panel($gfd, $g2p_panel, $confidence_attrib);
        add_annotations($gfd, %data);
      } else {
        add_gfd_to_panel($gfd, $g2p_panel, $confidence_attrib);
        add_annotations($gfd, %data);
      } 
    } else {
      if ($add_after_review) {
        my $gfd = create_gfd($gf, $disease, $allelic_requirement_attrib, $cross_cutting_modifier_attrib, $mutation_consequence_attrib, $mutation_consequence_flag_attrib);
        add_gfd_to_panel($gfd, $g2p_panel, $confidence_attrib);
        add_annotations($gfd, %data);
      } else {
        warn("Entry $entry cannot be added to the database because entries with the same gene symbol, allelic requirement and mutation consequence exist\n");
      }
    } 
  }

  if ($config->{check_input_data}) {
    check_annotations(%data);
    print STDERR "\n";
  }

}

print $fh_report "Created " . $import_stats->{new_gfd} . " new GFDs.\n" if ($import_stats->{new_gfd});
print $fh_report "Added " . $import_stats->{add_to_panel}->{$g2p_panel} . " GFDs to the $g2p_panel panel.\n" if ($import_stats->{add_to_panel}->{$g2p_panel});

$fh_report->close();

=head2 add_annotations
  Arg [1]    : GenomicFeatureDisease $gfd
  Arg [2]    : hash %data contains keys (column header) and values (column value) for one row in the
               input spreadsheet.
  Description: Add annotations from the input row for the given GenomicFeatureDisease.
  Returntype : 
  Exceptions : None
  Status     : Stable
=cut

sub add_annotations {
  my ($gfd, %data) = @_;

  my $other_disease_names = $data{'other disease names'};
  my $phenotypes = $data{'phenotypes'};
  my $organs = $data{'organ specificity list'};
  my $pmids = $data{'pmids'};
  my $comments = $data{'comments'};
  my $public_comments = $data{'public comments'};

  my $count = add_other_disease_names($gfd, $other_disease_names);
  print $fh_report "    Added $count other disease names\n" if ($count > 0);

  $count = add_publications($gfd, $pmids); 
  print $fh_report "    Added $count publications\n" if ($count > 0);

  $count = add_phenotypes($gfd, $phenotypes, $user);
  print $fh_report "    Added $count phenotypes\n" if ($count > 0);

  $count = add_organ_specificity($gfd, $organs);
  print $fh_report "    Added $count organs\n" if ($count > 0);
  
  $count = add_comments($gfd, $comments, $user);
  print $fh_report "    Added $count comments\n" if ($count > 0);

  $count = add_public_comments($gfd, $public_comments, $user);
  print $fh_report "    Added $count comments\n" if ($count > 0);

}

=head2 check_annotations
  Arg [1]    : hash %data contains keys (column header) and values (column value) for one row in the
               input spreadsheet.
  Description: The provided phenotype ids and organ names must match the phenotype ids and organ names
               that are store in the gene2phenotype database in the phenotye and organ tables.
               Report any erros when trying to find the entry in the database.
               PMIDs are not preloaded in the database. We list all PMIDs that are planned to be imported
               for visual inspection. 
  Returntype : None 
  Exceptions : None
  Status     : Stable
=cut

sub check_annotations {
  my %data = @_;
  my $phenotypes = $data{'phenotypes'};
  my $organs = $data{'organ specificity list'};
  my $pmids = $data{'pmids'};
  my @phenotype_list = get_list($data{'phenotypes'});
  foreach my $hpo_id (@phenotype_list) {
    my $phenotype = $phenotype_adaptor->fetch_by_stable_id($hpo_id);
    if (!$phenotype) {
      print STDERR "    ERROR: Could not map given phenotype id ($hpo_id) to any phenotypes in the database\n";
    } 
  }

  my @organ_list = get_list($data{'organ specificity list'});
  foreach my $organ_name (@organ_list)  {
    my $organ = $organ_adaptor->fetch_by_name($organ_name);
    if (!$organ) {
      print STDERR "    ERROR: Could not match given organ ($organ_name) to any organ in the database\n";
    }
  }

  my @pmid_list = get_list($data{'pmids'});
  foreach my $pmid (@pmid_list) {
    print STDERR "    ADD: Planning to add PMID $pmid\n";
  }
}


=head2 get_list
  Arg [1]    : ';' or ',' separated list of values
  Description: Helper method to split a given string and remove any whitespace or other
               unwanted characters.
  Returntype : list of values
  Exceptions : None
  Status     : Stable
=cut

sub get_list {
  my $string = shift;
  my @list = ();
  if (!$string) {
    return @list;
  }
  my @ids = split(/;|,/, $string);
  foreach my $id (@ids) {
    $id =~ s/^\s+|\s+$//g;
    $id =~ s/]//g;
    push @list, $id;
  }
  return @list;
}


=head2 create_gfd
  Arg [1]    : GenomicFeature
  Arg [2]    : Disease
  Arg [3]    : Integer $allelic_requirement_attrib - Can be a single attrib id
  Arg [4]    : Integer Only if defined $cross_cutting_modifier_attrib- Can be a single attrib id or a list of attrib id 
  Arg [5]    : Integer $mutation_consequence_attrib - Single attrib id
  Arg [6]    : Integer $mutation_consequence_flag_attrib - Single attrib id 
  Description: Create a new GenomicFeatureDisease entry.
  Returntype : 
  Exceptions : None
  Status     : Stable
=cut

sub create_gfd {
  my ($gf, $disease, $allelic_requirement_attrib, $cross_cutting_modifier_attrib, $mutation_consequence_attrib, $mutation_consequence_flag_attrib) = @_;
  my $gfd; 
  if (defined ($mutation_consequence_flag_attrib) && defined ($cross_cutting_modifier_attrib) ){
    $gfd = Bio::EnsEMBL::G2P::GenomicFeatureDisease->new(
      -genomic_feature_id => $gf->dbID,
      -disease_id => $disease->dbID,
      -allelic_requirement_attrib => $allelic_requirement_attrib,
      -cross_cutting_modifier_atrrib => $cross_cutting_modifier_attrib,
      -mutation_consequence_attrib => $mutation_consequence_attrib,
      -mutation_consequence_flag_attrib => $mutation_consequence_flag_attrib,
      -adaptor => $gfd_adaptor,
    );
  }
  elsif (defined ($cross_cutting_modifier_attrib)) {
    $gfd = Bio::EnsEMBL::G2P::GenomicFeatureDisease->new(
      -genomic_feature_id => $gf->dbID,
      -disease_id => $disease->dbID,
      -allelic_requirement_attrib => $allelic_requirement_attrib,
      -cross_cutting_modifier_atrrib => $cross_cutting_modifier_attrib,
      -mutation_consequence_attrib => $mutation_consequence_attrib,
      -adaptor => $gfd_adaptor,
    );
  }
  elsif (defined ($mutation_consequence_flag_attrib) ) {
    $gfd = Bio::EnsEMBL::G2P::GenomicFeatureDisease->new(
      -genomic_feature_id => $gf->dbID,
      -disease_id => $disease->dbID,
      -allelic_requirement_attrib => $allelic_requirement_attrib,
      -mutation_consequence_attrib => $mutation_consequence_attrib,
      -mutation_consequence_flag_attrib => $mutation_consequence_flag_attrib,
      -adaptor => $gfd_adaptor,
    );
  }
  else {
    $gfd = Bio::EnsEMBL::G2P::GenomicFeatureDisease->new(
      -genomic_feature_id => $gf->dbID,
      -disease_id => $disease->dbID,
      -allelic_requirement_attrib => $allelic_requirement_attrib,
      -mutation_consequence_attrib => $mutation_consequence_attrib,
      -adaptor => $gfd_adaptor,
    );
  }
  $gfd = $gfd_adaptor->store($gfd, $user);

  my $allelic_requirement = $gfd->allelic_requirement;
  my $cross_cutting_modifier = $gfd->cross_cutting_modifier if (defined ($cross_cutting_modifier_attrib)); 
  my $mutation_consequence = $gfd->mutation_consequence;
  my $mutation_consequence_flag = $gfd->mutation_consequence_flag if (defined ($mutation_consequence_flag_attrib));


  $import_stats->{new_gfd}++;
  print $fh_report "Create new GFD: ", $gf->gene_symbol, "; ", $disease->name, "; $allelic_requirement; $mutation_consequence\n"; 

  return $gfd;
}

=head2 add_gfd_to_panel
  Arg [1]    : GenomicFeatureDisease database
  Arg [2]    : String $g2p_panel - Add GFD to this panel
  Arg [3]    : Integer $confidence_attrib - Single attrib id
  Description: Create a new GenomicFeatureDiseasePanel entry.
  Returntype : 
  Exceptions : None
  Status     : Stable
=cut 

sub add_gfd_to_panel {
  my ($gfd, $g2p_panel, $confidence_attrib) = @_;
  my $gfd_panel =  Bio::EnsEMBL::G2P::GenomicFeatureDiseasePanel->new(
    -genomic_feature_disease_id => $gfd->dbID,
    -panel => $g2p_panel,
    -confidence_category_attrib => $confidence_attrib,
    -adaptor => $gfd_panel_adaptor,
  );
  $gfd_panel = $gfd_panel_adaptor->store($gfd_panel, $user); 

  my $gene_symbol = $gfd->get_GenomicFeature->gene_symbol;
  my $disease_name = $gfd->get_Disease->name;
  my $allelic_requirement = $gfd->allelic_requirement;
  my $mutation_consequence = $gfd->mutation_consequence;
  my $confidence_category = $gfd_panel->confidence_category;
 
  $import_stats->{add_to_panel}->{$g2p_panel}++;
 
  print $fh_report "Add GFD: $gene_symbol; $disease_name; $allelic_requirement; $mutation_consequence to $g2p_panel with confidence $confidence_category\n"; 
}

=head2 update_gfd_panel
  Arg [1]    : GenomicFeatureDisease $gfd
  Arg [2]    : String $g2p_panel - Add GFD to this panel
  Arg [3]    : Integer $confidence_attrib - Single attrib id
  Description: Update the confidence value for the GenomicFeatureDiseasePanel entry.
               Check if the confidence value is different before updating.
  Returntype : 
  Exceptions : None
  Status     : Stable
=cut

sub update_gfd_panel {
  my ($gfd, $g2p_panel, $confidence_attrib) = @_;
  my $gfd_panel = $gfd_panel_adaptor->fetch_by_GenomicFeatureDisease_panel($gfd, $g2p_panel);
  if (!$gfd_panel) {
    die "Could not get GenomicFeatureDiseasePanel for GFD with gene symbol " .
        $gfd->get_GenomicFeature->gene_symbol . " and disease name " .
        $gfd->get_Disease->name . " and panel $g2p_panel\n";
  }
  if ($gfd_panel->confidence_category_attrib ne $confidence_attrib) {
    $gfd_panel->confidence_category_attrib($confidence_attrib);
    $gfd_panel_adaptor->update($gfd_panel, $user); 
  }
}

=head2 add_new_entry_to_panel
  Arg [1]    : String $panels - ';' or ',' separated list of panels provided by the user.
  Description: The list specifies all the panels to which the new entry needs to be added.
               The script is run for each panel separately and we check if the panel that
               has been passed to the script is included in the list.
  Returntype : 1 if the script argument panel is included in the panel list and 0 if not. 
  Exceptions : None
  Status     : Stable
=cut

sub add_new_entry_to_panel {
  my $panels = shift;
  my $add = 0;
  foreach my $panel (split/;|,/, $panels) {
    $panel =~ s/\s+//g;
    if (lc $panel eq lc $g2p_panel) {
      return 1;
    }
  } 
  return $add;
}

=head2 get_genomic_feature
  Arg [1]    : String $gene_symbol - Gene symbol from the import file
  Arg [2]    : String $prev_symbols - ';' or ',' separated list of previously assigned gene symbols
               from the import file
  Description: Tries to get the GenomicFeature for the given gene symbol or previously assigned gene
               symbols
  Returntype : GenomicFeature or undef
  Exceptions : None
  Status     : Stable
=cut

sub get_genomic_feature {
  my $gene_symbol = shift;
  my $prev_symbols = shift;
  my @symbols = ();
  push @symbols, $gene_symbol;
  if ($prev_symbols) {
    foreach my $symbol (split/;|,/, $prev_symbols) {
      $symbol =~ s/^\s+|\s+$//g;
      push @symbols, $symbol;
    }
  }
  foreach my $symbol (@symbols) { 
    my $gf = $gf_adaptor->fetch_by_gene_symbol($symbol);
    if (!$gf) {
      $gf = $gf_adaptor->fetch_by_synonym($symbol);
    }
    return $gf if (defined $gf);
  }
  return undef;
}

=head2 get_disease
  Arg [1]    : String $diseaes_name - Disease name from the import file
  Arg [2]    : Integer $mim - OMIM disease number
  Description: First tries to get the Disease for the given disease name.
               Create a new Disease entry if it doesn't already exist.
  Returntype : Disease
  Exceptions : None
  Status     : Stable
=cut

sub get_disease {
  my $disease_name = shift;
  my $disease_mim = shift;
  $disease_name =~ s/"//g;
  $disease_name =~ s/^\s+|\s+$//g;
  my $disease_list = $disease_adaptor->fetch_all_by_name($disease_name);
  my @sorted_disease_list = sort {$a->dbID <=> $b->dbID} @$disease_list;
  my $disease = $sorted_disease_list[0]; 
  if (! defined $disease) {
    $disease = Bio::EnsEMBL::G2P::Disease->new(
      -name => $disease_name,
      -adaptor => $disease_adaptor,
    );
    $disease = $disease_adaptor->store($disease);
  }

  my $mim = $disease->mim;
  if (!defined $mim && $disease_mim && $disease_mim =~ /^\d+$/) {
    $disease->mim($disease_mim);
    $disease_adaptor->update($disease);
  }
  return $disease;
}

=head2 get_confidence_attrib

  Arg [1]    : String $confidence_category - Confidence category from the import file 
  Description: Get the confidence category attrib id for the given confidence
               category value.
  Returntype : String $confidence_category_attrib 
  Exceptions : Throws error if no attrib id can be found for the given value. 
  Status     : Stable
=cut

sub get_confidence_attrib {
  my $confidence_category = shift;
  $confidence_category = lc $confidence_category;
  $confidence_category =~ s/^\s+|\s+$//g;
  if ($confidence_category eq 'child if' || $confidence_category eq 'rd+if' || $confidence_category eq 'both rd and if') {
    $confidence_category = 'both RD and IF';
  }
  return $attrib_adaptor->get_attrib('confidence_category', $confidence_category);
}

=head2 get_allelic_requirement_attrib
  Arg [1]    : String allelic requirement 
  Description: Get the allelic requirement attrib id for the given
               allelic requirement value
  Returntype : String $allelic_requirement_attrib 
  Exceptions : Throws error if no attrib id can be found for the given value. 
  Status     : Stable
=cut

sub get_allelic_requirement_attrib {
  my $allelic_requirement = shift;
  $allelic_requirement =~ s/^\s+|\s+$//g;
  return  $attrib_adaptor->get_attrib('allelic_requirement', $allelic_requirement);
}

=head2 get_cross_cutting_modifier_attrib
  Arg [1]    : String cross cutting modifier 
  Description: Get the cross cutting modifier attrib id(s) for the given
               cross cutting modifier value 
  Returntype : String $cross_cutting_modifier_attrib 
  Exceptions : Throws error if no attrib id can be found for the given value. 
  Status     : Stable
=cut
sub get_cross_cutting_modifier_attrib{
  my $cross_cutting_modifier = shift; 
  my @values = ();
  foreach my $value (split/;|,/, $cross_cutting_modifier){
    my $ccm = lc $value;
    $ccm =~ s/^\s+|\s+$//g;
    push @values, $ccm;
  }
  return $attrib_adaptor->get_attrib('cross_cutting_modifier', join(',', @values));
}

=head2 get_mutation_consequence_attrib
  Arg [1]    : String $mutation_consequence - mutation consequence from the
               import file
  Description: Get the mutation consequence attrib if for the given
               mutation consequence value.
  Returntype : 
  Exceptions : Throws error if no attrib id can be found for the given value. 
  Status     : Stable
=cut

sub get_mutation_consequence_attrib {
  my $mutation_consequence = shift;
  $mutation_consequence = lc $mutation_consequence;
  $mutation_consequence =~ s/^\s+|\s+$//g;
  return $attrib_adaptor->get_attrib('mutation_consequence', $mutation_consequence);
}

=head2 get_mutation_consequence_flag_attrib
  Arg [1]    : String $mutation_consequence_flag - mutation consequence flag from the
               import file
  Description: Get the mutation consequence flag attrib if for the given
               mutation consequence flag  value.
  Returntype : 
  Exceptions : Throws error if no attrib id can be found for the given value. 
  Status     : Stable
=cut

sub get_mutation_consequence_flag_attrib{
  my $mutation_consequences_flag = shift; 
  $mutation_consequences_flag = lc $mutation_consequences_flag;
  $mutation_consequences_flag  =~ s/^\s+|\s+$//g;
  return  $attrib_adaptor->get_attrib('mutation_consequence_flag', $mutation_consequences_flag);
}

=head2 add_other_disease_names
  Arg [1]    : GenomicFeatureDisease $gfd
  Arg [2]    : String $disease_names - ';' or ',' separated list of other disease names from the import file 
  Description: Add other disease names to the GenomicFeatureDisease entry.
  Returntype : None
  Exceptions : None
  Status     : Stable
=cut

sub add_other_disease_names {
  my $gfd = shift;
  my $disease_names = shift;
  return 0 if (!$disease_names);
  my $gfd_id = $gfd->dbID;
  my $count = 0;
  foreach my $disease_name (split(/;/, $disease_names)) {
    $disease_name =~ s/^\s+|\s+$//g;
    my $disease = get_disease($disease_name);
    my $gfd_disease_synonym = $gfd_disease_synonym_adaptor->fetch_by_GFD_id_disease_id($gfd_id, $disease->dbID);
    if (!$gfd_disease_synonym) {
      $gfd_disease_synonym = Bio::EnsEMBL::G2P::GFDDiseaseSynonym->new(
        -genomic_feature_disease_id => $gfd_id,
        -disease_id => $disease->dbID,
        -adaptor => $gfd_publication_adaptor,
      );
      $gfd_disease_synonym_adaptor->store($gfd_disease_synonym);
      $count++;
    }
  }
  return $count;
}

=head2 add_publications
  Arg [1]    : GenomicFeatureDisease $gfd
  Arg [2]    : String $pmids - ';' or ',' separated list of PMID ids from the import file 
  Description: Add publications to the GenomicFeatureDisease entry.
  Returntype : None
  Exceptions : None
  Status     : Stable
=cut

sub add_publications {
  my $gfd = shift;
  my $pmids = shift;
  return 0 if (!$pmids);
  my $gfd_id = $gfd->dbID;
  my $count = 0;
  foreach my $pmid (get_list($pmids)) {
    next unless($pmid);
    my $publication = $publication_adaptor->fetch_by_PMID($pmid);
    if (!$publication) {
      $publication = Bio::EnsEMBL::G2P::Publication->new(
        -pmid => $pmid,
      );
      $publication = $publication_adaptor->store($publication);
    }
    my $gfd_publication = $gfd_publication_adaptor->fetch_by_GFD_id_publication_id($gfd_id, $publication->dbID);
    if (!$gfd_publication) {
      $gfd_publication = Bio::EnsEMBL::G2P::GenomicFeatureDiseasePublication->new(
        -genomic_feature_disease_id => $gfd_id,
        -publication_id => $publication->dbID,
        -adaptor => $gfd_publication_adaptor,
      );
      $gfd_publication_adaptor->store($gfd_publication);
      $count++;
    }
  }
  return $count;
}

=head2 add_phenotypes
  Arg [1]    : GenomicFeatureDisease $gfd
  Arg [2]    : String $phenotypes - ';' or ',' separated list of phenotype ids from the import file
  Arg [3]    : User $user
  Description: Add phenotypes to the GenomicFeatureDisease entry.
  Returntype : Warns about phenotype ids that cannot be found in the database.
  Exceptions : None
  Status     : Stable
=cut

sub add_phenotypes {
  my $gfd = shift;
  my $phenotypes = shift;
  my $user = shift;
  return 0 if (!$phenotypes);
  my $gfd_id = $gfd->dbID;
  my $count = 0;
  my $new_gfd_phenotypes = $gfd_phenotype_adaptor->fetch_all_by_GenomicFeatureDisease($gfd);
  my $new_gfd_phenotypes_lookup = {};
  foreach my $new_gfd_phenotype (@$new_gfd_phenotypes) {
    my $phenotype_id = $new_gfd_phenotype->get_Phenotype->dbID;
    $new_gfd_phenotypes_lookup->{"$gfd_id\t$phenotype_id"} = 1;
  }
  foreach my $hpo_id (get_list($phenotypes)) {
    my $phenotype = $phenotype_adaptor->fetch_by_stable_id($hpo_id);
    if (!$phenotype) {
      warn("Could not map given phenotype id ($hpo_id) to any phenotypes in the database: " . $gfd->get_GenomicFeature->gene_symbol . "\n");
    } else {
      my $phenotype_id = $phenotype->dbID;
      if (!$new_gfd_phenotypes_lookup->{"$gfd_id\t$phenotype_id"}) {
        my $new_gfd_phenotype = Bio::EnsEMBL::G2P::GenomicFeatureDiseasePhenotype->new(
          -genomic_feature_disease_id => $gfd_id,
          -phenotype_id => $phenotype_id,
          -adaptor => $gfd_phenotype_adaptor,
        );
        $gfd_phenotype_adaptor->store($new_gfd_phenotype, $user);
        $count++;
      }
    }
  }
  return $count;
}

=head2 add_organ_specificity
  Arg [1]    : GenomicFeatureDisease $gfd
  Arg [2]    : String $organs - ';' or ',' separated list of organs from the import file
  Description: Add organs to the GenomicFeatureDisease entry.
  Returntype : Warns about organs that cannot be found in the database.
  Status     : Stable
=cut

sub add_organ_specificity {
  my $gfd = shift;
  my $organs = shift;
  return 0 if (!$organs);
  my $gfd_id = $gfd->dbID;
  my $new_gfd_organs = $gfd_organ_adaptor->fetch_all_by_GenomicFeatureDisease($gfd);
  my $new_gfd_organs_lookup = {};
  my $count = 0;
  foreach my $new_gfd_organ (@$new_gfd_organs) {
    my $organ_id = $new_gfd_organ->get_Organ->dbID;
    $new_gfd_organs_lookup->{"$gfd_id\t$organ_id"} = 1;
  }

  foreach my $name (get_list($organs)) {
    next unless($name);
    my $organ = $organ_adaptor->fetch_by_name($name);
    if (!$organ) {
      warn("Could not match given organ ($name) to any organ in the database:  " . $gfd->get_GenomicFeature->gene_symbol . "\n");
    } else {
      my $organ_id = $organ->dbID;
      if (!$new_gfd_organs_lookup->{"$gfd_id\t$organ_id"}) {
        my $new_gfd_organ =  Bio::EnsEMBL::G2P::GenomicFeatureDiseaseOrgan->new(
          -organ_id => $organ_id,
          -genomic_feature_disease_id => $gfd_id,
          -adaptor => $gfd_organ_adaptor, 
        );
        $gfd_organ_adaptor->store($new_gfd_organ);
        $new_gfd_organs_lookup->{"$gfd_id\t$organ_id"} = 1;
        $count++;
      }
    }
  }
  return $count;
}

=head2 add_comments
  Arg [1]    : GenomicFeatureDisease $gfd
  Arg [2]    : String $comments - Comments from the import file
  Arg [3]    : User $user
  Description: Add comments to the GenomicFeatureDisease entry.
  Returntype : None 
  Exceptions : None
  Status     : Stable
=cut

sub add_comments {
  my $gfd = shift;
  my $comments = shift;
  my $user = shift;
  return 0 if (!$comments);
  $comments =~ s/^\s+|\s+$//g;
  my $count = 0;
  my @existing_comments = @{$gfd_comment_adaptor->fetch_all_by_GenomicFeatureDisease($gfd)}; 
  if (! grep { $comments eq $_->comment_text} @existing_comments) {
    my $gfd_id = $gfd->dbID;
    my $gfd_comment = Bio::EnsEMBL::G2P::GenomicFeatureDiseaseComment->new(
      -comment_text => $comments,
      -genomic_feature_disease_id => $gfd_id,
      -adaptor => $gfd_comment_adaptor,
    );
    $gfd_comment_adaptor->store($gfd_comment, $user);
    $count++;
  }
  return $count;
}

sub add_public_comments {
  my $gfd = shift; 
  my $public_comments = shift; 
  my $user = shift; 
  return 0 if (!$public_comments);
   $public_comments =~ s/^\s+|\s+$//g;
  my $count = 0;
  my @existing_comments = @{$gfd_comment_adaptor->fetch_all_by_GenomicFeatureDisease($gfd)}; 
  if (! grep { $public_comments eq $_->comment_text} @existing_comments) {
    my $gfd_id = $gfd->dbID;
    my $gfd_comment = Bio::EnsEMBL::G2P::GenomicFeatureDiseaseComment->new(
      -comment_text => $public_comments,
      -genomic_feature_disease_id => $gfd_id,
      -is_public => 1,
      -adaptor => $gfd_comment_adaptor,
    );
    $gfd_comment_adaptor->store($gfd_comment, $user);
    $count++;
  }
  return $count;

}
