#!perl
#
# $Id$

use 5.024;
use strict;
use warnings;

package PEDSnet::Derivation::BMI;

our($VERSION) = '0.01';
our($REVISION) = '$Revision$' =~ /: (\d+)/ ? $1 : 0;

use Moo 2;

use Rose::DateTime::Util qw( parse_date );

extends 'PEDSnet::Derivation';
with 'MooX::Role::Chatty';

has '_pending_output' =>
  ( is => 'ro', required => 0, default => sub { [] });

=head 1 METHODS

=over 4

=item compute_bmi( $self, $ht_cm, $wt_kg )

=cut

sub compute_bmi {
  my($self, $ht_cm, $wt_kg ) = @_;
  return unless $ht_cm > 0;

  if ($wt_kg > 200) {
    warn "Presuming weight $wt_kg is in g rather than kg\n";
    $wt_kg /= 1000;
  }

  $wt_kg / ($ht_cm / 100) ** 2;
}

=item create_time_series( $self, $meas_list )

=cut

sub create_time_series {
  my( $self, $meas_list ) = @_;
  my @series;

  foreach my $m ( $meas_list->@*) {
    $m->{measurement_dt} = parse_date($m->{measurement_time} // $m->{measurement_date})
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

=cut

sub find_closest_meas {
  my( $self, $ts, $targ, $limit ) = @_;

  $targ->{measurement_dt} = parse_date($targ->{measurement_time} // $targ->{measurement_date})
    unless exists $targ->{measurement_dt};

  my $target_rdsec = $targ->{measurement_dt}->utc_rd_as_seconds;
  my $last_intvl = ($limit // $self->config->meas_match_limit_sec) + 1;
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

=cut

sub bmi_meas_for_person {
  my( $self, $measurements ) = @_;
  my $conf = $self->config;
  my($ht_cid, $wt_cid, $bmi_cid, $bmi_type_cid, $bmi_unit_cid,
     $bmi_unit_sv, $clone) =
    ($conf->ht_measurement_concept_id,
     $conf->wt_measurement_concept_id,
     $conf->bmi_measurement_concept_id,
     $conf->bmi_measurement_type_concept_id,
     $conf->bmi_unit_concept_id,
     $conf->bmi_unit_source_value,
     $conf->clone_bmi_measurements);
  my @hts = grep { $_->{measurement_concept_id} == $ht_cid }
            $measurements->@*;
  my @wts = grep { $_->{measurement_concept_id} == $wt_cid }
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
	 value_source_value => "wt: $wt->{measurement_id}, ht: $ht->{measurement_id}",
	};
      # Optional keys - should be there but may be skipped if input
      # was not read from measurement tabl    
      foreach my $k (qw/ measurement_result_date measurement_result_time
                         provider_id visit_occurrence_id site /) {
        $bmi_rec->{$k} = $wt->{$k} if exists $wt->{$k};
      }

    }
    push @bmis, $bmi_rec;
  }
  
  \@bmis;
}

=item get_meas_for_person_qry

=cut

sub get_meas_for_person_qry {
  my $self = shift;
  my $config = $self->config;
  
  $self->src_backend->
    get_query(q[SELECT * FROM ] . $config->input_measurement_table .
              q[ WHERE measurement_concept_id IN (] .
	      join(',', $config->ht_measurement_concept_id,
		   $config->wt_measurement_concept_id) . q[)
              AND person_id = ?]);
}

=item save_meas_qry($rows_to_save)

=cut

sub save_meas_qry {
  my( $self, $chunk_size ) = @_;
  my $sink = $self->sink_backend;
  my $tab = $self->config->output_measurement_table;
  my $full_chunk = $self->config->output_chunk_size;
  state $cols = [ grep { $_ ne 'measurement_id' }
		  $sink->column_names($tab) ];
  my $placeholders = 
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
  my $pending = $self->_pending_output;
  state $chunk_size = $self->config->output_chunk_size;

  push @$pending, @$bmi_list;
  
  if (@$pending > $chunk_size) {
    $self->sink_backend->store_chunk($self->save_meas_qry($chunk_size),
				     [ splice @$pending, 0, $chunk_size ]);
  }
  return scalar @$bmi_list;
}

sub flush_output {
  my $self = shift;
  my $pending = $self->_pending_output;
  if (@$pending) {
    $self->sink_backend->store_chunk($self->save_meas_qry(scalar @$pending),
				     $pending);
    @$pending = ();
  }
}

sub DEMOLISH { shift->flush_output }

=item process_person_list($persons)

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

=cut

sub generate_bmis {
  my $self = shift;
  my $src = $self->src_backend;
  my $config = $self->config;
  my $saved = 0;
  my $chunk_size =  $config->person_chunk_size;
  my($pt_qry, $chunk);

  # CSV backend can't handle self-joins or subselects,
  # so we limit preprocessing
  if (ref($src) =~ /::CSV/) { 
    $pt_qry =
      $src->build_query('select distinct person_id from ' .
		      $config->input_measurement_table .
		      ' where measurement_concept_id = ' .
		      $config->ht_measurement_concept_id );
  }
  else {
    $pt_qry =
      $src->build_query('select distinct m1.person_id from ' .
		      $config->input_measurement_table .
		      ' m1 inner join ' .
		      $config->input_measurement_table .
		      ' m2 on m1.person_id = m2.person_id ' .
		      ' where m1.measurement_concept_id = ' .
		      $config->ht_measurement_concept_id .
		      ' and m2.measurement_concept_id = ' .
		      $config->wt_measurement_concept_id );
  }
  return unless $pt_qry->execute;

  while ($chunk = $src->fetch_chunk($pt_qry, $chunk_size) and @$chunk) {
    my $ct = $self->process_person_chunk($chunk);
    $saved += $ct;
    $self->remark("Completed $ct persons (total $saved)") if $self->verbose;
  }

  $self->flush_output;

  $saved;
  
}

1;

__END__

=head1 NAME

PEDSnet::Derivation::BMI - blah blah blah

=head1 SYNOPSIS

  use PEDSnet::Derivation::BMI;
  blah blah blah

=head1 DESCRIPTION

Blah blah blah.

The following command line options are available:

=head1 OPTIONS

=over 4

=item B<--help>

Output a brief help message, then exit.

=item B<--man>

Output this documentation, then exit.

=item B<--version>

Output the program version, then exit.

=back

=head1 USE AS A MODULE

Is encouraged.  This file can be included in a larger program using
Perl's L<require> function.  It provides the following functions in the
package B<Foo>:

=head2 FUNCTIONS

It helps to document these if you encourage use as a module.

=over 4

=back

=head2 EXPORT

None by default.

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 DIAGNOSTICS

Any message produced by an included package, as well as

=over 4

=item B<EANY>

Anything went wrong.

=item B<Something to say here>

A warning that something newsworthy happened.

=back

=head1 BUGS AND CAVEATS

Are there, for certain, but have yet to be cataloged.

=head1 VERSION

version 0.01

=head1 AUTHOR

Charles Bailey <cbail@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Charles Bailey

This software may be used under the terms of the Artistic License or
the GNU General Public License, as the user prefers.

=cut
