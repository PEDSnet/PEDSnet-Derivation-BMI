#!perl
#
# $Id$

use 5.010;
use strict;
use warnings;

package PEDSnet::Derivation::BMI::Config;

our($VERSION) = '0.01';
our($REVISION) = '$Revision$' =~ /: (\d+)/ ? $1 : 0;

use Moo 2;
use Types::Standard qw/ Str Int HashRef /;

extends 'PEDSnet::Derivation::Config';

sub _build_config_param {
  my( $self, $param_name, $sql_where ) = @_;
  my $val = $self->config_datum($param_name);
  return $val if defined $val;

  my @cids = $self->ask_rdb('SELECT concept_id FROM concept WHERE ' . $sql_where);
  return $cids[0]->{concept_id};
}


has 'ht_measurement_concept_id' =>
  ( isa => Int, is => 'ro', required => 1,
    lazy => 1, builder => 'build_ht_measurement_concept_id' );

sub build_ht_measurement_concept_id {
  shift->_build_config_param('ht_measurement_concept_id',
			     q[concept_code = '3137-7' and
                               standard_concept = 'S' and vocabulary_id = 'LOINC']);
}

has 'wt_measurement_concept_id' =>
  ( isa => Int, is => 'ro', required => 1,
    lazy => 1, builder => 'build_wt_measurement_concept_id' );

sub build_wt_measurement_concept_id {
  shift->_build_config_param('wt_measurement_concept_id',
			     q[concept_code = '3141-9' and
                               standard_concept = 'S' and vocabulary_id = 'LOINC']);
}

has 'bmi_measurement_concept_id' =>
  ( isa => Int, is => 'ro', required => 1,
    lazy => 1, builder => 'build_bmi_measurement_concept_id' );

sub build_bmi_measurement_concept_id {
  shift->_build_config_param('bmi_measurement_concept_id',
			     # N.B. Need to add to ETL specs
			     q[concept_code = '39156-5' and
                               standard_concept = 'S' and vocabulary_id = 'LOINC']);
}

has 'bmi_measurement_type_concept_id' =>
  ( isa => Int, is => 'ro', required => 1,
    lazy => 1, builder => 'build_bmi_measurement_type_concept_id' );

sub build_bmi_measurement_type_concept_id {
  shift->_build_config_param('bmi_measurement_type_concept_id',
			     q[concept_name = 'Derived value' and
                               standard_concept = 'S' and vocabulary_id = 'Meas Type']);
}

has 'bmi_unit_concept_id' =>
  ( isa => Int, is => 'ro', required => 1,
    lazy => 1, builder => 'build_bmi_unit_concept_id' );

sub build_bmi_unit_concept_id {
  shift->_build_config_param('bmi_unit_concept_id',
			     q[concept_code = 'kg/m2' and
                               standard_concept = 'S' and vocabulary_id = 'UCUM']);
}

has 'bmi_unit_source_value' =>
  ( isa => Str, is => 'ro', required => 1,
    lazy => 1, builder => 'build_bmi_unit_source_value' );

sub build_bmi_unit_source_value {
  shift->config_datum('bmi_unit_source_value') // 'kg/m2';
}


has 'meas_match_limit_sec' =>
  ( isa => Int, is => 'ro', required => 1,
    lazy => 1, builder => 'build_meas_match_limit_sec');

sub build_meas_match_limit_sec {
  shift->config_datum('meas_match_limit_sec') //
  # Default 60 day max window between ht and wt for BMI calculation
  (60 * 24 * 60 * 60);
}

has 'input_measurement_table' =>
  ( isa => Str, is => 'ro', required => 1,
    builder => 'build_input_measurement_table' );

sub build_input_measurement_table {
  shift->_config_file_content->{input_measurement_table} // 'measurement'
}


has 'output_measurement_table' =>
  ( isa => Str, is => 'ro', required => 1,
    builder => 'build_output_measurement_table' );

sub build_output_measurement_table {
  shift->_config_file_content->{output_measurement_table} // 'measurement'
}

has 'output_chunk_size' =>
  ( isa => Int, is => 'ro', required => 1,
    builder => 'build_output_chunk_size' );

sub build_output_chunk_size {
  shift->_config_file_content->{output_chunk_size} // 1000;
}

has 'person_chunk_size' =>
  ( isa => Int, is => 'ro', required => 1,
    builder => 'build_person_chunk_size' );

sub build_person_chunk_size {
  shift->_config_file_content->{person_chunk_size} // 1000;
}



1;
