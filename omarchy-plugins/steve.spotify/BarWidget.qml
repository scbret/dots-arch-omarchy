import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

BarWidget {
    id: root

    moduleName: "steve.spotify"

    property real maxLabelWidth: 320

    function isSpotify(player) {
        if (!player)
            return false

        var dbus = (player.dbusName || "").toLowerCase()
        var identity = (player.identity || "").toLowerCase()
        var desktop = (player.desktopEntry || "").toLowerCase()

        return dbus.indexOf("spotify") !== -1
            || identity.indexOf("spotify") !== -1
            || desktop.indexOf("spotify") !== -1
    }

    function findSpotifyPlayer() {
        var players = Mpris.players ? Mpris.players.values : []

        for (var i = 0; i < players.length; i++) {
            if (isSpotify(players[i]))
                return players[i]
        }

        return null
    }

    readonly property var spotifyPlayer: findSpotifyPlayer()

    readonly property string title:
        spotifyPlayer ? (spotifyPlayer.trackTitle || "") : ""

    readonly property string artist:
        spotifyPlayer ? (spotifyPlayer.trackArtist || "") : ""

    readonly property bool hasSpotify:
        spotifyPlayer !== null

    readonly property bool hasTrack:
        hasSpotify && (title !== "" || artist !== "")

    readonly property bool playing:
        spotifyPlayer ? spotifyPlayer.isPlaying : false

    readonly property color barFg: bar ? bar.barForeground : Commons.Color.foreground
    readonly property string barFont: bar ? bar.fontFamily : Style.font.family
    readonly property real scaledMaxLabelWidth: Style.space(maxLabelWidth)
    readonly property string trackText: Model.formatTrackLabel(title, artist)
    readonly property string safeTooltip: hasTrack ? Model.formatTooltip(title, artist) : ""

    visible: hasTrack

    implicitWidth: hasTrack ? button.implicitWidth : 0
    implicitHeight: hasTrack ? button.implicitHeight : (vertical ? 0 : barSize)

    function playPause() {
        if (!spotifyPlayer)
            return

        if (spotifyPlayer.canTogglePlaying) {
            spotifyPlayer.togglePlaying()
        } else if (spotifyPlayer.isPlaying && spotifyPlayer.canPause) {
            spotifyPlayer.pause()
        } else if (!spotifyPlayer.isPlaying && spotifyPlayer.canPlay) {
            spotifyPlayer.play()
        }
    }

    function nextTrack() {
        if (spotifyPlayer && spotifyPlayer.canGoNext)
            spotifyPlayer.next()
    }

    function previousTrack() {
        if (spotifyPlayer && spotifyPlayer.canGoPrevious)
            spotifyPlayer.previous()
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        labelVisible: false
        hasVisualContent: root.hasTrack
        interactive: root.hasSpotify
        pressable: root.hasSpotify
        horizontalMargin: 7
        verticalPadding: 6
        fixedWidth: root.vertical
            ? -1
            : (root.hasTrack ? Math.ceil(row.implicitWidth + scaledHorizontalMargin * 2) : 0)
        fixedHeight: root.vertical
            ? (root.hasTrack ? Style.bar.iconSlot : 0)
            : -1
        tooltipText: root.safeTooltip
        pressFeedbackButtons: Qt.NoButton

        onPressed: function(b) {
            if (b === Qt.LeftButton) {
                root.playPause()
            } else if (b === Qt.MiddleButton) {
                root.nextTrack()
            } else if (b === Qt.RightButton) {
                Quickshell.execDetached(["spotify"])
            }
        }

        onWheelMoved: function(delta) {
            if (delta > 0)
                root.previousTrack()
            else if (delta < 0)
                root.nextTrack()
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: root.vertical ? 0 : Style.space(6)

            PlainText {
                id: spotifyIcon

                anchors.verticalCenter: parent.verticalCenter

                text: ""

                color: root.playing
                    ? root.barFg
                    : Qt.darker(root.barFg, 1.5)

                font.family: root.barFont
                font.pixelSize: Style.font.body
                renderType: Text.NativeRendering

                Behavior on color {
                    enabled: !root.bar || root.bar.foregroundAnimationEnabled

                    ColorAnimation {
                        duration: Style.duration(160)
                    }
                }
            }

            Item {
                id: labelClip

                anchors.verticalCenter: parent.verticalCenter

                width: Math.min(root.scaledMaxLabelWidth, trackLabel.implicitWidth)
                height: Math.max(spotifyIcon.height, trackLabel.implicitHeight)

                clip: true

                visible: !root.vertical && root.trackText !== ""

                PlainText {
                    id: trackLabel

                    anchors.verticalCenter: parent.verticalCenter

                    text: root.trackText

                    color: root.barFg

                    font.family: root.barFont
                    font.pixelSize: Style.font.body
                    renderType: Text.NativeRendering

                    elide: Text.ElideRight

                    width: Math.min(
                        root.scaledMaxLabelWidth,
                        implicitWidth
                    )
                }
            }
        }
    }
}
