import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: appearanceRoot

    property alias cfg_menuSize: menuSizeSlider.value
    property alias cfg_iconSize: iconSizeSlider.value
    property alias cfg_ringRadius: ringRadiusSlider.value
    property alias cfg_bgOpacity: bgOpacitySlider.value
    property alias cfg_showLabels: showLabelsCheck.checked
    property alias cfg_showSectorLines: showSectorLinesCheck.checked
    property alias cfg_animationSpeed: animSpeedSlider.value
    property alias cfg_requireShortcut: requireShortcutCheck.checked
    property alias cfg_semicircleRotation: semicircleRotationSlider.value
    property alias cfg_centerGap: centerGapSlider.value
    property string cfg_accentColorCustom
    property string cfg_panelIcon
    property string cfg_centerIcon
    property string cfg_menuLayout

    // Layout options — two parallel arrays (same pattern as colorpicker)
    readonly property var layoutValues: ["hexagonal", "wheel", "semicircle"]
    readonly property var layoutLabels: [
        i18n("Hexagonal (Hex Icons)"),
        i18n("Wheel (Pie Sectors)"),
        i18n("Semi-Circle (Arc)")
    ]

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
            text: i18n("Menu stays open on screen at all times instead of popping up from the panel icon.")
        }

        Item { Kirigami.FormData.isSection: true }

        // ── Icons ───────────────────────────────────────────
        Kirigami.Heading {
            text: i18n("Icons")
            level: 4
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Panel icon:")
            spacing: Kirigami.Units.smallSpacing
            QQC2.TextField {
                text: cfg_panelIcon
                placeholderText: "view-grid"
                onTextChanged: cfg_panelIcon = text
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: cfg_panelIcon || "view-grid"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Center icon:")
            spacing: Kirigami.Units.smallSpacing
            QQC2.TextField {
                text: cfg_centerIcon
                placeholderText: "configure"
                onTextChanged: cfg_centerIcon = text
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: cfg_centerIcon || "configure"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
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
                from: 300; to: 600; stepSize: 10
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: Math.round(menuSizeSlider.value) + " px"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Ring radius:")
            spacing: Kirigami.Units.smallSpacing
            QQC2.Slider {
                id: ringRadiusSlider
                from: 80; to: 220; stepSize: 5
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: Math.round(ringRadiusSlider.value) + " px"
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

        RowLayout {
            Kirigami.FormData.label: i18n("Animation speed:")
            spacing: Kirigami.Units.smallSpacing
            QQC2.Slider {
                id: animSpeedSlider
                from: 50; to: 200; stepSize: 10
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: Math.round(animSpeedSlider.value) + "%"
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
            QQC2.TextField {
                enabled: customAccentRadio.checked
                text: cfg_accentColorCustom
                placeholderText: "#3daee9"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                onTextChanged: { if (customAccentRadio.checked) cfg_accentColorCustom = text }
            }
            Rectangle {
                width: Kirigami.Units.gridUnit * 1.5
                height: Kirigami.Units.gridUnit * 1.5
                radius: 4
                color: cfg_accentColorCustom !== "" ? cfg_accentColorCustom : Kirigami.Theme.highlightColor
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.2)
            }
        }
    }
}
