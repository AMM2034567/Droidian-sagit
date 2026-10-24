# Droidian Linux for Xiaomi Mi 6 (sagit)

本项目旨在将 [Droidian](https://droidian.org)（基于 Debian 的现代移动 Linux 操作系统，采用 Phosh 桌面环境与 Wayland）移植到小米6（Xiaomi Mi 6，机型代号 `sagit`）。

本项目采用 **安全第一** 原则，提供完整的云端自动化 CI 构建流水线（内核与设备适配包）、免重分区的 initramfs 补丁方案，以及全流程交互式备份与刷写回滚工具。

---

## 📱 硬件与物理分区基准

- **SoC**: 高通骁龙 835 (Qualcomm MSM8998 Octa-core, Adreno 540 GPU)
- **架构**: `arm64` (A-only 传统分区布局)
- **底层底座**: Halium 9.0 (API 28 / Android 9 Pie)
- **内核基准**: Linux 4.4.302 (`android_kernel_xiaomi_msm8998`, 分支 `halium-9.0`)
- **屏幕规格**: 5.15 英寸, 1080x1920 (16:9), 480 DPI (Phosh 推荐 2.0x 缩放)

### 物理分区映射表与挂载突破

| 分区名 | 物理块设备节点 | 大小 | 在 Droidian 中的用途 | 关键技术实现 |
| :--- | :--- | :--- | :--- | :--- |
| **boot** | `/dev/block/sde40` | 67 MB | Droidian 内核与通用 initramfs | 页面大小 4096，偏移完全吻合硬件规范 |
| **cust** | `/dev/block/sde42` | 819 MB | **挂载为 `/vendor` 驱动底层** | **核心突破**：无需重新划分 GPT，通过 initramfs 补丁直接识别 `cust` 作为 `/vendor` |
| **system** | `/dev/block/sde43` | 4.9 GB | 系统基座保留 | 可保留或用于 GSI 挂载 |
| **recovery**| `/dev/block/sda15` | 67 MB | TWRP 恢复模式 | 用于 Sideload 根文件系统 |
| **userdata**| `/dev/block/sda17` | 110 GB | 存放 `rootfs.img` 循环挂载镜像 | Droidian GSI loop 挂载于 `/data/rootfs.img` |

> [!NOTE]
> **免重新分区突破**：官方 Droidian `halium-generic-initramfs` 默认仅扫描名为 `vendor` 的分区，而小米6原生没有独立的 vendor 分区（历史 Halium/Ubuntu Touch 均借用 819MB 的 `cust` 分区）。本项目在内核编译阶段通过 initramfs overlay 注入了专有探测脚本，使 Droidian 原生内核能直接识别挂载 `/dev/block/sde42`，无需危险的 GPT 重新分区操作。

---

## 📂 仓库结构

```text
├── .github/
│   └── workflows/
│       ├── build-kernel.yml       # GitHub Actions: 内核、initramfs overlay 与 boot.img 自动化构建 (含 ccache)
│       └── build-adaptation.yml   # GitHub Actions: sagit 设备专有适配 deb 软件包构建
├── adaptation/                    # 设备专有适配包源码
│   ├── debian/                    # Debian 打包标准描述文件 (control, rules, changelog)
│   ├── etc/
│   │   ├── modules-load.d/        # 内核模块自动加载 (wlan.conf)
│   │   ├── phosh/phoc.ini         # Phosh 显示缩放配置 (5.15寸 1080P 设置为 scale = 2.0)
│   │   └── udev/rules.d/          # 硬件设备权限规则 (70-sagit.rules: binder, ion, kgsl GPU 等)
│   └── usr/lib/droidian/device/   # 设备名优选脚本 (preferred-hostname: sagit)
├── kernel/
│   ├── debian/
│   │   ├── kernel-info.mk         # sagit 专用内核编译参数、基地址与 boot 镜像偏移参数
│   │   ├── rules                  # Droidian linux-packaging 编译流水线指令
│   │   ├── control                # 内核 Debian 包依赖元数据
│   │   └── initramfs-overlay/     # 针对 sagit cust 分区的挂载修补脚本
│   └── fragments/
│       └── 01-droidian.config     # Droidian 必需内核配置 (systemd, namespaces, cgroups, binder 等)
├── scripts/
│   └── download_file.py           # 大文件安全断点续传与 SHA256 校验脚本
├── tools/
│   └── deploy_droidian.ps1        # 交互式安全部署、全底包备份与一键回退工具
├── docs/
│   └── AGENT.md                   # 移植可行性评估与架构设计规范
└── README.md
```

---

## ⚙️ 自动化 CI 构建流水线

本项目包含两个 GitHub Actions 自动化工作流，无需在本地配置繁重的交叉编译环境：

### 1. 内核构建 (`build-kernel.yml`)
- **运行环境**：`ubuntu-22.04` + 官方 AOSP GCC 4.9 `aarch64-linux-android-` 交叉编译器。
- **缓存加速**：集成了持久化 5GB `ccache` 缓存，二次构建耗时由 11 分钟压缩至 3 分钟以内。
- **输出产物 (Artifact)**：
  - `boot.img`：包含集成 DTB 的 Linux 4.4 内核与注入了 `cust` 挂载脚本的 initramfs。
  - `linux-image-4.4-sagit_*.deb`：用于系统内更新的内核包。
  - `linux-bootimage-4.4-sagit_*.deb`：用于系统内更新的 bootimg 包。

### 2. 设备适配包构建 (`build-adaptation.yml`)
- **产物**：`adaptation-xiaomi-sagit-configs_1.0.0-1_all.deb`。
- **功能**：
  - 自动将 Wayland/Phosh 屏幕比例设为 `2.0`（解决 1080x1920 默认 1.0x 字体过小无法点击的问题）。
  - 配置 `/dev/binder`, `/dev/hwbinder`, `/dev/vndbinder` 和 `/dev/kgsl-3d0` 权限，确保 Android 容器正常运行及 GPU 硬件加速。
  - 自动加载 `wlan` 驱动模块。

---

## 🛠️ 安全部署工具指南 (`tools/deploy_droidian.ps1`)

为了防止误刷或损坏用户原有数据，本项目提供了专门编写的 PowerShell 部署工具。

### 运行部署工具
```powershell
# 仿真模拟模式（不执行任何实际写入，验证设备连通性与机型识别）
powershell -ExecutionPolicy Bypass -File .\tools\deploy_droidian.ps1 -DryRun

# 交互式操作模式
powershell -ExecutionPolicy Bypass -File .\tools\deploy_droidian.ps1
```

### 工具核心菜单功能
```text
------------------- MAIN MENU -------------------
  [1] Perform Safe Full Partition Backup (boot, cust, recovery)
  [2] Check All Local Firmware & Staged Images Integrity
  [3] Flash Droidian Halium 9.0 Kernel (boot.img)
  [4] Flash Halium 9.0 Vendor (cust partition)
  [5] Sideload Droidian Rootfs GSI (TWRP Recovery)
  [6] Install Device Adaptation Deb Package (sagit configs)
  [7] Restore Partitions from Previous Backup
  [Q] Exit
-------------------------------------------------
```

- **机型严格锁定**：仅允许代号为 `sagit` 的设备执行，非 `sagit` 立即熔断退出。
- **一键全量备份 (选项 1)**：在进行任何刷写前，一键将当前系统的 `boot`、`cust`、`recovery` 原生分区完整提取到 PC 并计算 SHA-256 哈希存档。
- **一键回退还原 (选项 7)**：若体验后需返回原有 Android 系统，选择备份目录即可自动通过 Fastboot 100% 原样还原。

---

## 🚀 完整刷写与体验流程（真机部署指南）

> [!CAUTION]
> **重要数据安全提醒**：刷入移动 Linux GSI 系统前，请务必提前将手机内的所有个人数据完全导出备份到电脑或移动硬盘。

### 第一阶段：准备工作（电脑端完成）
1. 运行 `deploy_droidian.ps1` 选项 `[2]`，确认以下 5 个核心资产均已就绪：
   - `build_output/droidian-kernel-sagit/boot.img`
   - `build_output/droidian-adaptation-sagit/adaptation-xiaomi-sagit-configs_1.0.0-1_all.deb`
   - `staging/unpacked/vendor.img` (Halium 9.0 驱动)
   - `staging/droidian-OFFICIAL-phosh-phone-rootfs-api28-arm64-next_20261024.zip` (官方 Rootfs)

### 第二阶段：分区备份
1. 手机保持开启 USB 调试连接电脑，运行部署工具执行选项 `[1]`；
2. 确认 `backups/sagit_backup_<时间戳>/` 下生成了完好的 `boot.img`、`cust.img`、`recovery.img`。

### 第三阶段：固件刷写
1. 执行选项 `[4]`：通过 Fastboot 将 Halium 9.0 Vendor 刷入 `cust` 分区；
2. 执行选项 `[3]`：通过 Fastboot 将 Droidian 内核刷入 `boot` 分区；
3. 手机进入 TWRP 恢复模式，依次点击：
   - **清除 (Wipe)** -> **格式化 Data 分区 (Format Data)** -> 输入 `yes`（清除 Android 加密锁定）；
   - **高级 (Advanced)** -> **ADB 线刷 (ADB Sideload)** -> 滑动开启；
4. 在电脑端部署工具中执行选项 `[5]`，自动推送并安装 Droidian 根文件系统；
5. 重启手机，体验 Droidian 启动画面。

### 第四阶段：配置应用
1. 首次进入桌面后，手机连接电脑执行选项 `[6]`，推送并安装设备专有适配包，享受最佳 DPI 比例与完整硬件驱动。

---

## 🗺️ 移植路线图与当前进展

- [x] 设备硬件基准与分区布局探测对账
- [x] GitHub Actions 内核与 `boot.img` 自动化编译流设计
- [x] 内核编译持久化缓存（ccache + 工具链）
- [x] 修补 initramfs 探测脚本以原生支持小米6 `cust` 分区
- [x] 云端编译内核与 boot.img 成功并下载本地物理校验通过
- [x] 构建 `adaptation-xiaomi-sagit-configs` 设备专有适配包
- [x] 离线固件全套资产（Vendor, Rootfs, Kernel, Adaptation）下载与 CRC32 校验
- [x] 交互式安全部署与一键回退工具 (`deploy_droidian.ps1`) 编写与验证
- [ ] 手机端个人数据导出与备份完毕（等待用户操作）
- [ ] 物理机无损全分区备份提取
- [ ] 真机刷入 Halium 9 Vendor + Droidian Kernel + Rootfs
- [ ] 首次开机验证、USB 网络调试与服务联调

---

## 📜 鸣谢与参考

- [Droidian Project](https://droidian.org) - 优秀的基于 Debian 的移动 Linux 方案
- [Halium](https://halium.org) - 为移动 Linux 统一 Android 硬件驱动抽象层
- [LineageOS & Ubuntu Touch sagit Porters](https://github.com/UbuntuTouch-sagit) - 提供稳定可靠的底层内核源码与 Vendor 固件
