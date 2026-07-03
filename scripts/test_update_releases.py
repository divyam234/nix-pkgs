import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SPEC = importlib.util.spec_from_file_location(
    "update_releases", Path(__file__).with_name("update-releases.py")
)
update_releases = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(update_releases)


class UpdateReleasesTests(unittest.TestCase):
    def test_asset_pattern_requires_exactly_one_match(self):
        assets = {"tool-1.2.3-linux-amd64.tar.gz": {}, "tool-1.2.3-linux-amd64-debug.tar.gz": {}}
        with self.assertRaisesRegex(RuntimeError, "multiple assets"):
            update_releases.resolve_asset_name(
                assets,
                {"pattern": r"^tool-{version}-linux-amd64.*\.tar\.gz$"},
                "1.2.3",
            )

    def test_asset_pattern_substitutes_version(self):
        name = update_releases.resolve_asset_name(
            {"tool-v1.2.3-linux-amd64.tar.gz": {}},
            {"pattern": r"^tool-v{version}-linux-amd64\.tar\.gz$"},
            "1.2.3",
        )
        self.assertEqual(name, "tool-v1.2.3-linux-amd64.tar.gz")

    def test_select_release_ignores_drafts_and_prereleases(self):
        releases = [
            {"tag_name": "v3.0.0", "draft": True, "prerelease": False},
            {"tag_name": "v2.0.0", "draft": False, "prerelease": True},
            {"tag_name": "v1.5.0", "draft": False, "prerelease": False},
        ]
        selected = update_releases.select_release(releases, {"tagPrefix": "v"})
        self.assertEqual(selected["tag_name"], "v1.5.0")

    def test_select_release_uses_highest_semver_not_api_order(self):
        releases = [
            {"tag_name": "v1.9.0", "draft": False, "prerelease": False},
            {"tag_name": "v1.10.0", "draft": False, "prerelease": False},
        ]
        selected = update_releases.select_release(releases, {"tagPrefix": "v"})
        self.assertEqual(selected["tag_name"], "v1.10.0")

    def test_prepare_update_refuses_downgrade(self):
        package = '''let
  version = "2.0.0";
  sources = {
    x86_64-linux = {
      asset = "tool.tar.gz";
      hash = "sha256-old";
    };
  };
in null
'''
        release = {
            "tag_name": "v1.0.0",
            "draft": False,
            "prerelease": False,
            "assets": [],
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "default.nix"
            path.write_text(package)
            config = {
                "repo": "owner/tool",
                "file": "default.nix",
                "tagPrefix": "v",
                "assets": {"x86_64-linux": {"name": "tool.tar.gz"}},
            }
            with mock.patch.object(update_releases, "run_gh_releases", return_value=[release]):
                with self.assertRaisesRegex(RuntimeError, "refusing to downgrade"):
                    update_releases.prepare_update(root, "tool", config)


if __name__ == "__main__":
    unittest.main()
