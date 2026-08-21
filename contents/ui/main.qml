import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ── Configuration ───────────────────────────────────────
    readonly property int cfgMenuSize: Plasmoid.configuration.menuSize
    readonly property int cfgIconSize: Plasmoid.configuration.iconSize
    readonly property int cfgRingRadius: Plasmoid.configuration.ringRadius
    readonly property real cfgBgOpacity: Plasmoid.configuration.bgOpacity
    readonly property bool cfgShowLabels: Plasmoid.configuration.showLabels
    readonly property bool cfgShowSectorLines: Plasmoid.configuration.showSectorLines
    readonly property string cfgAccentColor: Plasmoid.configuration.accentColorCustom
    readonly property real cfgAnimScale: Plasmoid.configuration.animationSpeed / 100.0
    readonly property string cfgPanelIcon: Plasmoid.configuration.panelIcon
    readonly property string cfgCenterIcon: Plasmoid.configuration.centerIcon
    readonly property string cfgMenuLayout: Plasmoid.configuration.menuLayout
    readonly property bool cfgRequireShortcut: Plasmoid.configuration.requireShortcut
    readonly property int cfgSemicircleRotation: Plasmoid.configuration.semicircleRotation
    readonly property int cfgCenterGap: Plasmoid.configuration.centerGap

    readonly property var cfgItems: {
        try { return JSON.parse(Plasmoid.configuration.menuItems) }
        catch (e) { return [] }
    }

    // ── App launcher ────────────────────────────────────────
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => { disconnectSource(sourceName) }
        function exec(cmd) { if (cmd) connectSource(cmd) }
    }

    // ── Compact representation ──────────────────────────────
    compactRepresentation: Item {
        Kirigami.Icon {
            anchors.fill: parent
            source: root.cfgPanelIcon || "view-grid"
            active: compactMouse.containsMouse
        }
        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            // When "require shortcut" is on, the panel icon is inert — the
            // menu only opens via the bound global shortcut action below.
            onClicked: { if (!root.cfgRequireShortcut) root.expanded = !root.expanded }
        }
    }

    // ── Full representation ─────────────────────────────────
    fullRepresentation: Item {
        id: fullRoot
        Layout.preferredWidth: root.cfgMenuSize + 60
        Layout.preferredHeight: root.cfgMenuSize + 60
        Layout.minimumWidth: root.cfgMenuSize + 60
        Layout.minimumHeight: root.cfgMenuSize + 60

        AdvancedRadialMenu {
            id: radialMenu
            anchors.centerIn: parent

            menuItems: root.cfgItems
            menuSize: root.cfgMenuSize
            cfgIconSize: root.cfgIconSize
            ringRadius: root.cfgRingRadius
            bgOpacity: root.cfgBgOpacity
            showLabels: root.cfgShowLabels
            showSectorLines: root.cfgShowSectorLines
            accentColor: root.cfgAccentColor !== ""
                ? root.cfgAccentColor
                : Kirigami.Theme.highlightColor
            animScale: root.cfgAnimScale
            centerIcon: root.cfgCenterIcon || "configure"
            menuLayout: root.cfgMenuLayout || "radial"
            semicircleRotation: root.cfgSemicircleRotation
            centerGap: root.cfgCenterGap

            onLaunchApp: (desktopFile) => {
                executable.exec("kioclient exec applications:" + desktopFile)
                root.expanded = false
            }

            onCloseRequested: {
                root.expanded = false
            }

            onOpenSettings: {
                // Trigger config dialog FIRST while QML context is still alive
                Plasmoid.internalAction("configure").trigger()
                root.expanded = false
            }
        }

        Component.onCompleted: radialMenu.show()
    }

    onExpandedChanged: {
        if (expanded && fullRepresentationItem) {
            for (let i = 0; i < fullRepresentationItem.children.length; i++) {
                let child = fullRepresentationItem.children[i]
                if (child.show) { child.show(); break }
            }
        }
        // "Always visible" mode (requireShortcut off): don't let it collapse.
        if (!expanded && !root.cfgRequireShortcut) {
            root.expanded = true
        }
    }

    Component.onCompleted: {
        // Registers a bindable action — set its global keyboard shortcut via
        // right-click the widget → "Configure Shortcuts…" (or System Settings
        // → Shortcuts → Plasma). Works whether requireShortcut is on or off.
        Plasmoid.setAction("toggleRadialMenu", i18n("Toggle Radial Menu"), root.cfgPanelIcon || "view-grid")
        Plasmoid.action("toggleRadialMenu").triggered.connect(function() {
            root.expanded = !root.expanded
        })
        if (!root.cfgRequireShortcut) root.expanded = true
    }
}
