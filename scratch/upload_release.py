import urllib.request
import urllib.parse
import json
import os
import sys

TOKEN = "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"
REPO = "BimboMixer-Releases/BimboMixer-Releases"
TAG = "v1.8.50"

headers = {
    "Authorization": f"token {TOKEN}",
    "Accept": "application/vnd.github.v3+json",
    "User-Agent": "Python-urllib"
}

# 1. Check if release already exists for this tag
req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/releases/tags/{TAG}", headers=headers)
release_id = None
upload_url = None

try:
    with urllib.request.urlopen(req) as response:
        release_data = json.loads(response.read().decode())
        release_id = release_data["id"]
        upload_url = release_data["upload_url"].split("{")[0]
        print(f"Release already exists with ID: {release_id}")
        
        # Check and delete existing assets
        assets_url = release_data["assets_url"]
        assets_req = urllib.request.Request(assets_url, headers=headers)
        with urllib.request.urlopen(assets_req) as assets_res:
            existing_assets = json.loads(assets_res.read().decode())
            for asset in existing_assets:
                print(f"Deleting existing asset: {asset['name']} (ID: {asset['id']})")
                del_req = urllib.request.Request(
                    asset["url"],
                    headers=headers,
                    method='DELETE'
                )
                try:
                    urllib.request.urlopen(del_req)
                except Exception as e:
                    print(f"Failed to delete {asset['name']}: {e}")
except urllib.error.HTTPError as e:
    if e.code == 404:
        # 2. Create Release
        payload = json.dumps({
            "tag_name": TAG,
            "name": TAG,
            "body": "Aggiornamento v1.8.50 con fix versione.",
            "draft": False,
            "prerelease": False
        }).encode('utf-8')
        
        create_req = urllib.request.Request(
            f"https://api.github.com/repos/{REPO}/releases",
            data=payload,
            headers=headers,
            method='POST'
        )
        try:
            with urllib.request.urlopen(create_req) as create_response:
                release_data = json.loads(create_response.read().decode())
                release_id = release_data["id"]
                upload_url = release_data["upload_url"].split("{")[0]
                print(f"Created new release with ID: {release_id}")
        except urllib.error.HTTPError as ce:
            print(f"Failed to create release: {ce.code} - {ce.read().decode()}")
            sys.exit(1)
    else:
        print(f"Error fetching release: {e.code} - {e.read().decode()}")
        sys.exit(1)

# 3. Upload Assets
assets = [
    {"path": "build/app/outputs/flutter-apk/app-release.apk", "name": "BimboMixer_v1.8.50.apk", "content_type": "application/vnd.android.package-archive"},
    {"path": "Contabile_App_v1.8.50_Windows.zip", "name": "Contabile_App_v1.8.50_Windows.zip", "content_type": "application/zip"}
]

for asset in assets:
    file_path = asset["path"]
    file_name = asset["name"]
    content_type = asset["content_type"]
    
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        continue
        
    print(f"Uploading {file_name}...")
    with open(file_path, "rb") as f:
        data = f.read()
        
    upload_headers = headers.copy()
    upload_headers["Content-Type"] = content_type
    
    upload_url_with_name = f"{upload_url}?name={file_name}"
    upload_req = urllib.request.Request(
        upload_url_with_name,
        data=data,
        headers=upload_headers,
        method='POST'
    )
    
    try:
        with urllib.request.urlopen(upload_req) as upload_res:
            if upload_res.status == 201:
                print(f"Successfully uploaded {file_name}")
    except urllib.error.HTTPError as ue:
        print(f"Failed to upload {file_name}: {ue.code} - {ue.read().decode()}")
