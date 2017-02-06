#!/usr/bin/env perl

use 5.024;
use strict;
use warnings;

use FindBin;
use Path::Tiny;
use Test::More;
use Test::Differences;

use PEDSnet::Derivation::Backend::CSV;

use PEDSnet::Derivation::BMI;
use PEDSnet::Derivation::BMI::Config;

my $backend = PEDSnet::Derivation::Backend::CSV->new(db_dir => $FindBin::Bin);
my $config = PEDSnet::Derivation::BMI::Config->
  new(config_stems => [ $FindBin::Bin . '/full_table' ]);

my $handle = PEDSnet::Derivation::BMI->new( src_backend => $backend,
					    sink_backend => $backend,
					    config => $config );


eval {
  # Suppress error message if table doesn't exist
  local $SIG{__WARN__} = sub {};
  my $dbh = $backend->rdb->dbh;
  $dbh->do('drop table ' .
	   $dbh->quote_identifier($config->output_measurement_table));
};
$backend->clone_table($config->input_measurement_table,
		      $config->output_measurement_table);


my @expected = map { s/v\d+\.\d+/vX/ }
  path('full_table_output_expected')->absolute($FindBin::Bin)->lines;

is($handle->generate_bmis, @expected - 1, 'Process full table');

my $outp = path($config->output_measurement_table)->
	   absolute($FindBin::Bin);
$outp->remove
  if eq_or_diff([ map { s/v\d+\.\d+/vX/ } $outp->lines ],
		\@expected, 'Output is correct');

done_testing;

