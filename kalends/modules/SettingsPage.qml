import QtQuick
import QtQuick.Layouts
import "." as App

/** Settings: calendar, events, appearance — saved in ~/.config/kalends/config.json. */
Item {
    id: page
    property string key: "settings"
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        App.Toolbar { title: qsTr("Settings"); subtitle: "~/.config/kalends/config.json" }
        App.SettingsPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            onClosed: App.Nav.go(App.Settings.get("view", "month"))
        }
    }
}
