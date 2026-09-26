import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.iconthemes as KIconThemes

KCM.SimpleKCM {
    id: configRoot

    property string cfg_menuItems

    // Internal list model built from JSON
    ListModel { id: listModel }

    property bool loading: false

    Component.onCompleted: loadFromConfig()
    onCfg_menuItemsChanged: {
        if (!loading) loadFromConfig()
    }

    function loadFromConfig() {
        loading = true
        listModel.clear()
        try {
            var arr = JSON.parse(cfg_menuItems)
            for (var i = 0; i < arr.length; i++) {
                listModel.append(arr[i])
            }
        } catch (e) {}
        loading = false
    }

    function saveToConfig() {
        loading = true
        var arr = []
        for (var i = 0; i < listModel.count; i++) {
            var item = listModel.get(i)
            arr.push({ label: item.label, icon: item.icon, desktop: item.desktop })
        }
        cfg_menuItems = JSON.stringify(arr)
        loading = false
    }

    // Desktop ids are compared with a trailing ".desktop" stripped, so
    // "org.kde.konsole.desktop" and "org.kde.konsole" are recognized as the
    // same app (main.qml's launch() already normalizes the same way when
    // invoking kstart) — otherwise both spellings could be added and would
    // defeat this duplicate check. skipIndex (optional) excludes one row
    // from the comparison — used when editing a row against itself.
    function normalizeDesktopId(desktopId) {
        // listModel rows come from JSON (cfg_menuItems), which can be
        // hand-edited — guard against a row missing/losing its "desktop"
        // field so one bad row doesn't throw inside every picker row's
        // alreadyAdded binding (this function runs once per picker item).
        if (!desktopId) return ""
        return desktopId.endsWith(".desktop") ? desktopId.slice(0, -".desktop".length) : desktopId
    }

    function isAlreadyAdded(desktopId, skipIndex) {
        var target = normalizeDesktopId(desktopId)
        for (var i = 0; i < listModel.count; i++) {
            if (skipIndex !== undefined && i === skipIndex) continue
            if (normalizeDesktopId(listModel.get(i).desktop) === target) return true
        }
        return false
    }

    // ── Installed-apps model ────────────────────────────────
    // org.kde.plasma.private.kicker's AppsModel and RootModel were both
    // confirmed live (twice) to return zero results when instantiated here
    // — that private API apparently only populates when driven from inside
    // a running Plasmoid's own context, which a KCM config page doesn't
    // have. Instead, list-apps.sh (bundled alongside this file) reads
    // .desktop entries directly from the standard XDG application
    // directories — the same mechanism every launcher ultimately relies on
    // — with no dependency on any KDE-private API, so it works the same in
    // a KCM as anywhere else, and on any Linux distro.
    ListModel { id: systemAppsModel }

    Plasma5Support.DataSource {
        id: appLister
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            configRoot.appsLoading = false
            systemAppsModel.clear()
            var out = (data["stdout"] || "").split("\n")
            for (var i = 0; i < out.length; i++) {
                var line = out[i]
                if (line === "") continue
                var parts = line.split("\t")
                if (parts.length < 2) continue
                systemAppsModel.append({
                    desktopId: parts[0] + ".desktop",
                    name: parts[1],
                    icon: parts[2] || "application-x-executable"
                })
            }
        }
        function refresh() {
            configRoot.appsLoading = true
            var scriptPath = Qt.resolvedUrl("list-apps.sh").toString().replace(/^file:\/\//, "")
            connectSource("sh '" + scriptPath.replace(/'/g, "'\\''") + "'")
        }
        Component.onCompleted: refresh()
    }

    // ── Picker state ────────────────────────────────────────
    property bool picking: false
    property string pickerQuery: ""
    property bool appsLoading: false
    readonly property int pickerMatchCount: {
        var q = pickerQuery.toLowerCase()
        if (q === "") return systemAppsModel.count
        var c = 0
        for (var i = 0; i < systemAppsModel.count; i++) {
            var name = systemAppsModel.get(i).name
            if (name && name.toLowerCase().indexOf(q) !== -1) c++
        }
        return c
    }

    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: { if (iconName) configRoot.editIcon = iconName }
    }

    function beginPick() {
        picking = true
        pickerQuery = ""
        appLister.refresh()
    }

    function pickApp(label, icon, desktop) {
        listModel.append({ label: label, icon: icon, desktop: desktop })
        saveToConfig()
        picking = false
    }

    // ── Inline edit state (manual add/edit, still available) ──
    property bool editing: false
    property int editIndex: -1
    property string editLabel: ""
    property string editIcon: "application-x-executable"
    property string editDesktop: ""

    function beginAdd() {
        editing = true
        editIndex = -1
        editLabel = ""
        editIcon = "application-x-executable"
        editDesktop = ""
    }

    function beginEdit(idx) {
        var item = listModel.get(idx)
        editing = true
        editIndex = idx
        editLabel = item.label
        editIcon = item.icon
        editDesktop = item.desktop
    }

    function commitEdit() {
        if (editLabel === "" || editDesktop === "") return
        // Manual entries skip the picker's built-in duplicate check, so
        // enforce it here too (normalized, so it also catches a manually
        // typed id that only differs from an existing entry by the
        // ".desktop" suffix) — but only when adding new (editIndex < 0) or
        // when editing an item into colliding with a *different* row.
        if (isAlreadyAdded(editDesktop, editIndex)) return
        if (editIndex >= 0) {
            listModel.set(editIndex, { label: editLabel, icon: editIcon, desktop: editDesktop })
        } else {
            listModel.append({ label: editLabel, icon: editIcon, desktop: editDesktop })
        }
        editing = false
        saveToConfig()
    }

    function cancelEdit() {
        editing = false
    }

    // ── Header ──────────────────────────────────────────────
    header: Kirigami.InlineMessage {
        Layout.fillWidth: true
        text: i18n("Manage the applications in your radial menu. Pick from installed apps, or add one manually.")
        type: Kirigami.MessageType.Information
        visible: true
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        // ── Item list ───────────────────────────────────────
        Repeater {
            model: listModel

            delegate: Rectangle {
                id: rowCard
                Layout.fillWidth: true
                height: delegateRow.implicitHeight + Kirigami.Units.largeSpacing
                radius: 8
                readonly property bool hovered: rowHover.hovered
                color: hovered
                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.12)
                    : Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.5)
                border.width: 1
                border.color: hovered
                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.5)
                    : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                HoverHandler { id: rowHover }

                RowLayout {
                    id: delegateRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    anchors.leftMargin: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        source: model.icon
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        QQC2.Label {
                            text: model.label
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        QQC2.Label {
                            text: model.desktop
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.5
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    QQC2.ToolButton {
                        icon.name: "go-up"
                        enabled: index > 0
                        onClicked: { listModel.move(index, index - 1, 1); configRoot.saveToConfig() }
                    }
                    QQC2.ToolButton {
                        icon.name: "go-down"
                        enabled: index < listModel.count - 1
                        onClicked: { listModel.move(index, index + 1, 1); configRoot.saveToConfig() }
                    }
                    QQC2.ToolButton {
                        icon.name: "document-edit"
                        onClicked: configRoot.beginEdit(index)
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-delete"
                        onClicked: { listModel.remove(index, 1); configRoot.saveToConfig() }
                    }
                }
            }
        }

        // ── Empty state ─────────────────────────────────────
        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit * 2
            visible: listModel.count === 0 && !configRoot.picking && !configRoot.editing
            icon.name: "view-grid"
            text: i18n("No applications yet")
            explanation: i18n("Add apps to show them in the radial menu.")
            helpfulAction: Kirigami.Action {
                icon.name: "list-add"
                text: i18n("Add Application")
                onTriggered: configRoot.beginPick()
            }
        }

        // ── App picker (installed applications) ─────────────
        Rectangle {
            id: pickerPanel
            Layout.fillWidth: true
            // Fade + slide in/out instead of popping
            opacity: configRoot.picking ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
            transform: Translate { y: (1 - pickerPanel.opacity) * -Kirigami.Units.gridUnit }
            height: pickerCol.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: 8
            color: Qt.rgba(
                Kirigami.Theme.highlightColor.r,
                Kirigami.Theme.highlightColor.g,
                Kirigami.Theme.highlightColor.b,
                0.06
            )
            border.width: 1
            border.color: Kirigami.Theme.highlightColor

            ColumnLayout {
                id: pickerCol
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: i18n("Choose an Installed Application")
                    font.weight: Font.Bold
                }

                QQC2.TextField {
                    Layout.fillWidth: true
                    placeholderText: i18n("Search installed applications…")
                    text: configRoot.pickerQuery
                    onTextChanged: configRoot.pickerQuery = text
                    focus: configRoot.picking
                }

                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 16
                    clip: true

                    ListView {
                        id: appListView
                        model: systemAppsModel
                        boundsBehavior: Flickable.StopAtBounds

                        QQC2.BusyIndicator {
                            anchors.centerIn: parent
                            running: configRoot.appsLoading
                            visible: running
                        }

                        Kirigami.PlaceholderMessage {
                            anchors.centerIn: parent
                            width: parent.width - Kirigami.Units.gridUnit * 4
                            visible: !configRoot.appsLoading && configRoot.pickerMatchCount === 0
                            icon.name: "edit-none"
                            text: configRoot.pickerQuery === "" ? i18n("No applications found") : i18n("No apps match \"%1\"", configRoot.pickerQuery)
                        }

                        delegate: QQC2.ItemDelegate {
                            id: appDelegate
                            width: appListView.width
                            readonly property string _lcQuery: configRoot.pickerQuery.toLowerCase()
                            readonly property bool matchesQuery: _lcQuery === "" ||
                                (model.name && model.name.toLowerCase().indexOf(_lcQuery) !== -1)
                            readonly property bool alreadyAdded: configRoot.isAlreadyAdded(model.desktopId)
                            visible: matchesQuery
                            height: visible ? implicitHeight : 0
                            enabled: !alreadyAdded

                            contentItem: RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Icon {
                                    source: model.icon
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                                }
                                QQC2.Label {
                                    text: model.name
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    opacity: appDelegate.enabled ? 1 : 0.5
                                }
                                QQC2.Label {
                                    text: i18n("Added")
                                    opacity: 0.5
                                    visible: appDelegate.alreadyAdded
                                }
                            }

                            onClicked: configRoot.pickApp(model.name, model.icon, model.desktopId)
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Button {
                        text: i18n("Add Manually…")
                        onClicked: { configRoot.picking = false; beginAdd() }
                    }
                    QQC2.Button {
                        text: i18n("Cancel")
                        highlighted: true
                        onClicked: configRoot.picking = false
                    }
                }
            }
        }

        // ── Inline manual edit / add form ────────────────────
        Rectangle {
            id: editPanel
            Layout.fillWidth: true
            opacity: configRoot.editing ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
            transform: Translate { y: (1 - editPanel.opacity) * -Kirigami.Units.gridUnit }
            height: editFormCol.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: 8
            color: Qt.rgba(
                Kirigami.Theme.highlightColor.r,
                Kirigami.Theme.highlightColor.g,
                Kirigami.Theme.highlightColor.b,
                0.06
            )
            border.width: 1
            border.color: Kirigami.Theme.highlightColor

            ColumnLayout {
                id: editFormCol
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: configRoot.editIndex >= 0 ? i18n("Edit Application") : i18n("Add Application Manually")
                    font.weight: Font.Bold
                }

                Kirigami.FormLayout {
                    QQC2.TextField {
                        Kirigami.FormData.label: i18n("Label:")
                        text: configRoot.editLabel
                        placeholderText: i18n("e.g. Firefox")
                        onTextChanged: configRoot.editLabel = text
                    }
                    QQC2.Button {
                        Kirigami.FormData.label: i18n("Icon:")
                        icon.name: configRoot.editIcon || "application-x-executable"
                        icon.width: Kirigami.Units.iconSizes.medium
                        icon.height: Kirigami.Units.iconSizes.medium
                        text: i18n("Choose…")
                        onClicked: iconDialog.open()
                    }
                    QQC2.TextField {
                        Kirigami.FormData.label: i18n("Desktop file:")
                        text: configRoot.editDesktop
                        placeholderText: i18n("e.g. firefox.desktop")
                        onTextChanged: configRoot.editDesktop = text
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Button {
                        text: i18n("Cancel")
                        onClicked: cancelEdit()
                    }
                    QQC2.Button {
                        text: configRoot.editIndex >= 0 ? i18n("Save") : i18n("Add")
                        highlighted: true
                        enabled: configRoot.editLabel !== "" && configRoot.editDesktop !== ""
                        onClicked: commitEdit()
                    }
                }
            }
        }

        // ── Add button ──────────────────────────────────────
        QQC2.Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.largeSpacing
            icon.name: "list-add"
            text: i18n("Add Application")
            visible: !configRoot.editing && !configRoot.picking && listModel.count > 0
            onClicked: beginPick()
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("%1 items in menu", listModel.count)
            visible: listModel.count > 0
            opacity: 0.4
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
}
