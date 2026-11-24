import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Bar widget displaying inline 5-hour session and 7-day weekly quota usage for
// Antigravity and Claude, with a ClaudeBar-style popover on click.
BarWidget {
  id: root
  moduleName: "steve.ai-usage"

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  readonly property var panelItem: panelLoader.item
  readonly property var agyRecord: panelItem ? panelItem.agyRecord : Model.emptyRecord("agy", "Antigravity")
  readonly property var claudeRecord: panelItem ? panelItem.claudeRecord : Model.emptyRecord("claude", "Claude Code")
  readonly property bool refreshing: panelItem ? panelItem.refreshing === true : false

  readonly property int warnRemainingPercent: Math.max(2, Math.min(99, parseInt(setting("warnRemainingPercent", 40), 10) || 40))
  readonly property int criticalRemainingPercent: Math.max(0, Math.min(warnRemainingPercent - 1, parseInt(setting("criticalRemainingPercent", 15), 10) || 15))

  readonly property color okColor: panelItem ? panelItem.okColor : "#7ec699"
  readonly property color warnColor: panelItem ? panelItem.warnColor : "#e5c07b"
  readonly property color criticalColor: panelItem ? panelItem.criticalColor : (bar ? bar.urgent : Commons.Color.urgent)
  readonly property color barFg: bar ? bar.barForeground : Commons.Color.foreground
  readonly property color dimColor: Util.alpha(barFg, 0.65)
  readonly property string barFont: bar ? bar.fontFamily : Style.font.family

  readonly property var agySessionPct: agyRecord && agyRecord.session ? agyRecord.session.remaining : null
  readonly property var agyWeeklyPct: agyRecord && agyRecord.weekly ? agyRecord.weekly.remaining : null
  readonly property var claudeSessionPct: claudeRecord && claudeRecord.session ? claudeRecord.session.remaining : null
  readonly property var claudeWeeklyPct: claudeRecord && claudeRecord.weekly ? claudeRecord.weekly.remaining : null
  readonly property var agyMinPct: Model.lowestRemaining(agyRecord)
  readonly property var claudeMinPct: Model.lowestRemaining(claudeRecord)

  function colorFor(pct) {
    var level = Model.severityForRemaining(pct, root.warnRemainingPercent, root.criticalRemainingPercent)
    if (level === "critical") return root.criticalColor
    if (level === "warn") return root.warnColor
    if (level === "ok") return root.okColor
    return root.dimColor
  }

  function fmtPct(pct) {
    if (pct === null || pct === undefined) return "--"
    return Commons.I18n.formatNumber(pct)
  }

  // Shape contract for shell.summon/hide/toggle and bar popout coordination.
  readonly property bool opened: panelItem ? panelItem.opened === true : false
  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: root.vertical ? Style.bar.iconSlot : horizontalRow.implicitWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function open() {
    if (panelItem) panelItem.open()
  }

  function close() {
    if (panelItem) panelItem.close()
  }

  function togglePanel() {
    if (panelItem) panelItem.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelItem) panelItem.closeForPopoutSwitch()
  }

  function forceRefresh() {
    if (panelItem) panelItem.forceRefresh()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  readonly property string computedTooltip: {
    if (root.refreshing) return strings.t("tooltip.refreshing")
    var summary = Model.buildTooltipSummary(
      root.agyRecord,
      root.claudeRecord,
      strings.t("agent.agy.short"),
      strings.t("agent.claude.short")
    )
    return Model.neutralizeMarkup(strings.t("tooltip.summary").arg(summary), 220)
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 8.5
    verticalPadding: 6
    fixedWidth: root.vertical ? -1 : Math.max(Style.space(24), Math.ceil(horizontalRow.implicitWidth + scaledHorizontalMargin * 2))
    fixedHeight: root.vertical ? Math.max(Style.bar.iconSlot, Math.ceil(verticalCol.implicitHeight + scaledVerticalPadding * 2)) : -1
    tooltipText: root.opened ? "" : root.computedTooltip
    pressFeedbackButtons: Qt.NoButton

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton || b === Qt.MiddleButton) root.forceRefresh()
      else root.togglePanel()
    }

    // Horizontal layout: AG 12/45% · CL 8/30%
    Row {
      id: horizontalRow
      visible: !root.vertical
      anchors.centerIn: parent
      spacing: 0
      opacity: root.refreshing ? 0.65 : 1.0

      Behavior on opacity {
        NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
      }

      PlainText {
        text: strings.t("agent.agy.short") + " "
        color: root.dimColor
        font.family: root.barFont
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering
      }

      PlainText {
        visible: root.agySessionPct !== null
        text: root.fmtPct(root.agySessionPct) + (root.agyWeeklyPct === null ? "%" : "")
        color: root.colorFor(root.agySessionPct)
        font.family: root.barFont
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering
      }

      PlainText {
        visible: root.agySessionPct !== null && root.agyWeeklyPct !== null
        text: "/"
        color: root.dimColor
        font.family: root.barFont
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering
      }

      PlainText {
        visible: root.agyWeeklyPct !== null
        text: root.fmtPct(root.agyWeeklyPct) + "%"
        color: root.colorFor(root.agyWeeklyPct)
        font.family: root.barFont
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering
      }

      PlainText {
        visible: root.agySessionPct === null && root.agyWeeklyPct === null
        text: "--"
        color: root.dimColor
        font.family: root.barFont
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering
      }

      PlainText {
        text: " · " + strings.t("agent.claude.short") + " "
        color: root.dimColor
        font.family: root.barFont
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering
      }

      PlainText {
        visible: root.claudeSessionPct !== null
        text: root.fmtPct(root.claudeSessionPct) + (root.claudeWeeklyPct === null ? "%" : "")
        color: root.colorFor(root.claudeSessionPct)
        font.family: root.barFont
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering
      }

      PlainText {
        visible: root.claudeSessionPct !== null && root.claudeWeeklyPct !== null
        text: "/"
        color: root.dimColor
        font.family: root.barFont
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering
      }

      PlainText {
        visible: root.claudeWeeklyPct !== null
        text: root.fmtPct(root.claudeWeeklyPct) + "%"
        color: root.colorFor(root.claudeWeeklyPct)
        font.family: root.barFont
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering
      }

      PlainText {
        visible: root.claudeSessionPct === null && root.claudeWeeklyPct === null
        text: "--"
        color: root.dimColor
        font.family: root.barFont
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering
      }
    }

    // Compact vertical fallback for left/right bar orientations.
    Column {
      id: verticalCol
      visible: root.vertical
      anchors.centerIn: parent
      spacing: Style.space(2)
      opacity: root.refreshing ? 0.65 : 1.0

      Behavior on opacity {
        NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
      }

      PlainText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: strings.t("agent.agy.short")
        color: root.dimColor
        font.family: root.barFont
        font.pixelSize: Style.font.caption
        renderType: Text.NativeRendering
      }

      PlainText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.agyMinPct !== null ? (root.fmtPct(root.agyMinPct) + "%") : "--"
        color: root.colorFor(root.agyMinPct)
        font.family: root.barFont
        font.pixelSize: Style.font.caption
        renderType: Text.NativeRendering
      }

      PlainText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: strings.t("agent.claude.short")
        color: root.dimColor
        font.family: root.barFont
        font.pixelSize: Style.font.caption
        renderType: Text.NativeRendering
      }

      PlainText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.claudeMinPct !== null ? (root.fmtPct(root.claudeMinPct) + "%") : "--"
        color: root.colorFor(root.claudeMinPct)
        font.family: root.barFont
        font.pixelSize: Style.font.caption
        renderType: Text.NativeRendering
      }
    }
  }
}
