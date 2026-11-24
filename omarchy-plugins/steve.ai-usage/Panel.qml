import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// ClaudeBar-style popover panel for Antigravity and Claude Code quota usage.
// Reads the JSON records produced by `omarchy-agent-usage-update` and triggers
// an hourly `--limits-only` refresh for `agy` and `claude`.
Panel {
  id: root
  moduleName: "steve.ai-usage"
  ipcTarget: "steve.ai-usage"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
  readonly property string usageDir: stateHome + "/omarchy/agents/usage"
  readonly property string agyRecordPath: stateHome + "/omarchy/steve-ai-usage/agy.json"
  readonly property string refreshScriptPath: String(Qt.resolvedUrl("refresh-quotas.py")).replace(/^file:\/\//, "")
  readonly property string themeColorsPath: stateHome + "/omarchy/current/theme/colors.toml"

  readonly property int refreshIntervalSec: Math.max(60, parseInt(setting("refreshIntervalSec", 3600), 10) || 3600)
  readonly property int warnRemainingPercent: Math.max(2, Math.min(99, parseInt(setting("warnRemainingPercent", 40), 10) || 40))
  readonly property int criticalRemainingPercent: Math.max(0, Math.min(warnRemainingPercent - 1, parseInt(setting("criticalRemainingPercent", 15), 10) || 15))

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Util.alpha(foreground, 0.65)
  readonly property color trackColor: Style.selectedFillFor(foreground, Commons.Color.accent)
  readonly property color cardColor: Util.alpha(foreground, 0.04)
  readonly property color cardBorderColor: Util.alpha(foreground, 0.14)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Theme-derived green/yellow/red with readable fallbacks.
  property var themeAnsi: ({ ok: "", warn: "", critical: "" })
  readonly property color okColor: themeAnsi.ok !== "" ? themeAnsi.ok : "#7ec699"
  readonly property color warnColor: themeAnsi.warn !== "" ? themeAnsi.warn : "#e5c07b"
  readonly property color criticalColor: themeAnsi.critical !== "" ? themeAnsi.critical : (bar ? bar.urgent : Commons.Color.urgent)

  property double nowMs: Date.now()
  property string agyRaw: ""
  property string claudeRaw: ""
  property bool pendingForce: false

  readonly property bool refreshing: updateProcess.running
  readonly property var agyRecord: Model.parseRecord(agyRaw, "agy", strings.t("agent.agy.name"), nowMs)
  readonly property var claudeRecord: Model.parseRecord(claudeRaw, "claude", strings.t("agent.claude.name"), nowMs)
  readonly property var agentCards: [agyRecord, claudeRecord]

  readonly property double latestFetchedAtMs: Math.max(
    agyRecord ? (agyRecord.fetchedAtMs || 0) : 0,
    claudeRecord ? (claudeRecord.fetchedAtMs || 0) : 0
  )

  readonly property string updatedSummary: {
    if (root.refreshing) return strings.t("panel.updating")
    var age = Model.describeAge(root.latestFetchedAtMs, root.nowMs)
    if (age.kind === "none") return strings.t("panel.neverUpdated")
    var ageStr = ""
    if (age.kind === "justNow") ageStr = strings.t("age.justNow")
    else if (age.kind === "minutes") ageStr = strings.t("age.minutes").arg(Commons.I18n.formatNumber(age.a))
    else if (age.kind === "hoursMinutes") ageStr = strings.t("age.hoursMinutes").arg(Commons.I18n.formatNumber(age.a)).arg(Commons.I18n.formatNumber(age.b))
    else if (age.kind === "hours") ageStr = strings.t("age.hours").arg(Commons.I18n.formatNumber(age.a))
    else ageStr = strings.t("age.days").arg(Commons.I18n.formatNumber(age.a))
    return strings.t("panel.updated").arg(ageStr)
  }

  function colorFor(pct) {
    var level = Model.severityForRemaining(pct, root.warnRemainingPercent, root.criticalRemainingPercent)
    if (level === "critical") return root.criticalColor
    if (level === "warn") return root.warnColor
    if (level === "ok") return root.okColor
    return root.dim
  }

  function localizedLimitLabel(limit) {
    if (!limit) return ""
    var title = String(limit.title || "")
    if (title === "Session") return strings.t("window.session")
    if (title === "Weekly") return strings.t("window.weekly")
    return limit.label || title
  }

  function localizedResetText(resetsAtMs) {
    var raw = Model.formatCountdown(resetsAtMs, root.nowMs)
    if (raw === "") return ""
    if (raw === "now") return strings.t("window.resetsNow")
    return strings.t("window.resetsIn").arg(raw)
  }

  function open() {
    root.nowMs = Date.now()
    agyFile.reload()
    claudeFile.reload()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function runUpdate(force) {
    if (updateProcess.running) {
      if (force) pendingForce = true
      return
    }
    var cmd = ["python3", "-B", root.refreshScriptPath]
    if (force) cmd.push("--force")
    updateProcess.command = cmd
    updateProcess.running = true
  }

  function forceRefresh() {
    runUpdate(true)
  }

  function reloadRecords() {
    root.nowMs = Date.now()
    agyFile.reload()
    claudeFile.reload()
  }

  function scheduleRetryIfAdvised() {
    var retry = (agyRecord && agyRecord.retryAdvised) || (claudeRecord && claudeRecord.retryAdvised)
    if (retry) retryTimer.restart()
    else retryTimer.stop()
  }

  // Reload theme ANSI palette whenever Omarchy swaps themes.
  Connections {
    target: Commons.Color
    function onForegroundChanged() { themeColorsFile.reload() }
    function onBackgroundChanged() { themeColorsFile.reload() }
  }

  FileView {
    id: themeColorsFile
    path: root.themeColorsPath
    watchChanges: false
    printErrors: false
    onLoaded: root.themeAnsi = Model.parseThemeAnsiColors(text())
    onLoadFailed: root.themeAnsi = ({ ok: "", warn: "", critical: "" })
  }

  FileView {
    id: agyFile
    path: root.agyRecordPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.nowMs = Date.now()
      root.agyRaw = text() || ""
      root.scheduleRetryIfAdvised()
    }
    onLoadFailed: root.agyRaw = ""
  }

  FileView {
    id: claudeFile
    path: root.usageDir + "/claude.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.nowMs = Date.now()
      root.claudeRaw = text() || ""
      root.scheduleRetryIfAdvised()
    }
    onLoadFailed: root.claudeRaw = ""
  }

  Process {
    id: updateProcess
    running: false
    onExited: {
      root.reloadRecords()
      if (root.pendingForce) {
        root.pendingForce = false
        root.runUpdate(true)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("steve.ai-usage", text.trim())
    }
  }

  // Wait briefly at startup so FileViews finish initial reads; only hit the
  // collectors right away when records are missing, stale, or older than the
  // configured refresh interval.
  Timer {
    id: startupCheckTimer
    interval: 1500
    running: true
    repeat: false
    onTriggered: {
      root.nowMs = Date.now()
      if (Model.needsStartupRefresh(root.agyRecord, root.claudeRecord, root.refreshIntervalSec, root.nowMs)) {
        root.runUpdate(false)
      }
    }
  }

  // Hourly automatic refresh (configurable via refreshIntervalSec).
  Timer {
    id: hourlyRefreshTimer
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    onTriggered: root.runUpdate(false)
  }

  // Short retry when a collector reports transient network unavailability.
  Timer {
    id: retryTimer
    interval: 30000
    running: false
    repeat: false
    onTriggered: root.runUpdate(false)
  }

  // Keep reset countdowns and "Updated Xm ago" fresh while the popover is open.
  Timer {
    id: openTickTimer
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(620))

    content: PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      implicitHeight: contentCol.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.forceRefresh()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar {
          id: scrollBar
          policy: ScrollBar.AsNeeded
        }

        Column {
          id: contentCol
          width: panelFlick.width - (panelFlick.interactive ? scrollBar.width + Style.space(6) : 0)
          spacing: Style.spacing.xl

          // ---- Header: title, updated timestamp, manual refresh button ----
          Row {
            width: parent.width
            spacing: Style.spacing.md

            Column {
              width: parent.width - refreshBtn.width - Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              PlainText {
                text: strings.t("panel.title")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
              }

              PlainText {
                text: root.updatedSummary
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: parent.width
              }
            }

            PanelActionButton {
              id: refreshBtn
              anchors.verticalCenter: parent.verticalCenter
              iconText: "↻"
              tooltipText: strings.t("panel.refreshTooltip")
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !root.refreshing
              bordered: true
              onClicked: root.forceRefresh()
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          // ---- Agent cards (Antigravity & Claude Code) ----
          Repeater {
            model: root.agentCards

            delegate: Rectangle {
              id: card
              required property var modelData
              readonly property var cardLimits: {
                var list = []
                if (modelData && modelData.session) list.push(modelData.session)
                if (modelData && modelData.weekly) list.push(modelData.weekly)
                if (modelData && Array.isArray(modelData.extraLimits)) {
                  for (var i = 0; i < modelData.extraLimits.length; i++)
                    list.push(modelData.extraLimits[i])
                }
                return list
              }

              width: contentCol.width
              implicitHeight: cardInner.implicitHeight + Style.spacing.xxl * 2
              radius: Style.cornerRadius
              color: root.cardColor
              border.width: Style.spacing.hairline
              border.color: root.cardBorderColor

              Column {
                id: cardInner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.spacing.xxl
                spacing: Style.spacing.lg

                // Card header: Agent name + plan tier badge + optional status
                Row {
                  width: parent.width
                  spacing: Style.spacing.md

                  PlainText {
                    id: agentTitle
                    text: modelData ? modelData.name : ""
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Rectangle {
                    visible: !!(modelData && modelData.tierLabel)
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: tierText.implicitWidth + Style.space(10)
                    implicitHeight: tierText.implicitHeight + Style.space(4)
                    radius: Style.cornerRadius
                    color: root.trackColor

                    PlainText {
                      id: tierText
                      anchors.centerIn: parent
                      text: modelData ? modelData.tierLabel : ""
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - agentTitle.implicitWidth
                      - (modelData && modelData.tierLabel ? tierText.implicitWidth + Style.space(10) + Style.spacing.md : 0)
                      - (statusBadge.visible ? statusBadge.implicitWidth + Style.spacing.md : 0)
                      - Style.spacing.md)
                    height: 1
                  }

                  PlainText {
                    id: statusBadge
                    visible: !!(modelData && (modelData.usageStatusText || modelData.stale))
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData && modelData.usageStatusText
                      ? modelData.usageStatusText
                      : strings.t("status.stale")
                    color: root.warnColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                // Quota rows (Session, Weekly, plus any model-scoped windows)
                Repeater {
                  model: card.cardLimits

                  delegate: Column {
                    required property var modelData
                    readonly property int pct: modelData ? modelData.remaining : 0
                    readonly property color barColor: root.colorFor(pct)
                    readonly property string resetText: modelData ? root.localizedResetText(modelData.resetsAtMs) : ""

                    width: cardInner.width
                    spacing: Style.spacing.xs

                    // Row label + exact % remaining
                    Item {
                      width: parent.width
                      implicitHeight: Math.max(limitLabel.implicitHeight, pctLabel.implicitHeight)

                      PlainText {
                        id: limitLabel
                        anchors.left: parent.left
                        anchors.right: pctLabel.left
                        anchors.rightMargin: Style.spacing.md
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.localizedLimitLabel(modelData)
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                      }

                      PlainText {
                        id: pctLabel
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: strings.t("window.percentRemaining").arg(Commons.I18n.formatNumber(pct))
                        color: barColor
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.weight: Font.DemiBold
                      }
                    }

                    // Color-coded progress bar
                    Rectangle {
                      id: meterTrack
                      width: parent.width
                      height: Style.space(6)
                      radius: Math.min(Style.cornerRadius, Math.floor(height / 2))
                      color: root.trackColor
                      clip: true

                      Rectangle {
                        height: parent.height
                        width: Math.round(parent.width * Math.max(0, Math.min(100, pct)) / 100)
                        radius: parent.radius
                        color: barColor

                        Behavior on width {
                          NumberAnimation {
                            duration: Style.duration(180)
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Style.easeOut
                          }
                        }

                        Behavior on color {
                          ColorAnimation { duration: Style.duration(160) }
                        }
                      }
                    }

                    // Reset countdown
                    PlainText {
                      visible: resetText !== ""
                      width: parent.width
                      text: resetText
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: LayoutMirroring.enabled ? Text.AlignLeft : Text.AlignRight
                    }
                  }
                }

                // Fallback when no quota windows are available yet
                Column {
                  visible: card.cardLimits.length === 0
                  width: parent.width
                  spacing: Style.spacing.xs

                  PlainText {
                    width: parent.width
                    text: (modelData && modelData.usageStatusText) ? modelData.usageStatusText : strings.t("status.noData")
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                  }

                  PlainText {
                    visible: !!(modelData && modelData.authHelpText) || !(modelData && modelData.hasFile)
                    width: parent.width
                    text: (modelData && modelData.authHelpText) ? modelData.authHelpText : strings.t("status.noDataHelp")
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                  }
                }
              }
            }
          }

          // ---- Footer hint ----
          PlainText {
            width: parent.width
            text: strings.t("panel.footerHint")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
