md5_cmd := $(shell which md5sum || which md5)

.PHONY: \
	bam-md5 \
	bam-upload

%.md5: %
	@echo "==> Calculating MD5 checksum for $<"
	${md5_cmd} $< >$@

%.uploaded-done: %
	@echo "==> Uploading $< to ENA Webin"
	cd $(shell dirname $<) && \
	ftp -u ftp://${webin_user}:${webin_pass}@webin.ebi.ac.uk/ \
	  $(shell basename $<) && \
	touch $(shell basename $@)

bam-md5: ${bamfile}.md5

bam-upload: bam-md5 ${bamfile}.uploaded-done ${bamfile}.md5.uploaded-done
