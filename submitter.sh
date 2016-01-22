#!/bin/sh -ex

# This is a wrapper around the submit.pl Perl script.
#
# The script performs the following steps:
#
#   1.  Submission of a study and sample XML to the ENA servers.
#
#   2.  Receives the identifiers assigned by the ENA to the submitted
#       study and sample.
#   3.  Updates the given flat file with the sample identifier.
#
#   4.  Compresses the flat file.
#
#   5.  Submits the compressed flat file, together with its MD5 digest,
#       to the ENA servers.
#
#   6.  Generates the analysis XML.
#
#   7.  Submits the generated analysis XML to the ENA servers.

# Current restrictions and assumptions:
#
#   1.  All input files are located in the one and same directory.
#
#   2.  All XML input files have obvious names, i.e. the sample XML file
#       is called "sample.xml" etc.
#
#   3.  The data flat file is also located in this same directory, and
#       its name is given on the command line to this script.

flatfile="$1"

if [ ! -f "$flatfile" ]; then
    echo "Can not find flat file '$flatfile'!"
    exit 1
fi

datadir="$( dirname "$flatfile" )"
