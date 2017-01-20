NOTE: This is a work in progress.
NOTE: While in development, the script only knows about the ENA test server.

TODO: Implement replacing locus tags in data file by biosample IDs.
TODO: Construct analysis XML template.
TODO: When viewing the state (XML), make it look pretty.
TODO: Enable submission of runs and other XML types.

========================================================================

submit
------------------------------------------------------------------------

The submit script is a menu-driven Bash shell script that will allow you
to submit XML files and data files to the European Nucleotide Archive
(ENA) at EMBL-EBI.

To use it:

    $ ./submit directory

or

    $ ./submit directory/datafile

In the first form, no datafile may be uploaded to the ENA FTP server,
but XMLs may still be submitted.

When started, the script will present you with a main menu, at which
you may choose to

    1) Exit
    2) Submit an XML file
    3) Upload a data file
    4) Display current state of submissions

The "Submit an XML file" option will take you to the submit menu.  The
contents of this menu will depend on the files present in the directory
given on the command line.

    1) Go back to the main menu
    2) Submit "study.xml" (STUDY_SET)
    3) Submit "sample.xml" (SAMPLE_SET)
    4) Submit "analysis.xml" (ANALYSIS_SET)

Choosing one of the submit options will perform the submission of that
file to the ENA, and the response will be parsed and stored in the
"state XML" (a special XML file that contains the state of submissions
for the particular directory given on the command line).

To view the state of submissions, pick "Display current state of
submissions" from the main menu.  Currently, it will simply display the
contents of the file "state.xml" in the data directory:

(an initial state, with no attempted submissions)

    Current state:
    <?xml version="1.0"?>
    <state created="2017-01-20 10:20:55">
      <files>
        <file name="study.xml"/>
        <file name="sample.xml"/>
        <file name="analysis.xml"/>
      </files>
    </state>

(the state after successfully having submitted the "sample.xml" file)

    Current state:
    <?xml version="1.0"?>
    <state created="2017-01-20 10:20:55">
      <files>
        <file name="study.xml">
          <submission action="ADD" success="true" accession="ERA789934">Webin-40692 2017-01-20 10:22:08<accession ena="ERP021100" ext="PRJEB19110">Fake test study for testing programatic submissions</accession></submission>
        </file>
        <file name="sample.xml"/>
        <file name="analysis.xml"/>
      </files>
    </state>


update_embl-validator.sh
------------------------------------------------------------------------

The ENA provides a validation tool for validating the contents of EMBL
flat files.  The update_embl-validator.sh script downloads this tool (or
updates an existing version of the tool).  More info about the validator
may be found at http://www.ebi.ac.uk/ena/software/flat-file-validator

The validator needs to be run separately.

You run the validator like this:

    $ java -jar embl-validator.jar mydata.embl

... or, as the ENA suggests:

    $ java -classpath embl-validator.jar uk.ac.ebi.client.EnaValidator \
        -r mydata.embl

The validator takes a bit of time to run, and upon completion creates a
set of report text files that hopefully will help you modify and correct
any possible errors in your data before submitting it to the ENA:

    VAL_ERROR.txt
    VAL_FIXES.txt
    VAL_INFO.txt
    VAL_REPORTS.txt
    VAL_SUMMARY.txt

