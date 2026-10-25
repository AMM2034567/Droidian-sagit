import subprocess
import json

def run_adb_root(cmd):
    try:
        res = subprocess.run(
            ["adb", "shell", f"su -c '{cmd}'"],
            capture_output=True,
            text=True,
            timeout=10
        )
        return res.stdout.strip()
    except Exception as e:
        return f"Error: {e}"

def run_adb(cmd):
    try:
        res = subprocess.run(
            ["adb", "shell", cmd],
            capture_output=True,
            text=True,
            timeout=10
        )
        return res.stdout.strip()
    except Exception as e:
        return f"Error: {e}"

print("=" * 60)
print("     Xiaomi Mi 6 (sagit) 深度硬件与系统只读诊断报告")
print("=" * 60)

# 1. 基础系统
print("\n[1] 系统与平台基本信息")
print("  - 机型型号:", run_adb("getprop ro.product.model"))
print("  - 机型代号:", run_adb("getprop ro.product.device"))
print("  - Android 版本:", run_adb("getprop ro.build.version.release"))
print("  - 安全补丁版本:", run_adb("getprop ro.build.version.security_patch"))
print("  - 当前内核版本:", run_adb("uname -r -v"))
print("  - 当前基带版本:", run_adb("getprop gsm.version.baseband"))

# 2. 闪存字库 (UFS)
print("\n[2] UFS 闪存芯片 (字库)")
vendor = run_adb_root("cat /sys/block/sda/device/vendor")
model = run_adb_root("cat /sys/block/sda/device/model")
rev = run_adb_root("cat /sys/block/sda/device/rev")
size_sec = run_adb_root("cat /sys/block/sda/size")
try:
    size_gb = int(size_sec) * 512 / (1024**3)
    size_str = f"{size_gb:.1f} GB"
except:
    size_str = "未知"
print(f"  - 制造厂商: {vendor}")
print(f"  - 颗粒型号: {model}")
print(f"  - 固件版本: {rev}")
print(f"  - 标称容量: {size_str}")

# 3. 屏幕与触控面板
print("\n[3] 屏幕与显示控制器")
cmdline = run_adb_root("cat /proc/cmdline")
panel = "未知"
for part in cmdline.split():
    if "panel" in part.lower() or "mdss" in part.lower():
        panel = part
        break
print(f"  - Bootloader 传递的屏幕驱动: {panel}")

# 4. 电池与供电健康
print("\n[4] 电池与供电状况")
cap = run_adb_root("cat /sys/class/power_supply/battery/capacity")
health = run_adb_root("cat /sys/class/power_supply/battery/health")
volt = run_adb_root("cat /sys/class/power_supply/battery/voltage_now")
temp = run_adb_root("cat /sys/class/power_supply/battery/temp")
try:
    volt_v = float(volt) / 1000000.0
    volt_str = f"{volt_v:.3f} V"
except:
    volt_str = volt
try:
    temp_c = float(temp) / 10.0
    temp_str = f"{temp_c:.1f} ℃"
except:
    temp_str = temp
print(f"  - 剩余电量: {cap} %")
print(f"  - 电池健康: {health}")
print(f"  - 当前电压: {volt_str}")
print(f"  - 电池温度: {temp_str}")

# 5. 关键硬件分区节点与容量
print("\n[5] 关键安全与硬件分区定位 (只读)")
parts = [
    ("modemst1 (EFS串号1)", "/dev/block/sdf4"),
    ("modemst2 (EFS串号2)", "/dev/block/sdf5"),
    ("fsg (EFS黄金备份)", "/dev/block/sde34"),
    ("fsc (EFS控制)", "/dev/block/sdf1"),
    ("persist (传感器/MAC校准)", "/dev/block/sda14"),
    ("modem (高通基带驱动)", "/dev/block/sde41"),
    ("boot (当前内核启动盘)", "/dev/block/sde40"),
    ("cust (原厂商定制/Vendor)", "/dev/block/sde42"),
    ("recovery (当前恢复模式)", "/dev/block/sda15"),
]

for name, node in parts:
    size = run_adb_root(f"blockdev --getsize64 {node} 2>/dev/null")
    try:
        size_mb = float(size) / (1024*1024)
        print(f"  - {name:<26} -> {node:<18} (大小: {size_mb:.2f} MB)")
    except:
        print(f"  - {name:<26} -> {node:<18} (大小: {size})")

print("\n" + "=" * 60)
print("     诊断完毕：所有操作均为只读查询，未进行任何改写")
print("=" * 60)
