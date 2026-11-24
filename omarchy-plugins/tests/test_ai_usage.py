"""Validation, UI-safety, and Model.js logic tests for steve.ai-usage."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGIN_DIR = ROOT / "steve.ai-usage"
MODEL_JS = PLUGIN_DIR / "Model.js"
I18N_EN = PLUGIN_DIR / "i18n" / "en.json"


def run_model_js(expr: str) -> object:
  """Evaluate a JS expression against Model.js using node."""
  node = shutil.which("node")
  if not node:
    raise unittest.SkipTest("node is required to execute Model.js unit tests")
  source = MODEL_JS.read_text(encoding="utf-8")
  # Strip QML pragma header so Node can load the pure JS library cleanly.
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


class PluginStructureTests(unittest.TestCase):
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

  def test_all_translation_keys_exist(self) -> None:
    catalog = json.loads(I18N_EN.read_text(encoding="utf-8"))
    key_pattern = re.compile(r'strings\.tn?\(\s*"([^"]+)"')
    referenced: set[str] = set()
    for qml in PLUGIN_DIR.glob("*.qml"):
      referenced.update(key_pattern.findall(qml.read_text(encoding="utf-8")))
    self.assertTrue(referenced, "Expected at least one translation lookup")
    missing = sorted(referenced - set(catalog.keys()))
    self.assertEqual(missing, [], f"Missing i18n keys in en.json: {missing}")

  def test_no_bare_qml_text_elements(self) -> None:
    """Every display Text element must use PlainText (or set textFormat: Text.PlainText)."""
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
    """All animation durations must go through Style.duration(...)."""
    bare_duration = re.compile(r"\bduration\s*:\s*\d+")
    for qml in PLUGIN_DIR.glob("*.qml"):
      content = qml.read_text(encoding="utf-8")
      self.assertIsNone(
        bare_duration.search(content),
        f"Found bare duration in {qml.name}; use Style.duration(ms)",
      )

  def test_refresh_script_syntax_and_fixed_https(self) -> None:
    script = PLUGIN_DIR / "refresh-quotas.py"
    self.assertTrue(script.is_file())
    source = script.read_text(encoding="utf-8")
    compile(source, str(script), "exec")
    self.assertIn('CLOUD_CODE_BASE = "https://daily-cloudcode-pa.googleapis.com"', source)
    self.assertIn("sys.dont_write_bytecode = True", source)


class ModelLogicTests(unittest.TestCase):
  def test_parse_record_normal_and_extra_limits(self) -> None:
    now_ms = 1_760_000_000_000
    record_json = json.dumps({
      "id": "agy",
      "name": "Antigravity",
      "tierLabel": "Pro",
      "limitsStale": False,
      "limitsFetchedAt": now_ms - 120_000,
      "limits": [
        {
          "title": "Session",
          "label": "Session (5-hour)",
          "percent": 0.124,
          "resetsAt": "2025-10-10T10:00:00+00:00",
        },
        {
          "title": "Weekly",
          "label": "Weekly (7-day)",
          "percent": 0.456,
          "resetsAt": "2025-10-15T10:00:00+00:00",
        },
        {
          "title": "Claude/GPT Weekly",
          "label": "Claude/GPT Weekly",
          "percent": 0.88,
          "resetsAt": "2025-10-15T10:00:00+00:00",
        },
      ],
    })
    res = run_model_js(f"parseRecord({json.dumps(record_json)}, 'agy', 'Antigravity', {now_ms})")
    self.assertTrue(res["hasFile"])
    self.assertEqual(res["tierLabel"], "Pro")
    self.assertEqual(res["fetchedAtMs"], now_ms - 120_000)
    self.assertFalse(res["stale"])
    self.assertEqual(res["session"]["used"], 12)
    self.assertEqual(res["session"]["remaining"], 88)
    self.assertEqual(res["weekly"]["used"], 46)
    self.assertEqual(res["weekly"]["remaining"], 54)
    self.assertEqual(len(res["extraLimits"]), 1)
    self.assertEqual(res["extraLimits"][0]["title"], "Claude/GPT Weekly")
    self.assertEqual(res["extraLimits"][0]["remaining"], 12)

  def test_parse_claude_label_only_and_stale_flag(self) -> None:
    now_ms = 1_760_000_000_000
    record_json = json.dumps({
      "id": "claude",
      "name": "Claude Code",
      "limitsStale": True,
      "limitsFetchedAt": now_ms - 60_000,
      "limits": [
        {"label": "Session (5-hour)", "percent": 0.02, "resetsAt": "2026-11-24T17:39:59+00:00"},
        {"label": "Weekly (7-day)", "percent": 0.26, "resetsAt": "2026-11-29T11:59:59+00:00"},
      ],
    })
    res = run_model_js(f"parseRecord({json.dumps(record_json)}, 'claude', 'Claude Code', {now_ms})")
    self.assertTrue(res["stale"])
    self.assertEqual(res["session"]["remaining"], 98)
    self.assertEqual(res["weekly"]["remaining"], 74)
    self.assertEqual(run_model_js(f"lowestRemaining({json.dumps(res)})"), 74)

  def test_reset_passed_window_reads_full_remaining(self) -> None:
    now_ms = 1_760_000_000_000
    past_iso = "2020-01-01T00:00:00+00:00"
    record_json = json.dumps({
      "id": "claude",
      "name": "Claude Code",
      "limits": [
        {"title": "Session", "label": "Session (5-hour)", "percent": 0.92, "resetsAt": past_iso},
      ],
    })
    res = run_model_js(f"parseRecord({json.dumps(record_json)}, 'claude', 'Claude Code', {now_ms})")
    self.assertEqual(res["session"]["used"], 0)
    self.assertEqual(res["session"]["remaining"], 100)
    self.assertTrue(res["session"]["resetPassed"])

  def test_severity_thresholds_for_remaining(self) -> None:
    self.assertEqual(run_model_js("severityForRemaining(null, 40, 15)"), "none")
    self.assertEqual(run_model_js("severityForRemaining(100, 40, 15)"), "ok")
    self.assertEqual(run_model_js("severityForRemaining(41, 40, 15)"), "ok")
    self.assertEqual(run_model_js("severityForRemaining(40, 40, 15)"), "warn")
    self.assertEqual(run_model_js("severityForRemaining(16, 40, 15)"), "warn")
    self.assertEqual(run_model_js("severityForRemaining(15, 40, 15)"), "critical")
    self.assertEqual(run_model_js("severityForRemaining(0, 40, 15)"), "critical")

  def test_markup_neutralization_and_bounds(self) -> None:
    evil = '<img src="https://example.invalid/tracker">\n<b>boom</b>'
    sanitized = run_model_js(f"neutralizeMarkup({json.dumps(evil)}, 120)")
    self.assertNotIn("<", sanitized)
    self.assertNotIn(">", sanitized)
    self.assertIn("&lt;img", sanitized)

    tooltip = run_model_js(
      "buildTooltipSummary("
      "{ session: null, weekly: null, usageStatusText: '<img src=\"x\">' },"
      "{ session: { remaining: 90 }, weekly: { remaining: 75 } },"
      "'AG', 'CL')"
    )
    self.assertNotIn("<img", tooltip)
    self.assertIn("&lt;img", tooltip)
    self.assertIn("CL 90% / 75%", tooltip)

    huge = json.dumps({"id": "agy", "pad": "x" * 600_000})
    res = run_model_js(f"parseRecord({json.dumps(huge)}, 'agy', 'Antigravity', 1760000000000)")
    self.assertFalse(res["hasFile"])

    many = json.dumps({
      "id": "agy",
      "limits": [{"title": f"W{i}", "percent": 0.1} for i in range(40)],
    })
    res_many = run_model_js(f"parseRecord({json.dumps(many)}, 'agy', 'Antigravity', 1760000000000)")
    self.assertEqual(len(res_many["limits"]), 16)

  def test_countdown_and_age_formatting(self) -> None:
    now = 1_760_000_000_000
    self.assertEqual(run_model_js(f"formatCountdown({now - 5000}, {now})"), "now")
    self.assertEqual(run_model_js(f"formatCountdown({now + 30_000}, {now})"), "<1m")
    self.assertEqual(run_model_js(f"formatCountdown({now + 42 * 60_000}, {now})"), "42m")
    self.assertEqual(run_model_js(f"formatCountdown({now + (3 * 60 + 15) * 60_000}, {now})"), "3h 15m")
    self.assertEqual(run_model_js(f"formatCountdown({now + (4 * 24 + 6) * 3_600_000}, {now})"), "4d 6h")

    self.assertEqual(run_model_js(f"describeAge({now - 20_000}, {now})")["kind"], "justNow")
    self.assertEqual(run_model_js(f"describeAge({now - 12 * 60_000}, {now})"), {"kind": "minutes", "a": 12, "b": 0})
    self.assertEqual(run_model_js(f"describeAge({now - 90 * 60_000}, {now})"), {"kind": "hoursMinutes", "a": 1, "b": 30})
    self.assertEqual(run_model_js(f"describeAge({now - 2 * 3_600_000}, {now})"), {"kind": "hours", "a": 2, "b": 0})
    self.assertEqual(run_model_js(f"describeAge({now - 3 * 86_400_000}, {now})"), {"kind": "days", "a": 3, "b": 0})

  def test_startup_refresh_and_theme_colors(self) -> None:
    now = 1_760_000_000_000
    fresh_agy = {"hasFile": True, "stale": False, "retryAdvised": False, "fetchedAtMs": now - 600_000}
    fresh_cl = {"hasFile": True, "stale": False, "retryAdvised": False, "fetchedAtMs": now - 600_000}
    old_cl = {"hasFile": True, "stale": False, "retryAdvised": False, "fetchedAtMs": now - 4_000_000}
    self.assertFalse(run_model_js(f"needsStartupRefresh({json.dumps(fresh_agy)}, {json.dumps(fresh_cl)}, 3600, {now})"))
    self.assertTrue(run_model_js(f"needsStartupRefresh({json.dumps(fresh_agy)}, {json.dumps(old_cl)}, 3600, {now})"))

    toml = 'background = "#1e1e2e"\ncolor1 = "#f38ba8"\ncolor2 = "#a6e3a1"\ncolor3 = "#f9e2af"\n'
    colors = run_model_js(f"parseThemeAnsiColors({json.dumps(toml)})")
    self.assertEqual(colors, {"ok": "#a6e3a1", "warn": "#f9e2af", "critical": "#f38ba8"})


if __name__ == "__main__":
  unittest.main()
