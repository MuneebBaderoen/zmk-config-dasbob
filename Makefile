.PHONY: build all

TARGETS_FILE=build.yml

all: build

build:
	@echo "Reading targets from $(TARGETS_FILE)..."
	@TARGETS=$$(yq eval '.include[] | "\(.board) \(.shield) \(.snippet // "")"' $(TARGETS_FILE)); \
	for t in $$TARGETS; do \
		set -- $$t; \
		BOARD=$$1; SHIELD=$$2; SNIPPET=$$3; \
		echo "Building board=$$BOARD shield=$$SHIELD snippet=$$SNIPPET"; \
		docker compose run --rm --build zmk-build -- /zmk-bin/build.sh \
			--board $$BOARD --shield $$SHIELD \
			$$( [ -n "$$SNIPPET" ] && echo "--snippet $$SNIPPET" ); \
	done
