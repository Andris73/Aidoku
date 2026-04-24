import io
import json
import os
import plistlib
import re
import zipfile
from datetime import datetime

import requests

bundle_id = "app.aidoku.Aidoku"
minimum_ios_version = "15.0"
json_file_name = ".github/workflows/supporting/livecontainer/apps.json"
github_repo = os.environ.get("GITHUB_REPOSITORY", "Aidoku/Aidoku")
github_token = os.environ.get("GITHUB_TOKEN", "")
release_tag = os.environ.get("RELEASE_TAG", "").strip()


def _auth_headers():
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if github_token:
        headers["Authorization"] = f"Bearer {github_token}"
    return headers


def fetch_release_by_tag(repo, tag):
    """Fetch a specific release by its tag name."""
    api_url = f"https://api.github.com/repos/{repo}/releases/tags/{tag}"
    response = requests.get(api_url, headers=_auth_headers())
    response.raise_for_status()
    return response.json()


def fetch_latest_release(repo):
    """Fetch the most recently *updated* non-draft release.

    Using ``updated_at`` instead of ``published_at`` matters for nightly
    builds: ``softprops/action-gh-release`` updates an existing release
    (keeping its ``published_at``) but bumps ``updated_at`` every time a
    new IPA is uploaded.
    """
    api_url = f"https://api.github.com/repos/{repo}/releases"
    response = requests.get(api_url, headers=_auth_headers())
    response.raise_for_status()
    releases = [r for r in response.json() if not r.get("draft", False)]
    if not releases:
        raise ValueError("No non-draft releases found.")

    def _sort_key(release):
        return datetime.strptime(
            release.get("updated_at") or release["published_at"],
            "%Y-%m-%dT%H:%M:%SZ",
        )

    releases.sort(key=_sort_key, reverse=True)
    return releases[0]


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


def pick_ipa_asset(assets):
    """Pick the most recently-created .ipa asset.

    A release can accumulate multiple .ipa assets over time (nightly
    builds keep the same tag and each new build uploads a new file). We
    want the newest one, so sort by ``created_at`` descending.
    """
    ipa_assets = [a for a in assets if a["name"].lower().endswith(".ipa")]
    if not ipa_assets:
        return None

    def _created_at(asset):
        return datetime.strptime(asset["created_at"], "%Y-%m-%dT%H:%M:%SZ")

    ipa_assets.sort(key=_created_at, reverse=True)
    return ipa_assets[0]


def update_json_file(json_file, repo):
    if release_tag:
        print(f"Fetching release by tag: {release_tag}")
        latest_release = fetch_release_by_tag(repo, release_tag)
    else:
        print("No RELEASE_TAG provided; falling back to most recently updated release")
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

    assets = latest_release.get("assets") or []
    if len(assets) == 0:
        print("There are no assets in the selected release.")
        raise ValueError("Empty assets")

    asset_to_use = pick_ipa_asset(assets)
    if asset_to_use is None:
        print(".ipa file is not found in assets")
        raise ValueError("No IPA found")

    print(
        f"Using asset '{asset_to_use['name']}' "
        f"(created {asset_to_use.get('created_at')}) "
        f"from release '{latest_release.get('tag_name')}'"
    )

    data["featuredApps"] = [bundle_id]
    app["bundleIdentifier"] = bundle_id

    download_url = asset_to_use["browser_download_url"]
    size = asset_to_use["size"]

    # Download IPA and read version/build from Info.plist. This is the
    # authoritative source for version+build, since nightly tags (e.g.
    # "nightly") don't contain a version number.
    ipa_response = requests.get(download_url)
    ipa_response.raise_for_status()
    with open("temp.ipa", "wb") as ipa_file:
        ipa_file.write(ipa_response.content)
    version, build = get_ipa_version_and_build("temp.ipa")

    version_entry_exists = any(
        item["version"] == version and item.get("buildVersion") == build
        for item in app["versions"]
    )
    # Nightly builds often share the same marketing version across
    # different commits; the build number is what distinguishes them.
    # Key history entries by build so consecutive nightlies don't
    # silently collapse into a single entry.
    if not version_entry_exists:
        # Prefer the asset's own upload time for the date (matches when
        # the IPA was actually produced, not when the release was first
        # created).
        version_date_iso = (
            asset_to_use.get("created_at")
            or latest_release.get("updated_at")
            or latest_release["published_at"]
        )
        date_obj = datetime.strptime(version_date_iso, "%Y-%m-%dT%H:%M:%SZ")
        version_date_short = date_obj.strftime("%Y-%m-%d")

        description = latest_release.get("body") or ""
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

        # Keep the versions list bounded so the source doesn't grow
        # without limit for nightly channels.
        max_versions = 25
        if len(app["versions"]) > max_versions:
            app["versions"] = app["versions"][:max_versions]

        # Update top-level app fields for LiveContainer compatibility.
        app["version"] = version
        app["versionDate"] = version_date_iso
        app["versionDescription"] = description
        app["downloadURL"] = download_url
        app["size"] = size

        try:
            with open(json_file, "w") as file:
                json.dump(data, file, indent=2)
            print(
                f"JSON file updated: version={version} build={build} "
                f"url={download_url}"
            )
        except IOError as e:
            print(f"Error writing to JSON file: {e}")
            raise
    else:
        print(
            f"Version {version} build {build} already present in apps.json; "
            "no changes needed."
        )


def main():
    try:
        update_json_file(json_file_name, github_repo)
    except Exception as e:
        print(f"An error occurred: {e}")
        raise


if __name__ == "__main__":
    main()
