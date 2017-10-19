#!/usr/bin/env perl

use 5.024;
use strict;
use warnings;

use Test::More;
use Test::Differences;

use PEDSnet::Derivation::BMI;
use PEDSnet::Derivation::Backend::CSV;

my $backend = PEDSnet::Derivation::Backend::CSV->new(db_dir => '.');

my $handle = PEDSnet::Derivation::BMI->new( src_backend => $backend,
					    sink_backend => $backend );


my $hts = [ { measurement_datetime => '2015-04-01T11:42:14',
	      measurement_concept_id => 3023540,
	      value_as_number => 125 },
	    { measurement_datetime => '2015-11-10T11:42:14',
	      measurement_concept_id => 3023540,
	      value_as_number => 130 },
	    { measurement_datetime => '2015-09-05T11:42:14',
	      measurement_concept_id => 3023540,
	      value_as_number => 126 },
	    { measurement_datetime => '2015-09-05T14:42:14',
	      measurement_concept_id => 3023540,
	      value_as_number => 127 }
	  ];

my $wt = { measurement_datetime => '2015-09-05T14:42:10',
	   measurement_concept_id => 3013762,
	   value_as_number => 25 };

my $ts = $handle->create_datetime_series( $hts );
eq_or_diff( [ map { $_->{meas} } @$ts ],
	    [ sort { $a->{measurement_datetime} cmp $b->{measurement_datetime} } @$hts ],
	    'Time series order');
ok( $ts->[0]->{rdsec} < $ts->[1]->{rdsec}, 'Time series rdsec reflects order');

eq_or_diff( $handle->find_closest_meas($ts, $wt),
	    $hts->[3],
	    'Find nearest item (valid result exists)');

delete $wt->{measurement_dt};
$wt->{measurement_datetime} = '2015-01-10T11:42:14';

ok(! defined $handle->find_closest_meas($ts, $wt),
   'No nearest item');

done_testing();
