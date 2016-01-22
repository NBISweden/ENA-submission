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
#   6.  Generates the analysis XML.
#
#   7.  Submits the generated analysis XML to the ENA servers.
