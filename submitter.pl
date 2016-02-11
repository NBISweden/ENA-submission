#!/usr/bin/env perl

use strict;
use warnings;

use Carp;
use File::Basename;
use File::Spec::Functions;
use IO::File;

use Data::Dumper;    # For debugging only

# This is a wrapper around the submit.pl Perl script.
#
# The script performs the following steps:
#
#   1.  Submission of a study and sample XML to the ENA servers.
#
#   2.  Receives the identifiers assigned by the ENA to the submitted
#       study and sample.
#
#   3.  Updates the given flat file with the sample identifier.
#
#   4.  Compresses the flat file.
#
#   5.  Submits the compressed flat file, together with its MD5 digest,
#       to the ENA servers.
#
#   6.  Generates a partially filled-in template for the analysis XML.
#
#   ( does not: 7.  Submits the generated analysis XML to the ENA servers. )

# Current restrictions and assumptions:
#
#   1.  All input files are located in the one and same directory.
#
#   2.  All XML input files have obvious names, i.e. the sample XML file
#       is called "sample.xml" etc.
#
#   3.  The data flat file is also located in this same directory, and
#       its name is given on the command line to this script.
#
#   4.  It is assumed that the alias of the sample is the prefix of the
#       "locus_tag" in the flat file data, i.e. that an alias of "RZ63"
#       corresponds to locus tags "RZ63_*".

my $flatfile_path = $ARGV[0];

if ( !defined($flatfile_path) ) {
    croak("Expected name of data flat file on command line!");
}
elsif ( !-f $flatfile_path ) {
    croak( sprintf( "Can not find flat file '%s'!", $flatfile_path ) );
}

my ( $flatfile, $datadir ) = fileparse($flatfile_path);

if ( !-f "$datadir/study.xml" ) {
    croak( sprintf( "Can not find study XML file '%s'!",
                    "$datadir/study.xml" ) );
}
elsif ( !-f "$datadir/sample.xml" ) {
    croak( sprintf( "Can not find sample XML file '%s'!",
                    "$datadir/sample.xml" ) );
}
elsif ( !-f "$datadir/analysis.xml" ) {
    croak( sprintf( "Can not find analysis XML file '%s'!",
                    "$datadir/analysis.xml" ) );
}

# The following is commented out while developing:
#system( "./submit.pl -c submit.conf.dist --action ADD " .
#"$datadir/study.xml $datadir/sample.xml >submit.out" );

if ( !-f "submit.out" ) {
    croak("Failed to create submit.pl output file!");
}
elsif ( -z "submit.out" ) {
    croak("Output from submit.pl is empty.  Something went wrong!");
}

my $submit_in = IO::File->new( "submit.out", "r" ) or
  croak( sprintf( "Failed to open 'submit.out' for reading: %s", $! ) );

my @study;
my @samples;

while ( my $line = $submit_in->getline() ) {
    chomp($line);

    my @fields = split( /\t/, $line );

    if ( $line =~ /^study/ ) {
        push( @study, { 'alias' => $fields[1], 'id' => $fields[2] } );
    }
    elsif ( $line =~ /^sample/ ) {
        push( @samples,
              {  'alias' => $fields[1],
                 'id'    => $fields[2],
                 'extid' => $fields[3] } );
    }
}

$submit_in->close();

my $new_flatfile_path = catfile( $datadir, "new-" . $flatfile );

my $flatfile_in = IO::File->new( $flatfile_path, "r" )
  or
  croak(
      sprintf( "Failed to open '%s' for reading: %s", $flatfile_path, $!
      ) );

my $flatfile_out = IO::File->new( $new_flatfile_path, "w" )
  or
  croak( sprintf( "Failed to open 'new-%s' for writing: %s",
                  $new_flatfile_path, $! ) );

##print Dumper( \@study, \@samples );    # DEBUG

while ( my $line = $flatfile_in->getline() ) {
    foreach my $sample (@samples) {
        my ( $alias, $id ) = ( $sample->{'alias'}, $sample->{'id'} );
        if ( $line =~ s/$alias/$id/ ) { last }
    }

    $flatfile_out->print($line);
}

$flatfile_in->close();
$flatfile_out->close();
