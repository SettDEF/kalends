# ui

The look, shared by Kalends and Dotos.

Same reasoning as [`icalcore`](../icalcore): the two apps are siblings and
should be indistinguishable in style. Two copies of a palette drift the moment
one of them is touched, and the drift is invisible until the windows are open
side by side.

    Appearance.qml    Material 3 roles read from kdeglobals — the file Dolphin
                      reads — so a window matches the desktop rather than
                      merely matching a palette. Type scale and rounding too.
    Icon.qml          a Material Symbol
    IconButton.qml    an icon with a hover state
    SettingRow.qml    one labelled control in a settings panel
    SettingSection.qml a titled group of them

Anything that knows what a calendar or a task is stays in the app. The
settings *panel* is per-app, because its contents are; the rows and sections
it is built from are here.

Imported by relative path: `import "../ui" as Ui`.
