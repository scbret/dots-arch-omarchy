import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

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

    visible: hasTrack

    implicitWidth: hasTrack
        ? row.implicitWidth + Style.space(14)
        : 0

    implicitHeight: barSize

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

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Style.space(6)

        Text {
            id: spotifyIcon

            anchors.verticalCenter: parent.verticalCenter

            text: ""

            color: root.playing
                ? root.bar.barForeground
                : Qt.darker(root.bar.barForeground, 1.5)

            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body

            Behavior on color {
                enabled: !root.bar || root.bar.foregroundAnimationEnabled

                ColorAnimation {
                    duration: 160
                }
            }
        }

        Item {
            id: labelClip

            anchors.verticalCenter: parent.verticalCenter

            width: Math.min(root.maxLabelWidth, trackLabel.implicitWidth)
            height: spotifyIcon.height

            clip: true

            visible: !root.bar.vertical

            Text {
                id: trackLabel

                anchors.verticalCenter: parent.verticalCenter

                text: root.title
                    + (root.artist ? "  ·  " + root.artist : "")

                color: root.bar.barForeground

                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body

                elide: Text.ElideRight

                width: Math.min(
                    root.maxLabelWidth,
                    implicitWidth
                )
            }
        }
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true

        cursorShape:
            root.spotifyPlayer
                ? Qt.PointingHandCursor
                : Qt.ArrowCursor

        acceptedButtons:
            Qt.LeftButton |
            Qt.MiddleButton |
            Qt.RightButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.playPause()
            } else if (mouse.button === Qt.MiddleButton) {
                root.nextTrack()
            } else if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached(["spotify"])
            }
        }

        onWheel: function(wheel) {
            if (wheel.angleDelta.y > 0)
                root.previousTrack()
            else if (wheel.angleDelta.y < 0)
                root.nextTrack()
        }

        onEntered: {
            if (root.bar && root.hasTrack) {
                root.bar.showTooltip(
                    root,
                    root.title
                        + (root.artist
                            ? " — " + root.artist
                            : "")
                )
            }
        }

        onExited: {
            if (root.bar)
                root.bar.hideTooltip(root)
        }
    }
}
