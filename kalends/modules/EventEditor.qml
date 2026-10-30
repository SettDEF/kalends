import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as App
import "../ui" as Ui

// Inline editor for one event, opened in place of its row. Not a dialog: a
// window that covers the calendar to change a title is more ceremony than the
// change deserves, and the month grid stays useful as context.
//
// Only fields that changed are sent — see Store.editEvent.
Rectangle {
    id: root
    required property var event
    signal done

    implicitHeight: col.implicitHeight + 20
    radius: Ui.Appearance.rounding.small
    color: Ui.Appearance.surfaceContainerHigh
    border.width: 1
    border.color: Ui.Appearance.primary

    // Seeded once from the event, then owned by the fields. Binding them
    // straight to `event` would discard the user's typing on every reload.
    property string draftTitle: String(root.event?.summary ?? "")
    property string draftTime: App.Store.clockOf(root.event?.start)
    property int draftMinutes: App.Store.minutesOf(root.event ?? ({}))
    property string draftLocation: String(root.event?.location ?? "")
    property bool draftAllDay: root.event?.all_day === true

    function save() {
        App.Store.editEvent(root.event, {
            summary: root.draftTitle,
            time: root.draftTime,
            minutes: root.draftMinutes,
            location: root.draftLocation,
            all_day: root.draftAllDay,
            calendar: root.event?.calendar,
        });
        root.done();
    }

    Keys.onEscapePressed: root.done()

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
        spacing: 6

        component Field: Rectangle {
            property alias text: inner.text
            property alias placeholder: inner.placeholderText
            property alias input: inner
            Layout.fillWidth: true
            implicitHeight: 30
            radius: Ui.Appearance.rounding.small
            color: Ui.Appearance.background
            TextField {
                id: inner
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                background: null
                font.family: Ui.Appearance.font.family
                font.pixelSize: Ui.Appearance.font.smaller
                color: Ui.Appearance.onSurface
                placeholderTextColor: Ui.Appearance.outlineVariant
            }
        }

        Field {
            placeholder: qsTr("Title")
            text: root.draftTitle
            onTextChanged: root.draftTitle = text
            Component.onCompleted: input.forceActiveFocus()
            input.onAccepted: root.save()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Field {
                Layout.preferredWidth: 72
                Layout.fillWidth: false
                visible: !root.draftAllDay
                placeholder: "HH:MM"
                text: root.draftTime
                onTextChanged: root.draftTime = text
            }
            Field {
                Layout.preferredWidth: 72
                Layout.fillWidth: false
                visible: !root.draftAllDay
                placeholder: qsTr("mins")
                text: String(root.draftMinutes)
                onTextChanged: root.draftMinutes = parseInt(text, 10) || root.draftMinutes
            }
            Field {
                placeholder: qsTr("Location")
                text: root.draftLocation
                onTextChanged: root.draftLocation = text
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                implicitHeight: 26
                implicitWidth: adLabel.implicitWidth + 22
                radius: height / 2
                color: root.draftAllDay ? Ui.Appearance.primary : Ui.Appearance.background
                TapHandler { onTapped: root.draftAllDay = !root.draftAllDay }
                Text {
                    id: adLabel
                    anchors.centerIn: parent
                    text: qsTr("All day")
                    font.family: Ui.Appearance.font.family
                    font.pixelSize: Ui.Appearance.font.smallest
                    color: root.draftAllDay ? Ui.Appearance.textOnPrimary : Ui.Appearance.onSurfaceVariant
                }
            }
            Item { Layout.fillWidth: true }
            Ui.IconButton { icon: "close"; onClicked: root.done() }
            Ui.IconButton { icon: "check"; active: true; onClicked: root.save() }
        }
    }
}
