#!perl

use 5.024;
use strict;
use warnings;

package PEDSnet::Derivation::BMI;

our($VERSION) = '0.03';

use Moo 2;

use Rose::DateTime::Util qw( parse_date );
use Types::Standard qw/ ArrayRef InstanceOf /;

extends 'PEDSnet::Derivation';
with 'MooX::Role::Chatty';

# Override default verbosity level - current MooX::Role::Chatty
# default silences warnings.
has '+verbose' => ( default => sub { -1; } );

=head1 NAME

PEDSnet::Derivation::BMI - Compute body mass index in the PEDSnet CDM

=head1 DESCRIPTION

L<PEDSnet::Derivation::BMI> computes body mass index values based on
weight and height values present in a PEDSnet CDM C<measurement>
table.  Consistent with the PEDSnet CDM specification, weight values
are treated as kg and heights as cm; the resulting BMI is in kg/m2.

While a number of specifics can be changed as described in
L<PEDSnet::Derivation::BMI::Config>, the default behavior is to
compute a BMI for each weight with a corresponding height measurement
within 60 days.  If multiple height measurements fall within that
range, the value closest in time is used.  The resulting BMI
measurement record takes its metadata from the weight record.

Please note that L<PEDSnet::Derivation::BMI> will not populate
C<measurement_id> in the records it writes.  This allows for the
output table to populate it automaatically from a sequence or by a
similar mechanism.  If not, the application code will need to do so.

L<PEDSnet::Derivation::BMI> makes available the following methods:

=head2 Methods

=over 4

=cut

has '_pending_output' =>
  ( isa => ArrayRef, is => 'ro', required => 0, default => sub { [] });

=item compute_bmi( $self, $ht_cm, $wt_kg )

Given I<$ht_cm> and I<$wt_kg>, return a BMI in kg/m2.  Returns nothing
unless $ht_cm is greater than zero.

If I<$wt_kg> is more than 200, it is treated as grams.  Similarly, if
I<$ht_cm> is less than 3, it is treated as meters instead of cm.  In
both cases, a warning is emitted.  Unfortunatley, because plausible
values of height in inches and cm overlap significantly, no attempt is
made to detect a value in inches.

=cut

sub compute_bmi {
  my($self, $ht_cm, $wt_kg ) = @_;
  return unless $ht_cm > 0;

  if ($wt_kg > 200) {
    $self->logger->warn("Presuming weight $wt_kg is in g rather than kg\n");
    $wt_kg /= 1000;
  }

  if ($ht_cm < 3) {
    $self->logger->warn("Presuming height $ht_cm is in m rather than cm\n");
    $ht_cm *= 100;
  }

  $wt_kg / ($ht_cm / 100) ** 2;
}

=item create_time_series( $self, $meas_list )

Given a list of measurement records referred to by I<$meas_list>,
return a reference to a list of hash references, each with two
elements with these keys:

=over 4

=item meas

The associated value is a measurement record from I<$meas_list>.  A
new element, with key C<measurement_dt> is added, whose value is the
L<DateTime> that results from parsing C<measurement_time>, or if
that's undefined, L<measurement_date>.

=item rdsec

The associated value is the count of Rata Die seconds corresponding to
the C<measurement_dt> element of L</meas>.

=back

The returned list is sorted in ascending datetime order.

=cut

sub create_time_series {
  my( $self, $meas_list ) = @_;
  my @series;

  foreach my $m ( $meas_list->@*) {
    $m->{measurement_dt} //= parse_date($m->{measurement_time} // $m->{measurement_date})
      unless exists $m->{measurement_dt};

    push @series, { rdsec => $m->{measurement_dt}->utc_rd_as_seconds,
		    meas => $m };
  }

  $self->remark({ level => 3,
		  message => 'Completed time series with ' .
		  scalar(@series) . ' elements' });
  [ sort { $a->{rdsec} <=> $b->{rdsec} } @series ];
}

=item find_closest_meas( $self, $time_series, $target_meas, $limit_sec );

Find the element of I<$time_series> closest in time to I<$target_meas>
(either before or after).  If I<$target_meas> doesn't have a
C<measurement_dt> element, one is added as described above (cf. L</create_time_series>).

If no element of I<$time_series> is within I<limit_sec> of
I<$target_meas>, returns nothing.  Otherwise, returns the
B<measurement record> from the closest element.

If I<$limit_sec> is not supplied, the configuration value
C<meas_match_limit_sec> is used as a default.  If that's not set
either, then 0 is used as a last resort.

=cut

sub find_closest_meas {
  my( $self, $ts, $targ, $limit ) = @_;

  $targ->{measurement_dt} //= parse_date($targ->{measurement_time} // $targ->{measurement_date})
    unless exists $targ->{measurement_dt};

  my $target_rdsec = $targ->{measurement_dt}->utc_rd_as_seconds;
  my $last_intvl = ($limit // $self->config->meas_match_limit_sec // 0) + 1;
  my $current_cand;

  foreach my $m ($ts->@*) {
    my $this_intvl = abs( $m->{rdsec} - $target_rdsec );

    if ($this_intvl < $last_intvl) {
      $current_cand = $m;
      $last_intvl = $this_intvl;
    }
    
    last if $m->{rdsec} > $target_rdsec; # Can't get any closer
  }

  return unless $current_cand;
  $self->remark({ level => 3,
		  message => 'Matched measurement at ' .
		  $current_cand->{meas}->{measurement_time} .
		  ' to target at ' . $targ->{measurement_time} });
  return $current_cand->{meas};
}

=item bmi_meas_for_person( $self, $person_info )

Compute BMI values from the measurement records in the list referred
to by I<$person_info>, which are presumed to be from the same
person.  If you want to get back BMI values, then the list must
contain some height and weight measurements; it may also contain other
measurements, which are ignored.

Returns a reference to a list of measurement records for computed BMIs.

BMI computation can be modified by a number of configuration settings,
as described in L<PEDSnet::Derivation::BMI::Config>.

=cut

sub bmi_meas_for_person {
  my( $self, $measurements ) = @_;
  my $conf = $self->config;
  my($ht_cids, $wt_cids, $bmi_cid, $bmi_type_cid, $bmi_unit_cid,
     $bmi_unit_sv, $clone) =
    ({ map { $_ => 1 } $conf->ht_measurement_concept_ids->@* },
     { map { $_ => 1 } $conf->wt_measurement_concept_ids->@* },
     $conf->bmi_measurement_concept_id,
     $conf->bmi_measurement_type_concept_id,
     $conf->bmi_unit_concept_id,
     $conf->bmi_unit_source_value,
     $conf->clone_bmi_measurements);
  my @hts = grep { exists $ht_cids->{ $_->{measurement_concept_id} } }
            $measurements->@*;
  my @wts = grep { exists $wt_cids->{ $_->{measurement_concept_id} } }
            $measurements->@*;
  my $verbose = $self->verbose;

  return unless @hts and @wts;

  $self->remark('Computing BMIs for person ' .
		$wts[0]->{person_id}) if $verbose >= 2;
  
  my $ht_ts = $self->create_time_series( \@hts );
  my(@bmis, @clone_except);


  @clone_except = $conf->clone_attributes_except->@* if $clone;
  
  foreach my $wt (@wts) {
    my $ht = $self->find_closest_meas($ht_ts, $wt);
    next unless $ht;
    my $bmi_rec;

    my $bmi_val = $self->compute_bmi($ht->{value_as_number},
				     $wt->{value_as_number});

    $self->remark( sprintf 'Computed BMI %4.2f for weight %d on %s',
		   $bmi_val, $wt->{measurement_id}, $wt->{measurement_time})
      if $verbose >= 3;
    
    if ($clone) { 
      $bmi_rec = { %$wt };
      delete $bmi_rec->{$_} for @clone_except;
      $bmi_rec->{measurement_concept_id} = $bmi_cid;
      $bmi_rec->{measurement_type_concept_id} = $bmi_type_cid;
      $bmi_rec->{value_as_number} = $bmi_val;
      $bmi_rec->{unit_concept_id} = $bmi_unit_cid;
      $bmi_rec->{unit_source_value} = $bmi_unit_sv;
      $bmi_rec->{measurement_source_value} = "PEDSnet BMI computation v$VERSION";
      $bmi_rec->{measurement_source_concept_id} = 0;
      $bmi_rec->{value_source_value} =
    	"wt: $wt->{measurement_id}, ht: $ht->{measurement_id}";
    }
    else {
      $bmi_rec = 
	{
	 person_id => $wt->{person_id},
	 measurement_concept_id => $bmi_cid,
	 measurement_date => $wt->{measurement_date},
	 measurement_time => $wt->{measurement_time},
	 measurement_type_concept_id => $bmi_type_cid,
	 value_as_number => $bmi_val,
	 unit_concept_id => $bmi_unit_cid,
	 unit_source_value => $bmi_unit_sv,
	 measurement_source_value => "PEDSnet BMI computation v$VERSION",
	 measurement_source_concept_id => 0,
	 value_source_value => "wt: $wt->{measurement_id}, ht: $ht->{measurement_id}",
	};
      # Optional keys - should be there but may be skipped if input
      # was not read from measurement table
      foreach my $k (qw/ measurement_result_date measurement_result_time
                         provider_id visit_occurrence_id site /) {
        $bmi_rec->{$k} = $wt->{$k} if exists $wt->{$k};
      }
    }

    # For operator, if either of the source records have a
    # greater-than operator, apply that to the BMI, then look for
    # less-than, and finally default to equality.
    if (defined $wt->{operator_concept_id} and
	($wt->{operator_concept_id} == 4171755 or
	 $wt->{operator_concept_id} == 4172704)) {
      $bmi_rec->{operator_concept_id} = $wt->{operator_concept_id};
      $bmi_rec->{operator_source_value} = $wt->{operator_source_value};
    }
    elsif (defined $ht->{operator_concept_id} and
	   ($ht->{operator_concept_id} == 4171755 or
	    $ht->{operator_concept_id} == 4172704)) {
      $bmi_rec->{operator_concept_id} = $ht->{operator_concept_id};
      $bmi_rec->{operator_source_value} = $ht->{operator_source_value};
    }
    elsif (defined $wt->{operator_concept_id} and
	   ($wt->{operator_concept_id} == 4171754 or
	    $wt->{operator_concept_id} == 4172756)) {
      $bmi_rec->{operator_concept_id} = $wt->{operator_concept_id};
      $bmi_rec->{operator_source_value} = $wt->{operator_source_value};
    }
    elsif (defined $ht->{operator_concept_id} and
	   ($ht->{operator_concept_id} == 4171754 or
	    $ht->{operator_concept_id} == 4172756)) {
      $bmi_rec->{operator_concept_id} = $ht->{operator_concept_id};
      $bmi_rec->{operator_source_value} = $ht->{operator_source_value};
    }
    else {
      $bmi_rec->{operator_concept_id} = 4172703;
      $bmi_rec->{operator_source_value} = '=';
    }

    push @bmis, $bmi_rec;
  }
  
  \@bmis;
}

=item get_meas_for_person_qry

Returns a L<Rose::DBx::CannedQuery::Glycosylated> object containing a
query to retrieve all height and weight measurement records for a
single person, whose C<person_id> is passed as the sole bind parameter
to the query.

=cut

sub get_meas_for_person_qry {
  my $self = shift;
  my $config = $self->config;
  
  $self->src_backend->
    get_query(q[SELECT * FROM ] . $config->input_measurement_table .
              q[ WHERE measurement_concept_id IN (] .
	      join(',', $config->ht_measurement_concept_ids->@*,
		   $config->wt_measurement_concept_ids->@*) . q[)
              AND person_id = ?]);
}

=item save_meas_qry($chunk_size)

Returns a L<Rose::DBx::CannedQuery::Glycosylated> object containing a
query that will save I<$chunk_size> measurement records.  The query
will expect values for the measurement records as bind parameter values.

=cut

sub save_meas_qry {
  my( $self, $chunk_size ) = @_;
  my $sink = $self->sink_backend;
  my $tab = $self->config->output_measurement_table;
  my $full_chunk = $self->config->output_chunk_size;
  state $cols = [ grep { $_ ne 'measurement_id' }
		  $sink->column_names($tab) ];
  my $sql = qq[INSERT INTO $tab (] . join(',', @$cols) .
            q[) VALUES ] .
	    join(',',
		 ('(' . join(',', ('?') x scalar @$cols) . ')') x $chunk_size);

  # Cache only "full-sized" version of query
  if ($chunk_size == $self->config->output_chunk_size) {
    return shift->sink_backend->get_query($sql);
  }
  else {
    return shift->sink_backend->build_query($sql);
  }
}

sub _save_bmis {
  my( $self, $bmi_list) = @_;
  return 0 unless $bmi_list and @$bmi_list;
  my $pending = $self->_pending_output;
  state $chunk_size = $self->config->output_chunk_size;

  push @$pending, @$bmi_list;
  
  while (@$pending > $chunk_size) {
    $self->sink_backend->store_chunk($self->save_meas_qry($chunk_size),
				     [ splice @$pending, 0, $chunk_size ]);
  }
  return scalar @$bmi_list;
}

=item flush_output

Flush any pending output records to the sink backend.  In most cases,
this is done for you automatically, but the method is public in case a
subclass or application wants to flush manually in circumstances where
it feels it's warranted.

=cut

sub flush_output {
  my $self = shift;
  my $pending = $self->_pending_output;
  if (@$pending) {
    $self->sink_backend->store_chunk($self->save_meas_qry(scalar @$pending),
				     $pending);
    @$pending = ();
  }
}

=for Pod::Coverage DEMOLISH

=cut

sub DEMOLISH { shift->flush_output }

has '_person_qry' => ( isa => InstanceOf['Rose::DBx::CannedQuery'], is => 'rwp',
		       lazy => 1, builder => '_build_person_qry');

# _get_person_qry
# Returns an active and executed L<Rose::DBx::CannedQuery> object used
# for fetching person records.  If any arguments are present, they are
# passed to the query as bind parameter values for execution.
#
# Returns nothing if the query could not be constructed or executed.
#
# This exists as a separate method only to provide a means to get bind
# parameters to the query, which a standard builder method cannot
# accommodate. If you need to use bind parameters, you have to call
# _get_person_qry yourself and pass the result to the
# PEDSnet::Derivation::BMI constructor as the value of _person_qry.
# If you can avoid this, consider it.  If you can't, consider wrapping
# the constructor in a method that does this bookkeeping, so the user
# doesn't need to.

sub _get_person_qry {
  my $self = shift;
  my $pt_qry = $self->src_backend->build_query($self->config->person_finder_sql);
  return unless $pt_qry && $pt_qry->execute(@_);

  $pt_qry;
}

sub _build_person_qry { shift->_get_person_qry; }

=item get_person_chunk($chunk)

Returns a reference to an array of person records.  If I<$chunk> is
present, specifies the desired number of records.  If it's not,
defaults to L<PEDSnet::Derivation::BMI::Config/person_chunk_size>.

This implementation fetches records as specified by
L<PEDSnet::Derivation::BMI::Config/person_finder_sql>.  You are free
to override this behavior in a subclass.  In particular, if you want
to parallelize computation over a large source database,
L</get_person_chunk> and
L<PEDSnet::Derivation::BMI::Config/person_finder_sql> give you
opportunities to point each process at a subset of persons.

=cut

sub get_person_chunk {
  my $ self = shift;
  my $qry = $self->_person_qry;
  my $chunk_size =  $self->config->person_chunk_size;
  
  $self->src_backend->fetch_chunk($self->_person_qry, $chunk_size);
}

=item process_person_chunk($persons)

For each person record in the list referred to by I<$persons>, compute
BMIs from measurement data in the source backend, and save results to
the sink backend.  A person record is a hash reference; the only
element used is C<person_id>.

Returns the number of BMI records saved.

=cut

sub process_person_chunk {
  my( $self, $person_list ) = @_;
  my $get_qry = $self->get_meas_for_person_qry;
  my $src = $self->src_backend;
  my $saved = 0;

  foreach my $p ($person_list->@*) {
    next unless $src->execute($get_qry, [ $p->{person_id} ]);
    my(@ht_wt);

    # Wrap into one go, since rare for a single patient to have a huge
    # number of height and weight measurements
    while (my @rows = $src->fetch_chunk($get_qry)->@*) { push @ht_wt, @rows }
    
    $saved += $self->_save_bmis($self->bmi_meas_for_person(\@ht_wt));

  }

  $saved;
}

=item generate_bmis()

Using data from the L<PEDSnet::Derivation/config> attribute, compute
BMIs for everyone.

In scalar context, returns the number of BMI records saved.  In list
contest returns the number of BMI records and the number of unique
persons with at least one BMI record.

=cut

sub generate_bmis {
  my $self = shift;
  my $src = $self->src_backend;
  my $config = $self->config;
  my($saved_rec, $saved_pers) = (0,0);
  my $verbose = $self->verbose;
  my($pt_qry, $chunk);

  $self->remark("Finding patients with measurements") if $verbose;

  $self->remark("Starting computation") if $verbose;
  while ($chunk = $self->get_person_chunk and @$chunk) {
    my $ct = $self->process_person_chunk($chunk);
    $saved_rec += $ct;
    $saved_pers += scalar @$chunk;
    $self->remark([ 'Completed %d persons/%d records (total %d/%d)',
		    scalar @$chunk, $ct, $saved_pers, $saved_rec ])
      if $self->verbose;
  }

  $self->flush_output;

  $self->remark("Done") if $self->verbose;
  
  return ($saved_rec, $saved_pers) if wantarray;
  return $saved_rec;
  
}

1;

__END__

=back

=head1 BUGS AND CAVEATS

Are there, for certain, but have yet to be cataloged.

=head1 VERSION

version 0.03

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
