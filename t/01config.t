#!/usr/bin/env perl


use 5.024;
use strict;
use warnings;

use Test::More;


my $has_sqlite = eval { require DBD::SQLite };
my $rdb;

if ($has_sqlite) {
  ### Test RDB class using in-core scratch db
  package My::Test::RDB;
  
  use parent 'Rose::DB';

  __PACKAGE__->use_private_registry;

  __PACKAGE__->register_db( domain   => 'test',
			    type     => 'vapor',
			    driver   => 'SQLite',
			    database => ':memory:',
			  );

  # SQLite in-memory db evaporates when original dbh is closed.
  sub dbi_connect {
    my( $self, @args ) = @_;
    state $dbh = $self->SUPER::dbi_connect(@args);
    $dbh;
  }


  package main;

  ### Set up the test environment
  $rdb = new_ok( 'My::Test::RDB' => [ connect_options => { RaiseError => 1 },
				      domain          => 'test',
				      type            => 'vapor'
				    ],
		    'Setup test db'
		  );
  my $dbh = $rdb->dbh;

  $dbh->do('create table concept
            (concept_id integer primary key,
             concept_code varchar(16),
             standard_concept varchar(1),
             vocabulary_id varchar(16) )');
  # N.B. concept_id deliberately wrong
  $dbh->do(q[insert into concept values (9532, 'kg/m2', 'S', 'UCUM')]);

}

require_ok('PEDSnet::Derivation::BMI::Config');

my $config = new_ok('PEDSnet::Derivation::BMI::Config');

cmp_ok($config->meas_match_limit_sec, '==', 60 * 24 * 60 * 60,
       '60 day default limit on ht-wt registration');

foreach my $c ( [ ht_measurement_concept_id => 3023540 ],
		[ wt_measurement_concept_id => 3013762 ],
		[ bmi_measurement_concept_id => 3038553 ],
		[ bmi_measurement_type_concept_id => 45754907 ],
		[ bmi_unit_concept_id => 9531 ],
		[ bmi_unit_source_value => 'kg/m2' ],
		[ input_measurement_table => 'measurement' ],
		[ output_measurement_table => 'measurement' ],
		[ output_chunk_size => 1000 ],
		[ person_chunk_size => 1000 ],
	      ) {
  my $meth = $c->[0];
  cmp_ok($config->$meth,
	 ($c->[1] =~ /^\d+$/ ? '==' : 'eq'),
	 $c->[1], "Value for $c->[0]");
}

if ($has_sqlite) {
  $config = PEDSnet::Derivation::BMI::Config->
    new( config_stems => [ 'bmi_less' ], config_rdb => $rdb);
  cmp_ok($config->bmi_unit_concept_id, '==', 9532,
	 'Value for bmi_unit_concept_id (via db)');
}

done_testing;
