import QtQuick
import QtQuick.Layouts
import "." as App
import "../ui" as Ui

// One chip per calendar. Tapping a chip hides that calendar's events from the
// grid and the agenda — the "calendar show/hide" M2 asks for.
Flow {
    id: root
    spacing: 6

    Repeater {
        model: App.Store.calendars
        delegate: Rectangle {
            id: chip
            required property var modelData
            readonly property bool off:
                (App.Settings.hiddenCalendars ?? []).indexOf(chip.modelData.name) >= 0

            implicitHeight: 26
            implicitWidth: row.implicitWidth + 18
            radius: height / 2
            color: chip.off ? "transparent"
                 : hov.hovered ? Ui.Appearance.surfaceContainerHigh
                 : Ui.Appearance.surfaceContainer
            border.width: chip.off ? 1 : 0
            border.color: Ui.Appearance.outlineVariant
            Behavior on color { ColorAnimation { duration: 140 } }

            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: App.Settings.toggleCalendar(chip.modelData.name) }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 6
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 8; implicitHeight: 8
                    radius: 4
                    // Hollow when hidden, so the chip reads as off at a glance
                    // rather than only by its background.
                    color: chip.off ? "transparent" : Ui.Appearance.primary
                    border.width: chip.off ? 1 : 0
                    border.color: Ui.Appearance.outlineVariant
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.name + "  " + chip.modelData.events
                    font.family: Ui.Appearance.font.family
                    font.pixelSize: Ui.Appearance.font.smaller
                    color: chip.off ? Ui.Appearance.outlineVariant : Ui.Appearance.onSurface
                }
            }
        }
    }
}
