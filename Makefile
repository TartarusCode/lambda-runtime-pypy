SHELL=/bin/bash

PYPY_VERSIONS := pypy3.11-v7.3.21

all: clean build upload publish

BUILD_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),$(pypy).zip)
UPLOAD_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),upload-$(pypy))
PUBLISH_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),publish-$(pypy))
PUBLICIZE_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),publicize-$(pypy))
LATEST_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),latest-$(pypy))
AUDIT_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),audit-$(pypy))

.PHONY: all clean build upload publish publicize latest audit $(UPLOAD_TARGETS) $(PUBLISH_TARGETS) $(PUBLICIZE_TARGETS) $(LATEST_TARGETS) $(AUDIT_TARGETS) shell

$(BUILD_TARGETS): %.zip:
	PYPY_VERSION="$*" ./build.sh

$(UPLOAD_TARGETS): upload-%: %.zip
	PYPY_VERSION="$*" ./upload.sh

$(PUBLISH_TARGETS): publish-%: %.zip
	PYPY_VERSION="$*" ./publish.sh

$(PUBLICIZE_TARGETS): publicize-%: %.zip
	PYPY_VERSION="$*" ./publish.sh -p

$(LATEST_TARGETS): latest-%:
	PYPY_VERSION="$*" ./latest-layer-arns.sh

$(AUDIT_TARGETS): audit-%: %.zip
	PYPY_VERSION="$*" ./audit.sh

build: $(BUILD_TARGETS)

upload: $(UPLOAD_TARGETS)

publish: $(PUBLISH_TARGETS)

publicize: $(PUBLICIZE_TARGETS)

latest: $(LATEST_TARGETS)

audit: $(AUDIT_TARGETS)

clean:
	rm -rf layer $(BUILD_TARGETS)

shell:
	docker run --rm -v "${PWD}":/opt public.ecr.aws/sam/build-provided.al2023 sh
