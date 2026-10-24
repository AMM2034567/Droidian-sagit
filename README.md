# Droidian for Xiaomi Mi 6 (sagit)

本项目旨在将 [Droidian](https://droidian.org)（基于 Debian 的移动操作系统）移植到小米6（Xiaomi Mi 6，机型代号 `sagit`）。

## 硬件与移植基准

- **SoC**: 高通骁龙 835 (Qualcomm MSM8998)
- **架构**: `arm64` (A-only 分区布局)
- **底层底座**: Halium 9.0 (API 28 / Android 9 Pie)
- **内核基准**: Linux 4.4 (`android_kernel_xiaomi_msm8998`, 分支 `halium-9.0`)
- **Vendor 分区**: 独立挂载于 `/dev/block/sde42` (原 `cust` 分区，大小约 819MB)
- **屏幕分辨率 / 密度**: 1080x1920, 480 DPI

---

## 仓库结构

```text
├── .github/
│   └── workflows/
│       └── build-kernel.yml       # GitHub Actions 自动化内核与 boot.img 编译流
├── kernel/
│   ├── debian/
│   │   ├── kernel-info.mk         # sagit 专用内核编译与 boot 镜像偏移参数
│   │   ├── rules                  # Droidian linux-packaging-snippets 规则文件
│   │   ├── control                # Debian 包描述
│   │   ├── compat                 # debhelper 兼容等级
│   │   └── changelog              # 变更记录
│   └── fragments/
│       └── 01-droidian.config     # Droidian 必需配置片段 (namespaces, cgroups, rndis 等)
├── docs/
│   └── AGENT.md                   # 移植背景与评估规约
└── README.md
```

---

## 如何在 GitHub Actions 触发编译

1. 在 GitHub 上新建一个空仓库（例如名为 `Droidian-sagit`）。
2. 在本地执行推送：
   ```bash
   git branch -M main
   git remote add origin https://github.com/<你的用户名>/Droidian-sagit.git
   git add .
   git commit -m "feat: setup Droidian kernel build workflow for sagit"
   git push -u origin main
   ```
3. 打开 GitHub 仓库页面，切换到 **Actions** 标签页：
   - GitHub Actions 将自动启动 `Build Droidian Kernel for Xiaomi Mi 6 (sagit)` 任务。
   - 任务在 Droidian 官方 `quay.io/droidian/build-essential:bookworm-amd64` 容器中拉取源码与 AOSP GCC 4.9 工具链进行交叉编译。
   - 编译完成后，在 Actions 页面底部的 **Artifacts** 区域即可一键下载编译好的：
     - `boot.img`（用于 fastboot / TWRP 直接刷入测试）
     - `linux-image-4.4-sagit_*.deb`（内核 deb 包）
     - `linux-bootimage-4.4-sagit_*.deb`（boot 镜像 deb 包）

---

## 移植路线图

- [x] 现状盘点与可行性评估
- [x] 设备物理参数与 TWRP 版本检测（已确认 TWRP 3.7.0_12）
- [x] 编写 GitHub Actions 内核与 Boot.img 自动编译工作流
- [ ] 云端编译验证并下载 `boot.img` 产物
- [ ] 备份当前手机完整系统与数据
- [ ] 构建 `adaptation-xiaomi-sagit` 硬件适配包骨架
- [ ] TWRP 刷入 Halium 9 vendor + Droidian api28 rootfs + boot.img
- [ ] USB Telnet 调试与服务联调
