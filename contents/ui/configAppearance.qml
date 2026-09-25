import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    id: appearanceRoot

    property alias cfg_menuSize: menuSizeSlider.value
    property alias cfg_iconSize: iconSizeSlider.value
    property alias cfg_bgOpacity: bgOpacitySlider.value
    property alias cfg_showLabels: showLabelsCheck.checked
    property alias cfg_showSectorLines: showSectorLinesCheck.checked
    property alias cfg_requireShortcut: requireShortcutCheck.checked
    property alias cfg_semicircleRotation: semicircleRotationSlider.value
    property alias cfg_centerGap: centerGapSlider.value
    property string cfg_accentColorCustom
    property string cfg_panelIcon
    property string cfg_centerIcon
    property string cfg_menuLayout
    property string cfg_menuStyle

    // Layout options — two parallel arrays (same pattern as colorpicker)
    readonly property var layoutValues: ["hexagonal", "wheel", "semicircle"]
    readonly property var layoutLabels: [
        i18n("Hexagonal (Hex Icons)"),
        i18n("Wheel (Pie Sectors)"),
        i18n("Semi-Circle (Arc)")
    ]

    readonly property var styleValues: ["glass", "neon", "minimal"]
    readonly property var styleLabels: [
        i18n("Glass (Depth)"),
        i18n("Neon (Glow)"),
        i18n("Minimal (Clean)")
    ]

    // One shared icon dialog; iconTarget says which config key it's editing
    property string iconTarget: ""
    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: {
            if (!iconName) return
            if (appearanceRoot.iconTarget === "panel") cfg_panelIcon = iconName
            else if (appearanceRoot.iconTarget === "center") cfg_centerIcon = iconName
        }
    }
    function pickIcon(target) { iconTarget = target; iconDialog.open() }

    Kirigami.FormLayout {

        // ── Menu Layout ─────────────────────────────────────
        Kirigami.Heading {
            text: i18n("Layout Style")
            level: 4
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            id: layoutCombo
            Kirigami.FormData.label: i18n("Menu layout:")
            model: appearanceRoot.layoutLabels
            currentIndex: appearanceRoot.layoutValues.indexOf(cfg_menuLayout)
            onActivated: index => {
                cfg_menuLayout = appearanceRoot.layoutValues[index]
            }
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Style:")
            model: appearanceRoot.styleLabels
            currentIndex: Math.max(0, appearanceRoot.styleValues.indexOf(cfg_menuStyle))
            onActivated: index => {
                cfg_menuStyle = appearanceRoot.styleValues[index]
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Semi-circle rotation:")
            visible: cfg_menuLayout === "semicircle"
            spacing: Kirigami.Units.smallSpacing
            QQC2.Slider {
                id: semicircleRotationSlider
                from: 0; to: 359; stepSize: 5
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: Math.round(semicircleRotationSlider.value) + "°"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        Item { Kirigami.FormData.isSection: true }

        // ── Activation ────────────────────────────────────────
        Kirigami.Heading {
            text: i18n("Activation")
            level: 4
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: requireShortcutCheck
            Kirigami.FormData.label: i18n("Trigger:")
            text: i18n("Only open via keyboard shortcut")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: requireShortcutCheck.checked
            type: Kirigami.MessageType.Information
            text: i18n("Bind the key: right-click this widget → Configure Shortcuts… (or System Settings → Shortcuts → Plasma) and assign a key to \"Toggle Radial Menu\".")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !requireShortcutCheck.checked
            type: Kirigami.MessageType.Information
            text: i18n("On the desktop the menu stays open at all times. In a panel, click the icon to open it.")
        }

        Item { Kirigami.FormData.isSection: true }

        // ── Icons ───────────────────────────────────────────
        Kirigami.Heading {
            text: i18n("Icons")
            level: 4
            Kirigami.FormData.isSection: true
        }

        QQC2.Button {
            Kirigami.FormData.label: i18n("Panel icon:")
            icon.name: cfg_panelIcon || "view-grid"
            icon.width: Kirigami.Units.iconSizes.medium
            icon.height: Kirigami.Units.iconSizes.medium
            text: i18n("Choose…")
            onClicked: appearanceRoot.pickIcon("panel")
        }

        QQC2.Button {
            Kirigami.FormData.label: i18n("Center icon:")
            icon.name: cfg_centerIcon || "configure"
            icon.width: Kirigami.Units.iconSizes.medium
            icon.height: Kirigami.Units.iconSizes.medium
            text: i18n("Choose…")
            onClicked: appearanceRoot.pickIcon("center")
        }

        Item { Kirigami.FormData.isSection: true }

        // ── Size & Layout ───────────────────────────────────
        Kirigami.Heading {
            text: i18n("Size & Layout")
            level: 4
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Menu size:")
            spacing: Kirigami.Units.smallSpacing
            QQC2.Slider {
                id: menuSizeSlider
                from: 260; to: 640; stepSize: 10
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: Math.round(menuSizeSlider.value) + " px"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Ring distance:")
            spacing: Kirigami.Units.smallSpacing
            QQC2.Slider {
                id: centerGapSlider
                from: -40; to: 150; stepSize: 5
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: Math.round(centerGapSlider.value) + " px"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Ring, items, icons and spacing all scale with the menu size. Values below are at the default 400 px size.")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Icon size:")
            spacing: Kirigami.Units.smallSpacing
            QQC2.Slider {
                id: iconSizeSlider
                from: 18; to: 48; stepSize: 2
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: Math.round(iconSizeSlider.value) + " px"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        Item { Kirigami.FormData.isSection: true }

        // ── Visual Style ────────────────────────────────────
        Kirigami.Heading {
            text: i18n("Visual Style")
            level: 4
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Background opacity:")
            spacing: Kirigami.Units.smallSpacing
            QQC2.Slider {
                id: bgOpacitySlider
                from: 0.0; to: 1.0; stepSize: 0.05
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: Math.round(bgOpacitySlider.value * 100) + "%"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        QQC2.CheckBox {
            id: showLabelsCheck
            Kirigami.FormData.label: i18n("Labels:")
            text: i18n("Show item labels on hover")
        }

        QQC2.CheckBox {
            id: showSectorLinesCheck
            Kirigami.FormData.label: i18n("Dividers:")
            text: i18n("Show sector divider lines")
        }

        Item { Kirigami.FormData.isSection: true }

        // ── Accent Color ────────────────────────────────────
        Kirigami.Heading {
            text: i18n("Accent Color")
            level: 4
            Kirigami.FormData.isSection: true
        }

        QQC2.RadioButton {
            id: systemAccentRadio
            Kirigami.FormData.label: i18n("Color:")
            text: i18n("Use system accent color")
            checked: cfg_accentColorCustom === ""
            onToggled: { if (checked) cfg_accentColorCustom = "" }
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            QQC2.RadioButton {
                id: customAccentRadio
                text: i18n("Custom:")
                checked: cfg_accentColorCustom !== ""
                onToggled: {
                    if (checked && cfg_accentColorCustom === "")
                        cfg_accentColorCustom = "#3daee9"
                }
            }
            KQuickControls.ColorButton {
                enabled: customAccentRadio.checked
                showAlphaChannel: false
                color: cfg_accentColorCustom !== "" ? cfg_accentColorCustom : Kirigami.Theme.highlightColor
                onAccepted: picked => { cfg_accentColorCustom = picked.toString() }
            }
        }
    }
}
