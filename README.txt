The two scripts available in this folder, submit.pl and submitter.pl,
were written to make it easier to submit data to the European Nucleotide
Archive (ENA) at the EMBL-EBI outside of Cambridge, UK.


submit.pl
========================================================================
This script both uploads data files and submits various XML files to the
ENA.  It has a lot of flags, please run it with the "--help" flag for a
full description.


submitter.pl
========================================================================
This script is designed to be easy to use and uses submit.pl to upload
a flat file provided by the user and the associated XML files, also
provided by the user.  It then creates a template analysis XML file that
may be filled in and submitted separately using the submit.pl script.

To invoke:

    $ ./submitter.pl mydata/flatfile.txt

Steps performed by script:

    1.  Submits the study and sample XML files to ENA.  It is assumed
        that these files are present in the data folder ("mydata" in the
        example above, but the folder may be called anything) and that
        they are named "study.xml" and "sample.xml".

    2.  Receives the locus tag identifiers assigned by the ENA.

    3.  Creates a new flat file with the locus tags recieved from the
        ENA replacing the old locus tags.  The new file will have the
        same name as the old file, but with a "submit-" prefix.

    4.  Compresses the new flat file using "gzip".

    7.  Uploads the newly compressed flat file to the ENA FTP server.

    6.  Generates a partially filled-out template for the analysis XML in
        the current directory.

The user is then expected to fill out the remainder of the analysis
file and to submit it manually to the ENA using the submit.pl script
(submitter.pl will suggest a command line to do this).
