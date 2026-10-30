import QtQuick
import QtQuick.Layouts
import "." as App
import "month.js" as Month
import "../ui" as Ui

// The month as the main view: six weeks of tiles that fill the window, each
// showing its events by name — dots on a 44 px numeral said "something is on"
// and made you click every day to find out what.
ColumnLayout {
    id: root
    required property var grid
    required property string selected
    signal picked(string date)
    signal opened(string date)            // double-click: add to this day
    signal eventPicked(string date, string uid)

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Item { visible: App.Settings.weekNumbers; Layout.preferredWidth: 26 }
        Repeater {
            model: Month.weekDayNames(App.Settings.mondayFirst)
            delegate: Text {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                leftPadding: 10
                text: modelData
                font.family: Ui.Appearance.font.family
                font.pixelSize: Ui.Appearance.font.smaller
                font.weight: Font.Medium
                color: Ui.Appearance.onSurfaceVariant
            }
        }
    }

    Repeater {
        model: root.grid
        delegate: RowLayout {
            id: week
            required property var modelData
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 1
            spacing: 4

            Text {
                visible: App.Settings.weekNumbers
                Layout.preferredWidth: 26
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 8
                horizontalAlignment: Text.AlignHCenter
                text: Month.isoWeek(week.modelData[0].date)
                font.family: Ui.Appearance.font.mono
                font.pixelSize: Ui.Appearance.font.smallest
                color: Ui.Appearance.outlineVariant
            }

            Repeater {
                model: week.modelData
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property var events: App.Store.eventsOn(tile.modelData.date)
                    readonly property bool sel: tile.modelData.date === root.selected
                    // as many rows as fit; the last one says how many did not
                    readonly property int fits: Math.max(0, Math.floor((tile.height - 30) / 20))
                    readonly property int shown: tile.events.length > tile.fits ? Math.max(0, tile.fits - 1) : tile.events.length

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    radius: Ui.Appearance.rounding.small
                    color: hov.hovered ? Ui.Appearance.surfaceContainerHigh
                         : tile.modelData.outside ? "transparent" : Ui.Appearance.surfaceContainer
                    // only the selected day is outlined; days of the other months just fade
                    border.width: tile.sel ? 2 : 0
                    opacity: tile.modelData.outside && !hov.hovered ? 0.55 : 1
                    border.color: tile.sel ? Ui.Appearance.primary : Ui.Appearance.surfaceContainer
                    Behavior on color { ColorAnimation { duration: Ui.Appearance.motion.fast } }
                    clip: true

                    HoverHandler { id: hov }
                    TapHandler {
                        onTapped: root.picked(tile.modelData.date)
                        onDoubleTapped: root.opened(tile.modelData.date)
                    }

                    // the day number; today sits in an accent circle
                    Rectangle {
                        id: num
                        x: 6; y: 5
                        width: Math.max(24, numText.implicitWidth + 12)
                        height: 24
                        radius: 12
                        color: tile.modelData.today ? Ui.Appearance.primary : "transparent"
                        Text {
                            id: numText
                            anchors.centerIn: parent
                            text: tile.modelData.day === 1
                                ? Qt.formatDateTime(Month.parse(tile.modelData.date), "d MMM")
                                : tile.modelData.day
                            font.family: Ui.Appearance.font.family
                            font.pixelSize: Ui.Appearance.font.smaller
                            font.weight: tile.modelData.today || tile.sel ? Font.DemiBold : Font.Normal
                            color: tile.modelData.today ? Ui.Appearance.textOnPrimary
                                 : tile.modelData.outside ? Ui.Appearance.outlineVariant
                                 : Ui.Appearance.onSurface
                        }
                    }

                    Column {
                        anchors { left: parent.left; right: parent.right; top: num.bottom; margins: 4; topMargin: 2 }
                        spacing: 2
                        opacity: tile.modelData.outside ? 0.6 : 1

                        Repeater {
                            model: tile.events.slice(0, tile.shown)
                            delegate: App.EventPill {
                                required property var modelData
                                width: parent.width
                                event: modelData
                                onPicked: root.eventPicked(tile.modelData.date, String(modelData.uid ?? ""))
                            }
                        }
                        Text {
                            visible: tile.events.length > tile.shown
                            leftPadding: 6
                            text: qsTr("+%1 more").arg(tile.events.length - tile.shown)
                            font.family: Ui.Appearance.font.family
                            font.pixelSize: Ui.Appearance.font.smallest
                            font.weight: Font.Medium
                            color: Ui.Appearance.onSurfaceVariant
                        }
                    }
                }
            }
        }
    }
}
