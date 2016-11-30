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
  new(config_stems => [ $FindBin::Bin . '/person_list' ]);

my $handle = PEDSnet::Derivation::BMI->new( src_backend => $backend,
					    sink_backend => $backend,
					    config => $config );


my $gq = $backend->build_query('select * from ' .
			       $config->input_measurement_table);
$gq->execute;
my $test_list = $backend->fetch_chunk($gq);


my $q = eval { $handle->get_meas_for_person_qry };
my $error = $@;

isa_ok($q, 'Rose::DBx::CannedQuery', 'Ht/wt retrieval query');
is($error, '', 'No error constructing query');
ok($q->execute(261461), 'Execute for test person');

my $list = eval { $backend->fetch_chunk($q); };
$error = $@;
is($error, '', 'No error executing query');
eq_or_diff($list,
	   [ grep { $_->{person_id} == 261461 } @$test_list ],
	   'Result is correct');


eval {
  # Suppress error message if table doesn't exist
  local $SIG{__WARN__} = sub {};
  my $dbh = $backend->rdb->dbh;
  $dbh->do('drop table ' .
	   $dbh->quote_identifier($config->output_measurement_table));
};
$backend->clone_table($config->input_measurement_table,
		      $config->output_measurement_table);

my $person_list = [ map { { person_id => $_} } 1..3 ];
my @expected =
  path('person_list_output_expected')->absolute($FindBin::Bin)->lines;

is($handle->process_person_chunk($person_list), @expected - 1, 'Process person list');

$handle->flush_output;

my $outp = path($config->output_measurement_table)->
	   absolute($FindBin::Bin);
$outp->remove
  if eq_or_diff([ $outp->lines ], \@expected, 'Output is correct');

done_testing;

