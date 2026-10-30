import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "." as App
import "../ui" as Ui

/**
 * The sidebar of Dotos, Vane and Vitals, for a calendar: the name and today
 * at the top, New event, the pages (Month · Week · Agenda), a small month and
 * the calendars, Settings at the bottom. Collapses to an icon rail (Ctrl B).
 */
Rectangle {
    id: root
    readonly property bool collapsed: App.Settings.get("sidebarCollapsed", false)
    implicitWidth: root.collapsed ? 64 : 256
    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    color: App.Console.panel
    clip: true

    /// the number beside each entry, and whether it is a "look here" badge
    function count(key) {
        switch (key) {
            case "month": return { n: App.Store.eventsOn(App.Cal.todayIso).length, alert: false };
            case "agenda": {
                // what is coming in the next seven days
                let n = 0;
                for (let i = 0; i < 7; i++) { const d = new Date(); d.setDate(d.getDate() + i); n += App.Store.eventsOn(App.Store.iso(d)).length; }
                return { n, alert: false };
            }
            default: return { n: 0, alert: false };
        }
    }

    component Entry: Rectangle {
        id: entry
        required property var page
        readonly property bool sel: App.Nav.page === entry.page.key || (entry.page.key === "projects" && App.Nav.page === "project")
        readonly property var c: root.count(entry.page.key)
        Layout.fillWidth: true
        implicitHeight: 40
        radius: Ui.Appearance.rounding.small
        color: entry.sel ? Qt.alpha(App.Console.data, 0.16)
            : hov.hovered ? Qt.alpha(App.Console.text, 0.06) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: App.Nav.go(entry.page.key) }
        ToolTip.visible: root.collapsed && hov.hovered
        ToolTip.delay: 300
        ToolTip.text: entry.c.n > 0 ? `${entry.page.label}  ·  ${entry.c.n}` : entry.page.label

        Rectangle {
            visible: entry.sel
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 3; height: 18; radius: 1.5
            color: App.Console.data
        }
        RowLayout {
            anchors { fill: parent; leftMargin: root.collapsed ? 0 : 12; rightMargin: root.collapsed ? 0 : 10 }
            spacing: 10
            Item {
                Layout.fillWidth: root.collapsed
                implicitWidth: 18; implicitHeight: 18
                Ui.Icon {
                    anchors.centerIn: parent
                    text: entry.page.icon
                    size: 20
                    filled: entry.sel
                    color: entry.sel ? App.Console.data : App.Console.dim
                }
                Rectangle {
                    visible: root.collapsed && entry.c.alert && entry.c.n > 0
                    anchors { right: parent.right; top: parent.top; rightMargin: (parent.width - 18) / 2 - 3; topMargin: -3 }
                    width: 8; height: 8; radius: 4
                    color: App.Console.crit
                    border.width: 1.5
                    border.color: App.Console.panel
                }
            }
            Text {
                visible: !root.collapsed
                Layout.fillWidth: true
                text: entry.page.label
                font.family: App.Console.sans
                font.pixelSize: 15
                font.weight: entry.sel ? Font.DemiBold : Font.Normal
                color: entry.sel ? App.Console.text : App.Console.dim
                elide: Text.ElideRight
            }
            Rectangle {
                visible: !root.collapsed && entry.c.n > 0 && entry.c.alert
                implicitWidth: Math.max(20, badgeText.implicitWidth + 10)
                implicitHeight: 18
                radius: 9
                color: App.Console.crit
                Text { id: badgeText; anchors.centerIn: parent; text: entry.c.n; font.family: App.Console.mono; font.pixelSize: 11; font.weight: Font.DemiBold; color: App.Console.bg }
            }
            Text {
                visible: !root.collapsed && entry.c.n > 0 && !entry.c.alert
                text: entry.c.n
                font.family: App.Console.mono
                font.pixelSize: 12
                color: App.Console.faint
            }
        }
    }

    component Group: Item {
        property string label: ""
        Layout.fillWidth: true
        implicitHeight: root.collapsed ? 17 : 33
        App.Label {
            visible: !root.collapsed
            anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 4 }
            text: parent.label
            font.pixelSize: 12
            color: App.Console.faint
        }
        Rectangle {
            visible: root.collapsed
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 }
            height: 1
            color: App.Console.rule
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 10; topMargin: 14 }
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.collapsed ? 0 : 6
            Layout.bottomMargin: 12
            spacing: 10
            Rectangle {
                Layout.alignment: root.collapsed ? Qt.AlignHCenter : Qt.AlignLeft
                implicitWidth: 34; implicitHeight: 34; radius: 10
                readonly property color tone: App.Store.lastError || App.Store.writeError ? App.Console.crit : App.Console.data
                // the app's own icon; narrow, a hover turns it into "expand"; a dot says when something needs you
                color: logoHov.hovered && root.collapsed ? Qt.alpha(App.Console.data, 0.2) : "transparent"
                Image { anchors.fill: parent; visible: !(root.collapsed && logoHov.hovered); source: Quickshell.iconPath("kalends", true); sourceSize: Qt.size(68, 68); smooth: true }
                Ui.Icon { anchors.fill: parent; visible: root.collapsed && logoHov.hovered; text: "left_panel_open"; size: 20; color: App.Console.data }
                Rectangle {
                    visible: parent.tone !== App.Console.data
                    anchors { right: parent.right; top: parent.top; margins: -1 }
                    width: 9; height: 9; radius: 4.5
                    color: parent.tone; border.width: 2; border.color: App.Console.bg
                }
                HoverHandler { id: logoHov; cursorShape: root.collapsed ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { enabled: root.collapsed; onTapped: App.Settings.set("sidebarCollapsed", false) }
                ToolTip.visible: root.collapsed && logoHov.hovered
                ToolTip.text: qsTr("Expand sidebar  (Ctrl B)")
            }
            ColumnLayout {
                visible: !root.collapsed
                Layout.fillWidth: true
                spacing: 0
                Text { text: "Kalends"; font.family: App.Console.sans; font.pixelSize: 15; font.weight: Font.DemiBold; color: App.Console.text }
                Text {
                    Layout.fillWidth: true
                    text: App.Store.lastError || App.Store.writeError || Qt.formatDate(new Date(), "dddd, d MMMM")
                    font.family: App.Console.sans
                    font.pixelSize: 12
                    color: App.Store.lastError || App.Store.writeError ? App.Console.crit : App.Console.dim
                    elide: Text.ElideRight
                }
            }
            Ui.IconButton {
                visible: !root.collapsed
                implicitWidth: 28; implicitHeight: 28
                icon: "left_panel_close"
                tooltip: qsTr("Collapse sidebar  (Ctrl B)")
                onClicked: App.Settings.set("sidebarCollapsed", true)
            }
        }

        // the one main action, as in the sketch
        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            implicitHeight: 40
            radius: Ui.Appearance.rounding.small
            color: newHov.hovered ? Qt.lighter(App.Console.data, 1.08) : App.Console.data
            HoverHandler { id: newHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: App.Nav.run("new") }
            ToolTip.visible: root.collapsed && newHov.hovered
            ToolTip.text: qsTr("New event  (N)")
            RowLayout {
                anchors { fill: parent; leftMargin: root.collapsed ? 0 : 14; rightMargin: 12 }
                spacing: 8
                Ui.Icon { Layout.fillWidth: root.collapsed; text: "add"; size: 20; color: App.Console.onData }
                Text { visible: !root.collapsed; Layout.fillWidth: true; text: qsTr("New event"); font.family: App.Console.sans; font.pixelSize: 15; font.weight: Font.DemiBold; color: App.Console.onData }
                Text { visible: !root.collapsed; text: "N"; font.family: App.Console.mono; font.pixelSize: 11; color: Qt.alpha(App.Console.onData, 0.7) }
            }
        }

        Repeater { model: App.Nav.pages.filter(p => p.group === ""); Entry { required property var modelData; page: modelData } }
        // a small month to pick a day, and the calendars: only when there is room
        App.MiniMonth {
            visible: !root.collapsed
            Layout.fillWidth: true
            Layout.topMargin: 14
            selected: App.Cal.selected
            onPicked: d => App.Cal.select(d)
        }
        App.CalendarList {
            visible: !root.collapsed && App.Store.calendars.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 10
        }

        Item { Layout.fillHeight: true }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: App.Console.rule; Layout.bottomMargin: 6 }
        Repeater { model: App.Nav.pages.filter(p => p.group === "foot"); Entry { required property var modelData; page: modelData } }
    }

    Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: App.Console.rule }
}
