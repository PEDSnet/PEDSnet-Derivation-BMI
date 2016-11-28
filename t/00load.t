#!/usr/bin/env perl

use Test::More;

use PEDSnet::Derivation::Backend::CSV;

require_ok('PEDSnet::Derivation::BMI');

my $backend = PEDSnet::Derivation::Backend::CSV->new(db_dir => '.');

new_ok('PEDSnet::Derivation::BMI',
       [ src_backend => $backend, sink_backend => $backend ]);

done_testing();

