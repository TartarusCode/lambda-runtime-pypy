SHELL=/bin/bash

PYPY_VERSIONS := pypy3.11-v7.3.21
LOCAL_TEMPLATE := examples/sam/template.local.example.yaml
LOCAL_EVENT := examples/sam/events/hello.json
LOCAL_LAYER_DIR := .local-layer
LOCAL_BUILD_TEMPLATE := .aws-sam/build/template.yaml
LOCAL_AWS_ENV := env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_SESSION_TOKEN=test AWS_REGION=us-east-1

all: clean build upload publish

BUILD_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),$(pypy).zip)
UPLOAD_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),upload-$(pypy))
PUBLISH_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),publish-$(pypy))
PUBLICIZE_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),publicize-$(pypy))
LATEST_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),latest-$(pypy))
AUDIT_TARGETS := $(foreach pypy,$(PYPY_VERSIONS),audit-$(pypy))

.PHONY: all clean build upload publish publicize latest audit local-layer local-build local-invoke $(UPLOAD_TARGETS) $(PUBLISH_TARGETS) $(PUBLICIZE_TARGETS) $(LATEST_TARGETS) $(AUDIT_TARGETS) shell

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

local-layer: $(firstword $(BUILD_TARGETS))
	rm -rf "$(LOCAL_LAYER_DIR)"
	mkdir -p "$(LOCAL_LAYER_DIR)"
	unzip -q "$(firstword $(BUILD_TARGETS))" -d "$(LOCAL_LAYER_DIR)"

local-build: local-layer
	sam build --template-file "$(LOCAL_TEMPLATE)" --use-container

local-invoke: local-build
	$(LOCAL_AWS_ENV) sam local invoke HelloFunction --template-file "$(LOCAL_BUILD_TEMPLATE)" --event "$(LOCAL_EVENT)"

clean:
	rm -rf layer $(BUILD_TARGETS)

shell:
	docker run --rm -v "${PWD}":/opt public.ecr.aws/sam/build-provided.al2023 sh
