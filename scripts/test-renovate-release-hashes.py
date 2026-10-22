"""Offline tests against real package layouts; no downloaded binaries execute."""

import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    "release_hashes", Path(__file__).with_name("renovate-release-hashes.py")
)
HOOK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HOOK)
ROOT = Path(__file__).resolve().parent.parent
FAKE = "sha256-" + "A" * 43 + "="


class HashUpdates(unittest.TestCase):
    def fixture(self, dep, root, version="99.1.2"):
        path, pname, _ = HOOK.PACKAGES[dep]
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        text = target.read_text() if target.exists() else (ROOT / path).read_text()
        text, count = re.subn(
            r'(pname\s*=\s*"' + re.escape(pname) + r'";\s*version\s*=\s*")[^"]+',
            lambda m: m[1] + version, text,
        )
        self.assertEqual(count, 1)
        target.write_text(text)
        return {"depName": dep, "packageFile": path, "newValue": version}

    def test_every_supported_package_updates_only_its_hashes(self):
        for dep in HOOK.PACKAGES:
            with self.subTest(dep=dep), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                upgrade = self.fixture(dep, root)
                target = root / upgrade["packageFile"]
                before = target.read_text()
                urls = []
                def fetch(url):
                    urls.append(url)
                    return FAKE
                HOOK.refresh([upgrade], root, fetch)
                after = target.read_text()
                expected = 2 if dep in ("can1357/oh-my-pi", "herdrdev/herdr", "hashicorp/terraform", "openai/codex") else 1
                self.assertEqual(len(urls), expected)
                self.assertEqual(after.count(FAKE), expected)
                self.assertEqual(re.sub(HOOK.HASH, "HASH", before), re.sub(HOOK.HASH, "HASH", after))
                self.assertTrue(all("99.1.2" in url and "${" not in url for url in urls))
                HOOK.refresh([upgrade], root, fetch)
                self.assertEqual(target.read_text(), after)

    def test_failed_second_platform_does_not_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            update = self.fixture("can1357/oh-my-pi", root)
            target = root / update["packageFile"]
            before = target.read_text()
            def fetch(url):
                if "darwin" in url:
                    raise RuntimeError("download failed")
                return FAKE
            with self.assertRaises(RuntimeError):
                HOOK.refresh([update], root, fetch)
            self.assertEqual(target.read_text(), before)

    def test_multiple_updates_in_same_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            upgrades = [self.fixture(dep, root) for dep in ("openai/codex", "hashicorp/terraform")]
            HOOK.refresh(upgrades, root, lambda _: FAKE)
            self.assertEqual((root / HOOK.UPSTREAM).read_text().count(FAKE), 4)

    def test_rejects_wrong_file_and_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            update = self.fixture("stablyai/orca", root)
            for override in ({"packageFile": "../outside.nix"}, {"newValue": "1; touch bad"}, {"newValue": "1.0.0"}):
                with self.assertRaises(ValueError):
                    HOOK.refresh([update | override], root, lambda _: self.fail("must not fetch"))

    def test_config_covers_registry(self):
        config = json.loads((ROOT / "renovate.json").read_text())
        rule = next(r for r in config["packageRules"]
                    if "python3 scripts/renovate-release-hashes.py"
                    in r.get("postUpgradeTasks", {}).get("commands", []))
        self.assertEqual(set(rule["matchDepNames"]), set(HOOK.PACKAGES))
        self.assertEqual(set(rule["postUpgradeTasks"]["fileFilters"]), {p[0] for p in HOOK.PACKAGES.values()})
        manual = next(r for r in config["packageRules"] if "needs-hash" in r.get("addLabels", []))
        self.assertEqual(set(manual["matchDepNames"]), {"!" + dep for dep in HOOK.PACKAGES})


if __name__ == "__main__":
    unittest.main()
