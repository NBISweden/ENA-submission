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
# version, otherwise it tries to use sed to parse the meta data
# available.  If either of these approaches fail, the value of
# 'current_version' below is used.

current_version="1.1.150"

# Use XMLStarlet to get the latest available version number.

xmlstarlet="$( which xmlstarlet 2>/dev/null || which xml 2>/dev/null )"

curr_version=$( curl -s http://central.maven.org/maven2/uk/ac/ebi/ena/sequence/embl-api-validator/maven-metadata.xml | "$xmlstarlet" sel -t -v '//latest' -nl )

if [ "x$curr_version" != "x" ]; then
    current_version="$curr_version"
    printf "ENA says current version of validator is '%s'\n" "$current_version"
    echo "Fetching/updating it as needed..."
else
    echo "Failed in getting current version number of validator from ENA."
    printf "Attempting to fetch version '%s'\n" "$current_version"
fi

if [ -f embl-validator.jar ]; then
    # Updating existing validator JAR file.
    curl -z embl-validator.jar -o embl-validator.jar \
        "http://central.maven.org/maven2/uk/ac/ebi/ena/sequence/embl-api-validator/$current_version/embl-api-validator-$current_version.jar"
else
    # Validator JAR file not present, fetching it.
    curl -o embl-validator.jar \
        "http://central.maven.org/maven2/uk/ac/ebi/ena/sequence/embl-api-validator/$current_version/embl-api-validator-$current_version.jar"
fi
