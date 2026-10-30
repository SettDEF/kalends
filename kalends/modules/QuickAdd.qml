import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as App
import "../ui" as Ui

// One-line capture for the selected day. Deliberately not a form: the full
// set of fields is what `kalends edit` is for, and a dialog you must fill in
// is how quick capture stops being quick.
//
//   Dentist            -> all day
//   Dentist @14:30     -> timed, one hour
Rectangle {
    id: root
    required property string date
    property string calendar: App.Settings.defaultCalendar

    implicitHeight: 36
    radius: Ui.Appearance.rounding.full
    color: Ui.Appearance.surfaceContainerHigh
    border.width: field.activeFocus ? 1 : 0
    border.color: Ui.Appearance.primary

    function focusField() { field.forceActiveFocus(); }
    function commit() {
        if (App.Store.quickAdd(field.text, root.date, root.calendar)) {
            field.text = "";
        }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 6 }
        spacing: 6

        TextField {
            id: field
            Layout.fillWidth: true
            placeholderText: qsTr("Add to this day…  Title @14:30")
            background: null
            font.family: Ui.Appearance.font.family
            font.pixelSize: Ui.Appearance.font.smaller
            color: Ui.Appearance.onSurface
            placeholderTextColor: Ui.Appearance.outlineVariant
            onAccepted: root.commit()
            Keys.onEscapePressed: { text = ""; focus = false; }
        }
        Ui.IconButton {
            // Only once there is something to add, so it does not sit there
            // looking pressable on an empty field.
            visible: field.text.trim().length > 0
            icon: "add"
            onClicked: root.commit()
        }
    }

    // A failed write must say so; silently doing nothing is the worst outcome
    // for a capture box.
    Text {
        anchors { left: parent.left; right: parent.right; top: parent.bottom; topMargin: 4; leftMargin: 14 }
        visible: App.Store.writeError.length > 0
        text: App.Store.writeError
        font.family: Ui.Appearance.font.family
        font.pixelSize: Ui.Appearance.font.smallest
        color: Ui.Appearance.error
        elide: Text.ElideRight
    }
}
