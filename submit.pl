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
my @opt_action;
my $opt_config  = 'submit.conf';
my $opt_debug   = 1;
my $opt_help    = 0;
my $opt_net     = 1;
my $opt_profile = 'default';
my $opt_quiet   = 0;
my $opt_test    = 1;
my $opt_upload  = 0;

if ( !GetOptions( "action|a=s"  => \@opt_action,
                  "config|c=s"  => \$opt_config,
                  "debug!"      => \$opt_debug,
                  "help|h!"     => \$opt_help,
                  "net!"        => \$opt_net,
                  "profile|p=s" => \$opt_profile,
                  "quiet!"      => \$opt_quiet,
                  "test|t!"     => \$opt_test,
                  "upload|u!"   => \$opt_upload, ) )
{
    pod2usage( { -message => '!!> Failed to parse command line',
                 -verbose => 0,
                 -exitval => 1 } );
}

if ($opt_help) {
    pod2usage( { -verbose => 2,
                 -exitval => 0 } );
}

# Each action should test here for existence of each required option.
# Validation of the option values (e.g. checking that files exists etc.)
# happens in the respective action subroutine.

if ($opt_upload) {
    if ( !defined($opt_file) ) {
        pod2usage( { -message => '!!> Need at least --file ' .
                       'for action "upload"',
                     -verbose => 0,
                     -exitval => 1 } );
    }

    action_upload();
}
# The remaining actions are "XML actions":
#
#   ADD:        "Add an object to the archive."
#
#   MODIFY:     "Modify an object in the archive."
#
#   CANCEL:     "Cancel an object which has not been made public.
#                Cancelled objects will not be made public."
#
#   SUPRESS:    "Suppress an object which has been made public.
#                Suppressed data will remain accessible by accession
#                number."
#
#   HOLD:       "Make the object public only when the hold date
#                expires."
#
#   RELEASE:    "The object will be released immediately to public."
#
#   PROTECT:    "This action is required for data submitted to European
#                Genome-Phenome Archive (EGA)."
#
#   VALIDATE:   "Validates the submitted XMLs without actually
#                submitting them."
#
# (ftp://ftp.sra.ebi.ac.uk/meta/xsd/latest/SRA.submission.xsd)
#
elsif ( $opt_action eq 'submission' || $opt_action eq 'submit' ) {
    if ( !( defined($opt_file) && defined($opt_config) ) ) {
        pod2usage( { -message => '!!> Need at least --file ' .
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
    # original digests and the new additional digest.
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

    if ( !$opt_net ) {
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

    if ( !$opt_net ) { return }

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

    if ( !$opt_quiet ) {
        printf( "==> ENA says: %s\n",
                $response_xml->{'MESSAGES'}{'INFO'} );
    }

    if ( $response_xml->{'success'} eq 'false' ) {
        if ( ref( $response_xml->{'MESSAGES'}{'ERROR'} ) eq 'ARRAY' ) {
            my $error_count = 0;
            foreach my $error_message (
                             @{ $response_xml->{'MESSAGES'}{'ERROR'} } )
            {
                printf( "!!> ERROR #%d: Submission failed: %s\n",
                        ++$error_count, $error_message );
            }
        }
        else {
            printf( "!!> ERROR: Submission failed: %s\n",
                    $response_xml->{'MESSAGES'}{'ERROR'} );
        }
        exit(1);
    }
    else {
        if ( !$opt_quiet ) {
            print("==> Success\n");
        }
    }

} ## end sub action_submission

sub get_userpass
{
    my ( $config_section, $missing_ok ) = @_;

    my $default_username;
    my $default_password;

    if ( $config_section ne 'default' ) {
        ( $default_username, $default_password ) =
          get_userpass( 'default', 1 );
    }

    if ( !defined($missing_ok) ) { $missing_ok = 0 }

    if ( !-f $opt_config ) {
        printf( "!!> ERROR: The specified configuration file '%s' " .
                  "was not found\n",
                $opt_config );
        exit(1);
    }

    my $config = Config::Simple->new($opt_config);

    my $profile = $config->param( -block => $config_section );

    ##print Dumper($profile);    # DEBUG

    if ( !$missing_ok ) {
        if ( scalar( keys( %{$profile} ) ) == 0 ) {
            printf( "!!> ERROR: Configuration profile '%s' " .
                      "is missing in '%s'\n",
                    $config_section, $opt_config );
            exit(1);
        }
        elsif ( !exists( $profile->{'username'} ) ||
                !exists( $profile->{'password'} ) )
        {
            printf( "!!> ERROR: Missing username/password " .
                      "for configuration profile '%s' in '%s'\n",
                    $config_section, $opt_config );
            exit(1);
        }
    }

    my $username = $profile->{'username'} || $default_username;
    my $password = $profile->{'password'} || $default_password;

    return ( $username, $password );
} ## end sub get_userpass

__END__

=head1 NAME

submit.pl - A script that handles submission of data to ENA at EBI.

=head1 SYNOPSIS

There are two main ways to invoke this script.  One is used for
uploading data files, and the other is used for submitting XML.  The
script will determine which of these is requested by looking for the
B<--upload> option on the command line (used for uploading data).

=head2 Uploading data to ENA

    ./submit.pl [ --nodebug ] [ --quiet ] [ --nonet ] \
        --upload DATA_FILENAME [ DATA_FILENAME ... ]

TODO: Implement uploading of multiple data files.

=head2 Submitting XML to ENA

    ./submit.pl [ --nodebug ] [ --quiet ] [ --nonet ] \
        --action ACTION[=PARAMETER] \
        [ --action ACTION[=PARAMETER] ... ] \
        [ XML_FILENAME [ XML_FILENAME ... ] ]

TODO: Implement this stuff.

TODO: FIXME: Documentation below.

=head1 OPTIONS

=over 8

=item B<--action> or B<-a>

The action to take when submitting XML files to ENA.  This option may
occur several times on the command line, but usually only once.  You may
want to use, e.g.,

    --action ADD --action HOLD=YYYY-MM-DD

... to submit (ADD) and hold data until a particular date (see the
B<HOLD> action below).

=item B<--upload>

Upload a single data file to ENA.  If this option is not present on the
command line it is assumed that a set of XML files should be submitted.

The data file is a file in BAM or CRAM format or in whatever other file
format ENA accepts.  No check is made of the data file format or its
integrity by this script.

The data file is specified by adding its path to the end of the command
line.

The MD5 digests (checksums) of each of the data files are written to a
corresponding C<.md5> file, and both the data and digests are uploaded
to the ENA FTP server.

[The MD5 digests are also added to a "manifest file" called
C<manifest.all> in the same directory as the data files (it is assumed
that all data files resides in the one and same directory).  This
manifest file is currently not used.]

Options used: B<--config>, B<--profile>, and B<--net> (or
B<--nonet>). In addition, the common options B<--quiet> (or
B<--noquiet>) and B<--debug> (or B<--nodebug>) are used.


=item B<--config> or B<-c>

A configuration file that contains the information neccesary to make a
submission to the ENA (your "Webin" username and password).

Example configuration file:

    [default]
    username    =   "my_username"
    password    =   "my_PASSword$$$"

    [otherperson]
    username    =   "their_username"
    password    =   "their_PaSSW0rd@#"

Use the B<--profile> option to pick any non-default profile.  All
configuration settings not present in a specifit profile section will be
copied from the C<default> section.

A file called C<submit.conf> will be used if this option is not used.

The following are the configuration setting that needs to be specified:

=over 16

=item B<username>

ENA Webin account username.

=item B<password>

ENA Webin account password.

=back

=item B<--debug>

Display various debug output.  This is the default during development.

=item B<--help> or B<-h>

Display full help text, and exit.

=item B<--net>

Make a connection to ENA over the network.  With B<--nonet>, no network
connection to ENA will be made.  The default is to make a network
connection.

=item B<--profile> or B<-p>

Used to pick a specific profile section from the configuration file (see
B<--config>). For example, to use the username and password for the
C<[myname]> section, use C<B<--profile>=myname> or C<B<-p> myname>.

The profile called C<default> will be used if this option is not used.

=item B<--quiet>

Be quiet. Only error messages will be displayed.  This option may be
negated using B<--noquiet> (which is the default).

=item B<--test> or B<-t>

When submitting XML using the B<submission> action, submit only to the
ENA test server, not to the ENA production server.  This option is
enabled by default and my be negated using the B<--notest> option.

=back

=cut