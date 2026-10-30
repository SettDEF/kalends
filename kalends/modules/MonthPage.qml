import QtQuick
import QtQuick.Layouts
import "." as App
import "../ui" as Ui

/** Month: the grid, the selected day beside it. */
Item {
    id: page
    property string key: "month"
    readonly property bool dayPanel: App.Settings.get("dayPanel", true) && width >= 900

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        App.Toolbar {
            title: App.Cal.monthTitle()
            subtitle: App.Cal.summary
            App.CalNav {}
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            App.MonthView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                grid: App.Cal.grid
                selected: App.Cal.selected
                onPicked: d => App.Cal.selected = d
                onOpened: d => { App.Cal.select(d); App.Nav.run("new"); }
                onEventPicked: (d, uid) => { App.Cal.select(d); day.edit(uid); }
            }
            App.DayPanel {
                id: day
                visible: page.dayPanel
                Layout.fillHeight: true
                Layout.preferredWidth: 330
            }
        }
    }
}
