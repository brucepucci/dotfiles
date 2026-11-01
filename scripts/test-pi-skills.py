#!/usr/bin/env python3
"""Offline tests for the explicit, reviewable two-skill refresh command."""

import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("pi_skills_sync", ROOT / "scripts/pi-skills-sync.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class SkillSyncTests(unittest.TestCase):
    def setUp(self):
        self.files = {name: (ROOT / "vendor/pi-skills" / name).read_bytes()
                      for name in sync.FILES}

    def test_committed_snapshot_has_exact_sources_and_hashes(self):
        sync.validate(self.files)
        metadata = json.loads((ROOT / "vendor/pi-skills/SOURCE.json").read_text())
        self.assertEqual(metadata["repository"], sync.REPOSITORY)
        self.assertRegex(metadata["commit"], r"^[0-9a-f]{40}$")
        self.assertEqual(set(metadata["files"]), set(self.files))
        for name, content in self.files.items():
            self.assertEqual(metadata["files"][name]["upstream_path"], sync.FILES[name])
            self.assertEqual(metadata["files"][name]["sha256"],
                             hashlib.sha256(content).hexdigest())

    def test_refresh_is_deterministic_and_preserves_unrelated_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            other = root / "unrelated"
            other.write_text("keep me")
            sync.write_snapshot(root, "a" * 40, self.files)
            before = (root / "vendor/pi-skills/SOURCE.json").read_bytes()
            sync.write_snapshot(root, "a" * 40, self.files)
            self.assertEqual(before, (root / "vendor/pi-skills/SOURCE.json").read_bytes())
            self.assertEqual(other.read_text(), "keep me")
            self.assertEqual(list(root.glob('.pi-skills-sync-*')), [])

    def test_changed_wrapper_fails_without_replacing_old_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sync.write_snapshot(root, "a" * 40, self.files)
            before = (root / "vendor/pi-skills/SOURCE.json").read_bytes()
            changed = dict(self.files)
            changed["grill-me/SKILL.md"] = changed["grill-me/SKILL.md"].replace(
                sync.DELEGATION.encode(), b"Run a different workflow.")
            with self.assertRaisesRegex(ValueError, "wrapper changed"):
                sync.write_snapshot(root, "b" * 40, changed)
            self.assertEqual(before, (root / "vendor/pi-skills/SOURCE.json").read_bytes())

    def test_download_failure_preserves_old_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sync.write_snapshot(root, "a" * 40, self.files)
            before = (root / "vendor/pi-skills/SOURCE.json").read_bytes()
            with patch.object(sync, "ROOT", root), patch("sys.argv", ["sync", "--ref", "b" * 40]):
                with patch.object(sync, "fetch", side_effect=OSError("offline")):
                    with self.assertRaises(OSError):
                        sync.main()
            self.assertEqual(before, (root / "vendor/pi-skills/SOURCE.json").read_bytes())

    def test_partial_snapshot_rejected(self):
        del self.files["grilling/SKILL.md"]
        with self.assertRaises(ValueError):
            sync.validate(self.files)

    def test_new_local_reference_requires_review(self):
        self.files["grilling/SKILL.md"] += b"\nRead [details](./new-file.md).\n"
        with self.assertRaisesRegex(ValueError, "bundled reference"):
            sync.validate(self.files)

    def test_user_only_flag_cannot_silently_disappear(self):
        self.files["grill-me/SKILL.md"] = self.files["grill-me/SKILL.md"].replace(
            b"disable-model-invocation: true", b"disable-model-invocation: false")
        with self.assertRaisesRegex(ValueError, "user-invoked"):
            sync.validate(self.files)

    def test_changed_license_requires_review(self):
        self.files["LICENSE"] = b"Different license\n"
        with self.assertRaisesRegex(ValueError, "license changed"):
            sync.validate(self.files)

    def test_license_body_change_requires_review_even_with_mit_heading(self):
        self.files["LICENSE"] += b"\nAdditional restrictions.\n"
        with self.assertRaisesRegex(ValueError, "license changed"):
            sync.validate(self.files)

    def test_moving_ref_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                sync.write_snapshot(Path(tmp), "main", self.files)


if __name__ == "__main__":
    unittest.main()
