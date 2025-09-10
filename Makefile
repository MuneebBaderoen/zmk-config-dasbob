.PHONY: build all

TARGETS_FILE=build.yml

all: build-all

init:
	docker-compose run --rm zmk-build /zmk-bin/init.sh

update:
	docker-compose run --rm zmk-build /zmk-bin/update.sh

clean:
	docker-compose run --rm zmk-build /zmk-bin/clean.sh

build-all: clean
	docker-compose run --rm zmk-build /zmk-bin/build-all.sh

build: clean
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_dongle

flash:
	./zmk-bin/flash.sh --uf2 ./zmk-out/dasbob_dongle_nice_nano_v2.uf2
