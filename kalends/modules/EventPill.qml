import QtQuick
import QtQuick.Layouts
import "." as App
import "../ui" as Ui

// One event inside a month tile. All-day events are a tinted bar in their
// calendar's colour; timed ones a dot, the start time and the title — the
// difference Google and Apple use, so it reads without a legend.
Rectangle {
    id: pill
    required property var event
    signal picked

    readonly property color cal: App.Store.colorOf(pill.event?.calendar ?? "")
    readonly property bool allDay: pill.event?.all_day === true

    implicitHeight: 18
    radius: 5
    color: pill.allDay ? App.Store.tint(pill.cal, hov.hovered ? 0.42 : 0.28)
         : hov.hovered ? App.Store.tint(Ui.Appearance.onSurface, 0.08) : "transparent"

    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: pill.picked() }

    RowLayout {
        anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
        spacing: 5
        Rectangle {
            visible: !pill.allDay
            implicitWidth: 6; implicitHeight: 6; radius: 3
            color: pill.cal
        }
        Text {
            visible: !pill.allDay
            text: App.Store.clockOf(pill.event?.start)
            font.family: Ui.Appearance.font.mono
            font.pixelSize: Ui.Appearance.font.smallest
            color: Ui.Appearance.onSurfaceVariant
        }
        Text {
            Layout.fillWidth: true
            text: pill.event?.summary ?? ""
            elide: Text.ElideRight
            font.family: Ui.Appearance.font.family
            font.pixelSize: Ui.Appearance.font.smallest
            font.weight: pill.allDay ? Font.Medium : Font.Normal
            color: Ui.Appearance.onSurface
        }
    }
}
