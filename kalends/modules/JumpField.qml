import QtQuick
import QtQuick.Controls
import "../ui" as Ui

// Jump to a date. Accepts the same vocabulary the CLI does — today, tomorrow,
// yesterday, YYYY-MM-DD — plus a bare day number for the month on screen, so
// the window and the terminal do not grow two different date languages.
Rectangle {
    id: root
    property int year: 0
    property int month: 0
    signal jumped(int year, int month, string iso)

    implicitWidth: 140
    implicitHeight: 32
    radius: Ui.Appearance.rounding.full
    color: Ui.Appearance.surfaceContainer
    border.width: field.activeFocus ? 1 : 0
    border.color: Ui.Appearance.primary

    function parse(text) {
        const t = String(text ?? "").trim().toLowerCase();
        if (t.length === 0) return null;
        const pad = n => (n < 10 ? "0" + n : "" + n);
        const iso = d => d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
        const now = new Date();
        if (t === "today")     return iso(now);
        if (t === "tomorrow")  { const d = new Date(now); d.setDate(d.getDate() + 1); return iso(d); }
        if (t === "yesterday") { const d = new Date(now); d.setDate(d.getDate() - 1); return iso(d); }
        // A bare number means that day of the month currently on screen.
        if (/^\d{1,2}$/.test(t)) {
            const day = parseInt(t, 10);
            if (day >= 1 && day <= 31) return root.year + "-" + pad(root.month) + "-" + pad(day);
        }
        if (/^\d{4}-\d{1,2}-\d{1,2}$/.test(t)) {
            const p = t.split("-").map(Number);
            const d = new Date(p[0], p[1] - 1, p[2]);
            // Round-trip check: 2026-02-31 parses but is not a real date.
            if (d.getMonth() === p[1] - 1 && d.getDate() === p[2]) return iso(d);
        }
        return null;
    }

    function go() {
        const iso = root.parse(field.text);
        if (!iso) { field.color = Ui.Appearance.error; return; }
        const p = iso.split("-").map(Number);
        root.jumped(p[0], p[1], iso);
        field.text = "";
        field.color = Ui.Appearance.onSurface;
    }

    TextField {
        id: field
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        placeholderText: qsTr("Jump to…")
        background: null
        font.family: Ui.Appearance.font.family
        font.pixelSize: Ui.Appearance.font.smaller
        color: Ui.Appearance.onSurface
        placeholderTextColor: Ui.Appearance.outlineVariant
        onAccepted: root.go()
        // Clear the error tint as soon as it is being corrected.
        onTextChanged: if (color === Ui.Appearance.error) color = Ui.Appearance.onSurface
        Keys.onEscapePressed: { text = ""; focus = false; }
    }
}
