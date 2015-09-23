#!/usr/bin/env perl

# Please format the code using 'perltidy'.  A perltidy configuration
# file is available in this directory (it will be picked up and used
# automatically).

use strict;
use warnings;

use Carp;
use Config::Simple;
use Data::Dumper;    # for debugging only
use Digest::MD5::File qw( file_md5_hex );
use File::Spec::Functions qw( splitpath catfile );
use Getopt::Long;
use HTTP::Request::Common qw( POST );
use IO::File;
use LWP::UserAgent;
use Net::FTP;
use Pod::Usage;
use XML::Simple qw( :strict );

# These are global variables
#
my $ENA_TEST_URL =
  'https://www-test.ebi.ac.uk/ena/submit/drop-box/submit/';
my $ENA_PRODUCTION_URL =
  'https://www.ebi.ac.uk/ena/submit/drop-box/submit/';
my $ENA_WEBIN_FTP = 'webin.ebi.ac.uk';

# All $opt_ variables are global too
#
my $opt_action;
my $opt_config;
my $opt_debug = 1;
my $opt_file;
my $opt_help   = 0;
my $opt_quiet  = 0;
my $opt_submit = 1;
my $opt_test   = 1;

if ( !GetOptions( "action|a=s" => \$opt_action,
                  "config|c=s" => \$opt_config,
                  "debug!"     => \$opt_debug,
                  "file|f=s"   => \$opt_file,
                  "help|h!"    => \$opt_help,
                  "quiet!"     => \$opt_quiet,
                  "submit|s!"  => \$opt_submit,
                  "test|t!"    => \$opt_test, ) )
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
    pod2usage( { -message => '!!> Missing --action or --help',
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
elsif ( $opt_action eq 'submission' ) {
    if ( !( defined($opt_file) && defined($opt_config) ) ) {
        pod2usage(
               { -message => '!!> Need at least --config and --file ' .
                   'for action "submission"',
                 -verbose => 0,
                 -exitval => 1 } );
    }

    action_submission();
}
else {
    pod2usage( { -message =>
                   sprintf( "!!> Unknown action '%s'", $opt_action ),
                 -verbose => 0,
                 -exitval => 1 } );
}

sub action_upload
{
    #-------------------------------------------------------------------
    # ACTION = "upload"
    #-------------------------------------------------------------------

    #
    # Step 1: Calculate MD5 digest for the data file.
    #

    if ( !-f $opt_file ) {
        printf( "!!> ERROR: The data file '%s' was not found\n",
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
    # directory as the data file.  If this file exists, read it and
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
                printf( "!!> WARNING: Can not find data file '%s' " .
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
    # Step 3: Upload the data file and the MD5 digest to the ENA FTP
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
      croak( sprintf( "Can not 'put' data file onto ENA FTP server: %s",
                      $ftp->message() ) );

    $ftp->put( sprintf( "%s.md5", $opt_file ) )
      or
      croak( sprintf( "Can not 'put' data file MD5 digest " .
                        "onto ENA FTP server: %s",
                      $ftp->message() ) );

    $ftp->quit();

    if ( !$opt_quiet ) {
        print( "==> Submitted data file and MD5 digest " .
               "to ENA FTP server\n" );
    }
} ## end sub action_upload

sub action_submission
{
    #-------------------------------------------------------------------
    # ACTION = "submission"
    #-------------------------------------------------------------------

    #
    # Step 1: Collect all file names from the end of the command line.
    #

    my %xml_file;

    foreach my $argv_file (@ARGV) {
        my $file = ( splitpath($argv_file) )[2];
        $xml_file{$file}{'file'} = $argv_file;
    }

    #
    # Step 2: Read the submission XML file to figure out what other
    # files to expect on the command line.
    #

    if ( !-f $opt_file ) {
        printf( "!!> ERROR: The XML submission file '%s' " .
                  "was not found\n",
                $opt_file );
        exit(1);
    }

    my $submission_xml = XMLin( $opt_file,
                                ForceArray => ['ACTION'],
                                KeyAttr    => undef,
                                GroupTags  => { 'ACTIONS' => 'ACTION' }
    );

    my %schema_file;
    my $error = 0;

    ##print Dumper($submission_xml);    # DEBUG

    foreach my $action ( @{ $submission_xml->{'ACTIONS'} } ) {
        foreach my $action_name ( keys( %{$action} ) ) {

            if ( exists( $action->{$action_name}{'source'} ) ) {
                my $source_file = $action->{$action_name}{'source'};
                my $source_schema =
                  uc( $action->{$action_name}{'schema'} );

                if ( !exists( $xml_file{$source_file} ) ) {
                    printf( "!!> ERROR: XML file '%s' " .
                              "referenced by submission XML " .
                              "was not available on command line\n",
                            $source_file );
                    $error = 1;
                }
                else {
                    if ( !$opt_quiet ) {
                        printf( "==> Submission XML will %s '%s' " .
                                  "(%s schema)\n",
                                $action_name, $source_file,
                                $source_schema );
                    }

                    $schema_file{$source_schema} =
                      $xml_file{$source_file}{'file'};

                    $xml_file{$source_file}{'available'} = 1;
                }

            } ## end if ( exists( $action->...))

        } ## end foreach my $action_name ( keys...)
    } ## end foreach my $action ( @{ $submission_xml...})

    foreach my $file ( keys(%xml_file) ) {
        if ( !exists( $xml_file{$file}{'available'} ) ) {
            printf( "!!> WARNING: File '%s' ('%s') " .
                      "given on command line " .
                      "is not mentioned by submission XML (ignoring)\n",
                    $file, $xml_file{$file}{'file'} );
        }
    }

    if ($error) {
        exit 1;
    }

    if ( !$opt_submit ) { return }

    #
    # Step 3: Make submission
    #

    $ENV{'HTTPS_DEBUG'} = $opt_debug;

    # To get around "certificate verify failed" (error 500)
    #
    $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
    IO::Socket::SSL::set_ctx_defaults( SSL_verifycn_scheme => 'www',
                                       SSL_verify_mode     => 0, );

    my $ua = LWP::UserAgent->new();
    $ua->show_progress($opt_debug);
    $ua->default_header(
               'Accept-Encoding' => scalar HTTP::Message::decodable() );

    my $url;
    if ($opt_test) {
        $url = $ENA_TEST_URL;
    }
    else {
        $url = $ENA_PRODUCTION_URL;
    }

    my ( $username, $password ) = get_userpass();

    $url =
      sprintf( "%s?auth=ENA%%20%s%%20%s", $url, $username, $password );

    my $request = POST( $url,
                        Content_Type => 'form-data',
                        Content      => [
                                     'SUBMISSION' => [$opt_file],
                                     map { $_ => [ $schema_file{$_} ] }
                                       keys(%schema_file) ] );

    ##print Dumper($request);    # DEBUG

    my $response = $ua->simple_request($request);

    ##print Dumper($response);    # DEBUG

    if ( !$response->is_success() ) {
        printf( "!!> ERROR: HTTPS request failed: %s\n",
                $response->as_string() );
        exit(1);
    }
    elsif ( !$opt_quiet ) {
        print("==> HTTPS request successful\n");
    }

    my $response_xml = XMLin( $response->decoded_content(),
                              ForceArray => undef,
                              KeyAttr    => undef );

    ##print Dumper($response_xml);    # DEBUG

    if ( $response_xml->{'success'} eq 'false' ) {
        printf( "!!> ERROR: Submission failed: %s\n",
                $response_xml->{'MESSAGES'}{'ERROR'} );
        exit(1);
    }

    # TODO: Handle successful submission (probably just diplay info
    #       (unless $opt_quiet))

} ## end sub action_submission

sub get_userpass
{
    if ( !-f $opt_config ) {
        printf( "!!> ERROR: The specified configuration file '%s' " .
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

    ./submit.pl [ --nodebug ] [ --quiet ] \
        --action="action" [other options (see below)]

    ./submit.pl --help

=head2 Actions

=head3 "upload"

The B<upload> action is for uploding data files.

    ./submit.pl --action=upload \
        --config=XXX --file=XXX [ --nosubmit ]

=head3 "submission"

The B<submission> action is for submitting XML files.

    ./submit.pl --action=submission \
        --config=XXX --file=XXX \
        [ --notest ] [ --nosubmit ] [ further XML files ]

=head1 OPTIONS

=over 8

=item B<--action> or B<-a>

The action to take.  This is one of the following:

=over 16

=item B<upload>

Upload a single data file to ENA.  The data file is a file in BAM or
CRAM format or in whatever other file format ENA accepts.  No check is
made of the data file format or its integrity by this script.

The data file is specified by the B<--file=C<XXX>> option.

The MD5 digest (checksum) of the file is written to C<B<XXX>.md5> and
both the data and digest is uploaded to the ENA FTP server.

The MD5 digest is also added to a "manifest file" called C<manifest.all>
in the same directory as the data file.  It is assumed that all data
files resides in the one and same directory.

When submitting multiple data files, this script should be invoked once
for each file, maybe like this (for B<sh>-compatible shells):

    for bam in *.bam; do
        ./submit.pl --action=upload \
            --config=XXX --file="$bam"
    done

Options used: B<--config>, B<--file> and B<--submit> (or B<--nosubmit>).
In addition, the common options B<--quiet> (or B<--noquiet>) and
B<--debug> (or B<--nodebug>) are used.

=item B<submission>

Submit an XML file to ENA.

The XML submission file is specified by the B<--file=C<XXX>> option and
any additional XML file is added to the end of the command line.

The submission XML file will be examined in order to figure out what the
other XML files are and a message will be displayed with a confirmation
of the submission (unless the B<--quiet> option is used).

Options used: B<--config>, B<--file>, B<--test> (or B<--notest>) and
B<--submit> (or B<--nosubmit>).  In addition, the common options
B<--quiet> (or B<--noquiet>) and B<--debug> (or B<--nodebug>) are used.

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

The data file to upload with the B<upload> action.

The submission XML to use with the B<submission> action.

=item B<--help> or B<-h>

Display full help text, and exit.

=item B<--quiet>

Be quiet. Only error messages will be displayed.  This option may be
negated using B<--noquiet> (which is the default).

=item B<--submit> or B<-s>

Make a submission over the network.  With B<--nosubmit>, no network
connection to ENA will be made.  The default is to make a network
connection.

=item B<--test> or B<-t>

When submitting XML using the B<submission> action, submit only to the
ENA test server, not to the ENA production server.  This switch is
enabled by default and my be negated using the B<--notest> switch.

=back

=cut
