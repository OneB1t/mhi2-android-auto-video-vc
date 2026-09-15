REGISTRY     := registry.gitlab.com
DOCKER_IMAGE := registry.gitlab.com/andrewleech/mibsdk:latest
PWD          := $(shell pwd)
TARGET       := libgal_hook.so
DMDT_FLUSH   := lib/libdmdt_flush.so
BUILD_ID     := $(shell git rev-parse --short=12 HEAD 2>/dev/null || echo release)
PACKAGE_DIR  := dist/sdcard_hook

.PHONY: all hook player package clean shell

all: hook

hook:
	@echo "==> Compiling native QNX $(TARGET) and $(DMDT_FLUSH) inside Docker SDK..."
	@mkdir -p $(dir $(DMDT_FLUSH))
	@docker run --rm -v $(PWD):/work -w /work $(DOCKER_IMAGE) sh -c "\
		. /etc/qnx/env && \
		arm-unknown-nto-qnx6.5.0eabi-gcc -O2 -Wall -Wextra -Werror -shared -fPIC \
			-I./src -DGAL_HOOK_BUILD='\"$(BUILD_ID)\"' \
			./src/*.c \
			-lsocket \
			-o ./$(TARGET) && \
		arm-unknown-nto-qnx6.5.0eabi-gcc -O2 -Wall -Wextra -Werror -shared -fPIC \
			./dmdt_flush/dmdt_flush.c \
			-o ./$(DMDT_FLUSH)"
	@echo "==> Build successful: $(TARGET) $(DMDT_FLUSH)"

player:
	@echo "==> Building player/stream-player..."
	@$(MAKE) -C player

# Assembles the SD-card deployable folder that scripts/deploy_to_car.sh
# expects at dist/sdcard_hook. Companion JARs are not built by this repo
# (deploy_to_car.sh's --with-jars path is unaffected).
package: hook player
	@echo "==> Assembling SD-card package at $(PACKAGE_DIR)..."
	@rm -rf $(PACKAGE_DIR)
	@mkdir -p $(PACKAGE_DIR)/scripts $(PACKAGE_DIR)/lib
	cp $(TARGET) $(PACKAGE_DIR)/
	cp $(DMDT_FLUSH) $(PACKAGE_DIR)/lib/
	cp player/stream-player $(PACKAGE_DIR)/
	cp player/config.txt $(PACKAGE_DIR)/
	cp scripts/enable_hook.sh scripts/disable_hook.sh $(PACKAGE_DIR)/
	cp scripts/gal_dualscreen.conf.example $(PACKAGE_DIR)/gal_dualscreen.conf
	cp scripts/hook_status.sh scripts/lib_app_mount.sh $(PACKAGE_DIR)/scripts/
	@echo "==> Package ready: $(PACKAGE_DIR)"
	@echo "    Review $(PACKAGE_DIR)/gal_dualscreen.conf before deploying, then run:"
	@echo "    scripts/deploy_to_car.sh <MIB_IP>"

shell:
	@docker run -it --rm -v $(PWD):/work -w /work $(DOCKER_IMAGE) sh -c ". /etc/qnx/env && exec sh"

clean:
	rm -f $(TARGET) $(DMDT_FLUSH)
	@$(MAKE) -C player clean
	rm -rf $(PACKAGE_DIR)
