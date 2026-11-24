.pragma library

var MAX_TEXT_LEN = 160
var MAX_TOOLTIP_LEN = 220

// Clean untrusted MPRIS metadata for Text.PlainText display.
function cleanPlainText(value, maxLen) {
  var limit = (typeof maxLen === "number" && maxLen > 0) ? maxLen : MAX_TEXT_LEN
  var text = String(value === undefined || value === null ? "" : value)
  text = text.replace(/[\x00-\x1f\x7f]+/g, " ").replace(/\s+/g, " ").trim()
  if (text.length > limit) text = text.slice(0, Math.max(0, limit - 1)).trim() + "…"
  return text
}

// Neutralize HTML/QML markup characters before passing untrusted MPRIS text
// into shared sinks (such as bar.showTooltip) whose Text.textFormat the plugin
// cannot directly control.
function neutralizeMarkup(value, maxLen) {
  var limit = (typeof maxLen === "number" && maxLen > 0) ? maxLen : MAX_TOOLTIP_LEN
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

function formatTrackLabel(title, artist) {
  var t = cleanPlainText(title, MAX_TEXT_LEN)
  var a = cleanPlainText(artist, MAX_TEXT_LEN)
  if (t && a) return t + "  ·  " + a
  return t || a
}

function formatTooltip(title, artist) {
  var t = cleanPlainText(title, MAX_TEXT_LEN)
  var a = cleanPlainText(artist, MAX_TEXT_LEN)
  var combined = (t && a) ? (t + " — " + a) : (t || a)
  return neutralizeMarkup(combined, MAX_TOOLTIP_LEN)
}
