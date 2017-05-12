# NAME

PEDSnet::Derivation::BMI - Compute body mass index in the PEDSnet CDM

# DESCRIPTION

[PEDSnet::Derivation::BMI](https://metacpan.org/pod/PEDSnet::Derivation::BMI) computes body mass index values based on
weight and height values present in a PEDSnet CDM `measurement`
table.  Consistent with the PEDSnet CDM specification, weight values
are treated as kg and heights as cm; the resulting BMI is in kg/m2.

While a number of specifics can be changed as described in
[PEDSnet::Derivation::BMI::Config](https://metacpan.org/pod/PEDSnet::Derivation::BMI::Config), the default behavior is to
compute a BMI for each weight with a corresponding height measurement
within 60 days.  If multiple height measurements fall within that
range, the value closest in time is used.  The resulting BMI
measurement record takes its metadata from the weight record.

Please note that [PEDSnet::Derivation::BMI](https://metacpan.org/pod/PEDSnet::Derivation::BMI) will not populate
`measurement_id` in the records it writes.  This allows for the
output table to populate it automaatically from a sequence or by a
similar mechanism.  If not, the application code will need to do so.

[PEDSnet::Derivation::BMI](https://metacpan.org/pod/PEDSnet::Derivation::BMI) makes available the following methods:

## Methods

- compute\_bmi( $self, $ht\_cm, $wt\_kg )

    Given _$ht\_cm_ and _$wt\_kg_, return a BMI in kg/m2.  Returns nothing
    unless $ht\_cm is greater than zero.

    If _$wt\_kg_ is more than 200, it is treated as grams.  Similarly, if
    _$ht\_cm_ is less than 3, it is treated as meters instead of cm.  In
    both cases, a warning is emitted.  Unfortunatley, because plausible
    values of height in inches and cm overlap significantly, no attempt is
    made to detect a value in inches.

- create\_time\_series( $self, $meas\_list )

    Given a list of measurement records referred to by _$meas\_list_,
    return a reference to a list of hash references, each with two
    elements with these keys:

    - meas

        The associated value is a measurement record from _$meas\_list_.  A
        new element, with key `measurement_dt` is added, whose value is the
        [DateTime](https://metacpan.org/pod/DateTime) that results from parsing `measurement_time`, or if
        that's undefined, [measurement\_date](https://metacpan.org/pod/measurement_date).

    - rdsec

        The associated value is the count of Rata Die seconds corresponding to
        the `measurement_dt` element of ["meas"](#meas).

    The returned list is sorted in ascending datetime order.

- find\_closest\_meas( $self, $time\_series, $target\_meas, $limit\_sec );

    Find the element of _$time\_series_ closest in time to _$target\_meas_
    (either before or after).  If _$target\_meas_ doesn't have a
    `measurement_dt` element, one is added as described above (cf. ["create\_time\_series"](#create_time_series)).

    If no element of _$time\_series_ is within _limit\_sec_ of
    _$target\_meas_, returns nothing.  Otherwise, returns the
    **measurement record** from the closest element.

    If _$limit\_sec_ is not supplied, the configuration value
    `meas_match_limit_sec` is used as a default.  If that's not set
    either, then 0 is used as a last resort.

- bmi\_meas\_for\_person( $self, $person\_info )

    Compute BMI values from the measurement records in the list referred
    to by _$person\_info_, which are presumed to be from the same
    person.  If you want to get back BMI values, then the list must
    contain some height and weight measurements; it may also contain other
    measurements, which are ignored.

    Returns a reference to a list of measurement records for computed BMIs.

    BMI computation can be modified by a number of configuration settings,
    as described in [PEDSnet::Derivation::BMI::Config](https://metacpan.org/pod/PEDSnet::Derivation::BMI::Config).

- get\_meas\_for\_person\_qry

    Returns a [Rose::DBx::CannedQuery::Glycosylated](https://metacpan.org/pod/Rose::DBx::CannedQuery::Glycosylated) object containing a
    query to retrieve all height and weight measurement records for a
    single person, whose `person_id` is passed as the sole bind parameter
    to the query.

- save\_meas\_qry($chunk\_size)

    Returns a [Rose::DBx::CannedQuery::Glycosylated](https://metacpan.org/pod/Rose::DBx::CannedQuery::Glycosylated) object containing a
    query that will save _$chunk\_size_ measurement records.  The query
    will expect values for the measurement records as bind parameter values.

- flush\_output

    Flush any pending output records to the sink backend.  In most cases,
    this is done for you automatically, but the method is public in case a
    subclass or application wants to flush manually in circumstances where
    it feels it's warranted.

- get\_person\_chunk($chunk)

    Returns a reference to an array of person records.  If _$chunk_ is
    present, specifies the desired number of records.  If it's not,
    defaults to ["PEDSnet::Derivation::BMI::Config" in person\_chunk\_size](https://metacpan.org/pod/person_chunk_size#PEDSnet::Derivation::BMI::Config).

    This implementation fetches records as specified by
    ["PEDSnet::Derivation::BMI::Config" in person\_finder\_sql](https://metacpan.org/pod/person_finder_sql#PEDSnet::Derivation::BMI::Config).  You are free
    to override this behavior in a subclass.  In particular, if you want
    to parallelize computation over a large source database,
    ["get\_person\_chunk"](#get_person_chunk) and
    ["PEDSnet::Derivation::BMI::Config" in person\_finder\_sql](https://metacpan.org/pod/person_finder_sql#PEDSnet::Derivation::BMI::Config) give you
    opportunities to point each process at a subset of persons.

- process\_person\_chunk($persons)

    For each person record in the list referred to by _$persons_, compute
    BMIs from measurement data in the source backend, and save results to
    the sink backend.  A person record is a hash reference; the only
    element used is `person_id`.

    Returns the number of BMI records saved.

- generate\_bmis()

    Using data from the ["PEDSnet::Derivation" in config](https://metacpan.org/pod/config#PEDSnet::Derivation) attribute, compute
    BMIs for everyone.

    In scalar context, returns the number of BMI records saved.  In list
    contest returns the number of BMI records and the number of unique
    persons with at least one BMI record.

# BUGS AND CAVEATS

Are there, for certain, but have yet to be cataloged.

# VERSION

version 0.03

# AUTHOR

Charles Bailey <cbail@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2016 by Charles Bailey

This software may be used under the terms of the Artistic License or
the GNU General Public License, as the user prefers.

This code was written at the Children's Hospital of Philadelphia as
part of [PCORI](http://www.pcori.org)-funded work in the
[PEDSnet](http://www.pedsnet.org) Data Coordinating Center.
