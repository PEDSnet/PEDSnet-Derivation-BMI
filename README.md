## PEDSnet::Derivation::BMI

The [PEDSnet::Derivation::BMI](https://metacpan.org/pod/PEDSnet::Derivation::BMI) module
computes body mass index (BMI) measurements for children with data in the PEDSnet CDM.

`PEDSnet::Derivation::BMI` is implemented as a [Perl5](http://www.perl.org)
package with the goal of portability, given the wide installed base for Perl5.
Consistent with this goal, we've made an effort to avoid use of code beyond base
Perl that requires a C compiler or specific binaries, and have stuck to
pure-Perl implementation wherever possible.  This comes at some performance
cost, and some code complexity.  Notably, the package uses the
[Moo](https://www.metacpan.org/pod/Moo) OO framework, which does not support
introspection; if you want a full-fledged meta-object framework, just `use
Moose;` in your code before loading `PEDSnet::Derivation`, and classes and
objects will transparently acquire full
[Moose](https://www.metacpan.org/pod/Moose) capabilities.

For more information on what's in the box, see the [SYNOPSIS](SYNOPSIS.md) and the documentation within the classes themselves.

### Installing PEDSnet::Derivation::BMI

Fundamentally, `PEDSnet::Derivation:BMI` is installed like any other Perl module.  If you're not already familiar with Perl module management, you may find one of these options useful.

#### Existing Perl5 Installation

If you have a recent version (5.24 or later is required) of Perl installed, you have several options for adding this package:

```
# Interactive package installer distributed with Perl
cpan PEDSnet::Derivation::BMI
# cpanminus - released version
cpanm PEDSnet::Derivation::BMI
# cpanminus - current development version
cpanm https://github.com/PEDSnet/PEDSnet-Derivation-BMI
```

#### New Perl5 Installation

If you don't have a recent version of Perl, or would like to avoid messing with the system's installed version, you can install a fresh copy of Perl and work with it instead.  On Unix-like systems with a C compiler, the following recipe will do the trick:

```
# Use perlbrew to manage local versions of Perl
curl -L https://install.perlbrew.pl | bash
perlbrew init
# Build a new perl version; see perlbrew available for options
perlbrew install perl-stable
perlbrew install-cpanm
# Install PEDSnet::Derivation::BMI
cpanm PEDSnet::Derivation::BMI
# OR, if you want the bleeding edge
cpanm https://github.com/PEDSnet/PEDSnet-Derivation-BMI
```

If building from source isn't an option for you, visit http://www.perl.org/get.html for binary versions, each of which comes with a package manager that should let you add on the released version of `PEDSnet::Derivation`.

#### Docker Container

Finally, if you want to avoid the overhead of building Perl, or prefer to keep PEDSnet::Derivation separated, you can use this [Dockerfile](etc/Dockerfile) or one like it build a Docker image that includes PEDSnet::Derivation::BMI.  This doesn't get you all the way to a running application -- you'll also have to provide configuration data and an application shell -- but it'll get you well on your way, and you can use additional building blocks in the `etc` directory to cover these last steps.
