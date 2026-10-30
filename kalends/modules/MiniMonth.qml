import QtQuick
import QtQuick.Layouts
import "." as App
import "month.js" as Month
import "../ui" as Ui

// The sidebar's small month: a date picker that also shows which days are
// busy. Pages on its own, so looking ahead does not move the main view
// until a day is picked.
ColumnLayout {
    id: root
    required property string selected
    property int year: Month.parse(root.selected).getFullYear()
    property int month: Month.parse(root.selected).getMonth() + 1
    signal picked(string date)

    // follow the main view when the selection moves to another month
    onSelectedChanged: {
        const d = Month.parse(root.selected);
        root.year = d.getFullYear();
        root.month = d.getMonth() + 1;
    }
    function shift(n) {
        let m = root.month + n, y = root.year;
        while (m < 1) { m += 12; y--; }
        while (m > 12) { m -= 12; y++; }
        root.month = m; root.year = y;
    }
    readonly property var grid: Month.monthGrid(root.year, root.month, App.Settings.mondayFirst)

    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 2
        Text {
            Layout.fillWidth: true
            leftPadding: 6
            text: Qt.formatDateTime(new Date(root.year, root.month - 1, 1), "MMMM yyyy")
            font.family: Ui.Appearance.font.family
            font.pixelSize: Ui.Appearance.font.smaller
            font.weight: Font.DemiBold
            color: Ui.Appearance.onSurface
        }
        Ui.IconButton { implicitWidth: 26; implicitHeight: 26; icon: "chevron_left"; onClicked: root.shift(-1) }
        Ui.IconButton { implicitWidth: 26; implicitHeight: 26; icon: "chevron_right"; onClicked: root.shift(1) }
    }

    GridLayout {
        columns: 7
        rowSpacing: 0
        columnSpacing: 0
        Layout.fillWidth: true
        Repeater {
            model: Month.weekDayNames(App.Settings.mondayFirst)
            delegate: Text {
                required property var modelData
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData.slice(0, 1)
                font.family: Ui.Appearance.font.family
                font.pixelSize: Ui.Appearance.font.smallest
                color: Ui.Appearance.outlineVariant
                bottomPadding: 4
            }
        }
        Repeater {
            model: [].concat(...root.grid)
            delegate: Item {
                id: d
                required property var modelData
                readonly property bool sel: d.modelData.date === root.selected
                readonly property bool busy: App.Store.countOn(d.modelData.date) > 0
                Layout.fillWidth: true
                implicitHeight: 30
                HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.picked(d.modelData.date) }
                Rectangle {
                    anchors.centerIn: parent
                    width: 28; height: 28; radius: 14
                    color: d.modelData.today ? Ui.Appearance.primary
                         : d.sel ? Ui.Appearance.surfaceContainerHigh
                         : dh.hovered ? Ui.Appearance.surfaceContainer : "transparent"
                    border.width: d.sel && d.modelData.today ? 0 : (d.sel ? 1 : 0)
                    border.color: Ui.Appearance.primary
                }
                Text {
                    anchors.centerIn: parent
                    text: d.modelData.day
                    font.family: Ui.Appearance.font.family
                    font.pixelSize: Ui.Appearance.font.smaller
                    font.weight: d.modelData.today || d.sel ? Font.DemiBold : Font.Normal
                    color: d.modelData.today ? Ui.Appearance.textOnPrimary
                         : d.modelData.outside ? Ui.Appearance.outlineVariant : Ui.Appearance.onSurface
                }
                Rectangle {   // "something is on"
                    visible: d.busy && !d.modelData.today
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: 4; height: 4; radius: 2
                    color: Ui.Appearance.primary
                    opacity: d.modelData.outside ? 0.5 : 1
                }
            }
        }
    }
}
