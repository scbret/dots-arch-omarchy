"""Validation, UI-safety, and Model.js logic tests for steve.spotify."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGIN_DIR = ROOT / "steve.spotify"
MODEL_JS = PLUGIN_DIR / "Model.js"


def run_model_js(expr: str) -> object:
  node = shutil.which("node")
  if not node:
    raise unittest.SkipTest("node is required to execute Model.js unit tests")
  source = MODEL_JS.read_text(encoding="utf-8")
  source = re.sub(r"^\s*\.pragma\s+library\s*\n", "", source)
  harness = f"{source}\nconst __result = ({expr});\nconsole.log(JSON.stringify(__result));\n"
  proc = subprocess.run(
    [node],
    input=harness,
    capture_output=True,
    text=True,
    check=True,
  )
  return json.loads(proc.stdout)


class SpotifyPluginStructureTests(unittest.TestCase):
  def test_omarchy_plugin_validate_passes(self) -> None:
    validator = shutil.which("omarchy-plugin-validate") or shutil.which("omarchy")
    if not validator:
      self.skipTest("omarchy CLI not available")
    cmd = (
      ["omarchy-plugin-validate", str(PLUGIN_DIR)]
      if shutil.which("omarchy-plugin-validate")
      else ["omarchy", "plugin", "validate", str(PLUGIN_DIR)]
    )
    proc = subprocess.run(cmd, capture_output=True, text=True)
    self.assertEqual(proc.returncode, 0, msg=proc.stderr or proc.stdout)

  def test_no_bare_qml_text_elements(self) -> None:
    bare_text = re.compile(r"(^|[^\w.])Text\s*\{", re.MULTILINE)
    for qml in PLUGIN_DIR.glob("*.qml"):
      if qml.name == "PlainText.qml":
        continue
      content = qml.read_text(encoding="utf-8")
      self.assertIsNone(
        bare_text.search(content),
        f"Found bare Text element in {qml.name}; use PlainText instead",
      )

  def test_no_bare_animation_durations(self) -> None:
    bare_duration = re.compile(r"\bduration\s*:\s*\d+")
    for qml in PLUGIN_DIR.glob("*.qml"):
      content = qml.read_text(encoding="utf-8")
      self.assertIsNone(
        bare_duration.search(content),
        f"Found bare duration in {qml.name}; use Style.duration(ms)",
      )


class SpotifyModelTests(unittest.TestCase):
  def test_track_label_and_edge_cases(self) -> None:
    self.assertEqual(run_model_js("formatTrackLabel('Time', 'Pink Floyd')"), "Time  ·  Pink Floyd")
    self.assertEqual(run_model_js("formatTrackLabel('Instrumental', '')"), "Instrumental")
    self.assertEqual(run_model_js("formatTrackLabel('', 'Pink Floyd')"), "Pink Floyd")
    self.assertEqual(run_model_js("formatTrackLabel('', '')"), "")

  def test_tooltip_neutralizes_markup_and_bounds_length(self) -> None:
    evil_title = '<img src="https://example.invalid/t.png">'
    evil_artist = "<b>Band & Co</b>\nLive"
    tooltip = run_model_js(f"formatTooltip({json.dumps(evil_title)}, {json.dumps(evil_artist)})")
    self.assertNotIn("<", tooltip)
    self.assertNotIn(">", tooltip)
    self.assertIn("&lt;img", tooltip)
    self.assertIn("&amp; Co", tooltip)

    long_tooltip = run_model_js(f"formatTooltip({json.dumps('A' * 300)}, {json.dumps('B' * 300)})")
    self.assertLessEqual(len(long_tooltip), 220)


if __name__ == "__main__":
  unittest.main()
