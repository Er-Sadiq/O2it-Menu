import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support

KCM.SimpleKCM {
    id: configRoot

    property string cfg_menuItems

    // Internal list model built from JSON
    ListModel { id: listModel }

    property bool loading: false
    property int forceUpdate: 0

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
        forceUpdate++
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
            var scriptPath = Qt.resolvedUrl("list-apps.sh").toString().replace(/^file:\/\//, "")
            connectSource("sh '" + scriptPath.replace(/'/g, "'\\''") + "'")
        }
        Component.onCompleted: refresh()
    }

    // ── Picker state ────────────────────────────────────────
    property bool picking: false
    property string pickerQuery: ""

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
                Layout.fillWidth: true
                height: delegateRow.implicitHeight + Kirigami.Units.largeSpacing
                radius: 8
                color: Qt.rgba(
                    Kirigami.Theme.backgroundColor.r,
                    Kirigami.Theme.backgroundColor.g,
                    Kirigami.Theme.backgroundColor.b,
                    0.5
                )
                border.width: 1
                border.color: Qt.rgba(
                    Kirigami.Theme.textColor.r,
                    Kirigami.Theme.textColor.g,
                    Kirigami.Theme.textColor.b,
                    0.08
                )

                RowLayout {
                    id: delegateRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.largeSpacing

                    QQC2.Label {
                        text: (index + 1) + "."
                        opacity: 0.4
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                        horizontalAlignment: Text.AlignRight
                    }

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

        // ── App picker (installed applications) ─────────────
        Rectangle {
            Layout.fillWidth: true
            visible: configRoot.picking
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
            Layout.fillWidth: true
            visible: configRoot.editing
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
                    RowLayout {
                        Kirigami.FormData.label: i18n("Icon:")
                        spacing: Kirigami.Units.smallSpacing
                        QQC2.TextField {
                            text: configRoot.editIcon
                            placeholderText: i18n("e.g. internet-web-browser")
                            onTextChanged: configRoot.editIcon = text
                            Layout.fillWidth: true
                        }
                        Kirigami.Icon {
                            source: configRoot.editIcon
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }
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
            visible: !configRoot.editing && !configRoot.picking
            onClicked: beginPick()
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("%1 items in menu", listModel.count)
            opacity: 0.4
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
}
