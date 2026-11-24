.pragma library

var MAX_JSON_BYTES = 524288
var MAX_LIMITS = 16
var MAX_TEXT_LEN = 200
var MAX_TITLE_LEN = 64

// Neutralize HTML/QML markup characters before passing dynamic strings into
// shared sinks (such as bar tooltips) whose Text.textFormat the plugin cannot
// directly control.
function neutralizeMarkup(value, maxLen) {
  var limit = (typeof maxLen === "number" && maxLen > 0) ? maxLen : MAX_TEXT_LEN
  var text = String(value === undefined || value === null ? "" : value)
  text = text.replace(/[\x00-\x1f\x7f]+/g, " ").replace(/\s+/g, " ").trim()
  text = text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
  if (text.length > limit) text = text.slice(0, Math.max(0, limit - 1)).trim() + "…"
  return text
}

// Clean untrusted text for Text.PlainText display: remove control characters,
// collapse runs of whitespace, and bound length.
function cleanPlainText(value, maxLen) {
  var limit = (typeof maxLen === "number" && maxLen > 0) ? maxLen : MAX_TEXT_LEN
  var text = String(value === undefined || value === null ? "" : value)
  text = text.replace(/[\x00-\x1f\x7f]+/g, " ").replace(/\s+/g, " ").trim()
  if (text.length > limit) text = text.slice(0, Math.max(0, limit - 1)).trim() + "…"
  return text
}

function parseTimestampMs(value) {
  if (value === undefined || value === null || value === "" || typeof value === "boolean") return 0
  if (typeof value === "number") {
    if (!isFinite(value) || value <= 0) return 0
    return value > 1e12 ? Math.round(value) : Math.round(value * 1000)
  }
  var raw = String(value).trim()
  if (raw === "") return 0
  if (/^\d+$/.test(raw)) {
    var num = Number(raw)
    if (!isFinite(num) || num <= 0) return 0
    return num > 1e12 ? Math.round(num) : Math.round(num * 1000)
  }
  var parsed = Date.parse(raw)
  return isFinite(parsed) && parsed > 0 ? parsed : 0
}

// Collectors emit used percent as a fraction in [0.0, 1.0]. Clamp defensively
// and return an integer used percentage in [0, 100], or null when invalid.
function fractionToUsedPercent(value) {
  if (value === undefined || value === null || value === "" || typeof value === "boolean") return null
  var num = Number(value)
  if (!isFinite(num) || num < 0) return null
  var pct = num <= 1.0 ? num * 100.0 : num
  return Math.max(0, Math.min(100, Math.round(pct)))
}

function isSessionLimit(title, label) {
  var t = String(title || "").toLowerCase()
  var l = String(label || "").toLowerCase()
  if (t === "session") return true
  if (t.indexOf("session") !== -1 && t.indexOf(" ") === -1) return true
  return l.indexOf("5-hour") !== -1 || l.indexOf("5h") !== -1
}

function isWeeklyLimit(title, label) {
  var t = String(title || "").toLowerCase()
  var l = String(label || "").toLowerCase()
  if (t === "weekly") return true
  if (t.indexOf("weekly") !== -1 && t.indexOf(" ") === -1) return true
  return l === "weekly (7-day)" || l === "weekly"
}

function emptyRecord(agentId, fallbackName) {
  return {
    id: cleanPlainText(agentId, 32),
    name: cleanPlainText(fallbackName || agentId, MAX_TITLE_LEN),
    tierLabel: "",
    hasFile: false,
    stale: false,
    fetchedAtMs: 0,
    retryAdvised: false,
    usageStatusText: "",
    authHelpText: "",
    session: null,
    weekly: null,
    extraLimits: [],
    limits: []
  }
}

// Parse one Omarchy agent usage JSON file (agy.json or claude.json).
// Converts the collector's used fraction [0..1] into remaining integer % [0..100].
function parseRecord(rawText, fallbackId, fallbackName, nowMs) {
  var base = emptyRecord(fallbackId, fallbackName)
  if (typeof rawText !== "string") return base
  var trimmed = rawText.trim()
  if (trimmed.length === 0 || trimmed.length > MAX_JSON_BYTES) return base

  var data
  try {
    data = JSON.parse(trimmed)
  } catch (e) {
    return base
  }
  if (!data || typeof data !== "object" || Array.isArray(data)) return base

  var now = (typeof nowMs === "number" && isFinite(nowMs) && nowMs > 0) ? nowMs : Date.now()

  base.hasFile = true
  base.id = cleanPlainText(data.id || fallbackId, 32)
  base.name = cleanPlainText(data.name || fallbackName || fallbackId, MAX_TITLE_LEN)
  base.tierLabel = cleanPlainText(data.tierLabel || "", 40)
  base.stale = data.limitsStale === true || data.stale === true
  base.retryAdvised = data.retryAdvised === true
  base.fetchedAtMs = parseTimestampMs(
    data.limitsFetchedAt || data.fetchedAtMs || data.fetchedAt || data.updatedAt
  )
  base.usageStatusText = cleanPlainText(data.usageStatusText || "", 80)
  base.authHelpText = cleanPlainText(data.authHelpText || "", MAX_TEXT_LEN)

  var rawLimits = Array.isArray(data.limits) ? data.limits : []
  var count = Math.min(rawLimits.length, MAX_LIMITS)
  var parsedLimits = []
  var session = null
  var weekly = null
  var extraLimits = []

  for (var i = 0; i < count; i++) {
    var item = rawLimits[i]
    if (!item || typeof item !== "object") continue
    var usedPct = fractionToUsedPercent(item.percent)
    if (usedPct === null) continue
    var title = cleanPlainText(item.title || item.label || "", MAX_TITLE_LEN)
    var label = cleanPlainText(item.label || item.title || "", MAX_TITLE_LEN)
    var resetsAtMs = parseTimestampMs(item.resetsAt)
    var resetPassed = resetsAtMs > 0 && resetsAtMs <= now
    var effectiveUsed = resetPassed ? 0 : usedPct
    var remaining = Math.max(0, Math.min(100, 100 - effectiveUsed))
    var entry = {
      title: title,
      label: label,
      used: effectiveUsed,
      remaining: remaining,
      resetsAtMs: resetsAtMs,
      resetPassed: resetPassed
    }
    parsedLimits.push(entry)
    if (!session && isSessionLimit(title, label)) {
      session = entry
    } else if (!weekly && isWeeklyLimit(title, label)) {
      weekly = entry
    } else {
      extraLimits.push(entry)
    }
  }

  base.limits = parsedLimits
  base.session = session
  base.weekly = weekly
  base.extraLimits = extraLimits
  return base
}

// Health color severity for % remaining:
//   > warnRemainingPercent (default > 40%)  -> "ok" (green)
//   <= warnRemainingPercent (default 16-40%) -> "warn" (yellow)
//   <= criticalRemainingPercent (default <= 15%) -> "critical" (red)
function severityForRemaining(remainingPct, warnRemainingPercent, criticalRemainingPercent) {
  if (remainingPct === null || remainingPct === undefined || typeof remainingPct !== "number" || !isFinite(remainingPct)) {
    return "none"
  }
  var warn = (typeof warnRemainingPercent === "number" && isFinite(warnRemainingPercent)) ? warnRemainingPercent : 40
  var crit = (typeof criticalRemainingPercent === "number" && isFinite(criticalRemainingPercent)) ? criticalRemainingPercent : 15
  if (crit >= warn) crit = Math.max(0, warn - 1)
  if (remainingPct <= crit) return "critical"
  if (remainingPct <= warn) return "warn"
  return "ok"
}

function lowestRemaining(record) {
  if (!record) return null
  var s = record.session ? record.session.remaining : null
  var w = record.weekly ? record.weekly.remaining : null
  if (s === null && w === null) return null
  if (s === null) return w
  if (w === null) return s
  return Math.min(s, w)
}

function formatCountdown(resetsAtMs, nowMs) {
  if (!resetsAtMs || resetsAtMs <= 0) return ""
  var now = (typeof nowMs === "number" && isFinite(nowMs) && nowMs > 0) ? nowMs : Date.now()
  var diffSec = Math.floor((resetsAtMs - now) / 1000)
  if (diffSec <= 0) return "now"
  if (diffSec < 60) return "<1m"
  var totalMin = Math.floor(diffSec / 60)
  if (totalMin < 60) return totalMin + "m"
  var totalHours = Math.floor(totalMin / 60)
  var remMin = totalMin % 60
  if (totalHours < 24) return remMin > 0 ? (totalHours + "h " + remMin + "m") : (totalHours + "h")
  var days = Math.floor(totalHours / 24)
  var remHours = totalHours % 24
  return remHours > 0 ? (days + "d " + remHours + "h") : (days + "d")
}

// Returns a structured age object so callers can localize through Translations.
function describeAge(fetchedAtMs, nowMs) {
  if (!fetchedAtMs || fetchedAtMs <= 0) return { kind: "none", a: 0, b: 0 }
  var now = (typeof nowMs === "number" && isFinite(nowMs) && nowMs > 0) ? nowMs : Date.now()
  var diffSec = Math.max(0, Math.floor((now - fetchedAtMs) / 1000))
  if (diffSec < 60) return { kind: "justNow", a: 0, b: 0 }
  var totalMin = Math.floor(diffSec / 60)
  if (totalMin < 60) return { kind: "minutes", a: totalMin, b: 0 }
  var totalHours = Math.floor(totalMin / 60)
  var remMin = totalMin % 60
  if (totalHours < 24) {
    if (remMin > 0) return { kind: "hoursMinutes", a: totalHours, b: remMin }
    return { kind: "hours", a: totalHours, b: 0 }
  }
  var days = Math.floor(totalHours / 24)
  return { kind: "days", a: days, b: 0 }
}

function needsStartupRefresh(agyRecord, claudeRecord, refreshIntervalSec, nowMs) {
  var now = (typeof nowMs === "number" && isFinite(nowMs) && nowMs > 0) ? nowMs : Date.now()
  var maxAgeMs = Math.max(60, Number(refreshIntervalSec) || 3600) * 1000
  var records = [agyRecord, claudeRecord]
  for (var i = 0; i < records.length; i++) {
    var rec = records[i]
    if (!rec || !rec.hasFile) return true
    if (rec.stale || rec.retryAdvised) return true
    if (!rec.fetchedAtMs || (now - rec.fetchedAtMs) >= maxAgeMs) return true
  }
  return false
}

// Parse ANSI green (color2), yellow (color3), and red (color1) from Omarchy's
// current theme colors.toml so status colors harmonize with light & dark themes.
function parseThemeAnsiColors(rawToml) {
  var out = { ok: "", warn: "", critical: "" }
  if (typeof rawToml !== "string" || rawToml.length === 0) return out
  var lines = rawToml.split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (!match) continue
    var key = match[1]
    var hex = match[2]
    if (key === "color2" || key === "green") out.ok = hex
    else if (key === "color3" || key === "yellow") out.warn = hex
    else if (key === "color1" || key === "red") out.critical = hex
  }
  return out
}

function buildTooltipSummary(agyRecord, claudeRecord, agyShort, claudeShort) {
  function fmt(shortLabel, rec) {
    var s = rec && rec.session ? rec.session.remaining : null
    var w = rec && rec.weekly ? rec.weekly.remaining : null
    if (s !== null && w !== null) return shortLabel + " " + s + "% / " + w + "%"
    if (s !== null) return shortLabel + " " + s + "%"
    if (w !== null) return shortLabel + " " + w + "%"
    if (rec && rec.usageStatusText) return shortLabel + " (" + rec.usageStatusText + ")"
    return shortLabel + " --"
  }
  return neutralizeMarkup(
    fmt(agyShort || "AG", agyRecord) + " · " + fmt(claudeShort || "CL", claudeRecord),
    MAX_TEXT_LEN
  )
}
