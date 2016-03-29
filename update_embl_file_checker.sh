#!/bin/sh

# This script updates the JAR file "embl-client.jar" in the current
# directory.  The JAR file is ENA's flat-file validator for
# EMBL-formatted files.  It program is frequently updated and the
# ENA says "This validator code is still developing quite fast, so
# check back every few weeks to see if a newer file is available"
# (http://www.ebi.ac.uk/ena/software/flat-file-validator).  Hence this
# script to fetch the latest version of the code.

# The JAR file is fetched using 'curl', but only if the JAR file is
# missing from the current directory, or if it's outdated.

curl -z embl-client.jar -o embl-client.jar \
    ftp://ftp.ebi.ac.uk/pub/databases/ena/lib/embl-client.jar
