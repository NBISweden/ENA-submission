#!/usr/bin/env perl

# Please format the code using 'perltidy'.  A perltidy configuration
# file is available in this directory (it will be picked up and used
# automatically).

use strict;
use warnings;

use Carp;
use Config::Simple;
use Data::Dumper;    # for debugging only
use Digest::MD5;
use File::Basename;
use File::Spec::Functions qw( splitpath catfile );
use Getopt::Long;
use HTTP::Request::Common qw( POST );
use IO::File;
use LWP::UserAgent;
use Net::FTP;
use POSIX qw( strftime );
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
my $opt_config  = 'submit.conf';
my $opt_debug   = 0;
my $opt_help    = 0;
my $opt_net     = 1;
my $opt_out     = 'submission.xml';
my $opt_profile = 'default';
my $opt_quiet   = 0;
my $opt_test    = 1;
my $opt_upload  = 0;
my @opt_action;

if ( !GetOptions( "action|a=s"  => \@opt_action,
                  "config|c=s"  => \$opt_config,
                  "debug!"      => \$opt_debug,
                  "help|h!"     => \$opt_help,
                  "net!"        => \$opt_net,
                  "out|o=s"     => \$opt_out,
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

if ($opt_upload) {
    do_data_upload(@ARGV);
}
# The remaining actions are "XML actions":
#
#   ADD:        "Add an object to the archive."
#
#   MODIFY:     "Modify an object in the archive."
#
#   CANCEL:     "Cancel an object which has not been made public.
#               Cancelled objects will not be made public."  NOT
#               CURRENTLY SUPPORTED!
#
#   SUPPRESS:   "Suppress an object which has been made public.
#               Suppressed data will remain accessible by accession
#               number."  NOT CURRENTLY SUPPORTED!
#
#   HOLD:       "Make the object public only when the hold date
#                expires."
#
#   RELEASE:    "The object will be released immediately to public."
#               NOT CURRENTLY SUPPORTED!
#
#   PROTECT:    "This action is required for data submitted to European
#               Genome-Phenome Archive (EGA)."  NOT CURRENTLY SUPPORTED!
#
#   VALIDATE:   "Validates the submitted XMLs without actually
#               submitting them."  NOT CURRENTLY SUPPORTED!
#
# (ftp://ftp.sra.ebi.ac.uk/meta/xsd/latest/SRA.submission.xsd)
#
elsif ( scalar(@opt_action) > 0 ) {
    do_submission(@ARGV);
}
else {
    pod2usage( { -message => '!!> Need either --upload or ' .
                   'at least one --action',
                 -verbose => 0,
                 -exitval => 1 } );
}

# END OF MAIN SCRIPT.
# Subroutines follow.

sub do_data_upload
{
    my (@data_files) = @_;

    my $error = 0;
    foreach my $data_file (@data_files) {
        if ( !-f $data_file ) {
            printf( STDERR
                      "!!> ERROR: The data file '%s' was not found\n",
                    $data_file );
            $error = 1;
        }
    }
    if ($error) { exit(1) }

    #
    # Step 1: Calculate MD5 digest for each of the data files.
    #

    foreach my $data_file (@data_files) {
        my $ctx = Digest::MD5->new();

        my $bam_in = IO::File->new( $data_file, "r" );
        $ctx->addfile($bam_in);
        $bam_in->close();

        my $md5_file = sprintf( "%s.md5", $data_file );
        my $md5_out = IO::File->new( $md5_file, "w" );

        $md5_out->print( $ctx->hexdigest(), "\n" );
        $md5_out->close();

        if ( !$opt_quiet ) {
            printf( STDERR "==> Wrote MD5 digest to '%s'\n",
                    $md5_file );
        }
    }

    if ( !$opt_net ) {
        return;
    }

    #
    # Step 3: Upload the data file and the MD5 digest to the ENA FTP
    # server.
    #

    my ( $username, $password ) =
      get_config( $opt_profile, 'username', 'password' );

    my $ftp = Net::FTP->new( $ENA_WEBIN_FTP, Debug => $opt_debug );

    $ftp->login( $username, $password )
      or
      croak( sprintf( "Can not 'login' on ENA FTP server: %s",
                      $ftp->message() ) );

    foreach my $data_file (@data_files) {
        $ftp->put($data_file)
          or
          croak(
             sprintf( "Can not 'put' data file onto ENA FTP server: %s",
                      $ftp->message() ) );

        $ftp->put( sprintf( "%s.md5", $data_file ) )
          or
          croak( sprintf( "Can not 'put' data file MD5 digest " .
                            "onto ENA FTP server: %s",
                          $ftp->message() ) );
    }

    $ftp->quit();

    if ( !$opt_quiet ) {
        print( STDERR "==> Submitted data file(s) and MD5 digest(s) " .
               "to ENA FTP server\n" );
    }
} ## end sub do_data_upload

sub do_submission
{
    my (@xml_files) = @_;

    #
    # Step 1: Collect all file names from the end of the command line.
    #

    my %xml_file;

    foreach my $file (@xml_files) {
        my $file_basename = basename($file);
        $xml_file{$file_basename}{'file'} = $file;
    }

    my %actions;
    foreach my $action_with_parameter (@opt_action) {
        my ( $action, $parameter ) =
          split( /=/, $action_with_parameter );
        $actions{ uc($action) } = $parameter;
    }

    # Check actions against currently supported actions.
    my $action_error = 0;
    foreach my $action ( keys(%actions) ) {
        if ( $action ne 'ADD' &&
             $action ne 'MODIFY' &&
             $action ne 'HOLD' )
        {
            printf( STDERR "!!> Unsupported action: %s\n", $action );
            $action_error = 1;
        }
    }
    if ($action_error) { exit 1 }

    if ( !exists( $actions{'HOLD'} ) ) {
        if ( !exists( $actions{'RELEASE'} ) &&
             !exists( $actions{'CANCEL'} ) &&
             !exists( $actions{'MODIFY'} ) &&
             !exists( $actions{'SUPPRESS'} ) )
        {
            my ( $year, $month, $day ) =
              ( gmtime( time() ) )[ 5, 4, 3 ];
            # Set HOLD date to two years into the future.
            $actions{'HOLD'} =
              sprintf( "%4d-%02d-%02dZ",
                       $year + 1902,
                       $month + 1, $day );
        }
    }

    ##print Dumper( \%actions );    # DEBUG

    my %schema_file_map;

    my ( $username, $password ) =
      get_config( $opt_profile, 'username', 'password' );

    my $submission_alias = sprintf( "%s_%s",
                                    $username,
                                    strftime(
                                            "%Y%m%d:%H%M%S", localtime()
                                    ) );

    ##printf( "submission_alias = %s\n", $submission_alias );    # DEBUG

    foreach my $xml_file (@xml_files) {
        # Read each XML file to figure out what type of XML it contains.
        # Weed out any submission XML file.

        my $xml =
          XMLin( $xml_file,
                 ForceArray => undef,
                 KeyAttr    => '' );

        ##die Dumper($xml);    # DEBUG

        my @toplevel;
        foreach my $toplevel ( keys( %{$xml} ) ) {
            if ( $toplevel !~ /xsi|xmlns/ ) {
                push( @toplevel, $toplevel );
            }
        }

        ##print Dumper( \@toplevel );    # DEBUG

        if ( scalar(@toplevel) == 1 && lc( $toplevel[0] ) ne 'actions' )
        {
            $schema_file_map{ $toplevel[0] } = {
                                       'fullname' => $xml_file,
                                       'basename' => basename($xml_file)
            };
        }
        elsif ( !$opt_quiet ) {
            printf( STDERR "!!> WARNING: Skipping XML file '%s'\n",
                    $xml_file );
        }
    } ## end foreach my $xml_file (@xml_files)

    ##die Dumper( \%actions, \%schema_file_map );    # DEBUG

    my $xml_out = IO::File->new( $opt_out, 'w' );

    # I'm writing the XML out directly using print-statements, because I
    # couldn't get XML::Simple to do it correctly for me.

    my ($center_name) = get_config($opt_profile, 'center_name');

    $xml_out->printf( "<SUBMISSION alias='%s' center_name='%s'>\n",
                      $submission_alias, $center_name );
    $xml_out->print("<ACTIONS>\n");
    foreach my $action ( keys(%actions) ) {
        if ( $action ne 'HOLD' ) {
            foreach my $schema ( keys(%schema_file_map) ) {
                $xml_out->printf(
                                "<ACTION>" .
                                  "<%s source=\"%s\" schema=\"%s\" />" .
                                  "</ACTION>\n",
                                $action,
                                $schema_file_map{$schema}{'basename'},
                                lc($schema) );
            }
        }
    }
    if ( exists( $actions{'HOLD'} ) ) {
        $xml_out->printf(
                     "<ACTION><HOLD HoldUntilDate=\"%s\" /></ACTION>\n",
                     $actions{'HOLD'} );
    }
    $xml_out->print("</ACTIONS>\n");
    $xml_out->print("</SUBMISSION>\n");

    $xml_out->close();

    if ( !$opt_net ) { return }

    #
    # Step 3: Make submission
    #

    $ENV{'HTTPS_DEBUG'} = $opt_debug;

    # To get around "certificate verify failed" (error 500)
    #
    $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
    IO::Socket::SSL::set_defaults( SSL_verifycn_scheme => 'www',
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

    $url =
      sprintf( "%s?auth=ENA%%20%s%%20%s", $url, $username, $password );

    my $request = POST(
        $url,
        Content_Type => 'form-data',
        Content      => [
            'SUBMISSION' => [$opt_out],
            map {
                $_ => [ $schema_file_map{$_}{'fullname'} ]
              }
              keys(%schema_file_map) ] );

    ##print Dumper($request);    # DEBUG

    my $response = $ua->simple_request($request);

    ##print Dumper($response);    # DEBUG

    if ( !$response->is_success() ) {
        printf( STDERR "!!> ERROR: HTTPS request failed: %s\n",
                $response->as_string() );
        exit(1);
    }
    elsif ( !$opt_quiet ) {
        print( STDERR "==> HTTPS request successful\n" );
    }

    my $response_xml = XMLin( $response->decoded_content(),
                              ForceArray => undef,
                              KeyAttr    => undef );

    ##print Dumper($response_xml);    # DEBUG

    if ( !$opt_quiet ) {
        if ( ref( $response_xml->{'MESSAGES'}{'INFO'} ) eq 'ARRAY' ) {
            foreach
              my $reply ( @{ $response_xml->{'MESSAGES'}{'INFO'} } )
            {
                printf( STDERR "==> ENA says: %s\n", $reply );
            }
        }
        else {
            printf( STDERR "==> ENA says: %s\n",
                    $response_xml->{'MESSAGES'}{'INFO'} );
        }
        print( STDERR "\n" );
    }

    if ( $response_xml->{'success'} eq 'false' ) {
        if ( ref( $response_xml->{'MESSAGES'}{'ERROR'} ) eq 'ARRAY' ) {
            my $error_count = 0;
            foreach my $error_message (
                             @{ $response_xml->{'MESSAGES'}{'ERROR'} } )
            {
                printf( STDERR "!!> ERROR #%d: Submission failed: %s\n",
                        ++$error_count, $error_message );
            }
        }
        else {
            printf( STDERR "!!> ERROR: Submission failed: %s\n",
                    $response_xml->{'MESSAGES'}{'ERROR'} );
        }
        exit(1);
    }
    else {
        if ( !$opt_quiet ) {
            print( STDERR "==> Success\n" );
        }
    }

    foreach my $toplevel ( keys( %{$response_xml} ) ) {
        my @things;

        if ( ref( $response_xml->{$toplevel} ) eq 'HASH' &&
             exists( $response_xml->{$toplevel}{'accession'} ) )
        {
            @things = ( $response_xml->{$toplevel} );
        }
        elsif ( ref( $response_xml->{$toplevel} ) eq 'ARRAY' &&
                exists( $response_xml->{$toplevel}[0]{'accession'} ) )
        {
            @things = @{ $response_xml->{$toplevel} };
        }

        foreach my $thing (@things) {
            printf( "%s\t%s\t%s",
                    lc($toplevel), $thing->{'alias'},
                    $thing->{'accession'} );

            if ( exists( $thing->{'EXT_ID'} ) ) {
                printf( "\t%s", $thing->{'EXT_ID'}{'accession'} );
            }

            print("\n");
        }
    } ## end foreach my $toplevel ( keys...)

} ## end sub do_submission

sub get_config
{
    my ( $profile, @settings ) = @_;

    #
    # This routine is called to get settings from the configuration
    # file.  Any requested settings not found in the specified profile
    # will be filled in with values taken from the default profile.
    # Missing settings will cause an error.
    #
    # Call for getting specific values:
    #   ( $setting1, $setting2 ) =
    #     get_config( $profile, 'setting1', 'setting2' );
    #
    # Call to get all values of a block:
    #   %settings = %{ get_config('profile') };

    my @values;
    my %default_values;

    if ( $profile ne 'default' ) {
        %default_values = %{ get_config('default') };
    }

    ##print Dumper( \%default_values );    # DEBUG

    if ( !-f $opt_config ) {
        printf( "!!> ERROR: The specified configuration file '%s' " .
                  "was not found\n",
                $opt_config );
        exit(1);
    }

    my $config = Config::Simple->new($opt_config);

    my $profile_block = $config->param( -block => $profile );

    ##print Dumper($profile_block);    # DEBUG

    if ( scalar( keys( %{$profile_block} ) ) == 0 ) {
        printf( "!!> ERROR: Configuration profile '%s' " .
                  "is missing in '%s'\n",
                $profile, $opt_config );
        exit(1);
    }

    if ( scalar(@settings) == 0 ) {
        return $profile_block;
    }

    for ( my $si = 0; $si < scalar(@settings); ++$si ) {
        if ( exists( $profile_block->{ $settings[$si] } ) ) {
            $values[$si] = $profile_block->{ $settings[$si] };
        }
        else {
            $values[$si] = $default_values{ $settings[$si] };
        }
    }

    my $error = 0;
    for ( my $si = 0; $si < scalar(@settings); ++$si ) {
        if ( !defined( $values[$si] ) ) {
            printf( "!!> ERROR: Unable to find setting '%s' " .
                      "for profile '%s' in '%s'\n",
                    $settings[$si], $profile, $opt_config );
            $error = 1;
        }
    }
    if ($error) { exit(1) }

    ##print Dumper(\@values);

    return @values;
} ## end sub get_config

__END__

=head1 NAME

submit.pl - A script that handles submission of data to ENA at EBI.

=head1 SYNOPSIS

There are two main ways to invoke this script.  One is used for
uploading data files, and the other is used for submitting XML.  The
script will determine which of these is requested by looking for the
B<--upload> option on the command line (used for uploading data).

Run the script with B<--help> to get more verbose help with options and
general configuration.

=head2 Uploading data to ENA

    ./submit.pl [ --nodebug ] [ --quiet ] [ --nonet ] \
        --upload DATA_FILENAME [ DATA_FILENAME ... ]

=head2 Submitting XML to ENA

    ./submit.pl [ --nodebug ] [ --quiet ] [ --nonet ] \
        --action ACTION[=PARAMETER] \
        [ --action ACTION[=PARAMETER] ... ] \
        [ XML_FILENAME [ XML_FILENAME ... ] ]

=head1 OPTIONS

=over 8

=item B<--action> or B<-a>

The action to take when submitting XML files to ENA.  This option may
occur several times on the command line, but usually only once.  You may
want to use, e.g.,

    --action ADD --action HOLD=YYYY-MM-DD

... to submit (ADD) and hold data until a particular date (see the
B<HOLD> action below).

The following are the actions available, with descriptions found in
L<ftp://ftp.sra.ebi.ac.uk/meta/xsd/latest/SRA.submission.xsd>.

=over 12

=item B<ADD>

"Add an object to the archive."

=item B<MODIFY>

"Modify an object in the archive."

=item B<CANCEL>

"Cancel an object which has not been made public.  Cancelled objects
will not be made public."

=item B<SUPPRESS>

"Suppress an object which has been made public.  Suppressed data will
remain accessible by accession number."

=item B<HOLD>

"Make the object public only when the hold date expires."

NOTE: THIS SCRIPT WILL AUTOMATICALLY ADD A B<HOLD> ACTION TO ALL
SUBMISSIONS, WITH A DATE SET TWO YEARS INTO THE FUTURE.  This is the
same as the default behaviour when B<HOLD> is not used, but we're making
it explicit here.

To release a data set for publication, use the B<RELEASE> action.

=item B<RELEASE>

"The object will be released immediately to public."

=item B<PROTECT>

"This action is required for data submitted to European Genome-Phenome
Archive (EGA)."

=item B<VALIDATE>

"Validates the submitted XMLs without actually submitting them."

=back

=item B<--upload>

Upload one or several data files to ENA.

Each data file is a file in BAM or CRAM format or in whatever other file
format ENA accepts.  No check is made of the data file format or its
integrity by this script.

The data files are specified by adding their path to the end of the
command line.

The MD5 digests (checksums) of each of the data files are written to a
corresponding C<.md5> file, and both the data and digests are uploaded
to the ENA FTP server.

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

Use the B<--profile> option to pick any non-default profile.  Any
configuration settings not present in a specific profile section will be
copied from the C<default> section.

A file called C<submit.conf> will be used if this option is not used.

The following are the configuration setting that needs to be specified:

=over 16

=item B<username>

ENA Webin account username (or email address).

=item B<password>

ENA Webin account password.

=back

=item B<--debug>

Display various debug output.

=item B<--help> or B<-h>

Display full help text, and exit.

=item B<--net>

Make a connection to ENA over the network.  With B<--nonet>, no network
connection to ENA will be made.  The default is to make a network
connection.

=item B<--out> or B<-o>

Specify the file name to use for the created submission XML.  The
default file name is C<submission.xml> (in the current working
directory).

=item B<--profile> or B<-p>

Used to pick a specific profile section from the configuration file (see
B<--config>). For example, to use the username and password for the
C<[myname]> section, use C<B<--profile>=myname> or C<B<-p> myname>.

The profile called C<default> will be used if this option is not used.

=item B<--quiet>

Be quiet. Only error messages (fatal) and warning messages (non-fatal)
will be displayed.  This option may be negated using B<--noquiet> (which
is the default).

=item B<--test> or B<-t>

When submitting XML, submit only to the ENA test server, not to the ENA
production server.  This option is enabled by default and my be negated
using the B<--notest> option.

=back

=cut
