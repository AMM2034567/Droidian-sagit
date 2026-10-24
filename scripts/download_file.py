import os
import sys
import time
import urllib.request
import hashlib

def download_with_resume(url, output_path, expected_sha256=None, max_retries=20):
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    temp_path = output_path + ".part"
    
    # Check existing part size
    downloaded = os.path.getsize(temp_path) if os.path.exists(temp_path) else 0

    retries = 0
    while retries < max_retries:
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            if downloaded > 0:
                req.add_header('Range', f'bytes={downloaded}-')
            
            with urllib.request.urlopen(req, timeout=30) as resp:
                status = resp.status
                total_len = resp.getheader('Content-Length')
                if total_len is not None:
                    total_bytes = downloaded + int(total_len)
                else:
                    total_bytes = None
                
                mode = 'ab' if downloaded > 0 else 'wb'
                with open(temp_path, mode) as f:
                    last_print = time.time()
                    while True:
                        chunk = resp.read(64 * 1024)
                        if not chunk:
                            break
                        f.write(chunk)
                        downloaded += len(chunk)
                        if time.time() - last_print > 2:
                            pct = f"({downloaded/total_bytes*100:.1f}%)" if total_bytes else ""
                            print(f"Downloaded {downloaded / 1024 / 1024:.2f} MB {pct}...")
                            last_print = time.time()
                
                if total_bytes is not None and downloaded < total_bytes:
                    raise ConnectionResetError(f"Incomplete download: {downloaded}/{total_bytes} bytes")
            
            # If we reached here, download completed
            break
        except Exception as e:
            retries += 1
            print(f"[Warning] Download interrupted: {e}. Retrying ({retries}/{max_retries}) from {downloaded / 1024 / 1024:.2f} MB...")
            time.sleep(2)
            if os.path.exists(temp_path):
                downloaded = os.path.getsize(temp_path)

    if os.path.exists(output_path):
        os.remove(output_path)
    os.rename(temp_path, output_path)
    print(f"Download finished: {output_path} ({os.path.getsize(output_path) / 1024 / 1024:.2f} MB)")

    if expected_sha256:
        h = hashlib.sha256()
        with open(output_path, 'rb') as f:
            while chunk := f.read(1024 * 1024):
                h.update(chunk)
        calc_sha = h.hexdigest()
        if calc_sha.lower() == expected_sha256.lower():
            print(f"SHA-256 verification SUCCESS: {calc_sha}")
            return True
        else:
            print(f"SHA-256 MISMATCH! Expected: {expected_sha256}, got: {calc_sha}")
            return False
    return True

if __name__ == '__main__':
    url = sys.argv[1]
    out = sys.argv[2]
    sha = sys.argv[3] if len(sys.argv) > 3 else None
    success = download_with_resume(url, out, sha)
    sys.exit(0 if success else 1)
