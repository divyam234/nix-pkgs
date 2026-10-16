#!/usr/bin/env python3
"""Download and verify Tern's Linux release using STENCIL_COOKIE."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request


BASE_URL = "https://build.stencil.so"
ARCHES = ("x86_64", "arm64")


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlsplit(newurl).scheme != "https":
            raise RuntimeError("Refusing a non-HTTPS download redirect")
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if urllib.parse.urlsplit(newurl).netloc != urllib.parse.urlsplit(req.full_url).netloc:
            redirected.remove_header("Cookie")
        return redirected


def open_url(url, cookie):
    request = urllib.request.Request(url, headers={
        "Cookie": cookie,
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    })
    return urllib.request.build_opener(SafeRedirect()).open(request, timeout=120)


def select_release(data):
    products = [product for product in data["products"] if product["id"] == "tern"]
    if len(products) != 1 or not products[0].get("access"):
        raise RuntimeError("Stencil account does not have access to Tern")
    release = products[0]["latest"]
    if release["channel"] != "stable" or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", release["version"]):
        raise RuntimeError("Expected a stable Tern semantic version")
    files = []
    for arch in ARCHES:
        matches = [file for file in release["files"]
                   if file["platform"] == "linux" and file["arch"] == arch
                   and file["kind"] == "archive"]
        if len(matches) != 1:
            raise RuntimeError(f"Expected exactly one glibc Linux archive for {arch}")
        file = matches[0]
        if file["name"] != f"Tern-{release['version']}-linux-{arch}.tar.gz":
            raise RuntimeError(f"Unexpected archive name for {arch}")
        if not re.fullmatch(r"[0-9a-f]{64}", file["sha256"]):
            raise RuntimeError(f"Invalid SHA-256 for {arch}")
        url = urllib.parse.urljoin(BASE_URL, file["url"])
        if urllib.parse.urlsplit(url).scheme != "https" or urllib.parse.urlsplit(url).netloc != urllib.parse.urlsplit(BASE_URL).netloc:
            raise RuntimeError("Expected a Stencil download URL")
        files.append((file, url))
    return release, files


def prepare(directory, cookie, repository, force=False):
    with open_url(f"{BASE_URL}/api/products", cookie) as response:
        release, files = select_release(json.load(response))
    version = release["version"]
    tag = f"tern-v{version}"
    existing = subprocess.run(
        ["gh", "api", f"repos/{repository}/releases/tags/{tag}"],
        capture_output=True, text=True,
    )
    if existing.returncode and "HTTP 404" not in existing.stderr:
        raise RuntimeError("Unable to check GitHub release; check GH_TOKEN permissions")
    if not existing.returncode and not force:
        published = json.loads(existing.stdout)
        assets = {asset["name"] for asset in published["assets"]}
        if not published["draft"] and {file["name"] for file, _ in files} <= assets:
            return version, tag, False

    directory.mkdir(parents=True, exist_ok=True)
    checksums = []
    for file, url in files:
        destination = directory / file["name"]
        digest = hashlib.sha256()
        size = 0
        try:
            with open_url(url, cookie) as response, destination.open("wb") as output:
                while chunk := response.read(1024 * 1024):
                    digest.update(chunk)
                    size += len(chunk)
                    output.write(chunk)
            if size != file["size"] or digest.hexdigest() != file["sha256"]:
                raise RuntimeError(f"Size or SHA-256 mismatch for {file['name']}")
        except Exception:
            destination.unlink(missing_ok=True)
            raise
        checksums.append(f"{file['sha256']}  {file['name']}\n")
        print(f"Verified {file['name']}")
    (directory / "checksums.txt").write_text("".join(checksums))
    (directory / "release-notes.md").write_text(
        f"Tern {version}\n\nUpstream build: {release['id']}\n\n"
        f"Source: {BASE_URL}\n\n{release.get('notes', '')}\n"
    )
    return version, tag, True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("dist"))
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    cookie = os.environ.get("STENCIL_COOKIE", "").strip()
    repository = os.environ.get("GITHUB_REPOSITORY", "")
    if not cookie or "\n" in cookie or "\r" in cookie:
        parser.error("STENCIL_COOKIE must contain a single raw Cookie header value")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        parser.error("GITHUB_REPOSITORY must be owner/repository")
    try:
        version, tag, publish = prepare(args.output, cookie, repository, args.force)
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        # Do not print redirect URLs, response bodies, or authentication headers.
        if isinstance(error, urllib.error.HTTPError):
            parser.exit(1, f"Stencil request failed (HTTP {error.code}); check STENCIL_COOKIE and Tern access\n")
        parser.exit(1, f"Tern release preparation failed: {type(error).__name__}\n")
    if output := os.environ.get("GITHUB_OUTPUT"):
        with open(output, "a") as stream:
            stream.write(f"version={version}\ntag={tag}\npublish={str(publish).lower()}\n")
    print(f"{tag}: {'ready to publish' if publish else 'already published'}")


if __name__ == "__main__":
    main()
