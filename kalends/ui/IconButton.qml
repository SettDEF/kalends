import QtQuick
import "." as App

// A round icon button. The glyph is centred by anchors on a square box, so
// every button in a row lines up regardless of which symbol it carries.
Rectangle {
    id: btn
    property string icon: ""
    property string tooltip: ""
    property bool active: false
    signal clicked

    implicitWidth: 34
    implicitHeight: 34
    radius: width / 2
    color: btn.active ? App.Appearance.primary
         : tap.pressed ? App.Appearance.surfaceContainerHigh
         : hov.hovered ? App.Appearance.surfaceContainerHigh
         : App.Appearance.surfaceContainer
    Behavior on color { ColorAnimation { duration: 140 } }

    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: btn.clicked() }
    // the keyboard: Tab to it, Enter or Space presses it
    activeFocusOnTab: btn.visible
    Keys.onPressed: e => {
        if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(e.key)) { btn.clicked(); e.accepted = true; }
    }
    App.FocusRing {}

    App.Icon {
        anchors.fill: parent
        text: btn.icon
        size: 19
        filled: btn.active
        color: btn.active ? App.Appearance.textOnPrimary : App.Appearance.onSurface
    }
}
