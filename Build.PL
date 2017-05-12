
use strict;
use warnings;

use Module::Build 0.28;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.28"
  },
  "configure_requires" => {
    "ExtUtils::MakeMaker" => 0,
    "Module::Build" => "0.28"
  },
  "dist_abstract" => "Compute body mass index in the PEDSnet CDM",
  "dist_author" => [
    "Charles Bailey <cbail\@cpan.org>"
  ],
  "dist_name" => "PEDSnet-Derivation-BMI",
  "dist_version" => "0.03",
  "license" => "open_source",
  "module_name" => "PEDSnet::Derivation::BMI",
  "recursive_test_files" => 1,
  "requires" => {
    "Moo" => 2,
    "MooX::Role::Chatty" => 0,
    "PEDSnet::Derivation" => 0,
    "PEDSnet::Derivation::Config" => 0,
    "Rose::DateTime::Util" => 0,
    "Types::Standard" => 0,
    "perl" => "5.024",
    "strict" => 0,
    "warnings" => 0
  },
  "test_requires" => {
    "Config::General" => 0,
    "DBD::SQLite" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "FindBin" => 0,
    "PEDSnet::Derivation::Backend::CSV" => 0,
    "Path::Tiny" => 0,
    "Rose::DB" => 0,
    "Test::Differences" => 0,
    "Test::More" => 0,
    "parent" => 0
  }
);


my %fallback_build_requires = (
  "Config::General" => 0,
  "DBD::SQLite" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "FindBin" => 0,
  "Module::Build" => "0.28",
  "PEDSnet::Derivation::Backend::CSV" => 0,
  "Path::Tiny" => 0,
  "Rose::DB" => 0,
  "Test::Differences" => 0,
  "Test::More" => 0,
  "parent" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;
