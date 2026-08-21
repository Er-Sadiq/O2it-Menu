import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.private.kicker as Kicker

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

    function isAlreadyAdded(desktopId) {
        for (var i = 0; i < listModel.count; i++) {
            if (listModel.get(i).desktop === desktopId) return true
        }
        return false
    }

    // ── Installed-apps model ────────────────────────────────
    // NOTE: Kickoff itself never lists apps off RootModel's top level —
    // that level mixes in Favorites/Power-session rows. It drills into a
    // child via rootModel.modelForRow(row), which is a plain Kicker.AppsModel.
    // That base class has no favorites/session concept at all, so we use it
    // directly: pure enumeration of installed .desktop applications.
    Kicker.AppsModel {
        id: systemAppsModel
        flat: true
        sorted: true
        showSeparators: false
        appNameFormat: 0
        autoPopulate: true
    }

    // ── Picker state ────────────────────────────────────────
    property bool picking: false
    property string pickerQuery: ""

    function beginPick() {
        picking = true
        pickerQuery = ""
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
                        onClicked: { listModel.move(index, index - 1, 1); saveToConfig() }
                    }
                    QQC2.ToolButton {
                        icon.name: "go-down"
                        enabled: index < listModel.count - 1
                        onClicked: { listModel.move(index, index + 1, 1); saveToConfig() }
                    }
                    QQC2.ToolButton {
                        icon.name: "document-edit"
                        onClicked: beginEdit(index)
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-delete"
                        onClicked: { listModel.remove(index, 1); saveToConfig() }
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
                            readonly property bool matchesQuery: configRoot.pickerQuery === "" ||
                                (model.display && model.display.toLowerCase().indexOf(configRoot.pickerQuery.toLowerCase()) !== -1)
                            readonly property bool alreadyAdded: configRoot.isAlreadyAdded(model.favoriteId)
                            visible: !model.isSeparator && !!model.favoriteId && matchesQuery
                            height: visible ? implicitHeight : 0
                            enabled: !alreadyAdded

                            contentItem: RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Icon {
                                    source: model.decoration
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                                }
                                QQC2.Label {
                                    text: model.display
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

                            onClicked: configRoot.pickApp(model.display, model.decoration, model.favoriteId)
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
