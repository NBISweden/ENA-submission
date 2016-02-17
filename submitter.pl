#!/usr/bin/env perl

use strict;
use warnings;

use Carp;
use File::Basename;
use File::Spec::Functions;
use IO::File;

#use Data::Dumper;    # For debugging only

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
#
#   5.  This script doesn't currently support multiple samples from
#       *different* centers, i.e. all samples must have the same
#       "center_name" attribute in the sample XML file.
#
#   6.  The study 'center_name' will be used as the analysis
#       'center_name' in the analysis XML template generated.

my $flatfile_path = pop(@ARGV);
my @other_options = @ARGV;

##print Dumper( $flatfile_path, \@other_options );    # DEBUG

if ( !defined($flatfile_path) ) {
    croak("!> Expected name of data flat file on command line!");
}
elsif ( !-f $flatfile_path ) {
    croak(
         sprintf( "!> Can not find flat file '%s'!", $flatfile_path ) );
}

my ( $flatfile, $datadir ) = fileparse($flatfile_path);

printf( "=> Files are created in '%s'.\n", $datadir );

if ( !-f catfile( $datadir, 'study.xml' ) ) {
    croak( sprintf( "!> Can not find study XML file '%s'!",
                    catfile( $datadir, 'study.xml' ) ) );
}
elsif ( !-f catfile( $datadir, 'sample.xml' ) ) {
    croak( sprintf( "!> Can not find sample XML file '%s'!",
                    catfile( $datadir, 'sample.xml' ) ) );
}

print("=> Calling 'submit.pl' to submit study and sample(s)...\n");

my $reply = 'n';

if ( -f catfile( $datadir, 'submit.out' ) ) {
    print <<MESSAGE_END;
!> Found old output from submit.pl in '$datadir/sumbit.out'
!> Should it be used?
!>
!>  y:  Yes, use the old data from submit.pl
!>  n:  No, re-run submit.pl
!>  m:  No, re-run, but use MODIFY instead of ADD.
MESSAGE_END
    $reply = <STDIN>;
}

if ( $reply =~ /^n/i ) {
    system( "./submit.pl --action ADD " .
          join( ' ', @other_options ) .
          " $datadir/study.xml $datadir/sample.xml >$datadir/submit.out"
    );
}
elsif ( $reply =~ /^m/i ) {
    system( "./submit.pl --action MODIFY " .
          join( ' ', @other_options ) .
          " $datadir/study.xml $datadir/sample.xml >$datadir/submit.out"
    );
}

if ( !-f catfile( $datadir, 'submit.out' ) ) {
    croak("!> Failed to create submit.pl output file 'submit.out'!");
}
elsif ( -z catfile( $datadir, 'submit.out' ) ) {
    croak("!> Output file 'submit.out' from submit.pl is empty!");
}
else {
    print("=> Ok.\n");
}

my $submit_in =
  IO::File->new( catfile( $datadir, 'submit.out' ), "r" ) or
  croak(
      sprintf( "!> Failed to open 'submit.out' for reading: %s", $! ) );

my $study;
my @samples;

while ( my $line = $submit_in->getline() ) {
    chomp($line);

    my @fields = split( /\t/, $line );

    if ( $line =~ /^study/ ) {
        $study = { 'alias' => $fields[1], 'id' => $fields[2] };
    }
    elsif ( $line =~ /^sample/ ) {
        push( @samples,
              {  'alias' => $fields[1],
                 'id'    => $fields[2],
                 'extid' => $fields[3] } );
    }
}

$submit_in->close();

my $new_flatfile = 'submit-' . $flatfile;
my $new_flatfile_path = catfile( $datadir, $new_flatfile );

printf( "=> Now creating '%s' from '%s', " .
          "replacing locus tags with ENA IDs...\n",
        $new_flatfile, $flatfile );

my $flatfile_in = IO::File->new( $flatfile_path, "r" )
  or
  croak( sprintf( "!> Failed to open '%s' for reading: %s",
                  $flatfile_path, $! ) );

my $flatfile_out = IO::File->new( $new_flatfile_path, "w" )
  or
  croak( sprintf( "!> Failed to open '%s' for writing: %s",
                  $new_flatfile_path, $! ) );

##print Dumper( \@study, \@samples );    # DEBUG

while ( my $line = $flatfile_in->getline() ) {
    foreach my $sample (@samples) {
        my ( $alias, $id ) =
          ( $sample->{'alias'}, $sample->{'id'} );
        if ( $line =~ s/$alias/$id/ ) { last }
    }

    $flatfile_out->print($line);
}

$flatfile_in->close();
$flatfile_out->close();

printf( "=> Compressing data file '%s' using gzip...\n",
        $new_flatfile );

system( 'gzip', '--force', '--best', $new_flatfile_path );

printf( "=> Submitting data file '%s.gz' to ENA...\n", $new_flatfile );

system( './submit.pl', @other_options, '--upload',
        $new_flatfile_path . '.gz' );

my %miscinfo;
foreach my $file (qw( study sample )) {
    printf( "=> Getting misc %s info...\n", $file );
    my $file_in =
      IO::File->new( catfile( $datadir, $file . '.xml' ), "r" )
      or
      croak( sprintf( "!> Failed to open '%s' for reading: %s",
                      catfile( $datadir, $file . '.xml' ), $! ) );

    while ( my $line = $file_in->getline() ) {
        if ( $line =~ /center_name="([^"]+)"/ ) {
            $miscinfo{$file}{'center_name'} = $1;
            last;
        }
    }

    $file_in->close();
}

##print Dumper( \%miscinfo );    # DEBUG

print("=> Creating analysis XML template...\n");

my $digest_in = IO::File->new( $new_flatfile_path . '.gz.md5', "r" )
  or
  croak( sprintf( "!> Failed to open '%s.gz.md5' for reading: %s",
                  $new_flatfile_path, $! ) );

my $digest = $digest_in->getline();
chomp($digest);

$digest_in->close();

my $analysis_out =
  IO::File->new( catfile( $datadir, 'analysis.xml' ), "w" )
  or
  croak( sprintf( "!> Failed to open '%s' for writing: %s",
                  catfile( $datadir, 'analysis.xml' ), $! ) );

$analysis_out->print( <<XML_END );
<?xml version="1.0" encoding="utf-8"?>
<ANALYSIS_SET>
\t<ANALYSIS
\t  alias="%%ANALYSIS_ALIAS%%"
\t  center_name="$miscinfo{'study'}{'center_name'}">
\t\t<TITLE>%%ANALYSIS_TITLE%%</TITLE>
\t\t<DESCRIPTION>%%ANALYSIS_DESCRIPTION%%</DESCRIPTION>
\t\t<STUDY_REF
\t\t  refname="$study->{'alias'}"
\t\t  refcenter="$miscinfo{'study'}{'center_name'}" />
XML_END

foreach my $sample (@samples) {
    $analysis_out->print( <<XML_END );
\t\t<SAMPLE_REF
\t\t  refname="$sample->{'alias'}"
\t\t  refcenter="$miscinfo{'sample'}{'center_name'}" />
XML_END
}

$analysis_out->print( <<XML_END );
\t\t<ANALYSIS_TYPE>
\t\t\t<SEQUENCE_ASSEMBLY>
\t\t\t\t<NAME>%%ASSEMBLY_NAME%%</NAME>
\t\t\t\t<PARTIAL>%%ASSEMBLY_IS_PARTIAL_TRUE_OR_FALSE%%</PARTIAL>
\t\t\t\t<COVERAGE>%%ASSEMBLY_COVERAGE_INTEGER_PERCENT%%</COVERAGE>
\t\t\t\t<PROGRAM>%%ASSEMBLY_PROGRAM_AND_VERSION%%</PROGRAM>
\t\t\t\t<PLATFORM>%%ASSEMBLY_PLATFORM%%</PLATFORM>
\t\t\t</SEQUENCE_ASSEMBLY>
\t\t</ANALYSIS_TYPE>
\t\t<FILES>
\t\t\t<FILE
\t\t\t  filename="$new_flatfile.gz"
\t\t\t  filetype="%%FILE_FILETYPE%%"
\t\t\t  checksum_method="MD5"
\t\t\t  checksum="$digest" />
\t\t</FILES>
\t</ANALYSIS>
</ANALYSIS_SET>

<!--
 Controlled vocabulary for filetype (%%FILE_FILETYPE%%):
 "contig_fasta"
 "contig_flatfile"
 "scaffold_fasta"
 "scaffold_flatfile"
 "scaffold_agp"
 "chromosome_fasta"
 "chromosome_flatfile"
 "chromosome_agp"
 "chromosome_list"
 "unlocalised_contig_list"
 "unlocalised_scaffold_list"
 -->
XML_END

print("=> All done.\n");
printf( "=> Fill out '%s' and submit it with the command\n",
        catfile( $datadir, 'analysis.xml' ) );
printf( "\t./submit.pl [maybe other options] -a ADD %s\n",
        catfile( $datadir, 'analysis.xml' ) );
