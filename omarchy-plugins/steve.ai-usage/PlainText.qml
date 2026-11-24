import QtQuick

// Safe Text wrapper that forces Text.PlainText so untrusted data from JSON
// records or collectors can never be interpreted as rich text or HTML.
Text {
  textFormat: Text.PlainText
}
