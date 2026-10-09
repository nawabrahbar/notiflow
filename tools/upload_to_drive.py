#!/usr/bin/env python3
"""
Automated Google Drive Uploader for Notification Handler Builds.
Target Folders:
- APK Folder: 1dtQcJCng75eTqdr7YtRv3AWWbiwupj-K
- iOS Folder: 1O9YFeyV_sABnnyTJkCAmCzoKkGJtsj8X
"""

import os
import sys

APK_FOLDER_ID = "1dtQcJCng75eTqdr7YtRv3AWWbiwupj-K"
IOS_FOLDER_ID = "1O9YFeyV_sABnnyTJkCAmCzoKkGJtsj8X"

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RELEASE_DIR = os.path.join(PROJECT_ROOT, "release_builds")

def main():
    print(f"Build artifacts directory: {RELEASE_DIR}")
    for item in os.listdir(RELEASE_DIR):
        item_path = os.path.join(RELEASE_DIR, item)
        size_mb = os.path.getsize(item_path) / (1024 * 1024)
        print(f" - {item} ({size_mb:.1f} MB)")
    print("\nGoogle Drive Destinations:")
    print(f" - APK Folder: https://drive.google.com/drive/folders/{APK_FOLDER_ID}")
    print(f" - iOS Folder: https://drive.google.com/drive/folders/{IOS_FOLDER_ID}")

if __name__ == "__main__":
    main()
