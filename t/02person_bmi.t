#!/usr/bin/env perl

use 5.024;
use strict;
use warnings;

use Test::More;

use PEDSnet::Derivation::BMI;
use PEDSnet::Derivation::Backend::CSV;

my $csvdb = PEDSnet::Derivation::Backend::CSV->
  new(db_dir => '.');

my $handle = PEDSnet::Derivation::BMI->
  new( src_backend => $csvdb, sink_backend => $csvdb);

my $inputs = [
	      {
	       measurement_id => 1,
	       person_id => 1,
	       measurement_concept_id => 3023540,
	       measurement_type_concept_id => 2000000033,
	       measurement_date => '2015-04-01',
	       measurement_time => '2015-04-01T11:42:14',
	       value_as_number => 110,
	       provider_id => 1,
	       visit_occurrence_id => 1
	      },
	      {
	       measurement_id => 2,
	       person_id => 1,
	       measurement_concept_id => 3023540,
	       measurement_type_concept_id => 2000000033,
	       measurement_date => '2015-11-10',
	       measurement_time => '2015-11-10T11:42:14',
	       value_as_number => 140,
	       provider_id => 2,
	       visit_occurrence_id => 2
	      },
	      {
	       measurement_id => 3,
	       person_id => 1,
	       measurement_concept_id => 3023540,
	       measurement_type_concept_id => 2000000033,
	       measurement_date => '2015-09-05',
	       measurement_time => '2015-09-05T11:42:14',
	       value_as_number => 122,
	       provider_id => 2,
	       visit_occurrence_id => 3
	      },
	      {
	       measurement_id => 4,
	       person_id => 1,
	       measurement_concept_id => 3023540,
	       measurement_type_concept_id => 2000000033,
	       measurement_date => '2015-09-05',
	       measurement_time => '2015-09-05T14:42:14',
	       value_as_number => 100,
	       provider_id => 2,
	       visit_occurrence_id => 3
	      },
	      {
	       measurement_id => 5,
	       person_id => 1,
	       measurement_concept_id => 3023541,
	       measurement_type_concept_id => 2000000033,
	       measurement_date => '2015-09-05',
	       measurement_time => '2015-09-05T14:10:14',
	       value_as_number => 50,
	       provider_id => 2,
	       visit_occurrence_id => 3
	      },
	      	      {
	       measurement_id => 6,
	       person_id => 1,
	       measurement_concept_id => 3013762,
	       measurement_type_concept_id => 2000000033,
	       measurement_date => '2015-09-05',
	       measurement_time => '2015-09-05T14:10:14',
	       value_as_number => 25,
	       provider_id => 2,
	       visit_occurrence_id => 3
	      },
	     ];

my $output = [
	      {
	       person_id => 1,
	       measurement_concept_id => 3038553,
	       measurement_type_concept_id => 45754907,
	       unit_concept_id => 9531,
	       measurement_date => '2015-09-05',
	       measurement_time => '2015-09-05T14:10:14',
	       value_as_number => 25,
	       provider_id => 2,
	       visit_occurrence_id => 3,
	       measurement_source_value => 'PEDSnet BMI computation v' .
	         $PEDSnet::Derivation::BMI::VERSION,
	       value_source_value => 'wt: 6, ht: 4'
	      }
	     ];

my $bmis = eval { $handle->bmi_meas_for_person( $inputs ) };
my $err = $@;

ok($bmis, 'Computed BMI values');
is($err, '', 'No error');
is_deeply($bmis, $output, 'Correct result');


done_testing;
