#!/usr/bin/env perl

# Please format the code using 'perltidy'.  A perltidy configuration
# file is available in this directory (it will be picked up and used
# automatically).

use strict;
use warnings;

use Carp;
use Config::Simple;
use Digest::MD5::File qw( file_md5_hex );
use File::Spec::Functions qw( splitpath catfile );
use Getopt::Long;
use IO::File;
use Net::FTP;
use Pod::Usage;
#notyet use XML::Simple;

my $ENA_TEST_URL =
  'https://www-test.ebi.ac.uk/ena/submit/drop-box/submit/?';
my $ENA_PRODUCTION_URL =
  'https://www.ebi.ac.uk/ena/submit/drop-box/submit/?';
my $ENA_WEBIN_FTP = 'webin.ebi.ac.uk';

# All $opt_ variables are global.
#
my $opt_action;
my $opt_config;
my $opt_debug = 1;
my $opt_file;
my $opt_help   = 0;
my $opt_quiet  = 0;
my $opt_submit = 1;
my $opt_test   = 1;
my $opt_xmldir;

if ( !GetOptions( "action|a=s" => \$opt_action,
                  "config|c=s" => \$opt_config,
                  "debug!"     => \$opt_debug,
                  "file|f=s"   => \$opt_file,
                  "help|h!"    => \$opt_help,
                  "quiet!"     => \$opt_quiet,
                  "submit|s!"  => \$opt_submit,
                  "test|t!"    => \$opt_test,
                  "xmldir|x=s" => \$opt_xmldir, ) )
{
    pod2usage( { -message => '!!> Failed to parse command line',
                 -verbose => 0,
                 -exitval => 1 } );
}

if ($opt_help) {
    pod2usage( { -verbose => 2,
                 -exitval => 0 } );
}

if ( !defined($opt_action) ) {
    pod2usage( { -message => '!!> Missing --action',
                 -verbose => 0,
                 -exitval => 1 } );
}

# Each action should test here for existance of each required option.
# Validation of the option values (e.g. checking that files exists etc.)
# happens in the respective action subroutine.

if ( $opt_action eq 'upload' ) {
    if ( !( defined($opt_file) && defined($opt_config) ) ) {
        pod2usage(
               { -message => '!!> Need at least --config and --file ' .
                   'for action "upload"',
                 -verbose => 0,
                 -exitval => 1 } );
    }

    action_upload();
}

sub action_upload
{
    #-------------------------------------------------------------------
    # ACTION = "upload"
    #-------------------------------------------------------------------

    #
    # Step 1: Calculate MD5 digest for the BAM file.
    #

    if ( !-f $opt_file ) {
        printf( "!!> Error: The BAM file '%s' was not found\n",
                $opt_file );
        exit(1);
    }

    my $digest = file_md5_hex($opt_file);

    my $md5_file = sprintf( "%s.md5", $opt_file );
    my $md5_out = IO::File->new( $md5_file, "w" );

    $md5_out->print( $digest, "\n" );
    $md5_out->close();

    if ( !$opt_quiet ) {
        printf( "==> Wrote MD5 digest to '%s'\n", $md5_file );
    }

    #
    # Step 2: Add the MD5 digest to the file "manifest.all" in the same
    # directory as the BAM data file.  If this file exists, read it and
    # make sure each entry is unique before overwriting it with all tho
    # original digests and the new addiional digest.
    #

    my ( $bam_path, $bam_file ) = ( splitpath($opt_file) )[ 1, 2 ];
    my $manifest_file = catfile( $bam_path, "manifest.all" );

    my %manifest = ( $bam_file => $digest );

    if ( -f $manifest_file ) {
        my $manifest_in = IO::File->new( $manifest_file, "r" );

        while ( my $line = $manifest_in->getline() ) {
            chomp($line);
            my ( $file, $file_digest ) = split( /\t/, $line );
            $manifest{$file} = $file_digest;

            if ( !-f catfile( $bam_path, $file ) ) {
                printf( "!!> Warning: Can not find BAM file '%s' " .
                          "listed in manifest file '%s'\n",
                        catfile( $bam_path, $file ), $manifest_file );
            }
        }

        $manifest_in->close();
    }

    my $manifest_out = IO::File->new( $manifest_file, "w" );

    foreach my $file ( sort( keys(%manifest) ) ) {
        $manifest_out->printf( "%s\t%s\n", $file, $manifest{$file} );
    }

    $manifest_out->close();

    if ( !$opt_quiet ) {
        printf( "==> Added MD5 digest to '%s'\n", $manifest_file );
    }

    if ( !$opt_submit ) {
        return;
    }

    #
    # Step 3: Upload the BAM file and the MD5 digest to the ENA FTP
    # server.
    #

    my ( $username, $password ) = get_userpass();

    my $ftp = Net::FTP->new( $ENA_WEBIN_FTP, Debug => $opt_debug );

    $ftp->login( $username, $password )
      or
      croak( sprintf( "Can not 'login' on ENA FTP server: %s",
                      $ftp->message() ) );

    $ftp->put($opt_file)
      or
      croak( sprintf( "Can not 'put' BAM file onto ENA FTP server: %s",
                      $ftp->message() ) );

    $ftp->put( sprintf( "%s.md5", $opt_file ) )
      or
      croak( sprintf( "Can not 'put' BAM file MD5 digest " .
                        "onto ENA FTP server: %s",
                      $ftp->message() ) );

    $ftp->quit();

    if ( !$opt_quiet ) {
        print( "==> Submitted BAM file and MD5 digest " .
               "to ENA FTP server\n" );
    }
} ## end sub action_upload

sub get_userpass
{
    if ( !-f $opt_config ) {
        printf( "!!> Error: The specified configuration file '%s' " .
                  "was not found\n",
                $opt_config );
        exit(1);
    }

    my $config = Config::Simple->new($opt_config);

    my $username = $config->param('username');
    my $password = $config->param('password');

    return ( $username, $password );
}

__END__

=head1 NAME

submit.pl - A script that handles submission of data to ENA at EBI.

=head1 SYNOPSIS

    ./submit.pl --action="action" [other options (see below)]

    ./submit.pl --help

=head2 Actions

    ./submit.pl --action=upload \
        --config=XXX --file=XXX [ --nosubmit ]

=head1 OPTIONS

=over 8

=item B<--action> or B<-a>

The action to take.  This is one of the following:

=over 16

=item B<upload>

Upload a single BAM file to ENA.

The BAM file is specified by the
B<--file=C<XXX>> option.

The MD5 digest (checksum) of the file is written to C<B<XXX>.md5> and
the data is submitted to the ENA FTP server.

The MD5 digest is also added to a "manifest file" called C<manifest.all>
in the same directory as the BAM data file.  It is assumed that all BAM
files resides in the one and same directory.

When submitting multiple BAM files, this script should be invoked once
for each file, maybe like this (for B<sh>-compatible shells):

    for bam in *.bam; do
        ./submit.pl --action=upload \
            --config=XXX --file="$bam"
    done

Options used: B<--config>, B<--file>, and either B<--submit> or
B<--nosubmit> (B<--submit> is the default).

=item B<submit>

Submit an XML file to ENA.

The XML file is specified by the B<--file=C<XXX>> option.

=back

=item B<--config> or B<-c>

A configuration file that contains the information neccesary to make a
submission to the ENA (your "Webin" user name and password).

Example configuration file:

    username    =   "my_username"
    password    =   "myPASSword$$$"

=item B<--debug>

Display various debug output.  This is the default during development.

=item B<--file> or B<-f>

The BAM file to upload with the "upload" action.

=item B<--help> or B<-h>

Display full help text, and exit.

=item B<--quiet>

Be quiet. Only error messages will be displayed.

=item B<--submit> or B<-s>

Make a submission over the network.  With B<--nosubmit>, no network
connection to ENA will be made.  The default is to make a sumbission.

=item B<--test> or B<-t>

When submitting XML, submit only to the ENA test server, not to the ENA
production server.  This switch is enabled by default and my be negated
using the B<--notest> switch.

=item B<--xmldir> or B<-x>

The directory containing the following XML files:

    submission.xml

    #TODO: Add more.

=back

=cut
