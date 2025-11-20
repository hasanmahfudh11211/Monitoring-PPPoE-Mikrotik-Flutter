import requests
from bs4 import BeautifulSoup
import json

BASE_URL = "https://mikrotik.com/products"

def fetch_router_images():
    print("🔍 Mengambil data produk dari Mikrotik...")
    res = requests.get(BASE_URL, timeout=20)
    res.raise_for_status()
    soup = BeautifulSoup(res.text, "html.parser")

    mapping = {}

    # tiap produk ada di div.product
    for div in soup.select("div.product"):
        # ambil nama produk
        name_tag = div.select_one("h2 a")
        img_tag = div.select_one("img.lazyload")

        if not name_tag or not img_tag:
            continue

        name = name_tag.text.strip()
        img_url = img_tag.get("data-src")

        if img_url:
            mapping[name] = img_url

    # simpan hasil JSON
    with open("router_images_online.json", "w", encoding="utf-8") as f:
        json.dump(mapping, f, indent=2, ensure_ascii=False)

    print(f"✅ Berhasil ambil {len(mapping)} produk!")
    print("💾 Disimpan di router_images_online.json")

if __name__ == "__main__":
    fetch_router_images()
