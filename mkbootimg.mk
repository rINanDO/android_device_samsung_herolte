# mkbootimg.mk - Custom mkbootimg Makefile for Exynos devices
#
# Copyright (C) 2017 Jesse Chan <cjx123@outlook.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

LOCAL_PATH := $(call my-dir)

DTS_NAMES := exynos8890-hero2lte_eur_open

DTS_FILES = $(wildcard $(TOP)/$(TARGET_KERNEL_SOURCE)/arch/arm64/boot/dts/$(DTS_NAMES)*.dts)
DTS_FILE = $(lastword $(subst /, ,$(1)))

PROCESSED_DTS_FILE = $(addprefix $(KERNEL_OUT)/arch/arm64/boot/dts_processed/,$(call DTS_FILE,$(1)))

DTB_FILE = $(addprefix $(KERNEL_OUT)/arch/arm64/boot/,$(patsubst %.dts,%.dtb,$(call DTS_FILE,$(1))))
DTC = $(KERNEL_OUT)/scripts/dtc/dtc

define process-dts
	rm -rf $(KERNEL_OUT)/arch/arm64/boot;\
	mkdir -p $(KERNEL_OUT)/arch/arm64/boot/dts_processed;\
	$(foreach d, $(DTS_FILES), \
		cpp -nostdinc -undef -x assembler-with-cpp -I $(TARGET_KERNEL_SOURCE)/include $(d) -o $(call PROCESSED_DTS_FILE,$(d));)
endef

define make-dtbs
	$(foreach d, $(DTS_FILES), \
		$(DTC) -p 0 -i $(TARGET_KERNEL_SOURCE)/arch/arm64/boot/dts -O dtb -o $(call DTB_FILE,$(d)) $(call PROCESSED_DTS_FILE,$(d));)
endef


## Build and run dtbtool
DTBTOOL := $(HOST_OUT_EXECUTABLES)/$(TARGET_CUSTOM_DTBTOOL)$(HOST_EXECUTABLE_SUFFIX)
INSTALLED_DTIMAGE_TARGET := $(PRODUCT_OUT)/dt.img

$(INSTALLED_DTIMAGE_TARGET): $(DTBTOOL) $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ/usr $(INSTALLED_KERNEL_TARGET)
	@echo -e ${CL_CYN}"Start DT image: $@"${CL_RST}
	$(call process-dts)
	$(call make-dtbs)
	$(call pretty,"Target dt image: $(INSTALLED_DTIMAGE_TARGET)")
	$(hide) $(DTBTOOL) -o $(INSTALLED_DTIMAGE_TARGET) -s $(BOARD_KERNEL_PAGESIZE) -d $(KERNEL_OUT)/arch/arm64/boot/
	@echo -e ${CL_CYN}"Made DT image: $@"${CL_RST}


## Boot Image Generation
$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES) $(INSTALLED_DTIMAGE_TARGET)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --dt $(INSTALLED_DTIMAGE_TARGET) --output $@
	$(hide) echo -n "SEANDROIDENFORCE" >> $(INSTALLED_BOOTIMAGE_TARGET)
	$(hide) $(call assert-max-image-size,$@,$(BOARD_BOOTIMAGE_PARTITION_SIZE),raw)
	@echo -e ${CL_CYN}"Made boot image: $@"${CL_RST}

## Recovery Image Generation
$(INSTALLED_RECOVERYIMAGE_TARGET): $(MKBOOTIMG) $(INSTALLED_DTIMAGE_TARGET) \
		$(recovery_ramdisk) \
		$(recovery_kernel)
	@echo -e ${CL_CYN}"----- Making recovery image ------"${CL_RST}
	$(hide) $(MKBOOTIMG) $(INTERNAL_RECOVERYIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --dt $(INSTALLED_DTIMAGE_TARGET) --output $@
	$(hide) echo -n "SEANDROIDENFORCE" >> $(INSTALLED_RECOVERYIMAGE_TARGET)
	$(hide) $(call assert-max-image-size,$@,$(BOARD_RECOVERYIMAGE_PARTITION_SIZE),raw)
	@echo -e ${CL_CYN}"Made recovery image: $@"${CL_RST}

.PHONY: dtimage
dtimage: $(INSTALLED_DTIMAGE_TARGET)