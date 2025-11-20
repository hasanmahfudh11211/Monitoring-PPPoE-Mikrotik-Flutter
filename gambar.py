import os
import re
import requests

BASE_URL = "https://mikrotik.com/products"
CDN_PREFIX = "https://cdn.mikrotik.com"
OUTPUT_DIR = "mikrotik_images"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def fetch_all_images():
    print("🔍 Mengambil HTML dari Mikrotik...")
    html = requests.get(BASE_URL, timeout=20).text

    # cari semua gambar dari web-assets/rb_images/
    pattern = r'\/web-assets\/rb_images\/[0-9]+_m\.png'
    matches = sorted(set(re.findall(pattern, html)))

    print(f"📦 Ditemukan {len(matches)} gambar...")

    if not matches:
        print("❌ Tidak ada gambar ditemukan — mungkin butuh render JS (gunakan selenium).")
        return

    success, failed = 0, 0

    for idx, path in enumerate(matches, start=1):
        img_url = f"{CDN_PREFIX}{path}"
        filename = os.path.basename(path)
        save_path = os.path.join(OUTPUT_DIR, filename)

        try:
            res = requests.get(img_url, timeout=15)
            if res.status_code == 200:
                with open(save_path, "wb") as f:
                    f.write(res.content)
                print(f"✅ ({idx}) {filename}")
                success += 1
            else:
                print(f"⚠️ ({idx}) Gagal {filename}: HTTP {res.status_code}")
                failed += 1
        except Exception as e:
            print(f"⚠️ ({idx}) Error {filename}: {e}")
            failed += 1

    print(f"\n🎯 Selesai! {success} berhasil, {failed} gagal.")
    print(f"📁 Gambar tersimpan di: {os.path.abspath(OUTPUT_DIR)}")

if __name__ == "__main__":
    fetch_all_images()
