md5_cmd := $(shell which md5sum || which md5)

.PHONY: \
	bam-md5 \
	bam-upload

%.md5: %
	@echo "==> Calculating MD5 checksum for $<"
	${md5_cmd} $< >$@

%.upload-done: %
	@echo "==> Uploading $< to ENA Webin"
	cd $(shell dirname $<) && \
	ftp -u ftp://${webin_user}:${webin_pass}@webin.ebi.ac.uk/ \
	  $(shell basename $<) && \
	touch $(shell basename $@)

%.validate-done: %
	@echo "==> Validating submission XMLs"
	cd $(shell dirname $<) && \
	curl -k \
	  -F "SUBMISSION=@submission.xml" \
	  -F "STUDY=@study.xml" \
	  -F "SAMPLE=@sample.xml" \
	  -F "EXPERIMENT=@experiment.xml" \
	  -F "RUN=@run.xml" \
	  "https://www-test.ebi.ac.uk/ena/submit/drop-box/submit/?auth=ENA%20${webin_user}%20${webin_pass}" && \
	touch $(shell basename $@)

bam-md5: ${bamfile}.md5

bam-upload: bam-md5 ${bamfile}.upload-done ${bamfile}.md5.upload-done

xml-validate: bam-upload ${submission_xml}.validate-done
