#!/usr/bin/env perl

# Please format the code using 'perltidy'.  A perltidy configuration
# file is available in this directory (it will be picked up and used
# automatically).

use strict;
use warnings;

use Carp;
use Config::Simple;
use Digest::MD5::File qw( file_md5_hex );
#notyet use File::Spec::Functions;
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
my $opt_debug = 0;
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
# happens in the respctive action subroutine.
if ( $opt_action eq 'bamupload' ) {
    if ( !( defined($opt_file) && defined($opt_config) ) ) {
        pod2usage(
               { -message => '!!> Need at least --config and --file ' .
                   'for action "bamupload"',
                 -verbose => 0,
                 -exitval => 1 } );
    }

    action_bamupload();
}

sub action_bamupload
{
    #-------------------------------------------------------------------
    # ACTION = "bamupload"
    #-------------------------------------------------------------------

    #
    # Step 1: Calculate MD5 digest for the BAM file.
    #

    if ( !-f $opt_file ) {
        pod2usage(
              { -message => '!!> The specified BAM file was not found',
                -verbose => 0,
                -exitval => 1 } );
    }

    my $digest = file_md5_hex($opt_file);

    my $md5_file = sprintf( "%s.md5", $opt_file );
    my $md5_out = IO::File->new( $md5_file, "w" );
    $md5_out->print( $digest, "\n" );
    $md5_out->close();

    if ( !$opt_quiet ) {
        printf( "==> Wrote MD5 digest to '%s'\n", $md5_file );
    }

    if ( !$opt_submit ) {
        return;
    }

    #
    # Step 2: Upload the BAM file and the MD5 digest to the ENA FTP
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
} ## end sub action_bamupload

sub get_userpass
{
    if ( !( defined($opt_config) && -f $opt_config ) ) {
        pod2usage( { -message => '!!> --config not specified, ' .
                       'or specified configuration file was not found',
                     -verbose => 0,
                     -exitval => 1 } );
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

    ./submit.pl --action=bamupload \
        --config=XXX --file=XXX [ --nosubmit ]

=head1 OPTIONS

=over 8

=item B<--action> or B<-a>

The action to take.  This is one of the following:

=over 16

=item B<bamupload>

Upload a single BAM file to ENA.  The MD5 digest of the BAM file is
written to C<B<file>.md5> and the data is submitted to the ENA
server.  When submitting multiple BAM files, this script should be
invoked once for each file, maybe like this (for C<sh>-compatible
shells):

    for bam in *.bam; do
        ./submit.pl --action=bamupload \
            --config=XXX --file="$bam"
    done

Options used: B<--config>, B<--file>, and either B<--submit> or
B<--nosubmit> (B<--submit> is the default).

=back

=item B<--config> or B<-c>

A configuration file that contains the information neccesary to make a
submission to the ENA (your "Webin" user name and password).

Example configuration file:

    username    =   "my_username"
    password    =   "myPASSword$$$"

=item B<--debug>

Display various debug output.

=item B<--file> or B<-f>

The BAM file to upload with the "bamupload" action.

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
