import json
import re

INPUT_FILE = "router_images_online.json"
OUTPUT_FILE = "router_images_clean.json"

def clean_json():
    print("🧹 Membersihkan file JSON...")
    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)

    cleaned = {}
    for name, url in data.items():
        # Hapus tab/newline
        clean_name = re.sub(r'[\n\t\r]+', ' ', name).strip()
        clean_url = re.sub(r'[\n\t\r]+', '', url).strip()

        # Hapus kata 'NEW' dari nama produk
        clean_name = clean_name.replace("NEW", "").strip()

        # Buang entry URL yang tidak valid
        if not clean_url.startswith("http"):
            continue

        # Hapus duplikat berdasarkan nama unik
        cleaned[clean_name] = clean_url

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(cleaned, f, indent=2, ensure_ascii=False)

    print(f"✅ Berhasil dibersihkan: {len(cleaned)} data disimpan ke {OUTPUT_FILE}")

if __name__ == "__main__":
    clean_json()
