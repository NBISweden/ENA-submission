#!/bin/ksh -e

xmltidy_cmd="$( which tidy || cat )"
if [[ "$xmltidy_cmd" != "cat" ]]; then
    xmltidy_cmd="$xmltidy_cmd -quiet -indent -xml"
fi

#=======================================================================
# This script follows the tutorial available here:
# http://www.ebi.ac.uk/ena/support/read-submission-rest-tutorial
#
# It makes use of a file called "SRA.zip" which is available from here:
# http://www.ebi.ac.uk/sites/ebi.ac.uk/files/groups/ena/documents/SRA.zip
#=======================================================================

# The "SRA.zip" archive was unpacked here:
SRA_archive="${HOME}/Work/Development/code/scripts/ENA/submission-tutorial/SRA"

# The unpacked SRA archive contains a number of subfolders, each with
# a BAM file and a number of XML files.  Each student at the tutorial
# was (apparently) given a piece of paper with the name of "their"
# subfolder.  The $token_name contains the name of the subfolder that
# this script will use.
token_name="archery"

token_dir="$( perl -MFile::Spec \
    -e "print File::Spec->abs2rel('${SRA_archive}/${token_name}')" )"

# Get ENA Webin user details.  This file should define the two shell
# variables "$webin_user" and "$webin_pass".
source ./submit.conf

#-----------------------------------------------------------------------
# Part 1. Create a new submission using REST API
#-----------------------------------------------------------------------

# Step 1: Calculate the MD5 checksum for the BAM file

## The Makefile target "bam-md5" is a prerequisite for the "bam-upload"
## target invoked in the next step, so we do not need to call this
## explicitly here.

## make -f submit.mk bam-md5 bamfile="${token_name}/FILES/${token_name}.bam"

# Step 2: Upload the BAM file and MD5 checksum file using ftp

## make -f submit.mk bam-upload \
##    bamfile="${token_dir}/FILES/${token_name}.bam" \
##    webin_user="${webin_user}" \
##    webin_pass="${webin_pass}"

# Step 3: Submit the metadata and data files using the ENA REST API

make -f submit.mk xml-validate \
    bamfile="${token_dir}/FILES/${token_name}.bam" \
    submission_xml="${token_dir}/XML/simple/submission.xml" \
    webin_user="${webin_user}" \
    webin_pass="${webin_pass}"

# Test for successful validation

if ! grep -q 'RECEIPT.*success="true"' \
    "${token_dir}/XML/simple/submission-receipt.xml"
then
    echo "!!> Validation of sumbission XML failed."
    echo "!!> See '${token_dir}/XML/simple/submission-receipt.xml'"
    echo "!!> Fix this and remove '${token_dir}/XML/simple/submission.xml.validate-done'"
    $xmltidy_cmd "${token_dir}/XML/simple/submission-receipt.xml"
    exit 1
fi
