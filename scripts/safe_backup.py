import subprocess
import os
import sys
import time
import hashlib
from datetime import datetime

# 保证 Windows 控制台输出不因编码报错
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except:
        pass

PARTITIONS = [
    {"name": "modemst1", "node": "/dev/block/sdf4", "desc": "EFS 串号分区 1 (IMEI 1 / NVRAM)"},
    {"name": "modemst2", "node": "/dev/block/sdf5", "desc": "EFS 串号分区 2 (IMEI 2 / Config)"},
    {"name": "fsg",      "node": "/dev/block/sde34", "desc": "EFS 黄金出厂备份 (Golden Copy)"},
    {"name": "fsc",      "node": "/dev/block/sdf1",  "desc": "EFS 完整性校验与控制"},
    {"name": "persist",  "node": "/dev/block/sda14", "desc": "出厂传感器/陀螺仪/WiFi与蓝牙MAC校准"},
    {"name": "devinfo",  "node": "/dev/block/sde35", "desc": "Bootloader 锁状态与设备信息"},
    {"name": "splash",   "node": "/dev/block/sde38", "desc": "开机第一屏 MI 图标镜像"},
    {"name": "modem",    "node": "/dev/block/sde41", "desc": "高通骁龙 X16 LTE 全网通基带固件"},
    {"name": "boot",     "node": "/dev/block/sde40", "desc": "当前 Android 14 原生内核与启动盘"},
    {"name": "recovery", "node": "/dev/block/sda15", "desc": "当前 Recovery 恢复模式镜像"},
    {"name": "cust",     "node": "/dev/block/sde42", "desc": "当前 Cust / Vendor 底包"},
]

def run_cmd(cmd_list, timeout=120):
    try:
        res = subprocess.run(cmd_list, capture_output=True, text=True, timeout=timeout)
        return res.returncode, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def compute_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest().lower()

def main():
    print("=" * 70)
    print("     Xiaomi Mi 6 (sagit) 核心硬件与系统底包安全备份工具")
    print("=" * 70)

    # 1. 检查 ADB
    code, out, _ = run_cmd(["adb", "devices"])
    if "device" not in out:
        print("[错误] 未检测到处于 ADB 正常开机模式的小米6！请检查连接。")
        sys.exit(1)

    # 2. 检查 Root
    code, out, _ = run_cmd(["adb", "shell", "su -c 'id'"])
    if "uid=0" not in out:
        print("[错误] 手机端未授予 Root 权限或 Magisk 未激活！无法安全提取底层块设备。")
        sys.exit(1)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = os.path.join("backups", f"sagit_hardware_backup_{timestamp}")
    os.makedirs(backup_dir, exist_ok=True)
    device_tmp = "/sdcard/sagit_backup_tmp"

    print(f"\n[INFO] 本地备份目录: {os.path.abspath(backup_dir)}")
    print("[INFO] 开始逐分区安全只读提取与 SHA-256 双重物理对账...\n")

    run_cmd(["adb", "shell", f"mkdir -p {device_tmp}"])

    checksums = []
    success_count = 0

    for idx, p in enumerate(PARTITIONS, 1):
        name = p["name"]
        node = p["node"]
        desc = p["desc"]
        out_filename = f"{name}.img"
        dev_file = f"{device_tmp}/{out_filename}"
        local_file = os.path.join(backup_dir, out_filename)

        print(f"[{idx}/{len(PARTITIONS)}] 正在提取 {name:<10} ({desc})...")
        t0 = time.time()

        # 手机端 dd 提取
        code, out, err = run_cmd(["adb", "shell", f"su -c 'dd if={node} of={dev_file} bs=4096'"], timeout=60)
        if code != 0:
            print(f"  [失败] 无法提取 {node}: {err}")
            continue

        # 手机端计算 SHA256
        code, out, err = run_cmd(["adb", "shell", f"su -c 'sha256sum {dev_file}'"])
        if code != 0 or not out:
            print(f"  [失败] 手机端计算哈希失败: {err}")
            continue
        device_hash = out.split()[0].strip().lower()

        # 拉取到电脑
        code, out, err = run_cmd(["adb", "pull", dev_file, local_file], timeout=180)
        if code != 0 or not os.path.exists(local_file):
            print(f"  [失败] adb pull 传输失败: {err}")
            continue

        # 手机端立即清除临时文件以防占空间
        run_cmd(["adb", "shell", f"su -c 'rm -f {dev_file}'"])

        # 电脑端计算 SHA256 并交叉验证
        local_hash = compute_sha256(local_file)
        file_sz_mb = os.path.getsize(local_file) / (1024 * 1024)
        elapsed = time.time() - t0

        if local_hash == device_hash:
            print(f"  [OK] 校验通过! 大小: {file_sz_mb:.2f} MB | 耗时: {elapsed:.1f}s | SHA256: {local_hash[:16]}...")
            checksums.append(f"{local_hash}  {out_filename}")
            success_count += 1
        else:
            print(f"  [FAIL] 严重警告: {name} 传输校验不一致! 手机: {device_hash} 电脑: {local_hash}")

    # 清理手机临时目录
    run_cmd(["adb", "shell", f"su -c 'rm -rf {device_tmp}'"])

    # 写入校验清单与报告
    chk_file = os.path.join(backup_dir, "checksums.sha256")
    with open(chk_file, "w", encoding="utf-8") as f:
        f.write("\n".join(checksums) + "\n")

    print("\n" + "=" * 70)
    print(f"     备份完成！成功导出并校验 {success_count}/{len(PARTITIONS)} 个关键硬件分区")
    print(f"     备份文件存储路径: {os.path.abspath(backup_dir)}")
    print(f"     哈希清单文件: {os.path.abspath(chk_file)}")
    print("=" * 70)

if __name__ == "__main__":
    main()
