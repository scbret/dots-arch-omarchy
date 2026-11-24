import QtQuick

// Safe Text wrapper forcing Text.PlainText so untrusted MPRIS metadata can
// never be interpreted as rich text or HTML.
Text {
  textFormat: Text.PlainText
}
