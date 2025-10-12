
sync:
	docker-compose run --rm zmk-build /zmk-bin/sync.sh

init: sync
	docker-compose run --rm zmk-build /zmk-bin/init.sh

update: sync
	docker-compose run --rm zmk-build /zmk-bin/update.sh

clean: sync
	docker-compose run --rm zmk-build /zmk-bin/clean.sh

build-all: clean
	docker-compose run --rm zmk-build /zmk-bin/build-all.sh 

build-main: clean
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_main_left --pristine
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_main_right --pristine

build-dongle: clean
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_dongle_central --pristine
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_dongle_left --pristine
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_dongle_right --pristine

build: clean
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_dongle_central --pristine

flash-main-left:
	./zmk-bin/flash.sh --uf2 ./zmk-out/dasbob_main_left_nice_nano_v2.uf2

flash-main-right:
	./zmk-bin/flash.sh --uf2 ./zmk-out/dasbob_main_right_nice_nano_v2.uf2

flash-dongle-central:
	./zmk-bin/flash.sh --uf2 ./zmk-out/dasbob_dongle_central_nice_nano_v2.uf2

flash-dongle-left:
	./zmk-bin/flash.sh --uf2 ./zmk-out/dasbob_dongle_left_nice_nano_v2.uf2

flash-dongle-right:
	./zmk-bin/flash.sh --uf2 ./zmk-out/dasbob_dongle_right_nice_nano_v2.uf2
