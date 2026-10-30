import QtQuick
import QtQuick.Layouts
import "." as App
import "month.js" as Month
import "../ui" as Ui

// The week as a timeline: all-day events in a strip on top, timed ones as
// blocks on a 24-hour grid, overlaps side by side, and a line at "now".
Rectangle {
    id: root
    required property string selected
    signal picked(string date)
    signal opened(string date)
    signal eventPicked(string date, string uid)

    readonly property var days: Month.weekOf(root.selected, App.Settings.mondayFirst)
    readonly property real hourH: 46
    readonly property int gutter: 52
    readonly property string todayIso: Month.isoOf(new Date())
    property real nowMin: 0

    radius: Ui.Appearance.rounding.normal
    color: Ui.Appearance.surfaceContainer
    clip: true

    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { const d = new Date(); root.nowMin = d.getHours() * 60 + d.getMinutes(); }
    }

    // open at the morning, or at the first event if it starts earlier
    function scrollHome() {
        let first = 8 * 60;
        for (const d of root.days)
            for (const it of Month.layoutDay(App.Store.eventsOn(d), d)) first = Math.min(first, it.top);
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, first / 60 * root.hourH - root.hourH));
    }
    // Once per week shown, and again when its events arrive (they load after
    // the week does) — but never on a later reload, which would yank the
    // view away from where the user scrolled.
    property bool homePending: true
    onDaysChanged: { root.homePending = true; Qt.callLater(root.scrollHome); }
    Component.onCompleted: Qt.callLater(root.scrollHome)
    Connections {
        target: App.Store
        function onByDayChanged() { if (root.homePending) { root.homePending = false; Qt.callLater(root.scrollHome); } }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 0

        // ── day headers ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.gutter
            spacing: 0
            Repeater {
                model: root.days
                delegate: Item {
                    id: head
                    required property string modelData
                    readonly property bool today: head.modelData === root.todayIso
                    readonly property bool sel: head.modelData === root.selected
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 52
                    TapHandler { onTapped: root.picked(head.modelData); onDoubleTapped: root.opened(head.modelData) }
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(Month.parse(head.modelData), "ddd")
                            font.family: Ui.Appearance.font.family
                            font.pixelSize: Ui.Appearance.font.smallest
                            font.weight: Font.Medium
                            color: head.today ? Ui.Appearance.primary : Ui.Appearance.onSurfaceVariant
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 30; height: 30; radius: 15
                            color: head.today ? Ui.Appearance.primary
                                 : head.sel ? Ui.Appearance.surfaceContainerHigh : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: Month.parse(head.modelData).getDate()
                                font.family: Ui.Appearance.font.family
                                font.pixelSize: Ui.Appearance.font.small
                                font.weight: head.today || head.sel ? Font.DemiBold : Font.Normal
                                color: head.today ? Ui.Appearance.textOnPrimary : Ui.Appearance.onSurface
                            }
                        }
                    }
                }
            }
        }

        // ── all-day strip ───────────────────────────────────────────
        RowLayout {
            id: allDayRow
            readonly property int most: Math.max(0, ...root.days.map(d => App.Store.eventsOn(d).filter(e => e.all_day).length))
            visible: most > 0
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: 0
            Text {
                Layout.preferredWidth: root.gutter
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 2
                rightPadding: 8
                horizontalAlignment: Text.AlignRight
                text: qsTr("all day")
                font.family: Ui.Appearance.font.family
                font.pixelSize: Ui.Appearance.font.smallest
                color: Ui.Appearance.outlineVariant
            }
            Repeater {
                model: root.days
                delegate: Column {
                    id: adCol
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 2
                    Repeater {
                        model: App.Store.eventsOn(adCol.modelData).filter(e => e.all_day).slice(0, 3)
                        delegate: App.EventPill {
                            required property var modelData
                            x: 2
                            width: adCol.width - 4
                            event: modelData
                            onPicked: root.eventPicked(adCol.modelData, String(modelData.uid ?? ""))
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Appearance.background }

        // ── the timeline ────────────────────────────────────────────
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: 24 * root.hourH + 8
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Item {
                width: flick.width
                height: flick.contentHeight

                // hour lines and labels
                Repeater {
                    model: 24
                    delegate: Item {
                        required property int index
                        y: index * root.hourH + 4
                        width: parent.width
                        Text {
                            visible: index > 0
                            width: root.gutter - 8
                            y: -height / 2
                            horizontalAlignment: Text.AlignRight
                            text: App.Settings.twentyFour ? String(index).padStart(2, "0") + ":00"
                                : ((index % 12) || 12) + (index < 12 ? " AM" : " PM")
                            font.family: Ui.Appearance.font.mono
                            font.pixelSize: Ui.Appearance.font.smallest
                            color: Ui.Appearance.outlineVariant
                        }
                        Rectangle {
                            x: root.gutter; width: parent.width - root.gutter; height: 1
                            color: Ui.Appearance.background
                            opacity: 0.8
                        }
                    }
                }

                Row {
                    x: root.gutter
                    y: 4
                    width: parent.width - root.gutter
                    height: 24 * root.hourH
                    Repeater {
                        model: root.days
                        delegate: Item {
                            id: dayCol
                            required property string modelData
                            readonly property bool today: dayCol.modelData === root.todayIso
                            width: parent.width / 7
                            height: parent.height

                            Rectangle {   // column divider + today's tint
                                anchors.fill: parent
                                color: dayCol.today ? App.Store.tint(Ui.Appearance.primary, 0.05) : "transparent"
                                Rectangle { width: 1; height: parent.height; color: Ui.Appearance.background; opacity: 0.8 }
                            }
                            TapHandler { onTapped: root.picked(dayCol.modelData); onDoubleTapped: root.opened(dayCol.modelData) }

                            Repeater {
                                model: Month.layoutDay(App.Store.eventsOn(dayCol.modelData), dayCol.modelData)
                                delegate: Rectangle {
                                    id: block
                                    required property var modelData
                                    readonly property color cal: App.Store.colorOf(block.modelData.ev.calendar ?? "")
                                    readonly property real colW: (dayCol.width - 6) / block.modelData.cols
                                    x: 3 + block.modelData.col * block.colW
                                    y: block.modelData.top / 60 * root.hourH + 1
                                    width: block.colW - 2
                                    height: Math.max(18, (block.modelData.bottom - block.modelData.top) / 60 * root.hourH - 2)
                                    radius: 6
                                    color: App.Store.tint(block.cal, bHov.hovered ? 0.45 : 0.30)
                                    clip: true
                                    HoverHandler { id: bHov; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.eventPicked(dayCol.modelData, String(block.modelData.ev.uid ?? "")) }
                                    Rectangle { width: 3; height: parent.height; radius: 2; color: block.cal }
                                    Column {
                                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 8; rightMargin: 4; topMargin: 3 }
                                        Text {
                                            width: parent.width
                                            text: block.modelData.ev.summary ?? ""
                                            elide: Text.ElideRight
                                            maximumLineCount: block.height > 50 ? 2 : 1
                                            wrapMode: Text.Wrap
                                            font.family: Ui.Appearance.font.family
                                            font.pixelSize: Ui.Appearance.font.smallest
                                            font.weight: Font.DemiBold
                                            color: Ui.Appearance.onSurface
                                        }
                                        Text {
                                            visible: block.height > 34
                                            width: parent.width
                                            text: App.Store.clockOf(block.modelData.ev.start) + " – " + App.Store.clockOf(block.modelData.ev.end)
                                                + (block.modelData.ev.location ? "  ·  " + block.modelData.ev.location : "")
                                            elide: Text.ElideRight
                                            font.family: Ui.Appearance.font.family
                                            font.pixelSize: Ui.Appearance.font.smallest
                                            color: Ui.Appearance.onSurfaceVariant
                                        }
                                    }
                                }
                            }

                            // now
                            Rectangle {
                                visible: dayCol.today
                                y: root.nowMin / 60 * root.hourH - 1
                                width: parent.width; height: 2
                                color: Ui.Appearance.error
                                Rectangle { x: -4; y: -3; width: 8; height: 8; radius: 4; color: Ui.Appearance.error }
                            }
                        }
                    }
                }
            }
        }
    }
}
