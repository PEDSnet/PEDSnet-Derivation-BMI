#!perl
#

use 5.010;
use strict;
use warnings;

package PEDSnet::Derivation::BMI::Config;

our($VERSION) = '0.03';

=head1 NAME

PEDSnet::Derivation::BMI::Config - Configuration setting for BMI computation

=head1 DESCRIPTION

BMI computation in L<PEDSnet::Derivation::BMI> depends both on
characteristics of the source data, such as what
C<measurement_concept_id>s are used for weight and height, and on
conventions during computation, such as the size of the time window in
which to look for paired heights and weights.
L<PEDSnet::Derivation::BMI::Config> allows you to make these choices
by setting attribute values, using the various options described in
L<PEDSnet::Derivation::Config>.  

The following attributes are defined for the BMI computation process:

=head2 Attributes

=for Pod::Coverage build_.+

=over 4

=cut

use Moo 2;
use Types::Standard qw/ Bool Str Int HashRef ArrayRef Enum /;

extends 'PEDSnet::Derivation::Config';

sub _build_config_param {
  my( $self, $param_name, $sql_where ) = @_;
  my $val = $self->config_datum($param_name);
  return $val if defined $val;

  return unless defined $sql_where;
  my @cids = $self->ask_rdb('SELECT concept_id FROM concept WHERE ' . $sql_where);
  return $cids[0]->{concept_id};
}

=item ht_measurement_concept_ids

A reference to an array of C<measurement_concept_id> values indicating
that the record contains a height in cm or meters.

It may be set by passing an array reference or a string of
comma-separated integers.

If no values are provided, an attempt is made to look up the concept
ID associated with LOINC code C<3137-7>.

=cut

has 'ht_measurement_concept_ids' =>
  ( isa => ArrayRef[Int], is => 'ro', required => 1,
    coerce => sub { ref $_[0] ? $_[0] : [ split /,/, $_[0] ] },
    lazy => 1, builder => 'build_ht_measurement_concept_ids' );

sub build_ht_measurement_concept_ids {
  my $data =
    shift->_build_config_param('ht_measurement_concept_ids',
			       q[concept_code = '3137-7' and
                               standard_concept = 'S' and vocabulary_id = 'LOINC']);
  return $data if ref $data;
  return [ split /,/, $data ];
}

=item wt_measurement_concept_ids

A reference to an array of C<measurement_concept_id> values indicating
that the record contains a weight in kg or grams.

It may be set by passing an array reference or a string of
comma-separated integers.

If no values are provided, an attempt is made to look up the concept
ID associated with LOINC code C<3141-9>.

=cut

has 'wt_measurement_concept_ids' =>
  ( isa => ArrayRef[Int], is => 'ro', required => 1,
    coerce => sub { ref $_[0] ? $_[0] : [ split /,/, $_[0] ] },
    lazy => 1, builder => 'build_wt_measurement_concept_ids' );

sub build_wt_measurement_concept_ids {
  my $data =
    shift->_build_config_param('wt_measurement_concept_ids',
			       q[concept_code = '3141-9' and
                               standard_concept = 'S' and vocabulary_id = 'LOINC']);
  return $data if ref $data;
  return [ split /,/, $data ];
}

=item bmi_measurement_concept_id

The C<measurement_concept_id> value to be used in newly-created BMI records.

If no value is provided, an attempt is made to look up the concept
ID associated with LOINC code C<39156-5>.

=cut

has 'bmi_measurement_concept_id' =>
  ( isa => Int, is => 'ro', required => 1,
    lazy => 1, builder => 'build_bmi_measurement_concept_id' );

sub build_bmi_measurement_concept_id {
  shift->_build_config_param('bmi_measurement_concept_id',
			     # N.B. Need to add to ETL specs
			     q[concept_code = '39156-5' and
                               standard_concept = 'S' and vocabulary_id = 'LOINC']);
}

=item bmi_measurement_type_concept_id

The C<measurement_type_concept_id> value to be used in newly-created BMI records.

If no value is provided, an attempt is made to look up the concept
ID associated with C<Meas type> name C<Derived value>.

=cut

has 'bmi_measurement_type_concept_id' =>
  ( isa => Int, is => 'ro', required => 1,
    lazy => 1, builder => 'build_bmi_measurement_type_concept_id' );

sub build_bmi_measurement_type_concept_id {
  shift->_build_config_param('bmi_measurement_type_concept_id',
			     q[concept_name = 'Derived value' and
                               standard_concept = 'S' and vocabulary_id = 'Meas Type']);
}

=item bmi_unit_concept_id

The C<unit_concept_id> value to be used in newly-created BMI records.

If no value is provided, an attempt is made to look up the concept
ID associated with UCUM code C<kg/m2>.

=cut

has 'bmi_unit_concept_id' =>
  ( isa => Int, is => 'ro', required => 1,
    lazy => 1, builder => 'build_bmi_unit_concept_id' );

sub build_bmi_unit_concept_id {
  shift->_build_config_param('bmi_unit_concept_id',
			     q[concept_code = 'kg/m2' and
                               standard_concept = 'S' and vocabulary_id = 'UCUM']);
}

=item bmi_unit_source_value

The C<unit_source_value> value to be used in newly-created BMI records.

If no value is provided, the default is C<kg/m2>.

=cut

has 'bmi_unit_source_value' =>
  ( isa => Str, is => 'ro', required => 1,
    lazy => 1, builder => 'build_bmi_unit_source_value' );

sub build_bmi_unit_source_value {
  shift->_build_config_param('bmi_unit_source_value') // 'kg/m2';
}

=item meas_match_limit_sec

The maximum time, in seconds, between a height and weight measurement
that may be paired to compute a BMI.  A weight will always be paired
with the closest height, but only if the interval is smaller than this
limit.

=cut

has 'meas_match_limit_sec' =>
  ( isa => Int, is => 'ro', required => 1,
    lazy => 1, builder => 'build_meas_match_limit_sec');

sub build_meas_match_limit_sec {
  shift->_build_config_param('meas_match_limit_sec') //
  # Default 60 day max window between ht and wt for BMI calculation
  (60 * 24 * 60 * 60);
}

=item input_measurement_table

The name of the table in the source backend from which to read height
and weight measurements.  Defaults to C<measurement>.

=cut

has 'input_measurement_table' =>
  ( isa => Str, is => 'ro', required => 1, lazy => 1,
    builder => 'build_input_measurement_table' );

sub build_input_measurement_table {
  shift->_build_config_param('input_measurement_table') // 'measurement'
}

=item output_measurement_table

The name of the table in the sink backend to which BMI measurements
are written.  Defaults to C<measurement>.

=cut

has 'output_measurement_table' =>
  ( isa => Str, is => 'ro', required => 1, lazy => 1,
    builder => 'build_output_measurement_table' );

sub build_output_measurement_table {
  shift->_build_config_param('output_measurement_table') // 'measurement'
}

=item output_chunk_size

It is often more efficient to write BMI records to
L</output_measurement_table> in groups rather than individually, as
this permits the sink backend RDBMS to batch up insertions, foreign
key checks, etc.  To facilitate this, L<output_chunk_size> specifies
the number of BMI records that are cached and written together.  The
risk, of course, is that if the connection to the sink is lost, or the
application encounters another fatal error, cached records are lost.

Defaults to 1000.

=cut

has 'output_chunk_size' =>
  ( isa => Int, is => 'ro', required => 1, lazy => 1,
    builder => 'build_output_chunk_size' );

sub build_output_chunk_size {
  shift->_build_config_param('output_chunk_size') // 1000;
}

=item sql_flavor

Provides a hint about the complexity of SQL statement the source
backend can handle.  A value of C<limited> indicates that the backend
has limited range, as seen with C<DBD::CSV>, and queries should avoid
constructs such as subselects or multiple joins.  A value of C<full>
indicates that expressions such as these are ok.

Defaults to C<limited>, which produces less efficient SQL in some
case, but will work, albeit slowly, with a wider range of backends.

=cut

has 'sql_flavor' =>
  ( isa => Enum[ qw/ limited full /], is => 'ro', required => 0, lazy => 1,
    builder => 'build_sql_flavor' );

sub build_sql_flavor { shift->_build_config_param('sql_flavor') // 'limited' }

=item person_finder_sql

A string of SQL to be used to select the C<person_id>s for whom BMIs
should be computed.

The default value for more capable SQL backends is to find persons who
have both height and weight measurements.  For backends with a
L</sql_flavor> of C<limited>, finds those persons with height
measurements, on the assumption that heights are less common then
weights, and heights without weights are rare.

=cut

has 'person_finder_sql' =>
  ( isa => Str, is => 'ro', required => 1, lazy => 1,
    builder => 'build_person_finder_sql' );

sub build_person_finder_sql {
  my $self = shift;

  my $sql = $self->_build_config_param('person_finder_sql');
  return $sql if $sql;

  my @ht_conc = $self->ht_measurement_concept_ids->@*;
  my @wt_conc = $self->wt_measurement_concept_ids->@*;
  my($ht_constraint, $wt_constraint);

  # Put up with backends that can't handle single arg to IN
  # N.B. 'IN' must be in caps to accommodate SQL::Statement
  if (@ht_conc > 1) {
    $ht_constraint = 'IN (' . join(', ', @ht_conc) . ')';
  }
  else {
    $ht_constraint = '= ' . $ht_conc[0];
  }
  if (@wt_conc > 1) {
    $wt_constraint = 'IN (' . join(', ', @wt_conc) . ')';
  }
  else {
    $wt_constraint = '= ' . $wt_conc[0];
  }
  
  # CSV backend can't handle self-joins or subselects,
  # so we limit preprocessing by just looking for heights
  if ($self->sql_flavor eq 'limited') { 
    'select distinct person_id from ' .
      $self->input_measurement_table .
      " where measurement_concept_id $ht_constraint ";
  }
  else {
    'select distinct m1.person_id from ' .
      $self->input_measurement_table .
      ' m1 inner join ' .
      $self->input_measurement_table .
      ' m2 on m1.person_id = m2.person_id ' .
      " where m1.measurement_concept_id $ht_constraint" .
      " and m2.measurement_concept_id $wt_constraint";
  }
  
}

=item person_chunk_size

The number of C<person_id>s to retrieve at a time from the source
backend in L<PEDSnet::Derivation::BMI/generate_bmis>.  

Defaults to 1000.

=cut

has 'person_chunk_size' =>
  ( isa => Int, is => 'ro', required => 1, lazy => 1,
    builder => 'build_person_chunk_size' );

sub build_person_chunk_size {
  shift->_build_config_param('person_chunk_size') // 1000;
}

=item clone_bmi_measurements

When BMI records are constructed, a number of fields are set directly,
such as the value itself and the metadata indicating that it's a
BMI. For the rest of the fields in a measurement record, you have two
choices.  If L</clone_bmi_measurements> is true, then the remaining
values (e.g. dates, provider) are taken from the weight record that
underlies the BMI.  If L</clone_bmi_measurements> is false, then a
known set of fields (from the PEDSnet CDM definition) are copied from
the weight record, but any other fields (such as custom fields you may
have added in your measurement table) are not.

Defaults to false as a conservative approach, but unless you've made
major modifications to measurement record structure, it's generally a
good idea to set this to a true value, and use
L</clone_attributes_except> to weed out any attributes you don't
want to carry over.

=cut

has 'clone_bmi_measurements' =>
  ( isa => Bool, is => 'ro', required => 0, lazy => 1,
    builder => 'build_clone_bmi_measurements' );

sub build_clone_bmi_measurements {
  shift->_build_config_param('clone_bmi_measurements') // 0;
}

=item clone_attributes_except

If L</clone_bmi_measurements> is true, then the value of
L</clone_attributes_except> is taken as a reference to an array of
attribute names that should NOT be carried over from the parent weight
record. 

Defaults to a list of attributes that specific to the fact that the
new record is a BMI.

=cut

has 'clone_attributes_except' =>
  ( isa => ArrayRef, is => 'ro', required => 0, lazy => 1,
    builder => 'build_clone_attributes_except' );

sub build_clone_attributes_except {
  shift->_build_config_param('clone_attributes_except') //
    [ qw(measurement_id measurement_concept_id measurement_type_concept_id
         value_as_number value_as_concept_id unit_concept_id range_low range_high
         measurement_source_value measurement_source_concept_id unit_source_value
         value_source_value
         siteid measurement_concept_name measurement_type_concept_name
         value_as_concept_name) ];
}


1;

__END__

=back

=head1 BUGS AND CAVEATS

Are there, for certain, but have yet to be cataloged.

=head1 VERSION

version 0.02

=head1 AUTHOR

Charles Bailey <cbail@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Charles Bailey

This software may be used under the terms of the Artistic License or
the GNU General Public License, as the user prefers.

This code was written at the Children's Hospital of Philadelphia as
part of L<PCORI|http://www.pcori.org>-funded work in the
L<PEDSnet|http://www.pedsnet.org> Data Coordinating Center.

=cut
