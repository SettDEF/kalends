import QtQuick
import QtQuick.Layouts
import "." as App
import "month.js" as Month
import "../ui" as Ui

/**
 * The selected day, beside the month or the week — like Dotos' inspector and
 * Vane's place panel: when it is, what is on, a line to add to it. New event
 * (N, the sidebar button) puts the cursor in that line.
 */
Rectangle {
    id: root
    color: App.Console.panel
    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 1; color: App.Console.rule }

    function edit(uid) { agenda.editingUid = uid; }
    Connections {
        target: App.Nav
        function onAction(name) { if (name === "new") Qt.callLater(() => agenda.focusAdd()); }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 18 }
        spacing: 10
        Text {
            text: Qt.formatDate(Month.parse(App.Cal.selected), "dddd")
            font.family: App.Console.sans; font.pixelSize: 13; font.weight: Font.Medium
            color: App.Cal.selected === App.Cal.todayIso ? App.Console.data : App.Console.dim
        }
        RowLayout {
            spacing: 12
            Text {
                text: Qt.formatDate(Month.parse(App.Cal.selected), "d")
                font.family: App.Console.sans; font.pixelSize: 40; font.weight: Font.DemiBold
                color: App.Console.text
            }
            ColumnLayout {
                spacing: 0
                Text { text: Qt.formatDate(Month.parse(App.Cal.selected), "MMMM yyyy"); font.family: App.Console.sans; font.pixelSize: 15; color: App.Console.text }
                Text { text: App.Cal.relative + "  ·  " + qsTr("week %1").arg(Month.isoWeek(App.Cal.selected)); font.family: App.Console.mono; font.pixelSize: 11; color: App.Console.dim }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: App.Console.rule }
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: agenda.implicitHeight + 8
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            App.Agenda {
                id: agenda
                width: parent.width
                date: App.Cal.selected
                showHeading: false
            }
        }
    }
}
