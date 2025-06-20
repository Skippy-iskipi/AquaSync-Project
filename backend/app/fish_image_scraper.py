import os
import time
import requests
import pandas as pd
from PIL import Image
from io import BytesIO
from pathlib import Path
from imagehash import average_hash
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from concurrent.futures import ThreadPoolExecutor
from duckduckgo_search import DDGS

# CONFIG
CSV_PATH = "app/datasets/aquarium_fish_dataset_cleaned_final.csv"
SAVE_DIR = "app/datasets/raw_fish_images"
NUM_IMAGES = 50
MIN_WIDTH = 150
MIN_HEIGHT = 150

# LOAD SPECIES
df = pd.read_csv(CSV_PATH)
FISH_SPECIES = df["Common Name"].dropna().unique().tolist()

# SETUP SELENIUM (Google fallback)
options = Options()
options.add_argument('--headless')
options.add_argument('--disable-gpu')
options.add_argument('--window-size=1920x1080')
driver = webdriver.Chrome(options=options)

def save_image(url, save_path, hashes):
    if not (url.endswith('.jpg') or url.endswith('.jpeg')):
        return False  # Skip non-JPEG images
    try:
        response = requests.get(url, timeout=10)
        img = Image.open(BytesIO(response.content)).convert("RGB")
        img_hash = average_hash(img)
        if img_hash in hashes:
            return False  # Image is a duplicate
        if img.width >= MIN_WIDTH and img.height >= MIN_HEIGHT:
            img.save(save_path)
            hashes.add(img_hash)
            return True
    except Exception as e:
        print(f"Error saving image {url}: {str(e)}")
    return False

def fetch_duckduckgo_images(query):
    results = []
    with DDGS() as ddgs:
        for r in ddgs.images(query, max_results=NUM_IMAGES * 2):
            results.append(r["image"])
    return results

def fetch_google_images(query):
    urls = []
    try:
        driver.get("https://www.google.com/imghp")
        box = driver.find_element(By.NAME, "q")
        box.send_keys(query)
        box.submit()
        time.sleep(2)
        images = driver.find_elements(By.CSS_SELECTOR, "img")
        for img in images:
            src = img.get_attribute("src")
            if src and "http" in src:
                urls.append(src)
            if len(urls) >= NUM_IMAGES * 2:
                break
    except Exception as e:
        print(f"Google scrape error: {e}")
    return urls

def download_images(urls, species, hashes):
    folder = Path(SAVE_DIR) / species.replace(" ", "_")
    folder.mkdir(parents=True, exist_ok=True)
    count = 0
    for url in urls:
        filename = folder / f"{species.replace(' ', '_')}_{count}.jpg"
        if save_image(url, filename, hashes):
            count += 1
        if count >= NUM_IMAGES:
            break
    return count

# Main process
def main():
    hashes = set()
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = []
        for species in FISH_SPECIES:
            print(f"\n🔍 Collecting: {species}")
            urls = fetch_duckduckgo_images(f"{species} fish")
            if len(urls) < NUM_IMAGES:
                urls += fetch_google_images(f"{species} fish")
            future = executor.submit(download_images, urls, species, hashes)
            futures.append(future)
        for future in futures:
            count = future.result()
            print(f"✅ Images saved for species")

    driver.quit()
    print("\n✅ All available species processed with multi-source search.")

if __name__ == "__main__":
    main()
