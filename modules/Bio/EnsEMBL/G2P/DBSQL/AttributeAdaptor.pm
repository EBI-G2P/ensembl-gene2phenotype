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

package Bio::EnsEMBL::G2P::DBSQL::AttributeAdaptor;

use Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor;

our @ISA = ('Bio::EnsEMBL::G2P::DBSQL::BaseAdaptor'); 

=head2 get_attrib

  Arg [1]    : String $type - code of attrib type as stored in the attrib_type table
  Arg [2]    : String $value - attribute value for which to retrieve the attribute id
  Example    : my $attrib_id = $attribute_adaptor->get_attrib('mutation_consequence', 'all missense/in frame');
  Description: Get the attribute id for the attribute value and the given attribute type.
               attrib_id_for_type_value is used to get the attribute id. get_attrib deals with
               error messages if no attribute id was found.
               This method also deals with the case where more than one value can be translated
               to each respective attribute id. This is only supported for the allelic_requirement
               attribute type.
  Returntype : Integer $attrib_id
  Exceptions : Throw error if attribute id for given value does not exisit
  Caller     : For example Bio::EnsEMBL::G2P::DBSQL::GenomicFeatureDiseaseAdaptor::new
  Status     : Stable
=cut

sub get_attrib {
  my $self = shift;
  my $type = shift;
  my $value = shift;
  if ($value =~ m/,/) {
    my @ids = ();
    foreach my $v (split(',', $value)) {
      my $id = $self->attrib_id_for_type_value($type, $v);
      if (!$id) {
        die "Could not get attrib for value: $v and type: $type\n";
      }
      push @ids, $self->attrib_id_for_type_value($type, $v);
    }        
    return join(',', sort @ids);
  } else {
    my $attrib = $self->attrib_id_for_type_value($type, $value);
    if (!$attrib) {
      die "Could not get attrib for value: $value and type: $type\n";
    }
    return $attrib;
  }
}

=head2 get_value

  Arg [1]    : String $type - code of attrib type as stored in the attrib_type table
  Arg [2]    : Integer $attrib - attribute id for which to retrieve the attribute value
  Example    : my $attrib_value = $attribute_adaptor->get_attrib('mutation_consequence', 22);
  Description: Get the attribute value for the attribute id and the given attribute type.
               attrib_value_for_type_id is used to get the attribute value. get_value deals with
               error messages if no attribute value was found.
               This method also deals with the case where more than one attrib id can be translated
               to each respective attribute value. This is only supported for the allelic_requirement
               attribute type.
  Returntype : String $attrib_value
  Exceptions : Throw error if attribute value for given id does not exisit
  Caller     : For example Bio::EnsEMBL::G2P::DBSQL::GenomicFeatureDiseaseAdaptor::new
  Status     : Stable
=cut

sub get_value {
  my $self = shift;
  my $type = shift;
  my $attrib = shift;
  if ($attrib =~ m/,/) {
    my @values = ();
    foreach my $id (split(',', $attrib)) {
      my $value =  $self->attrib_value_for_type_id($type, $id);
      if (!$value) {
        die "Could not get value for attrib: $id and type: $type\n";
      }
      push @values, $value;
    }
    return join(',', sort @values);
  } else {
    my $value = $self->attrib_value_for_type_id($type, $attrib);
    if (!$value) {
      die "Could not get value for attrib: $attrib and type: $type\n";
    }
    return $value;
  }
}

=head2 set_attribs

  Description: Get all mappings from value to id and id to value for each attrib type.
               The mappings are stored in $self->{attrib_ids} and $self->{attrib_values}.
  Example    : $self->{attrib_ids} looks like: (just showing for attrib type allelic_requirement)
                {
                  'allelic_requirement' => {
                    'mitochondrial' => 19,
                    'hemizygous' => 15,
                    'biallelic' => 3,
                    'monoallelic' => 14,
                    'monoallelic (Y)' => 6,
                    'x-linked dominant' => 16,
                    'uncertain' => 13,
                    'imprinted' => 12,
                    'x-linked over-dominance' => 17,
                    'digenic' => 20,
                    'mosaic' => 18
                  }
                }
  Returntype : None
  Exceptions : None
  Caller     : Bio::EnsEMBL::G2P::DBSQL::AttributeAdaptor::attrib_id_for_type_value
               Bio::EnsEMBL::G2P::DBSQL::AttributeAdaptor::attrib_value_for_type_id
  Status     : Stable
=cut

sub set_attribs {
  my $self = shift;

  unless ($self->{attribs}) {
    my $attribs;
    my $attrib_ids;
    my $attrib_values;
    my $sql = qq{
      SELECT  a.attrib_id, t.code, a.value
      FROM    attrib a, attrib_type t
      WHERE   a.attrib_type_id = t.attrib_type_id
    };

    my $dbh = $self->dbc->db_handle;
    my $sth = $dbh->prepare($sql);
    $sth->execute;

    while (my ($attrib_id, $type, $value) = $sth->fetchrow_array) {
      $attribs->{$attrib_id}->{type}  = $type;
      $attribs->{$attrib_id}->{value} = $value;
      $attrib_ids->{$type}->{$value} = $attrib_id;
      $attrib_values->{$type}->{$attrib_id} = $value;
    }
    $self->{attribs}    = $attribs;
    $self->{attrib_ids} = $attrib_ids;
    $self->{attrib_values} = $attrib_values;
  }
}

=head2 attrib_id_for_type_value

  Arg [1]    : String $type - code of attrib type as stored in the attrib_type table
  Arg [2]    : String $value - attribute value for which to retrieve the attribute id
  Example    : my $id = $self->attrib_id_for_type_value('mutation_consequence', 'all missense/in frame');
  Description: Get the attribute id for the attribute value and the given attribute type.
  Returntype : Integer $attrib_id
  Exceptions : None
  Caller     : For example Bio::EnsEMBL::G2P::DBSQL::AttributeAdaptor::get_attrib
  Status     : Stable
=cut

sub attrib_id_for_type_value {
  my ($self, $type, $value) = @_;
  unless ($self->{attrib_ids}) {
    $self->set_attribs;
  }
  return $self->{attrib_ids}->{$type}->{$value};
}

=head2 attrib_value_for_type_id

  Arg [1]    : String $type - code of attrib type as stored in the attrib_type table
  Arg [2]    : Integer $attrib_id - attribute id for which to retrieve the attribute value
  Example    : my $value = $self->attrib_value_for_type_id('mutation_consequence', 22);
  Description: Get the attribute value for the attribute id and the given attribute type.
  Returntype : String $attrib_value
  Exceptions : None
  Caller     : For example Bio::EnsEMBL::G2P::DBSQL::AttributeAdaptor::get_value
  Status     : Stable
=cut

sub attrib_value_for_type_id {
  my ($self, $type, $attrib_id) = @_;
  unless ($self->{attrib_values}) {
    $self->set_attribs;
  }
  return $self->{attrib_values}->{$type}->{$attrib_id};
}

=head2 get_values_by_type

  Arg [1]    : String $attrib_type_code - type of attribute as stored in
               code column in attrib_type table 
  Example    : my $confidence_categories = $attribute_adaptor->get_values_by_type('confidence_category');
  Description: Get a hash of values to id mappings for all values of a given
               attribute type.
  Returntype : Hashref $attribs where keys are all values for the given
               attrib type
  Exceptions : None
  Caller     : for example Gene2phenotype::Model::GenomicFeatureDisease::get_confidence_values
  Status     : Stable
=cut

sub get_values_by_type {
  my ($self, $attrib_type_code) = @_;
  my $attribs = {};
  my $sql = qq{
    SELECT  a.attrib_id, a.value
    FROM    attrib a, attrib_type t
    WHERE   a.attrib_type_id = t.attrib_type_id
    AND     t.code = ?;
  };

  my $dbh = $self->dbc->db_handle;
  my $sth = $dbh->prepare($sql);
  $sth->execute($attrib_type_code);

  while (my ($attrib_id, $value) = $sth->fetchrow_array) {
    $attribs->{$value} = $attrib_id;
  }
  $sth->finish();
  return $attribs;
}

=head2 get_attribs_by_type

  Arg [1]    : String $attrib_type_code - type of attribute as stored in
               code column in attrib_type table
  Example    : $confidence_category_attribs = $attribute_adaptor->get_attribs_by_type('confidence_category');
  Description: Get a hash of id to value mappings for all values of a given
               attribute type.
  Returntype : Hashref $attribs where keys are all attrib ids for the given
               attrib type
  Exceptions : None
  Caller     : for example Bio::EnsEMBL::G2P::Utils::Downloads::download_data
  Status     : Stable
=cut

sub get_attribs_by_type {
  my ($self, $attrib_type_code) = @_;
  my $attribs = {};
  my $sql = qq{
    SELECT  a.attrib_id, a.value
    FROM    attrib a, attrib_type t
    WHERE   a.attrib_type_id = t.attrib_type_id
    AND     t.code = ?;
  };

  my $dbh = $self->dbc->db_handle;
  my $sth = $dbh->prepare($sql);
  $sth->execute($attrib_type_code);

  while (my ($attrib_id, $value) = $sth->fetchrow_array) {
    $attribs->{$attrib_id} = $value;
  }
  $sth->finish();
  return $attribs;
}

1;
