import QtQuick
import "." as App
import "../ui" as Ui

// One day. Dots under the numeral mean events; three dots means "three or more".
Rectangle {
    id: cell
    required property var model
    property bool selected: false
    signal picked(string date)

    readonly property int count: App.Store.countOn(cell.model.date ?? "")

    implicitWidth: 44
    implicitHeight: 42
    radius: Ui.Appearance.rounding.small
    color: cell.model.today ? Ui.Appearance.primary
         : cell.selected ? Ui.Appearance.secondaryContainer
         : (hov.hovered ? Ui.Appearance.surfaceContainerHigh : "transparent")
    Behavior on color { ColorAnimation { duration: 140 } }

    HoverHandler { id: hov }
    TapHandler { onTapped: cell.picked(cell.model.date ?? "") }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: cell.count > 0 ? -4 : 0
        text: cell.model.day ?? ""
        font.family: Ui.Appearance.font.family
        font.pixelSize: Ui.Appearance.font.small
        font.weight: cell.model.today ? Font.DemiBold : Font.Normal
        color: cell.model.today ? Ui.Appearance.textOnPrimary
             : cell.model.outside ? Ui.Appearance.outlineVariant
             : Ui.Appearance.onSurface
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        spacing: 2
        visible: cell.count > 0 && App.Settings.showDots
        Repeater {
            model: Math.min(cell.count, 3)
            delegate: Rectangle {
                implicitWidth: cell.count > 3 ? 9 : 4
                implicitHeight: 3
                radius: 2
                color: cell.model.today ? Ui.Appearance.textOnPrimary
                     : cell.model.outside ? Ui.Appearance.outlineVariant
                     : Ui.Appearance.primary
            }
        }
    }
}
