# Droidian Kernel Info Configuration for Xiaomi Mi 6 (sagit)
# Target SoC: Qualcomm Snapdragon 835 (MSM8998)

VARIANT = android
KERNEL_BASE_VERSION = 4.4.302-1
DEVICE_VENDOR = xiaomi
DEVICE_MODEL = sagit
DEVICE_FULL_NAME = Xiaomi Mi 6
KERNEL_DEFCONFIG = sagit_defconfig

# DTB Configuration (Snapdragon 835 kernel target Image.gz-dtb already appends DTB)
KERNEL_IMAGE_WITH_DTB = 0

# Boot Image Header Offsets & Parameters (Extracted from sagit physical boot partition)
KERNEL_BOOTIMAGE_PAGE_SIZE = 4096
KERNEL_BOOTIMAGE_BASE_OFFSET = 0x00000000
KERNEL_BOOTIMAGE_KERNEL_OFFSET = 0x00008000
KERNEL_BOOTIMAGE_INITRAMFS_OFFSET = 0x01000000
KERNEL_BOOTIMAGE_SECONDIMAGE_OFFSET = 0x00f00000
KERNEL_BOOTIMAGE_TAGS_OFFSET = 0x00000100

# Kernel Command Line:
# - Retains essential MSM8998 hardware and service locator arguments
# - Adds console=tty0 and droidian.lvm.prefer
# - Systempart parameter MUST NOT be present
KERNEL_BOOTIMAGE_CMDLINE = androidboot.console=ttyMSM0 androidboot.hardware=qcom msm_rtb.filter=0x37 ehci-hcd.park=3 service_locator.enable=1 swiotlb=2048 loop.max_part=7 console=tty0 droidian.lvm.prefer

# Droidian config fragments
KERNEL_CONFIG_USE_FRAGMENTS = 1
KERNEL_CONFIG_COMMON_FRAGMENTS =
KERNEL_CONFIG_DEVICE_FRAGMENTS = $(KERNEL_SOURCES)/droidian/sagit.config

# Build settings
KERNEL_BOOTIMAGE_VERSION = 0
KERNEL_INITRAMFS_COMPRESSION = gz
KERNEL_BUILD_TARGET = Image.gz-dtb
BUILD_CROSS = 1
BUILD_TRIPLET = aarch64-linux-android-
BUILD_CC = aarch64-linux-android-gcc
BUILD_LLVM = 0
CLANG_CUSTOM = 1
BUILD_SKIP_MODULES = 0
DEB_BUILD_ON = amd64
DEB_BUILD_FOR = arm64
KERNEL_ARCH = arm64

# Verified Boot & Flashing
DEVICE_VBMETA_REQUIRED = 0
FLASH_ENABLED = 1
FLASH_IS_AONLY = 1
FLASH_IS_LEGACY_DEVICE = 1
FLASH_INFO_MANUFACTURER = Xiaomi
FLASH_INFO_MODEL = MI 6
FLASH_INFO_DEVICE_IDS = sagit
