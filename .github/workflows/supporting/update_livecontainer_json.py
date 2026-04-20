import io
import json
import plistlib
import re
import zipfile
from datetime import datetime

import requests

bundle_id = "app.aidoku.Aidoku"
minimum_ios_version = "15.0"
json_file_name = ".github/workflows/supporting/livecontainer/apps.json"
github_repo = "Aidoku/Aidoku"


def fetch_latest_release(repo):
    api_url = f"https://api.github.com/repos/{repo}/releases"
    headers = {
        "Accept": "application/vnd.github+json",
    }
    try:
        response = requests.get(api_url, headers=headers)
        response.raise_for_status()
        releases = response.json()
        if len(releases) == 0:
            raise ValueError("No release found.")

        sorted_releases = sorted(
            releases,
            key=lambda release: datetime.strptime(
                release["published_at"], "%Y-%m-%dT%H:%M:%SZ"
            ),
            reverse=True,
        )
        filtered_sorted_releases = list(
            filter(
                lambda release: release["draft"] == False,
                sorted_releases,
            )
        )
        if len(filtered_sorted_releases) == 0:
            raise ValueError("An error occurred while sorting and filtering releases.")

        return filtered_sorted_releases[0]
    except requests.RequestException as e:
        print(f"Error fetching releases: {e}")
        raise


def prepare_description(text):
    text = re.sub("<[^<]+?>", "", text)
    text = re.sub(r"#{1,6}\s?", "", text)
    text = re.sub(r"\*{2}", "", text)
    text = re.sub(r"(?<=\r|\n)-", "•", text)
    text = re.sub(r"`", '"', text)
    text = re.sub(r"\r\n\r\n", "\r \n", text)
    text = re.sub(r"\r\n", "\n", text)
    return text


def get_ipa_version_and_build(ipa_path):
    with zipfile.ZipFile(ipa_path, "r") as ipa:
        info_plist_path = None
        for name in ipa.namelist():
            if (
                name.startswith("Payload/")
                and name.count("/") == 2
                and name.endswith(".app/Info.plist")
            ):
                info_plist_path = name
                break
        if not info_plist_path:
            raise FileNotFoundError("Info.plist not found in IPA")

        with ipa.open(info_plist_path) as plist_file:
            plist_data = plist_file.read()
            plist = plistlib.load(io.BytesIO(plist_data))

        version = plist.get("CFBundleShortVersionString")
        build = plist.get("CFBundleVersion")
        return version, build


def update_json_file(json_file, repo):
    latest_release = fetch_latest_release(repo)
    try:
        with open(json_file, "r") as file:
            data = json.load(file)
    except json.JSONDecodeError as e:
        print(f"Error reading JSON file: {e}")
        raise

    if "apps" not in data:
        print(f'There is no "apps" key in {json_file}.')
        raise ValueError("Missing apps key")

    apps_data = data["apps"]
    if len(apps_data) == 0:
        print(f'There is no data for "apps" key in {json_file}.')
        raise ValueError("Empty apps array")

    app = apps_data[0]
    if "versions" not in app:
        app["versions"] = []

    if "assets" not in latest_release:
        print('There is no "assets" key in latest release JSON.')
        raise ValueError("No assets in release")

    assets = latest_release["assets"]
    if len(assets) == 0:
        print("There are no assets in latest release JSON.")
        raise ValueError("Empty assets")

    asset_to_use = None
    for asset in assets:
        if asset["name"].endswith(".ipa"):
            asset_to_use = asset
            break

    if asset_to_use is None:
        print(".ipa file is not found in assets")
        raise ValueError("No IPA found")

    data["featuredApps"] = [bundle_id]
    app["bundleIdentifier"] = bundle_id

    download_url = asset_to_use["browser_download_url"]
    size = asset_to_use["size"]

    # Download IPA and read version/build from Info.plist
    # This is the authoritative source for version, since nightly tags
    # (e.g. "nightly") don't contain a version number.
    ipa_response = requests.get(download_url)
    ipa_response.raise_for_status()
    with open("temp.ipa", "wb") as ipa_file:
        ipa_file.write(ipa_response.content)
    version, build = get_ipa_version_and_build("temp.ipa")

    version_entry_exists = any(
        item["version"] == version and item.get("buildVersion") == build
        for item in app["versions"]
    )
    if not version_entry_exists:
        version_date = latest_release["published_at"]
        date_obj = datetime.strptime(version_date, "%Y-%m-%dT%H:%M:%SZ")
        version_date_short = date_obj.strftime("%Y-%m-%d")

        description = latest_release["body"] or ""
        keyphrase = "Aidoku Release Information"
        if keyphrase in description:
            description = description.split(keyphrase, 1)[1].strip()

        description = prepare_description(description)

        version_entry = {
            "version": version,
            "date": version_date_short,
            "localizedDescription": description,
            "downloadURL": download_url,
            "size": size,
            "minOSVersion": minimum_ios_version,
            "buildVersion": build,
        }
        app["versions"].insert(0, version_entry)

        # Update top-level app fields for LiveContainer compatibility
        app["version"] = version
        app["versionDate"] = latest_release["published_at"]
        app["versionDescription"] = description
        app["downloadURL"] = download_url
        app["size"] = size

        try:
            with open(json_file, "w") as file:
                json.dump(data, file, indent=2)
            print("JSON file updated successfully.")
        except IOError as e:
            print(f"Error writing to JSON file: {e}")
            raise
    else:
        print("No need to update JSON")


def main():
    try:
        update_json_file(json_file_name, github_repo)
    except Exception as e:
        print(f"An error occurred: {e}")
        raise


if __name__ == "__main__":
    main()
