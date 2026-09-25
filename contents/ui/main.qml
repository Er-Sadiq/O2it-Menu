import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // Makes the pre-existing per-widget global shortcut (bound via
    // right-click → "Configure Shortcuts…", no registration code needed —
    // every applet already has Plasma::Applet.globalShortcut) actually
    // toggle this widget open/closed when triggered, instead of doing
    // nothing. Note: this is a property of PlasmoidItem/AppletQuickItem
    // itself (like `expanded` used elsewhere in this file), not a
    // Plasmoid.* attached property — confirmed via the installed
    // plasmoidplugin.qmltypes, where it's declared on
    // PlasmaQuick::AppletQuickItem, not on the Plasmoid interface.
    // In a panel the menu opens in our own frameless dialog instead of the
    // applet popup, so the shortcut is routed via onActivated below.
    activationTogglesExpanded: !inPanel

    // ── Configuration ───────────────────────────────────────
    readonly property int cfgMenuSize: Plasmoid.configuration.menuSize
    readonly property int cfgIconSize: Plasmoid.configuration.iconSize
    readonly property real cfgBgOpacity: Plasmoid.configuration.bgOpacity
    readonly property bool cfgShowLabels: Plasmoid.configuration.showLabels
    readonly property bool cfgShowSectorLines: Plasmoid.configuration.showSectorLines
    readonly property string cfgAccentColor: Plasmoid.configuration.accentColorCustom
    readonly property string cfgPanelIcon: Plasmoid.configuration.panelIcon
    readonly property string cfgCenterIcon: Plasmoid.configuration.centerIcon
    readonly property string cfgMenuLayout: Plasmoid.configuration.menuLayout
    readonly property string cfgMenuStyle: Plasmoid.configuration.menuStyle
    readonly property bool cfgRequireShortcut: Plasmoid.configuration.requireShortcut
    readonly property int cfgSemicircleRotation: Plasmoid.configuration.semicircleRotation
    readonly property int cfgCenterGap: Plasmoid.configuration.centerGap

    // "Always visible" only makes sense on the desktop. In a panel, forcing
    // the popup open made it pop up unasked, re-open the instant it was
    // dismissed, and steal focus from the config dialog.
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                                 || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool alwaysVisible: !inPanel && !cfgRequireShortcut

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
        // kstart resolves apps via KService (the same mechanism Kicker's own
        // AppEntry uses to launch), independent of the applications: KIO
        // menu-category tree — see appentry.cpp's ApplicationLauncherJob.
        // "kioclient exec applications:<id>" was tried previously and fails
        // for almost every app ("Unknown application folder") because that
        // KIO slave is organized by category folder, not by flat desktop-id.
        function launch(desktopId) {
            if (!desktopId) return
            var id = desktopId.endsWith(".desktop") ? desktopId.slice(0, -".desktop".length) : desktopId
            // Single-quote and escape any embedded single quotes — desktop
            // ids are almost always [A-Za-z0-9.-_], but don't trust config
            // JSON blindly since it can be hand-edited.
            var safe = "'" + id.replace(/'/g, "'\\''") + "'"
            // Bound with timeout: kstart can hang indefinitely on an
            // unresolvable desktop id (confirmed — it never exits on its
            // own), which would otherwise leave onNewData never firing and
            // the source connected forever.
            connectSource("timeout 15 kstart --application " + safe)
        }
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
            onClicked: { if (!root.cfgRequireShortcut) root.toggleMenu() }
        }
    }

    // ── Menu (shared by desktop full representation + panel dialog) ──
    Component {
        id: menuComponent
        Item {
            id: fullRoot
            // Sized to what the menu actually draws (semicircle only fills
            // half its square), so the panel dialog sits right against the panel
            width: Math.ceil(radialMenu.contentRect.width)
            height: Math.ceil(radialMenu.contentRect.height)
            Layout.preferredWidth: width
            Layout.preferredHeight: height
            Layout.minimumWidth: width
            Layout.minimumHeight: height

            AdvancedRadialMenu {
                id: radialMenu
                x: -contentRect.x
                y: -contentRect.y

                menuItems: root.cfgItems
                menuSize: root.cfgMenuSize
                cfgIconSize: root.cfgIconSize
                bgOpacity: root.cfgBgOpacity
                showLabels: root.cfgShowLabels
                showSectorLines: root.cfgShowSectorLines
                accentColor: root.cfgAccentColor !== ""
                    ? root.cfgAccentColor
                    : Kirigami.Theme.highlightColor
                centerIcon: root.cfgCenterIcon || "configure"
                menuLayout: root.cfgMenuLayout || "radial"
                menuStyle: root.cfgMenuStyle || "glass"
                semicircleRotation: root.cfgSemicircleRotation
                centerGap: root.cfgCenterGap

                onLaunchApp: (desktopFile) => {
                    executable.launch(desktopFile)
                    root.closeMenu()
                }

                onCloseRequested: root.closeMenu()

                onOpenSettings: {
                    // Trigger config dialog FIRST while QML context is still alive
                    Plasmoid.internalAction("configure").trigger()
                    root.closeMenu()
                }
            }

            Component.onCompleted: radialMenu.show()
        }
    }

    fullRepresentation: menuComponent

    // ── Panel menu ──────────────────────────────────────────
    // The applet popup always draws Plasma's framed box and has no way to
    // turn it off; a PlasmaCore.Dialog does (backgroundHints: NoBackground),
    // so in a panel only the menu itself shows. It's recreated on each open,
    // which replays the entrance animation.
    PlasmaCore.Dialog {
        id: panelMenu
        visible: false
        visualParent: root.compactRepresentationItem
        location: Plasmoid.location
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        // Loader takes the loaded menu's size, so the dialog fits the content
        mainItem: Loader {
            active: panelMenu.visible
            sourceComponent: menuComponent
        }
    }

    function toggleMenu() {
        if (inPanel) panelMenu.visible = !panelMenu.visible
        else root.expanded = !root.expanded
    }
    function closeMenu() {
        if (inPanel) panelMenu.visible = false
        else root.expanded = false
    }

    // Global shortcut (Applet::activated) in panel mode
    Connections {
        target: Plasmoid
        enabled: root.inPanel
        function onActivated() { root.toggleMenu() }
    }

    onExpandedChanged: {
        if (expanded && fullRepresentationItem) {
            for (let i = 0; i < fullRepresentationItem.children.length; i++) {
                let child = fullRepresentationItem.children[i]
                if (child.show) { child.show(); break }
            }
        }
        // "Always visible" mode (desktop, requireShortcut off): don't let it collapse.
        if (!expanded && root.alwaysVisible) {
            root.expanded = true
        }
    }

    // Plasma 6 removed the old imperative Plasmoid.setAction()/action().
    // triggered.connect() API (confirmed absent from the installed
    // plasmoidplugin.qmltypes). Plasmoid.contextualActions below adds a
    // context-menu entry ("Toggle Radial Menu") — it is NOT itself bindable
    // to a global keyboard shortcut. The widget's actual global shortcut is
    // Plasma::Applet's built-in `globalShortcut` property, which every
    // applet already exposes via right-click → "Configure Shortcuts…" (or
    // System Settings → Shortcuts → Plasma) with no registration code
    // needed. That shortcut fires Applet::activated(), which toggles this
    // widget open/closed via `activationTogglesExpanded` (desktop) or the
    // onActivated handler above (panel).
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Toggle Radial Menu")
            icon.name: root.cfgPanelIcon || "view-grid"
            onTriggered: root.toggleMenu()
        }
    ]

    Component.onCompleted: {
        if (root.alwaysVisible) root.expanded = true
    }
}
