import QtQuick
import QtQuick.Layouts
import "." as App
import "../ui" as Ui

/** The toolbar's controls on Month and Week: ‹ Today › · jump to a date · the day panel. */
RowLayout {
    spacing: 6
    Ui.IconButton { icon: "chevron_left"; tooltip: qsTr("Back  (←)"); onClicked: App.Cal.shift(-1) }
    Rectangle {
        implicitHeight: 34
        implicitWidth: todayText.implicitWidth + 28
        radius: height / 2
        color: todayHov.hovered ? App.Console.panelAlt : App.Console.panel
        HoverHandler { id: todayHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: App.Cal.today() }
        Text { id: todayText; anchors.centerIn: parent; text: qsTr("Today"); font.family: App.Console.sans; font.pixelSize: 14; color: App.Console.text }
    }
    Ui.IconButton { icon: "chevron_right"; tooltip: qsTr("Forward  (→)"); onClicked: App.Cal.shift(1) }
    App.JumpField {
        year: App.Cal.year
        month: App.Cal.month
        onJumped: (y, m, iso) => App.Cal.select(iso)
    }
    Ui.IconButton {
        readonly property bool on: App.Settings.get("dayPanel", true)
        icon: on ? "right_panel_close" : "right_panel_open"
        active: on
        tooltip: qsTr("The selected day  (D)")
        onClicked: App.Settings.set("dayPanel", !on)
    }
}
