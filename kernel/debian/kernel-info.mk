# Droidian Kernel Info Configuration for Xiaomi Mi 6 (sagit)
# Generated according to sagit hardware inspection & Droidian specifications

KERNEL_ARCH = arm64
KERNEL_BASE_VERSION = 4.4
KERNEL_DEFCONFIG = sagit_defconfig

# DTB Configuration (Snapdragon 835 appends DTB to kernel Image.gz)
KERNEL_IMAGE_WITH_DTB = 1

# Boot Image Header Offsets & Parameters (Extracted from sagit physical boot partition)
KERNEL_BOOTIMAGE_PAGE_SIZE = 4096
KERNEL_BOOTIMAGE_BASE_OFFSET = 0x00000000

# Kernel Command Line:
# - Retains essential MSM8998 hardware and service locator arguments
# - Adds console=tty0 and droidian.lvm.prefer
# - Systempart parameter MUST NOT be present
KERNEL_BOOTIMAGE_CMDLINE = androidboot.console=ttyMSM0 androidboot.hardware=qcom msm_rtb.filter=0x37 ehci-hcd.park=3 service_locator.enable=1 swiotlb=2048 loop.max_part=7 console=tty0 droidian.lvm.prefer

# Enable Droidian config fragments
KERNEL_CONFIG_USE_FRAGMENTS = 1
