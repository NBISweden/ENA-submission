#!/usr/bin/env perl

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

use constant
# All $opt_ variables are global.
#
my $opt_bamfile;
my $opt_action;
my $opt_xmldir;
my $opt_submit = 0;
my $opt_test   = 1;

my $opt_conf;

my $opt_help = 0;

if ( !GetOptions( "bamfile|b=s" => \$opt_bamfile,
                  "action|a=s"  => \$opt_action,
                  "xmldir|x=s"  => \$opt_xmldir,
                  "submit|s!"   => \$opt_submit,
                  "conf|c=s"    => \$opt_conf,
                  "test|t!"     => \$opt_test,
                  "help|h!"     => \$opt_help ) )
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

if ( $opt_action eq 'upload' ) {
    if ( !( defined($opt_bamfile) && defined($opt_xmldir) ) ||
         ( $opt_submit && !defined($opt_config) ) )
    {
        pod2usage( { -message => '!!> Need --bamfile and --xmldir, ' .
                       'and either --config or --nosubmit ' .
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

    my ( $xmldir, $username, $password, $bamfile ) = @_;

    #
    # Step 1: Calculate MD5 digest for the BAM file.
    #

    if ( !( defined($bamfile) && -f $bamfile ) ) {
        pod2usage( { -message => '!!> --bamfile not specified, ' .
                       'or specified BAM file was not found',
                     -verbose => 0,
                     -exitval => 1 } );
    }

    my $digest = file_md5_hex($bamfile);

    my $md5_out = IO::File->new( sprintf( "%s.md5", $bamfile ), "w" );
    $md5_out->print( $digest, "\n" );
    $md5_out->close();

    if ($opt_submit) {

        #
        # Step 2: Upload the BAM file and the MD5 digest to the ENA FTP
        # server.
        #

        my ( $username, $password ) = get_userpass();

        my $ftp = Net::FTP->new($ENA_FTP_SERVER);

        $ftp->login( $username, $password )
          or
          croak( sprintf( "Can not 'login' on ENA FTP server: %s",
                          $ftp->message() ) );

        $ftp->put($bamfile)
          or
          croak( sprintf( "Can not 'put' BAM file " .
                            "onto ENA FTP server: %s",
                          $ftp->message() ) );

        $ftp->put( sprintf( "%s.md5", $bamfile ) )
          or
          croak( sprintf( "Can not 'put' BAM file MD5 digest " .
                            "onto ENA FTP server: %s",
                          $ftp->message() ) );

        $ftp->quit();
    } ## end if ($opt_submit)
} ## end sub action_upload

sub get_userpass
{
    if ( !( defined($opt_config) && -f $opt_config ) ) {
        pod2usage( { -message => '!!> --config not specified, ' .
                       'or specified configuration file was not found',
                     -verbose => 0,
                     -exitval => 1 } );
    }

    $conf = Config::Simple->new($opt_config);

    my $username = $conf->param('username');
    my $password = $conf->param('password');

    return ( $username, $password );
}


__END__

=head1 NAME

submit.pl - A script that handles submission of data to ENA at EBI.

=head1 SYNOPSIS

    ./submit.pl --action="action" [other options]

    ./submit.pl --help

    ./submit.pl --action=upload --bamfile=XXX \
        [ --nosubmit | --config=XXX ]

=head1 OPTIONS

=over 8

=item B<--action> or B<-a>

The action to take.  This is one of the following:

=over 16

=item B<upload>

Upload a BAM file to ENA.  The MD5 digest of the BAM file is written to
C<B<bamfile>.md5> and the data is submitted to the ENA server.

Options used: B<--bamfile>, B<--submit>/B<--nosubmit>, B<--config>.

=back

=item B<--config> or B<-c>

A configuration file that contains the information neccesary to make a
submission to the ENA.

Example configuration file:

    username    =   "my_username"
    password    =   "myPASSword$$$"


=item B<--test> or B<-t>

When submitting, submit only to the ENA test server, not to the real
server.  This switch is enabled by default and my be negated using
the B<--notest> switch.

=item B<--submit> or B<-s>

Make a submission over the network.  With B<--nosubmit>, no network
connection to ENA will be made.  The default is to make a sumbission.

=item B<--help> or B<-h>

Display full help text, and exit.

=back

=cut
