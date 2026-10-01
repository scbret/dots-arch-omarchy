import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  readonly property var localScreen: root.QsWindow.window ? root.QsWindow.window.screen : null
  readonly property var localMonitor: localScreen ? Hyprland.monitorFor(localScreen) : null
  readonly property int offset: localScreen && localScreen.name === "DP-4" ? 10 : (localScreen && localScreen.name === "eDP-1" ? 20 : 0)

  function workspaceLabel(id) {
    if (id > offset && id <= offset + 10) return String(id - offset)
    // Keep migrated workspaces accessible when undocked.
    if (id <= 10) return "T:" + id
    if (id <= 20) return "B:" + (id - 10)
    if (id <= 30) return "L:" + (id - 20)
    return String(id)
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = []
    for (var slot = 1; slot <= 10; slot++) ids.push(offset + slot)
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (ws.id > 0 && ws.monitor === localMonitor && ids.indexOf(ws.id) === -1) ids.push(ws.id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!localMonitor) return
    Hyprland.dispatch("hl.dsp.focus({ monitor = " + localMonitor.id + " })")
    Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: root.localMonitor !== null && root.localMonitor.activeWorkspace !== null && root.localMonitor.activeWorkspace.id === modelData

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : root.workspaceLabel(modelData)
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
