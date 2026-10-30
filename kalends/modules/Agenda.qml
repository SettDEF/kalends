import QtQuick
import QtQuick.Layouts
import "." as App
import "../ui" as Ui

// The selected day's events.
ColumnLayout {
    id: agenda
    required property string date
    readonly property var events: App.Store.eventsOn(agenda.date)
    /// The uid being edited, or empty. Keyed on uid rather than index so a
    /// reload that reorders the day does not move the editor to another event.
    property string editingUid: ""
    /// the date as a heading; off where the page already shows the day (the day panel)
    property bool showHeading: true

    spacing: 6

    function clock(iso) {
        const d = new Date(iso);
        if (isNaN(d.getTime())) return "";
        const p = n => String(n).padStart(2, "0");
        if (App.Settings.twentyFour) return p(d.getHours()) + ":" + p(d.getMinutes());
        const h = d.getHours() % 12 || 12;
        return h + ":" + p(d.getMinutes()) + (d.getHours() < 12 ? " AM" : " PM");
    }

    Text {
        Layout.fillWidth: true
        visible: agenda.showHeading
        text: {
            const d = new Date(agenda.date + "T12:00:00");   // midday: no DST edge
            return isNaN(d.getTime()) ? agenda.date : Qt.formatDateTime(d, "dddd d MMMM");
        }
        font.family: Ui.Appearance.font.family
        font.pixelSize: Ui.Appearance.font.normal
        font.weight: Font.DemiBold
        color: Ui.Appearance.onSurface
    }
    function focusAdd() { quick.focusField(); }

    App.QuickAdd {
        id: quick
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 2
        date: agenda.date
        calendar: App.Settings.defaultCalendar
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: agenda.events.length === 0
        text: qsTr("Nothing scheduled")
        font.family: Ui.Appearance.font.family
        font.pixelSize: Ui.Appearance.font.smaller
        color: Ui.Appearance.outlineVariant
    }

    Repeater {
        model: agenda.events
        delegate: Loader {
            id: row
            required property var modelData
            Layout.fillWidth: true
            readonly property bool editing: agenda.editingUid === String(row.modelData.uid ?? "")
            sourceComponent: row.editing ? editorView : cardView

            Component {
                id: editorView
                App.EventEditor {
                    event: row.modelData
                    onDone: agenda.editingUid = ""
                }
            }

            Component {
            id: cardView
            Rectangle {
            id: card
            readonly property var modelData: row.modelData
            Layout.fillWidth: true
            implicitHeight: evRow.implicitHeight + 16
            radius: Ui.Appearance.rounding.small
            color: cardHov.hovered ? Ui.Appearance.surfaceContainerHigh
                                   : Ui.Appearance.surfaceContainer
            Behavior on color { ColorAnimation { duration: 140 } }
            HoverHandler { id: cardHov }

            RowLayout {
                id: evRow
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                spacing: 8

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 2
                    implicitWidth: 3
                    implicitHeight: 28
                    radius: 2
                    color: App.Store.colorOf(card.modelData.calendar ?? "")
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: modelData.summary ?? ""
                        font.family: Ui.Appearance.font.family
                        font.pixelSize: Ui.Appearance.font.small
                        color: Ui.Appearance.onSurface
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            const when = modelData.all_day ? qsTr("all day")
                                : agenda.clock(modelData.start) + " – " + agenda.clock(modelData.end);
                            const where = modelData.location ? "  ·  " + modelData.location : "";
                            return when + "  ·  " + (modelData.calendar ?? "") + where;
                        }
                        font.family: Ui.Appearance.font.family
                        font.pixelSize: Ui.Appearance.font.smallest
                        color: Ui.Appearance.onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                // Revealed on hover: buttons sitting on every row make the
                // list noisy, and a delete button always on show invites the
                // accident it exists to perform.
                Ui.IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    visible: cardHov.hovered
                    implicitWidth: 28
                    implicitHeight: 28
                    icon: "edit"
                    onClicked: agenda.editingUid = String(card.modelData.uid ?? "")
                }
                Ui.IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    visible: cardHov.hovered
                    implicitWidth: 28
                    implicitHeight: 28
                    icon: "delete"
                    onClicked: App.Store.removeEvent(card.modelData.uid)
                }
            }

            // The whole row opens the editor, so the button is a shortcut
            // rather than the only way in.
            TapHandler { onTapped: agenda.editingUid = String(card.modelData.uid ?? "") }
            }
            }
        }
    }
    Item { Layout.fillHeight: true }
}
