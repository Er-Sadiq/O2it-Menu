import QtQuick
import QtQuick.Layouts
import QtQuick.Window
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
    // The shortcut is routed via onActivated below instead: panel and
    // hold-to-show modes open our own frameless dialog, not the applet popup.
    activationTogglesExpanded: false

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
    // Panel and hold-to-show open the menu in our own dialog. On the desktop
    // the widget then shows just its icon, so there's never a second menu.
    readonly property bool useDialog: inPanel || cfgRequireShortcut
    preferredRepresentation: useDialog ? compactRepresentation : null

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

            // Helpers for the dialog / hold-to-show mode
            function show() { radialMenu.show() }
            function launchHovered() {
                if (radialMenu.selectedIndex < 0) return false
                radialMenu.startLaunch(radialMenu.selectedIndex)
                return true
            }

            // Hold-to-show: the dialog takes keyboard focus when opened by the
            // shortcut, so releasing the held key(s) arrives here
            focus: true
            Keys.onReleased: (event) => {
                if (!root.holdOpen || event.isAutoRepeat) return
                const mods = event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)
                const isMod = [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Meta,
                               Qt.Key_Super_L, Qt.Key_Super_R].indexOf(event.key) >= 0
                // Wait until the whole chord is let go (e.g. Space up while Meta held)
                if (isMod || mods === 0) root.releaseHold()
            }
            Keys.onEscapePressed: root.closeMenu()

            Component.onCompleted: radialMenu.show()
        }
    }

    fullRepresentation: menuComponent

    // ── Menu dialog (panel click + hold-to-show shortcut) ───
    // The applet popup always draws Plasma's framed box and has no way to
    // turn it off; a PlasmaCore.Dialog does (backgroundHints: NoBackground),
    // so only the menu itself shows. Opened from the panel icon it's anchored
    // to the icon; opened by the shortcut it floats centered on the screen.
    PlasmaCore.Dialog {
        id: panelMenu
        visible: false
        visualParent: root.compactRepresentationItem
        location: Plasmoid.location
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        // Loader takes the loaded menu's size, so the dialog fits the content.
        // Kept loaded so the size is known before positioning.
        mainItem: Loader {
            id: dialogLoader
            focus: true
            active: root.useDialog
            sourceComponent: menuComponent
        }
        onVisibleChanged: {
            if (visible && dialogLoader.item) dialogLoader.item.show()
            if (!visible) root.holdOpen = false
        }
    }

    // True while the menu is open because the shortcut is being held
    property bool holdOpen: false

    function toggleMenu() {
        if (useDialog) {
            if (panelMenu.visible) { closeMenu(); return }
            panelMenu.visualParent = root.compactRepresentationItem
            panelMenu.location = Plasmoid.location
            panelMenu.visible = true
        } else {
            root.expanded = !root.expanded
        }
    }
    function closeMenu() {
        if (panelMenu.visible) panelMenu.visible = false
        else root.expanded = false
    }

    // Shortcut pressed in hold-to-show mode: centered on the screen, with
    // keyboard focus so the key release reaches the menu. While held, key
    // repeat re-fires the shortcut; ignore those instead of toggling. If the
    // release is swallowed, Esc or clicking away still closes it.
    function openHold() {
        if (panelMenu.visible) { if (!holdOpen) closeMenu(); return }
        holdOpen = true
        panelMenu.visualParent = null
        panelMenu.location = PlasmaCore.Types.Floating
        // Loader already has the menu's size; the dialog may not until shown
        panelMenu.x = Screen.virtualX + (Screen.width - dialogLoader.width) / 2
        panelMenu.y = Screen.virtualY + (Screen.height - dialogLoader.height) / 2
        panelMenu.visible = true
        panelMenu.requestActivate()
    }

    // Held key released: launch whatever the pointer is on, else close
    function releaseHold() {
        holdOpen = false
        if (!(dialogLoader.item && dialogLoader.item.launchHovered())) closeMenu()
    }

    // Global shortcut (Applet::activated)
    Connections {
        target: Plasmoid
        function onActivated() {
            if (root.cfgRequireShortcut) root.openHold()
            else if (root.inPanel) root.toggleMenu()
        }
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
    // needed (the Appearance page also binds it). That shortcut fires
    // Applet::activated(), handled by onActivated above.
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
