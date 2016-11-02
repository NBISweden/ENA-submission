#!/bin/sh

# This script updates the JAR file "embl-validator.jar" in the
# current directory.  The JAR file is ENA's flat-file validator for
# EMBL-formatted files.  It program is frequently updated and the
# ENA says "This validator code is still developing quite fast, so
# check back every few weeks to see if a newer file is available"
# (http://www.ebi.ac.uk/ena/software/flat-file-validator), hence this
# script.

# The JAR file is fetched using 'curl', but only if the JAR file is
# missing from the current directory, or if it's outdated.

# If XMLStarlet is installed, the script is smart and get the latest
# version, otherwise it fetches the version corresponding to the value
# of 'current_version' below.

current_version="1.1.146"

if which -s xml; then
    # Use XMLStarlet to get the latest available version number.
    current_version=$( curl http://central.maven.org/maven2/uk/ac/ebi/ena/sequence/embl-api-validator/maven-metadata.xml | xml sel -t -v '//latest' -nl )
else
    # We don't have XMLStarlet installed, so use the hard-coded value.

    # Please check the following URL for what the most current version is:
    # http://central.maven.org/maven2/uk/ac/ebi/ena/sequence/embl-api-validator/

    true
fi

curl -z embl-validator.jar -o embl-validator.jar \
    "http://central.maven.org/maven2/uk/ac/ebi/ena/sequence/embl-api-validator/$current_version/embl-api-validator-$current_version.jar"
