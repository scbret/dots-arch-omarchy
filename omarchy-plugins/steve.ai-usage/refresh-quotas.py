#!/usr/bin/python3
"""Refresh Antigravity (agy) and Claude quota records for steve.ai-usage.

- Claude: delegates directly to `omarchy-agent-usage-update --limits-only claude`.
- Antigravity: queries Google's Cloud Code `loadCodeAssist` and
  `retrieveUserQuotaSummary` endpoints over fixed HTTPS with a current
  Antigravity Hub User-Agent so the `Gemini Models` group (5-hour and weekly
  windows) is included rather than omitted, and writes the sanitized record to
  `~/.local/state/omarchy/steve-ai-usage/agy.json`.
"""

from __future__ import annotations

import argparse
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

CLOUD_CODE_BASE = "https://daily-cloudcode-pa.googleapis.com"
HUB_USER_AGENT = "antigravity/hub/2.24.0"
HTTP_TIMEOUT_SEC = 8
MAX_RESPONSE_BYTES = 512 * 1024
REUSE_SECONDS = 15


def state_home() -> Path:
  return Path(os.environ.get("XDG_STATE_HOME") or (Path.home() / ".local" / "state"))


def plugin_agy_path() -> Path:
  return state_home() / "omarchy" / "steve-ai-usage" / "agy.json"


def load_omarchy_agy_module() -> Any:
  omarchy_path = Path(os.environ.get("OMARCHY_PATH") or "/usr/share/omarchy")
  collector_path = omarchy_path / "bin" / "omarchy-agent-usage-agy"
  if not collector_path.is_file():
    return None
  os.environ["OMARCHY_PATH"] = str(omarchy_path)
  loader = importlib.machinery.SourceFileLoader("omarchy_agy_collector", str(collector_path))
  spec = importlib.util.spec_from_loader("omarchy_agy_collector", loader)
  if spec is None:
    return None
  mod = importlib.util.module_from_spec(spec)
  loader.exec_module(mod)
  return mod


def post_cloud_code(endpoint: str, access_token: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
  url = f"{CLOUD_CODE_BASE}/v1internal:{endpoint}"
  payload = json.dumps(body or {}).encode("utf-8")
  req = urllib.request.Request(
    url,
    data=payload,
    headers={
      "Authorization": f"Bearer {access_token}",
      "Content-Type": "application/json",
      "User-Agent": HUB_USER_AGENT,
    },
    method="POST",
  )
  with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT_SEC) as resp:
    raw = resp.read(MAX_RESPONSE_BYTES + 1)
  if len(raw) > MAX_RESPONSE_BYTES:
    raise ValueError("response exceeded size limit")
  parsed = json.loads(raw.decode("utf-8"))
  if not isinstance(parsed, dict):
    raise ValueError("unexpected response shape")
  return parsed


def read_existing(path: Path) -> dict[str, Any]:
  try:
    data = json.loads(path.read_text(encoding="utf-8"))
    return data if isinstance(data, dict) else {}
  except Exception:
    return {}


def atomic_write_json(path: Path, data: dict[str, Any]) -> None:
  path.parent.mkdir(parents=True, exist_ok=True)
  fd, tmp_name = tempfile.mkstemp(prefix=".agy.", dir=str(path.parent))
  try:
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
      json.dump(data, fh, separators=(",", ":"))
      fh.write("\n")
    os.replace(tmp_name, path)
  except Exception:
    try:
      os.unlink(tmp_name)
    except OSError:
      pass
    raise


def build_record(
  *,
  tier_label: str,
  limits: list[dict[str, Any]],
  stale: bool,
  fetched_at_ms: int,
  retry_advised: bool,
  usage_status_text: str,
  auth_help_text: str,
) -> dict[str, Any]:
  return {
    "schemaVersion": 1,
    "id": "agy",
    "name": "Antigravity",
    "tierLabel": tier_label,
    "limits": limits,
    "limitsStale": stale,
    "limitsFetchedAt": fetched_at_ms,
    "retryAdvised": retry_advised,
    "usageStatusText": usage_status_text,
    "authHelpText": auth_help_text,
  }


def refresh_agy(force: bool) -> int:
  out_path = plugin_agy_path()
  existing = read_existing(out_path)
  now_ms = int(time.time() * 1000)

  if (
    not force
    and existing
    and not existing.get("limitsStale")
    and isinstance(existing.get("limits"), list)
    and existing.get("limits")
    and isinstance(existing.get("limitsFetchedAt"), (int, float))
    and (now_ms - int(existing["limitsFetchedAt"])) < REUSE_SECONDS * 1000
  ):
    return 0

  agy = load_omarchy_agy_module()
  if agy is None:
    return 1

  entries = agy.logins()
  now = time.time()
  ordered = sorted(entries, key=lambda e: (not agy.token_fresh(e, now), -e["expiresAt"]))
  fresh = [e for e in ordered if agy.token_fresh(e, now)]
  lead = next(iter(fresh or [e for e in ordered if e["accessToken"]] or ordered), None)

  prev_limits = existing.get("limits") if isinstance(existing.get("limits"), list) else []
  prev_tier = str(existing.get("tierLabel") or "")
  prev_fetched = int(existing.get("limitsFetchedAt") or 0)

  if not lead or not lead["accessToken"]:
    atomic_write_json(
      out_path,
      build_record(
        tier_label=prev_tier,
        limits=prev_limits,
        stale=bool(prev_limits),
        fetched_at_ms=prev_fetched,
        retry_advised=False,
        usage_status_text="Waiting for auth",
        auth_help_text=agy.AUTH_HELP,
      ),
    )
    return 0

  refused: list[dict[str, Any]] = []
  failure: tuple[str, bool] | None = None

  for entry in fresh:
    try:
      assist = post_cloud_code("loadCodeAssist", entry["accessToken"])
      tier = agy.extract_tier(assist)
      summary = post_cloud_code(
        "retrieveUserQuotaSummary",
        entry["accessToken"],
        agy.project_body(assist),
      )
      limits = agy.extract_limits(summary)
      if limits is None:
        failure = ("Google's quota service sent an answer that couldn't be read.", False)
        break
      atomic_write_json(
        out_path,
        build_record(
          tier_label=tier,
          limits=limits,
          stale=False,
          fetched_at_ms=int(time.time() * 1000),
          retry_advised=False,
          usage_status_text="",
          auth_help_text="",
        ),
      )
      return 0
    except urllib.error.HTTPError as err:
      if err.code in (401, 403):
        refused.append(entry)
        continue
      failure = (f"Google's quota service answered with status {err.code}.", False)
      break
    except (urllib.error.URLError, TimeoutError, OSError):
      failure = ("Couldn't reach Google's quota service. Retrying shortly.", True)
      break
    except Exception:
      failure = ("Google's quota service sent an answer that couldn't be read.", False)
      break

  if failure is not None:
    help_text, retry = failure
    atomic_write_json(
      out_path,
      build_record(
        tier_label=prev_tier,
        limits=prev_limits,
        stale=bool(prev_limits),
        fetched_at_ms=prev_fetched,
        retry_advised=retry,
        usage_status_text="" if prev_limits else "Antigravity limits unavailable",
        auth_help_text=help_text,
      ),
    )
    return 0

  if refused:
    atomic_write_json(
      out_path,
      build_record(
        tier_label=prev_tier,
        limits=prev_limits,
        stale=bool(prev_limits),
        fetched_at_ms=prev_fetched,
        retry_advised=False,
        usage_status_text="Sign-in expired",
        auth_help_text=agy.refused_help(refused[0]),
      ),
    )
    return 0

  atomic_write_json(
    out_path,
    build_record(
      tier_label=prev_tier,
      limits=prev_limits,
      stale=bool(prev_limits),
      fetched_at_ms=prev_fetched,
      retry_advised=False,
      usage_status_text="Limits paused" if lead["refresh"] else "Sign-in expired",
      auth_help_text=agy.lapsed_help(lead, prev_limits),
    ),
  )
  return 0


def refresh_claude(force: bool) -> int:
  cmd = ["omarchy-agent-usage-update", "--limits-only"]
  if force:
    cmd.append("--force")
  cmd.append("claude")
  try:
    proc = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
    if proc.stderr.strip():
      print(proc.stderr.strip(), file=sys.stderr)
    return proc.returncode
  except Exception as exc:
    print(f"refresh-quotas: claude update failed: {exc}", file=sys.stderr)
    return 1


def main() -> int:
  parser = argparse.ArgumentParser(description="Refresh Antigravity and Claude quotas.")
  parser.add_argument("--force", action="store_true", help="Bypass short-term cache reuse.")
  args = parser.parse_args()

  rc_agy = refresh_agy(args.force)
  rc_claude = refresh_claude(args.force)
  return 0 if (rc_agy == 0 and rc_claude == 0) else 1


if __name__ == "__main__":
  sys.exit(main())
