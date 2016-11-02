#!/bin/sh

# Please check the following URL for what the most current version is:
# http://central.maven.org/maven2/uk/ac/ebi/ena/sequence/embl-api-validator/
current_version="1.1.146"

# This script updates the JAR file "embl-validator.jar" in the
# current directory.  The JAR file is ENA's flat-file validator for
# EMBL-formatted files.  It program is frequently updated and the
# ENA says "This validator code is still developing quite fast, so
# check back every few weeks to see if a newer file is available"
# (http://www.ebi.ac.uk/ena/software/flat-file-validator).

# The JAR file is fetched using 'curl', but only if the JAR file is
# missing from the current directory, or if it's outdated.

curl -z embl-validator.jar -o embl-validator.jar \
    "http://central.maven.org/maven2/uk/ac/ebi/ena/sequence/embl-api-validator/$current_version/embl-api-validator-$current_version.jar"
