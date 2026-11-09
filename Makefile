
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

build-main: 
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_main_left --pristine
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_main_right --pristine
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield settings_reset --pristine

build-dongle: clean
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_dongle_central --pristine
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_dongle_left --pristine
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_dongle_right --pristine
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield settings_reset --pristine

build: clean
	docker-compose run --rm zmk-build /zmk-bin/build.sh --board nice_nano_v2 --shield dasbob_main_left --pristine

test-sticky-mod-layer:
	docker-compose run --rm zmk-build /zmk-bin/test-module.sh /repo/zmk-modules/sticky-mod-layer/tests/sticky-mod-layer

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

flash-settings-reset:
	./zmk-bin/flash.sh --uf2 ./zmk-out/settings_reset_nice_nano_v2.uf2

include keymap-drawer/render.mk

KEYMAP_DRAWER = uv tool run --from keymap-drawer==0.23.0 keymap -c keymap-drawer/config.yaml
VISIBLE_LAYERS = $(filter-out $(HIDE_LAYERS),$(DRAW_LAYERS))

.PHONY: render-keymap
render-keymap:
	@test -n "$(strip $(VISIBLE_LAYERS))" || (echo "No visible layers: check DRAW_LAYERS and HIDE_LAYERS in keymap-drawer/render.mk" >&2; exit 1)
	mkdir -p zmk-out
	$(KEYMAP_DRAWER) parse -z zmk-config/dasbob.keymap -o zmk-out/dasbob.yaml
	$(KEYMAP_DRAWER) draw zmk-out/dasbob.yaml --ortho-layout '{split: true, rows: 3, columns: 5, thumbs: 3}' --select-layers $(VISIBLE_LAYERS) -o zmk-out/dasbob.svg.tmp
	mv zmk-out/dasbob.svg.tmp zmk-out/dasbob.svg
