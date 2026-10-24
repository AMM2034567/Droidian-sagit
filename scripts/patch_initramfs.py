import os
import urllib.request

overlay_dir = os.path.join('kernel', 'debian', 'initramfs-overlay', 'scripts')
os.makedirs(overlay_dir, exist_ok=True)

url = 'https://raw.githubusercontent.com/droidian/initramfs-tools-halium/droidian/scripts/halium'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
content = urllib.request.urlopen(req).read().decode('utf-8')

# Inject cust partition into vendor_images search list for sagit
target = 'vendor_images="/tmpmnt/vendor.img'
replacement = 'vendor_images="/dev/disk/by-partlabel/cust /dev/block/sde42 /tmpmnt/vendor.img'

if target in content:
    content = content.replace(target, replacement, 1)
    target_path = os.path.join(overlay_dir, 'halium')
    with open(target_path, 'w', newline='\n', encoding='utf-8') as f:
        f.write(content)
    print("Successfully patched scripts/halium with sagit cust support!")
else:
    print("Warning: target string not found in scripts/halium")
