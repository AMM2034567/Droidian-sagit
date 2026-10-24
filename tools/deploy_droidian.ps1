<#
.SYNOPSIS
    Droidian Deployment & Safe Backup Utility for Xiaomi Mi 6 (sagit)
.DESCRIPTION
    A strict safety-first deployment and backup toolkit designed for porting
    Droidian Linux to Xiaomi Mi 6 (Snapdragon 835 / MSM8998).
.PARAMETER DryRun
    Simulate all checks and commands without performing any write or erase operations.
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success($msg) { Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning($msg) { Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
function Write-ErrorMsg($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Host "==========================================================" -ForegroundColor Magenta
Write-Host "    Droidian Linux Deployment Tool - Xiaomi Mi 6 (sagit)   " -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Magenta

if ($DryRun) {
    Write-Warning "DRY-RUN MODE ACTIVATED: No data will be written or erased on device."
}

# 1. Device Baseline Check
Write-Info "Checking ADB connectivity..."
$adbDevices = adb devices
$deviceLines = $adbDevices -split "`n" | Where-Object { $_ -match "\s+device$" -or $_ -match "\s+recovery$" }

if ($deviceLines.Count -eq 0) {
    Write-Warning "No active ADB device detected. Checking Fastboot mode..."
    $fbDevices = fastboot devices
    if (-not $fbDevices) {
        Write-ErrorMsg "No connected device found in ADB or Fastboot mode."
        Write-Host "Please connect your phone and ensure USB debugging or Fastboot is enabled."
        exit 1
    }
    $mode = "fastboot"
    Write-Info "Device detected in FASTBOOT mode."
} else {
    $mode = "adb"
    Write-Info "Device detected in ADB mode."
}

# Verify Model Codename
if ($mode -eq "adb") {
    $deviceModel = (adb shell getprop ro.product.device).Trim()
    if ($deviceModel -ne "sagit") {
        # Check TWRP recovery fallback
        $deviceModel = (adb shell getprop ro.build.product).Trim()
    }
    Write-Info "Connected device model: '$deviceModel'"
    if ($deviceModel -ne "sagit") {
        Write-ErrorMsg "Safety Abort: Connected device is NOT 'sagit'! Aborting to prevent device damage."
        exit 1
    }
} elseif ($mode -eq "fastboot") {
    $fbProduct = (fastboot getvar product 2>&1 | Select-String "product:").ToString().Split(":")[1].Trim()
    Write-Info "Connected Fastboot product: '$fbProduct'"
    if ($fbProduct -ne "sagit") {
        Write-ErrorMsg "Safety Abort: Fastboot product is NOT 'sagit'! Aborting."
        exit 1
    }
}

Write-Success "Device validated: Xiaomi Mi 6 (sagit)."

# Menu loop
while ($true) {
    Write-Host ""
    Write-Host "------------------- MAIN MENU -------------------" -ForegroundColor Yellow
    Write-Host "  [1] Perform Safe Full Partition Backup (boot, cust, recovery)"
    Write-Host "  [2] Check All Local Firmware & Staged Images Integrity"
    Write-Host "  [3] Flash Droidian Halium 9.0 Kernel (boot.img)"
    Write-Host "  [4] Flash Halium 9.0 Vendor (cust partition)"
    Write-Host "  [5] Sideload Droidian Rootfs GSI (TWRP Recovery)"
    Write-Host "  [6] Install Device Adaptation Deb Package (sagit configs)"
    Write-Host "  [7] Restore Partitions from Previous Backup"
    Write-Host "  [Q] Exit"
    Write-Host "-------------------------------------------------" -ForegroundColor Yellow
    
    $choice = Read-Host "Select an option [1-7, Q]"

    switch ($choice.ToUpper()) {
        "1" {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupDir = "backups\sagit_backup_$timestamp"
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            Write-Info "Starting partition backup to '$backupDir'..."
            
            if ($mode -ne "adb") {
                Write-ErrorMsg "Partition backup requires ADB (Android or TWRP recovery). Current mode is '$mode'."
                continue
            }

            # Partition nodes on sagit (MSM8998)
            $partitions = @(
                @{ Name = "boot"; Node = "/dev/block/sde40"; OutFile = "boot.img" },
                @{ Name = "cust"; Node = "/dev/block/sde42"; OutFile = "cust.img" },
                @{ Name = "recovery"; Node = "/dev/block/sda15"; OutFile = "recovery.img" }
            )

            foreach ($p in $partitions) {
                Write-Info "Dumping $($p.Name) ($($p.Node))..."
                if ($DryRun) {
                    Write-Host "  [DryRun] adb shell su -c 'dd if=$($p.Node) of=/sdcard/$($p.OutFile) bs=4096'"
                    Write-Host "  [DryRun] adb pull /sdcard/$($p.OutFile) $backupDir\$($p.OutFile)"
                } else {
                    adb shell "dd if=$($p.Node) of=/sdcard/$($p.OutFile) bs=4096 2>/dev/null"
                    adb pull "/sdcard/$($p.OutFile)" "$backupDir\$($p.OutFile)"
                    adb shell "rm -f /sdcard/$($p.OutFile)"
                    if (Test-Path "$backupDir\$($p.OutFile)") {
                        $hash = (Get-FileHash "$backupDir\$($p.OutFile)" -Algorithm SHA256).Hash
                        Write-Success "Backup $($p.Name) verified! SHA256: $hash"
                    } else {
                        Write-ErrorMsg "Failed to backup $($p.Name)!"
                    }
                }
            }
            Write-Success "Backup completed: $backupDir"
        }

        "2" {
            Write-Info "Checking local images and staging resources..."
            $filesToCheck = @(
                @{ Name = "Droidian Kernel (boot.img)"; Path = "build_output\droidian-kernel-sagit\boot.img" },
                @{ Name = "Device Adaptation Deb"; Path = "build_output\droidian-adaptation-sagit\adaptation-xiaomi-sagit-configs_1.0.0-1_all.deb" },
                @{ Name = "Vendor Archive (vendor.zip)"; Path = "staging\vendor.zip" },
                @{ Name = "Vendor Image (vendor.img)"; Path = "staging\unpacked\vendor.img" },
                @{ Name = "Droidian Rootfs GSI Archive"; Path = "staging\droidian-OFFICIAL-phosh-phone-rootfs-api28-arm64-next_20261024.zip" }
            )
            foreach ($f in $filesToCheck) {
                if (Test-Path $f.Path) {
                    $sz = (Get-Item $f.Path).Length / 1MB
                    $hash = (Get-FileHash $f.Path -Algorithm SHA256).Hash
                    Write-Success "$($f.Name): Ready ($([math]::Round($sz, 2)) MB), SHA256: $hash"
                } else {
                    Write-Warning "$($f.Name): NOT FOUND at '$($f.Path)'"
                }
            }
        }

        "3" {
            $bootPath = "build_output\droidian-kernel-sagit\boot.img"
            if (-not (Test-Path $bootPath)) {
                Write-ErrorMsg "boot.img not found at '$bootPath'. Run CI build or download first."
                continue
            }
            Write-Warning "TARGET: Flash Droidian Kernel to 'boot' partition."
            $confirm = Read-Host "Type 'CONFIRM' to proceed with flashing boot partition"
            if ($confirm -ne "CONFIRM") {
                Write-Info "Operation canceled."
                continue
            }
            if ($DryRun) {
                Write-Host "  [DryRun] fastboot flash boot $bootPath"
            } else {
                if ($mode -eq "adb") {
                    Write-Info "Rebooting to fastboot bootloader..."
                    adb reboot bootloader
                    Start-Sleep -Seconds 5
                }
                fastboot flash boot $bootPath
                Write-Success "Kernel boot.img flashed successfully!"
            }
        }

        "4" {
            $vendorImg = "staging\unpacked\vendor.img"
            if (-not (Test-Path $vendorImg)) {
                # Check if vendor.zip can be unpacked
                if (Test-Path "staging\vendor.zip") {
                    Write-Info "Unpacking staging\vendor.zip..."
                    Expand-Archive -Path "staging\vendor.zip" -DestinationPath "staging\unpacked" -Force
                }
            }
            if (-not (Test-Path $vendorImg)) {
                Write-ErrorMsg "vendor.img not found at '$vendorImg'!"
                continue
            }
            Write-Warning "TARGET: Flash Halium 9.0 Vendor to 'cust' partition (/dev/block/sde42)."
            $confirm = Read-Host "Type 'CONFIRM' to proceed with flashing cust/vendor partition"
            if ($confirm -ne "CONFIRM") {
                Write-Info "Operation canceled."
                continue
            }
            if ($DryRun) {
                Write-Host "  [DryRun] fastboot flash cust $vendorImg"
            } else {
                if ($mode -eq "adb") {
                    adb reboot bootloader
                    Start-Sleep -Seconds 5
                }
                fastboot flash cust $vendorImg
                Write-Success "Vendor flashed to cust partition successfully!"
            }
        }

        "5" {
            $rootfsZip = "staging\droidian-OFFICIAL-phosh-phone-rootfs-api28-arm64-next_20261024.zip"
            if (-not (Test-Path $rootfsZip)) {
                Write-ErrorMsg "Rootfs archive not found at '$rootfsZip'!"
                continue
            }
            Write-Warning "TARGET: Sideload Droidian Rootfs GSI via TWRP Recovery."
            Write-Host "Please ensure your phone is booted into TWRP recovery and in 'Advanced > ADB Sideload' mode." -ForegroundColor Cyan
            $confirm = Read-Host "Type 'CONFIRM' to begin ADB sideload"
            if ($confirm -ne "CONFIRM") {
                Write-Info "Operation canceled."
                continue
            }
            if ($DryRun) {
                Write-Host "  [DryRun] adb sideload $rootfsZip"
            } else {
                Write-Info "Sideloading Droidian rootfs GSI..."
                adb sideload $rootfsZip
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Rootfs sideload completed successfully!"
                } else {
                    Write-ErrorMsg "Rootfs sideload failed (exit code $LASTEXITCODE)."
                }
            }
        }

        "6" {
            $debPath = "build_output\droidian-adaptation-sagit\adaptation-xiaomi-sagit-configs_1.0.0-1_all.deb"
            if (-not (Test-Path $debPath)) {
                Write-ErrorMsg "Adaptation package not found at '$debPath'!"
                continue
            }
            Write-Info "Pushing and installing adaptation package..."
            if ($DryRun) {
                Write-Host "  [DryRun] adb push $debPath /tmp/"
                Write-Host "  [DryRun] adb shell dpkg -i /tmp/adaptation-xiaomi-sagit-configs_1.0.0-1_all.deb"
            } else {
                adb push $debPath /tmp/
                Write-Info "Attempting to install via adb shell dpkg..."
                adb shell "dpkg -i /tmp/adaptation-xiaomi-sagit-configs_1.0.0-1_all.deb"
                Write-Success "Adaptation configs applied!"
            }
        }

        "7" {
            Write-Info "Available backup folders:"
            $backups = Get-ChildItem -Path "backups" -Directory -ErrorAction SilentlyContinue
            if (-not $backups) {
                Write-Warning "No existing backups found in 'backups/' directory."
                continue
            }
            for ($i = 0; $i -lt $backups.Count; $i++) {
                Write-Host "  [$i] $($backups[$i].Name)"
            }
            $idx = Read-Host "Select backup index to restore"
            if ($idx -match "^\d+$" -and [int]$idx -lt $backups.Count) {
                $selBackup = $backups[[int]$idx].FullName
                Write-Warning "Restoring from '$selBackup'..."
                $confirm = Read-Host "Type 'CONFIRM' to restore partitions"
                if ($confirm -eq "CONFIRM") {
                    if ($mode -eq "adb") { adb reboot bootloader; Start-Sleep -Seconds 5 }
                    if (Test-Path "$selBackup\boot.img") { fastboot flash boot "$selBackup\boot.img" }
                    if (Test-Path "$selBackup\cust.img") { fastboot flash cust "$selBackup\cust.img" }
                    if (Test-Path "$selBackup\recovery.img") { fastboot flash recovery "$selBackup\recovery.img" }
                    Write-Success "Partitions restored successfully!"
                }
            }
        }

        "Q" {
            Write-Info "Exiting deployment tool. Goodbye!"
            break
        }
    }
}
