#!/usr/bin/env perl

use Test::More;

use PEDSnet::Derivation::BMI;
use PEDSnet::Derivation::Backend::CSV;

my $backend = PEDSnet::Derivation::Backend::CSV->new(db_dir => '.');

my $handle = PEDSnet::Derivation::BMI->new( src_backend => $backend,
					    sink_backend => $backend );

cmp_ok( $handle->compute_bmi(100, 30), '==', 30, 'Basic BMI computation' );

my($warning);
$SIG{__WARN__} = sub { $warning = shift };

cmp_ok( $handle->compute_bmi(100, 30000), '==', 30, 'Corrected wt in g' );
is( $warning, "Presuming weight 30000 is in g rather than kg\n",
      '... and warned about it');

ok( ! defined eval { $handle->compute_bmi }, 'Bailed out with missing ht');

done_testing();
