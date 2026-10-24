你现在是我的嵌入式 Linux 移植助手。请先不要写代码、不要改仓库，先完成一次“现状盘点”。

## 项目背景
目标：把 Droidian 移植到小米6（代号 sagit，机型 MI 6）。
起点：社区已有 Ubuntu Touch 的 Halium 9.0 端口。
我的条件：我现在已经有电脑，可以做本地编译、fastboot 刷机和较重的调试；手机 + Termux 仍可用于轻量信息收集、仓库管理和临时日志查看。
我的原则：agent 提假设，我上机验事实。所有结论必须区分“已确认事实 / 合理推断 / 待验证”。

## 我已经确认的设备信息（来自当前 Android 14 ROM）
- ro.product.device=sagit，ro.product.model=MI 6
- android_release=14，sdk=34
- ro.treble.enabled=true
- 存在独立 /vendor 挂载：/dev/block/sde42 on /vendor
- ro.vendor.api_level=25
- ab_update 为空，设备为 A-only
- 当前系统带 Magisk，mount 输出很长，已脱敏

## 联网搜索要求
- 你必须联网搜索并核实信息，不能只凭记忆回答。
- 优先查官方文档和源码仓库：Droidian 官方文档、droidian-devices GitHub 组织、Ubuntu Touch / Halium 的 sagit 端口仓库、postmarketOS wiki、Linux 内核邮件列表或 commit。
- 每个仓库/产物都要给出：链接、分支或标签、最后更新时间、包含内容、可信度。
- 关键判断要给出来源链接；没有来源的写“推断”，不要伪装成事实。
- 搜索后仍找不到的，明确写“未找到”，不要编造仓库名、分支名、版本号或链接。
- 请标注信息检索日期（例如：检索于 2026-10-24）。
- 如果你当前无法联网，请在第一段明确写“我无法联网搜索，以下基于已有知识，需你核实”，不要假装已经搜索过。
- 请实际调用搜索/网页读取工具，不要只描述“我会去搜”。搜索完成后，在资源清单里附上你实际访问过的 URL。
- 建议搜索关键词包括但不限于：
  - Droidian GSI vendor partition requirements
  - Droidian adaptation package structure
  - droidian-devices sagit
  - Ubuntu Touch sagit Halium 9
  - halium-9.0 sagit kernel
  - postmarketOS xiaomi sagit
  - Droidian kernel compilation systempart

## 请你完成以下盘点任务

### 1. 核实 Droidian 侧的前置条件
- Droidian 对 GSI / 通用 rootfs 的要求是什么？独立 vendor 分区 + ro.treble.enabled=true 是否足以走 GSI 路径？
- 对 vendor 底包的 Android 版本最低要求是什么？ro.vendor.api_level=25 是否构成阻碍？如果构成，需要换哪个底包？
- A-only 设备在选择 GSI 镜像时要注意什么？
- 官方文档中 “skip image creation” 的准确条件是什么？请给出出处链接或仓库路径。

### 2. 核实小米6现有社区资源
请搜索并列出：
- droidian-devices 组织下是否存在 sagit 的适配仓库或适配包；
- Ubuntu Touch / Halium 9 的 sagit 端口仓库、内核源码仓库、设备树仓库；
- postmarketOS 或其他社区是否有 sagit 的主线/非主线内核工作；
- 是否存在可直接下载的 Droidian 适配包、内核 .deb、GSI rootfs 产物。
每一项都要给出：仓库地址、分支/标签、最后更新时间、是否包含内核、是否包含适配包、可信度备注。

### 3. 核实内核路径
- 小米6 Halium 9 内核源码的可用分支是什么？
- Droidian 内核编译需要哪些配置片段、打包文件、Docker 构建镜像？
- 内核 cmdline 中 systempart= 为什么必须移除？请给出依据。
- 如果走 GitHub Actions 或本地编译，分别需要哪些输入：源码仓库、分支、defconfig、fragment、输出产物格式？

### 4. 核实适配包与 rootfs
- Droidian 适配包（adaptation package）的标准结构是什么？
- 小米6需要从 Ubuntu Touch 端口提取哪些文件/配置？
- 适配包中的 APT 仓库地址应该如何组织？
- 通用 GSI rootfs 和适配包之间是什么关系？

### 5. 风险与未知项
列出：
- 当前信息中哪些是“已确认”，哪些是“推断”，哪些“必须上机验证”；
- 最可能卡住的 3 个环节；
- 按资源需求分阶段说明：哪些步骤电脑上可做，哪些适合 GitHub Actions，哪些必须真机验证，哪些手机 + Termux 就能做。

## 输出格式要求
请用以下结构输出：
1. 结论摘要（不超过 10 行）
2. 事实表：项目 | 状态（已确认/推断/待验证）| 依据/链接 | 对我的影响
3. 资源清单：仓库/产物 | 地址 | 分支/版本 | 最后更新 | 包含内容 | 可信度
4. 路径判断：GSI 路径是否可行？如果不可行，替代路径是什么？
5. 下一步行动清单：按优先级排序，每项注明“电脑可做 / 需 GitHub Actions / 需真机 / 手机可做”
6. 需要我补充的信息清单

## 约束
- 不要编造仓库、分支、版本号或链接；找不到就写“未找到”。
- 所有关键判断尽量给出来源；没有来源的写“推断”。
- 不要直接给我一大段代码；先给盘点和判断。
- 如果某项需要我提供文件或日志，明确告诉我需要什么、怎么生成。
- 不要因为某一步需要真机或电脑就否定整条路径；请标注清楚所需资源。