import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as App
import "month.js" as Month
import "../ui" as Ui

/**
 * Agenda: what is coming, day by day, for the next eight weeks — the list a
 * phone calendar opens on. Empty days are left out; a click opens the day.
 */
Item {
    id: page
    property string key: "agenda"
    readonly property var days: {
        App.Store.byDay;
        const out = [];
        for (let i = 0; i < 56; i++) {
            const iso = Month.addDays(App.Cal.todayIso, i);
            const ev = App.Store.eventsOn(iso);
            if (ev.length) out.push({ iso, ev });
        }
        return out;
    }
    Component.onCompleted: App.Store.loadRange(App.Cal.todayIso, Month.addDays(App.Cal.todayIso, 56))
    Component.onDestruction: App.Cal.loadVisible()   // the grid's six weeks again

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        App.Toolbar {
            title: qsTr("Agenda")
            subtitle: page.days.length === 0 ? qsTr("nothing in the next eight weeks")
                : qsTr("%1 days with events in the next eight weeks").arg(page.days.length)
        }
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: col.implicitHeight + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            ColumnLayout {
                id: col
                x: 24; y: 18
                width: Math.min(820, flick.width - 48)
                spacing: 14
                Repeater {
                    model: page.days
                    delegate: RowLayout {
                        id: day
                        required property var modelData
                        readonly property date d: Month.parse(modelData.iso)
                        Layout.fillWidth: true
                        spacing: 18
                        // the date, as a column of its own
                        ColumnLayout {
                            Layout.preferredWidth: 70
                            Layout.alignment: Qt.AlignTop
                            spacing: 0
                            Text { text: Qt.formatDate(day.d, "ddd"); font.family: App.Console.sans; font.pixelSize: 12; color: day.modelData.iso === App.Cal.todayIso ? App.Console.data : App.Console.dim }
                            Text { text: Qt.formatDate(day.d, "d"); font.family: App.Console.sans; font.pixelSize: 26; font.weight: Font.DemiBold; color: day.modelData.iso === App.Cal.todayIso ? App.Console.data : App.Console.text }
                            Text { text: Qt.formatDate(day.d, "MMM"); font.family: App.Console.mono; font.pixelSize: 11; color: App.Console.faint }
                        }
                        App.Panel {
                            Layout.fillWidth: true
                            Repeater {
                                model: day.modelData.ev
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Rectangle { implicitWidth: 4; implicitHeight: 28; radius: 2; color: App.Store.colorOf(modelData.calendar) }
                                    Text {
                                        Layout.preferredWidth: 96
                                        text: modelData.all_day ? qsTr("all day") : App.Store.clockOf(modelData.start) + (modelData.end ? " – " + App.Store.clockOf(modelData.end) : "")
                                        font.family: App.Console.mono; font.pixelSize: 12; color: App.Console.dim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { Layout.fillWidth: true; text: modelData.summary ?? ""; elide: Text.ElideRight; font.family: App.Console.sans; font.pixelSize: 15; color: App.Console.text }
                                        Text { visible: !!modelData.location; Layout.fillWidth: true; text: modelData.location ?? ""; elide: Text.ElideRight; font.family: App.Console.sans; font.pixelSize: 12; color: App.Console.faint }
                                    }
                                    Text { text: modelData.calendar ?? ""; font.family: App.Console.mono; font.pixelSize: 11; color: App.Console.faint }
                                }
                            }
                        }
                        TapHandler { onTapped: { App.Cal.select(day.modelData.iso); App.Nav.go("month"); } }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
                Text {
                    visible: page.days.length === 0
                    text: qsTr("Nothing in the next eight weeks. New event (N) adds one.")
                    font.family: App.Console.sans; font.pixelSize: 14; color: App.Console.dim
                }
            }
        }
    }
}
