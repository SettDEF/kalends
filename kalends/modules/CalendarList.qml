import QtQuick
import QtQuick.Layouts
import "." as App
import "../ui" as Ui

// The calendars, each in its colour, ticked when shown. Replaces the chip
// row: a list has room for the count and reads as the legend for the grid.
ColumnLayout {
    id: root
    spacing: 0

    Text {
        Layout.leftMargin: 8
        Layout.bottomMargin: 4
        text: qsTr("Calendars")
        font.family: Ui.Appearance.font.family
        font.pixelSize: Ui.Appearance.font.smallest
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
        color: Ui.Appearance.onSurfaceVariant
    }

    Repeater {
        model: App.Store.calendars
        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool off: (App.Settings.hiddenCalendars ?? []).indexOf(row.modelData.name) >= 0
            readonly property color cal: App.Store.colorOf(row.modelData.name)
            Layout.fillWidth: true
            implicitHeight: 32
            radius: Ui.Appearance.rounding.small
            color: hov.hovered ? Ui.Appearance.surfaceContainer : "transparent"
            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: App.Settings.toggleCalendar(row.modelData.name) }

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 10 }
                spacing: 10
                Rectangle {   // a checkbox in the calendar's colour
                    implicitWidth: 16; implicitHeight: 16; radius: 5
                    color: row.off ? "transparent" : row.cal
                    border.width: 2
                    border.color: row.cal
                    Ui.Icon {
                        anchors.fill: parent
                        visible: !row.off
                        text: "check"
                        size: 13
                        color: Ui.Appearance.background
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.name.charAt(0).toUpperCase() + row.modelData.name.slice(1)
                    elide: Text.ElideRight
                    font.family: Ui.Appearance.font.family
                    font.pixelSize: Ui.Appearance.font.smaller
                    color: row.off ? Ui.Appearance.outlineVariant : Ui.Appearance.onSurface
                }
                Text {
                    text: row.modelData.events
                    font.family: Ui.Appearance.font.mono
                    font.pixelSize: Ui.Appearance.font.smallest
                    color: Ui.Appearance.outlineVariant
                }
            }
        }
    }
}
