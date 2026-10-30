import QtQuick
import "." as Ui

// The keyboard's focus, the same on every control: a ring just outside it while it has focus.
// Put one inside the control; it follows the control's shape and takes no input.
Rectangle {
    readonly property Item target: parent
    visible: target && target.activeFocus
    anchors.fill: parent
    anchors.margins: -3
    radius: (target?.radius ?? 0) + 3
    color: "transparent"
    border.width: 2
    border.color: Ui.Appearance.primary
    z: 100
}
