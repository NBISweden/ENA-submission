#!/usr/bin/env perl

use strict;
use warnings;

use XML::Simple;
use Getopt::Long;
use Pod::Usage;

my $opt_bam;
my $opt_action;
my $opt_xmldir;
my $opt_submit = 0;

if ( !GetOptions( "bam|b=s"    => \$opt_bam,
                  "action|a=s" => \$opt_action,
                  "xmldir|x=s" => \$opt_xmldir,
                  "submit|s!"  => \$opt_submit ) )
{
    pod2usage( { -message => '!!> Failed to parse command line',
                 -verbose => 0,
                 -exitval => 1 } );
}

if ( !defined($opt_action) ||
     !defined($opt_xmldir) )
{
    pod2usage(
        {  -message => '!!> Missing --action, or --xmldir',
                 -verbose => 0,
                 -exitval => 1 } );
}
