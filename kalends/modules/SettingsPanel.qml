import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as App
import "../ui" as Ui

// Kalends's settings. Every row here changes something real; anything not
// wired yet says so rather than offering a control that does nothing.
Item {
    id: panel
    property string filter: search.text.trim().toLowerCase()
    signal closed

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 200
                    implicitHeight: 32
                    radius: Ui.Appearance.rounding.full
                    color: Ui.Appearance.surfaceContainer
                    TextField {
                        id: search
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        placeholderText: qsTr("Search settings")
                        background: null
                        font.family: Ui.Appearance.font.family
                        font.pixelSize: Ui.Appearance.font.smaller
                        color: Ui.Appearance.onSurface
                        placeholderTextColor: Ui.Appearance.outlineVariant
                    }
                }
                Ui.IconButton {
                    icon: "close"
                    onClicked: panel.closed()
                }
            }

            Ui.SettingSection {
                title: qsTr("Calendar")
                Ui.SettingRow {
                    filter: panel.filter
                    label: qsTr("Week starts on Monday")
                    description: qsTr("Otherwise the grid starts on Sunday.")
                    terms: "first day week monday sunday"
                    hasSwitch: true
                    checked: App.Settings.mondayFirst
                    onToggled: on => App.Settings.set("mondayFirst", on)
                }
                Ui.SettingRow {
                    filter: panel.filter
                    label: qsTr("24-hour time")
                    description: qsTr("Event times as 14:30 rather than 2:30 PM.")
                    terms: "clock 12 24 am pm time format"
                    hasSwitch: true
                    checked: App.Settings.twentyFour
                    onToggled: on => App.Settings.set("twentyFour", on)
                }
                Ui.SettingRow {
                    filter: panel.filter
                    label: qsTr("Event dots")
                    description: qsTr("Mark days that have events in the month grid.")
                    terms: "dots markers indicator busy"
                    hasSwitch: true
                    checked: App.Settings.showDots
                    onToggled: on => App.Settings.set("showDots", on)
                }
                Ui.SettingRow {
                    filter: panel.filter
                    label: qsTr("Week numbers")
                    description: qsTr("Show the ISO week number beside each row.")
                    terms: "iso week number column"
                    hasSwitch: true
                    checked: App.Settings.weekNumbers
                    onToggled: on => App.Settings.set("weekNumbers", on)
                }
            }

            Ui.SettingSection {
                title: qsTr("Events")
                footer: qsTr("The store lives in ~/.local/share/kalends/calendars. "
                           + "Anything the app does here, `kalends` does from a terminal.")
                Ui.SettingRow {
                    filter: panel.filter
                    label: qsTr("Default calendar")
                    description: qsTr("Where new events go.")
                    terms: "calendar default new event personal work"
                    Ui.SegmentedControl {
                        implicitWidth: Math.min(420, App.Store.calendars.length * 96)
                        model: App.Store.calendars.map(c => ({ key: c.name, label: c.name }))
                        current: App.Settings.defaultCalendar
                        onPicked: k => App.Settings.set("defaultCalendar", k)
                    }
                }
                Ui.SettingRow {
                    filter: panel.filter
                    label: qsTr("Open on today")
                    description: qsTr("Otherwise it reopens on the month you last looked at.")
                    terms: "startup open today month remember"
                    hasSwitch: true
                    checked: App.Settings.openOnToday
                    onToggled: on => App.Settings.set("openOnToday", on)
                }
            }

            Ui.SettingSection {
                title: qsTr("Appearance")
                footer: qsTr("Colours come from the shell's palette — the same one Vane, Dotos and Vitals use — "
                           + "so this window matches the apps next to it and retints with the wallpaper.")
                Ui.SettingRow {
                    filter: panel.filter
                    label: qsTr("Font")
                    description: qsTr("Empty follows the desktop's own font.")
                    terms: "font family typeface text"
                    value: App.Settings.fontOverride.length > 0
                        ? App.Settings.fontOverride : Ui.Appearance.font.family
                    // shown, not set here: the desktop's font, unless config.json names one
                }
            }

            Item { Layout.preferredHeight: 8 }
        }
    }
}
