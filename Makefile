obj-m := src/linuwu_sense.o

KVER  ?= $(shell uname -r)
KDIR  := /lib/modules/$(KVER)/build
PWD   := $(shell pwd)

MDIR  := /lib/modules/$(KVER)/kernel/drivers/platform/x86
MODNAME := linuwu_sense
REAL_USER := $(shell echo $${SUDO_USER:-$$(whoami)})

# DKMS rebuilds the module automatically whenever a new kernel is installed.
# It is used when available; pass USE_DKMS=0 to install for $(KVER) only.
PKGVER    := $(shell sed -n 's/.*define DRIVER_VERSION "\(.*\)".*/\1/p' src/$(MODNAME).c 2>/dev/null)
SRCDIR    := /usr/src/$(MODNAME)-$(PKGVER)
DKMS_TREE := /var/lib/dkms/$(MODNAME)
USE_DKMS  ?= $(if $(shell command -v dkms 2>/dev/null),1,0)

.PHONY: all clean install install-dkms install-legacy install-config uninstall dkms-remove

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

uninstall:
	@sudo rm -f /etc/modules-load.d/$(MODNAME).conf
	@sudo rm -f /etc/modprobe.d/blacklist-acer_wmi.conf
	@sudo systemctl stop linuwu_sense.service
	@sudo systemctl disable linuwu_sense.service
	@sudo rm -f /etc/systemd/system/linuwu_sense.service
	@sudo systemctl daemon-reload
	@sudo rmmod $(MODNAME) 2>/dev/null || true
	@sudo modprobe acer_wmi
	@echo "Removing current user from linuwu_sense group if exists..."
	@if getent group linuwu_sense >/dev/null; then \
		sudo gpasswd -d $(REAL_USER) linuwu_sense || true; \
		sudo groupdel linuwu_sense || true; \
	else \
		echo "Group linuwu_sense does not exist."; \
	fi
	@sudo rm -f /etc/tmpfiles.d/$(MODNAME).conf
	@$(MAKE) --no-print-directory dkms-remove
	@sudo rm -f $(MDIR)/$(MODNAME).ko
	@sudo depmod -a
	@echo "Uninstalled $(MODNAME) and cleaned up related configuration."

# Remove every DKMS-registered version of the module and its sources.
dkms-remove:
	@for v in $$(ls $(DKMS_TREE) 2>/dev/null | grep -v -e '^original_module$$' -e '^kernel-'); do \
		echo "Removing $(MODNAME)/$$v from DKMS..."; \
		sudo dkms remove -m $(MODNAME) -v $$v --all || true; \
	done
	@sudo rm -rf /usr/src/$(MODNAME)-*

# Register the sources with DKMS and install for $(KVER), then for every other
# installed kernel that has headers. DKMS rebuilds (and, where configured,
# signs) the module for each new kernel from then on. Older installs copied the
# module straight into a kernel's tree; that copy is removed only after DKMS has
# built the module for the same kernel, so a failed build never leaves a kernel
# without a driver.
install-dkms:
	@test -n "$(PKGVER)" || { echo "Error: could not read DRIVER_VERSION from src/$(MODNAME).c"; exit 1; }
	@$(MAKE) --no-print-directory dkms-remove
	sudo install -d $(SRCDIR)/src
	sudo install -m 644 dkms.conf Makefile $(SRCDIR)/
	sudo install -m 644 $(filter-out %.mod.c,$(wildcard src/*.c src/*.h)) $(SRCDIR)/src/
	sudo sed -i 's/^PACKAGE_VERSION=.*/PACKAGE_VERSION="$(PKGVER)"/' $(SRCDIR)/dkms.conf
	sudo dkms add -m $(MODNAME) -v $(PKGVER)
	sudo dkms build -m $(MODNAME) -v $(PKGVER) -k $(KVER)
	sudo rm -f $(MDIR)/$(MODNAME).ko
	sudo dkms install -m $(MODNAME) -v $(PKGVER) -k $(KVER)
	@# Best effort for the other installed kernels that have headers.
	@for k in $$(ls /lib/modules); do \
		[ "$$k" != "$(KVER)" ] && [ -e "/lib/modules/$$k/build/Makefile" ] || continue; \
		if sudo dkms build -m $(MODNAME) -v $(PKGVER) -k "$$k" > /dev/null 2>&1; then \
			sudo rm -f "/lib/modules/$$k/kernel/drivers/platform/x86/$(MODNAME).ko"; \
			sudo dkms install -m $(MODNAME) -v $(PKGVER) -k "$$k" > /dev/null 2>&1 \
				&& echo "Also installed for kernel $$k."; \
		else \
			echo "Note: could not build for kernel $$k, left it unchanged."; \
		fi; \
	done

# Previous behaviour: copy the module into $(KVER)'s tree only. It has to be
# reinstalled after every kernel update.
install-legacy: all
	sudo install -d $(MDIR)
	sudo install -m 644 src/$(MODNAME).ko $(MDIR)
	sudo depmod -a

install:
	@sudo rmmod acer_wmi 2>/dev/null || true
	@echo "blacklist acer_wmi" | sudo tee /etc/modprobe.d/blacklist-acer_wmi.conf > /dev/null
ifeq ($(USE_DKMS),1)
	@$(MAKE) --no-print-directory install-dkms
else
	@echo "Installing $(MODNAME) for kernel $(KVER) only (no DKMS)."
	@echo "After a kernel update run 'make install' again, or install dkms so it happens automatically."
	@$(MAKE) --no-print-directory install-legacy
endif
	@$(MAKE) --no-print-directory install-config

install-config:
	@echo "$(MODNAME)" | sudo tee /etc/modules-load.d/$(MODNAME).conf > /dev/null
	@# Reload, so an older copy that is still loaded is replaced by the new one.
	@sudo rmmod $(MODNAME) 2>/dev/null || true
	sudo modprobe $(MODNAME)
	@sudo cp linuwu_sense.service /etc/systemd/system/
	@sudo systemctl daemon-reload
	@sudo systemctl enable linuwu_sense.service
	@sudo systemctl start linuwu_sense.service
	@echo "Setting up group and permissions..."
	@echo "Detected user: $(REAL_USER)"
	@if ! getent group linuwu_sense >/dev/null; then \
		sudo groupadd linuwu_sense; \
	fi; 
	sudo usermod -aG linuwu_sense $(REAL_USER)
	@echo "Setting permissions via tmpfiles..."
	@model_path=$$(ls /sys/module/$(MODNAME)/drivers/platform:acer-wmi/acer-wmi/ | grep -E 'predator_sense|nitro_sense' || true); \
	if [ -n "$$model_path" ]; then \
		echo "Detected model directory: $$model_path"; \
		conf_file="/etc/tmpfiles.d/$(MODNAME).conf"; \
		[ -f $$conf_file ] || sudo touch $$conf_file; \
		if echo "$$model_path" | grep -q "nitro_sense"; then \
			supported_fields="fan_speed battery_limiter battery_calibration usb_charging"; \
		else \
			supported_fields="backlight_timeout battery_calibration battery_limiter boot_animation_sound fan_speed lcd_override usb_charging"; \
		fi; \
		for f in $$supported_fields; do \
			entry="f /sys/module/$(MODNAME)/drivers/platform:acer-wmi/acer-wmi/$$model_path/$$f 0660 root $(MODNAME)"; \
			grep -qxF "$$entry" $$conf_file || echo "$$entry" | sudo tee -a $$conf_file > /dev/null; \
		done; \
		kb_base="/sys/module/$(MODNAME)/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb"; \
		if [ -d "$$kb_base" ]; then \
			for z in four_zone_mode per_zone_mode; do \
				entry="f $$kb_base/$$z 0660 root $(MODNAME)"; \
				grep -qxF "$$entry" $$conf_file || echo "$$entry" | sudo tee -a $$conf_file > /dev/null; \
			done; \
		fi; \
		logo_path="/sys/module/$(MODNAME)/drivers/platform:acer-wmi/acer-wmi/back_logo/color"; \
		if [ -f "$$logo_path" ]; then \
			entry="f $$logo_path 0660 root $(MODNAME)"; \
			grep -qxF "$$entry" $$conf_file || echo "$$entry" | sudo tee -a $$conf_file > /dev/null; \
		fi; \
		sudo systemd-tmpfiles --create $$conf_file; \
	else \
		echo "Warning: Could not detect predator_sense or nitro_sense in sysfs."; \
	fi
	@echo "Module $(MODNAME) installed and configured to load at boot."
