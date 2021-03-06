import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12

import QtFolderDialog 1.0
import QtUtf8ByteLimitValidator 1.0

Popup {
    id: settingsWindow
    width: window.width
    height: window.height
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    visible: false
    property bool dontSave: false

    // enable adjustTop only for this window
    Connections {
        target: window
        onKeyboardActiveChanged: {
            if (settingsWindow.visible) {
                bridge.setKeyboardAdjustMode(!window.keyboardActive)
            }
        }
        onFocusObjectChanged: {
            if (settingsWindow.visible && window.keyboardActive) {
                bridge.setKeyboardAdjustMode(false)
            }
        }
    }

    readonly property real shadowWidth: 32
    enter: Transition {
        NumberAnimation { property: "x"; from: settingsWindow.width + settingsWindow.shadowWidth; to: 0; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "x"; from: 0; to: settingsWindow.width + settingsWindow.shadowWidth; easing.type: Easing.OutCubic }
    }

    readonly property int sf_none: 0
    // slot 1 unused
    readonly property int sf_title: 1 << 1
    readonly property int sf_switch: 1 << 2
    readonly property int sf_help: 1 << 3
    readonly property int sf_input: 1 << 4
    readonly property int sf_numbers_only: 1 << 5
    readonly property int sf_mask: 1 << 6
    readonly property int sf_placeholder: 1 << 7
    readonly property int sf_warning: 1 << 8
    readonly property int sf_password: 1 << 9
    readonly property int sf_button: 1 << 10
    readonly property int sf_acceptAction: 1 << 11

    FolderDialog {
        id: downloadsFolderDialog

        onAccepted: {
            settingsModel.setValueString("downloads_folder", bridge.uriToRealPath(folderUrl.toString()))
        }
    }

    MessageDialog {
        id: settingsAlertDialog
        visible: false
    }

    MessageDialog {
        id: settingsConfirmationDialog
        visible: false
        property string yesAction
        standardButtons: StandardButton.Yes | StandardButton.No

        onYes: {
            settingsModel.actions[yesAction]()
        }
    }

    function setProfileEncrypted (encrypted) {
        for (var i = 0; i < settingsModel.count; i++) {
            if (settingsModel.get(i).prop === "profile_encrypted") {
                settingsModel.get(i).name = encrypted ? qsTr("The password is set.") : qsTr("The password is not set.")
                return
            }
        }
    }

    function setAvailableNodes (count) {
        for (var i = 0; i < settingsModel.count; i++) {
            if (settingsModel.get(i).prop === "available_nodes") {
                settingsModel.get(i).name = qsTr("%n bootstrap node(s) available in .json file.", "", count)
                return
            }
        }
    }

    RegExpValidator { id: default_validator; regExp: /.*/gm }
    RegExpValidator { id: hex_validator; regExp: /[0-9A-F]+/ }
    Utf8ByteLimitValidator { id: address_validator; length: safe_bridge().getHostnameMaxLength() }
    IntValidator { id: last_messages_limit_validator; bottom: 32; top: 1024 }
    IntValidator { id: absent_timer_interval_validator; bottom: 0; top: 10000 }
    IntValidator { id: proxy_port_validator; bottom: 1; top: 65535 }
    IntValidator { id: max_accept_file_size_validator; bottom: 0; top: 100 }

    Menu {
        id: changeProxyTypeMenu
        readonly property int margin: 25
        width: parent.width - margin * 2
        title: "Change avatar"
        x: (window.width - width) * 0.5
        y: (window.height - height) * 0.5
        z: z_menu
        modal: true

        ButtonGroup {
            id: proxyButtonsGroup
            buttons: proxyButtons.children
            function selectButton(number) {
                for (var i = 0; i < buttons.length; i++) {
                    if (buttons[i].buttonNumber === number) {
                        proxyButtonsGroup.checkedButton = buttons[i]
                    }
                }
            }

            onClicked: {
                bridge.setSettingsValue("Toxcore", "proxy_type", 
                                        String(button.buttonNumber))
                changeProxyTypeMenu.close()
            }
        }

        ColumnLayout {
            id: proxyButtons

            RadioButton {
                Layout.fillWidth: true
                readonly property int buttonNumber: 0
                text: qsTr("None")
            }

            RadioButton {
                Layout.fillWidth: true
                readonly property int buttonNumber: 1
                text: qsTr("HTTP")
            }

            RadioButton {
                Layout.fillWidth: true
                readonly property int buttonNumber: 2
                text: qsTr("SOCKS5")
            }
        }
    }

    Component.onCompleted: {
        settingsModel.actions = {
            "randomize_nospam" : function () {
                var hex_symbols = "0123456789ABCDEF"
                var nospam = ""

                for (var j = 0; j < 8; j++) {
                    nospam += hex_symbols.charAt(Math.floor(Math.random() * hex_symbols.length))
                }

                settingsModel.setValueString("no_spam_value", nospam)
            },
            "change_password" : function () {
                var password = String(settingsModel.getValueString("password"))
                var repeated_password = String(settingsModel.getValueString("repeated_password"))

                if (password !== repeated_password) {
                    settingsAlertDialog.title = qsTr("Password change failed!")
                    settingsAlertDialog.text = qsTr("Password fields don't match.")
                    settingsAlertDialog.open()
                    return
                }

                bridge.setToxPassword(password)
                bridge.saveProfile()
                bridge.updateDataBasePassword(password)

                toast.show({ message : qsTr("Password changed successfully!"), duration : Toast.Short })

                var encrypted = password.length > 0
                settingsWindow.setProfileEncrypted(encrypted)

                if (encrypted) {
                    bridge.setSettingsValue("Profile", "auto_login_profile", String(""))
                    settingsModel.setValueNumber("auto_login_enabled", false)
                }

                settingsModel.setEnabled("auto_login_enabled", !encrypted)
                settingsModel.setValueString("password", "")
                settingsModel.setValueString("repeated_password", "")
            },
            "delete_profile" : function () {
                settingsConfirmationDialog.title = qsTr("Profile deletion")
                settingsConfirmationDialog.text = qsTr("Do you really want to PERMANENTLY delete the current profile ") + " \"" +
                                                  bridge.getCurrentProfile() + "\". " +
                                                  qsTr("The chat history will be erased as well!") + " " +
                                                  qsTr("You will be logged out automatically.")
                settingsConfirmationDialog.yesAction = "delete_profile_yes"
                settingsConfirmationDialog.open()
            },
            "delete_profile_yes" : function () {
                settingsWindow.dontSave = true
                settingsWindow.close()
                bridge.signOutProfile(true)
                loginWindow.reopen(true, false)
            },
            "change_downloads_directory" : function () {
                downloadsFolderDialog.open()
            },
            "select_proxy_type" : function() {
                proxyButtonsGroup.selectButton(parseInt(bridge.getSettingsValueDefault("Toxcore", "proxy_type", 
                                                                                ptype_string)))
                changeProxyTypeMenu.open()
            }
        }

        settingsModel.append({ flags: sf_title, name: qsTr("Tox options") })
        settingsModel.append({ flags: sf_title | sf_help | sf_warning, name: qsTr("These settings require client restart!") })
        settingsModel.append({ flags: sf_switch, name: qsTr("Enable UDP"), itemEnabled: true, prop: "udp_enabled", 
                    nvalue: bridge.getSettingsValueDefault("Toxcore", "udp_enabled", ptype_bool) })
        settingsModel.append({ flags: sf_switch, name: qsTr("Enable IPv6"), itemEnabled: true, prop: "ipv6_enabled", 
                    nvalue: bridge.getSettingsValueDefault("Toxcore", "ipv6_enabled", ptype_bool) })
        settingsModel.append({ flags: sf_switch, name: qsTr("Enable LAN discovery"), itemEnabled: true, prop: "local_discovery_enabled", 
                    nvalue: bridge.getSettingsValueDefault("Toxcore", "local_discovery_enabled", ptype_bool) })
        settingsModel.append({ flags: sf_title | sf_help, name: "", prop: "available_nodes"})
        settingsModel.append({ flags: sf_input | sf_placeholder, fieldValidator: default_validator, itemWidth: 128, 
                    name: qsTr("Custom nodes .json file"), prop: "nodes_json_file", helperText: "nodes.json",
                    svalue: bridge.getSettingsValueDefault("Toxcore", "nodes_json_file", ptype_string) })
        settingsModel.append({ flags: sf_button, name: qsTr("Proxy type"), buttonText: qsTr("Select"), 
                                 clickAction: "select_proxy_type"})
        settingsModel.append({ flags: sf_input | sf_placeholder, fieldValidator: address_validator, itemWidth: 148, 
                    name: qsTr("Proxy address"), prop: "proxy_host", helperText: "",
                    svalue: bridge.getSettingsValueDefault("Toxcore", "proxy_host", ptype_string) })
        settingsModel.append({ flags: sf_input | sf_numbers_only | sf_placeholder, 
                    fieldValidator: proxy_port_validator, itemWidth: 96, 
                    name: qsTr("Proxy port"), prop: "proxy_port", helperText: "51552",
                    svalue: bridge.getSettingsValueDefault("Toxcore", "proxy_port", ptype_string) })
        settingsModel.append({ flags: sf_title, name: qsTr("Client options") })
        settingsModel.append({ flags: sf_title | sf_help, name: qsTr("This value is measured in minutes. Set to 0 to disable.")})
        settingsModel.append({ flags: sf_input | sf_numbers_only | sf_placeholder, 
                    fieldValidator: absent_timer_interval_validator, itemWidth: 96, 
                    name: qsTr("Auto-away after"), prop: "absent_timer_interval", helperText: "10",
                    svalue: bridge.getSettingsValueDefault("Client", "absent_timer_interval", ptype_string)})
        settingsModel.append({ flags: sf_input | sf_numbers_only | sf_placeholder, 
                    fieldValidator: last_messages_limit_validator, itemWidth: 96, 
                    name: qsTr("Recent messages limit"), prop: "last_messages_limit", helperText: "128",
                    svalue: bridge.getSettingsValueDefault("Client", "last_messages_limit", ptype_string) })
        settingsModel.append({ flags: sf_input | sf_numbers_only | sf_placeholder, 
                    fieldValidator: last_messages_limit_validator, itemWidth: 96, 
                    name: qsTr("Number of messages to load when scrolling up"), prop: "load_messages_limit", helperText: "64",
                    svalue: bridge.getSettingsValueDefault("Client", "load_messages_limit", ptype_string) })
        settingsModel.append({ flags: sf_button, prop: "downloads_folder", 
                                 svalue: bridge.getSettingsValueDefault("Client", "downloads_folder", ptype_string), 
                                 name: qsTr("Downloads folder"), buttonText: qsTr("Select"), 
                                 clickAction: "change_downloads_directory"})
        settingsModel.append({ flags: sf_switch, name: qsTr("Auto-accept files"), itemEnabled: true, prop: "auto_accept_files", 
                    nvalue: bridge.getSettingsValueDefault("Client", "auto_accept_files", ptype_bool) })
        settingsModel.append({ flags: sf_title | sf_help, name: qsTr("This value is measured in megabytes. Set to 0 to disable the limit.")})
        settingsModel.append({ flags: sf_input | sf_numbers_only | sf_placeholder, 
                    fieldValidator: max_accept_file_size_validator, itemWidth: 96, 
                    name: qsTr("Max auto-accept file size"), prop: "auto_accept_file_size", helperText: "20",
                    svalue: bridge.getSettingsValueDefault("Client", "auto_accept_file_size", ptype_string) })
        settingsModel.append({ flags: sf_title, name: qsTr("Privacy") })
        settingsModel.append({ flags: sf_switch, name: qsTr("Keep chat history"), itemEnabled: true, prop: "keep_chat_history", 
                    nvalue: bridge.getSettingsValueDefault("Privacy", "keep_chat_history", ptype_bool) })
        settingsModel.append({ flags: sf_title | sf_help, name: qsTr("The NoSpam value is a part of your Tox ID that can be changed at will.")})
        settingsModel.append({ flags: sf_title | sf_help, name: qsTr("If you are getting spammed with friend requests, change this value.")})
        settingsModel.append({ flags: sf_title | sf_help, name: qsTr("Only hexadecimal characters are allowed.")})
        settingsModel.append({ flags: sf_input | sf_mask | sf_button, fieldValidator: hex_validator, name: qsTr("NoSpam"), prop: "no_spam_value", 
                    svalue: "" /* will be set later */, itemWidth: 128, mask: ">HHHHHHHH;0", buttonText: qsTr("Randomize"), 
                    clickAction: "randomize_nospam"})
        settingsModel.append({ flags: sf_title | sf_help, fieldValidator: default_validator, name: "", prop: "profile_encrypted"})
        settingsModel.append({ flags: sf_input | sf_password, name: qsTr("Password"), prop: "password", 
                    svalue: "", itemWidth: 128
                    })
        settingsModel.append({ flags: sf_input | sf_button | sf_password, fieldValidator: default_validator, name: qsTr("Repeat"), prop: "repeated_password", 
                    svalue: "", itemWidth: 128, buttonText: qsTr("Change"), clickAction: "change_password"
                    })
        settingsModel.append({ flags: sf_title, name: qsTr("Profile") })
        settingsModel.append({ flags: sf_switch, name: qsTr("Auto-login into this profile"), itemEnabled: true, prop: "auto_login_enabled", 
                    nvalue: false /* will be set later */ })
        settingsModel.append({ flags: sf_button, name: qsTr("Profile deletion"), buttonText: qsTr("Delete"), 
                                 clickAction: "delete_profile"})
        settingsModel.append({ flags: sf_title, name: qsTr("Version") })
        settingsModel.append({ flags: sf_title | sf_help, name: "Protox: " + applicationVersion + " (" + bridge.getCurrentCommitSha1() + ")", prop: "application_version"})
        settingsModel.append({ flags: sf_title | sf_help, name: "Toxcore: " + bridge.getToxcoreVersion(), prop: "toxcore_version"})
    }

    function open() {
        settingsWindow.visible = true
        drawer.close()
        drawer.dragEnabled = false
        leftOverlayButton.highlighted = false
        closeSettingsButton.highlighted = false
    }
    //property bool reloadChatHistory: false
    function _close() {
        drawer.dragEnabled = true

        if (dontSave) {
            dontSave = false
            return
        }

        bridge.setSettingsValue("Toxcore", "udp_enabled", Boolean(settingsModel.getValueNumber("udp_enabled")))
        bridge.setSettingsValue("Toxcore", "ipv6_enabled", Boolean(settingsModel.getValueNumber("ipv6_enabled")))
        bridge.setSettingsValue("Toxcore", "local_discovery_enabled", Boolean(settingsModel.getValueNumber("local_discovery_enabled")))
        bridge.setSettingsValue("Toxcore", "nodes_json_file", String(settingsModel.getValueString("nodes_json_file")))
        bridge.setSettingsValue("Toxcore", "proxy_host", String(settingsModel.getValueString("proxy_host")))
        bridge.setSettingsValue("Toxcore", "proxy_port", String(settingsModel.getValueString("proxy_port")))
        bridge.setSettingsValue("Client", "absent_timer_interval", String(settingsModel.getValueString("absent_timer_interval")))
        absentTimer.interval = parseInt(settingsModel.getValueString("absent_timer_interval")) * 60 * 1000
        bridge.setSettingsValue("Client", "last_messages_limit", settingsModel.getValueString("last_messages_limit"))
        bridge.setSettingsValue("Client", "load_messages_limit", settingsModel.getValueString("load_messages_limit"))
        bridge.setSettingsValue("Client", "downloads_folder", String(settingsModel.getValueString("downloads_folder")))
        bridge.setSettingsValue("Client", "auto_accept_files", Boolean(settingsModel.getValueNumber("auto_accept_files")))
        bridge.setSettingsValue("Client", "auto_accept_file_size", String(settingsModel.getValueString("auto_accept_file_size")))
        bridge.setSettingsValue("Privacy", "keep_chat_history", Boolean(settingsModel.getValueNumber("keep_chat_history")))
        bridge.setSettingsValue("Profile", "auto_login_profile", settingsModel.getValueNumber("auto_login_enabled") ? bridge.getCurrentProfile() : "")
        bridge.setNospamValue(settingsModel.getValueString("no_spam_value"))
        updateQRcode()
    }

    onClosed: {
        settingsWindow._close()
    }

    ToolBar {
        y: 0
        id: settingsOverlayHeader
        width: parent.width

        ToolButton {
            id: closeSettingsButton
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Text {
                text: "\uE629"
                anchors.centerIn: parent
                font.family: themify.name
                font.pointSize: 28
                font.bold: true
                color: parent.highlighted ? getTheme().highlightedButtonColor : "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                closeSettingsButton.highlighted = true
                settingsWindow.close()
            }
        }

        Label {
            id: settingsLabel
            anchors.centerIn: parent
            text: qsTr("Settings")
        }
    }

    ListModel {
        id: settingsModel
        property variant actions

        function getValueNumber(p) {
            for (var i = 0; i < count; i++) {
                if (get(i).prop === p) {
                    return get(i).nvalue
                }
            }
        }

        function setValueNumber(p, v) {
            for (var i = 0; i < count; i++) {
                if (get(i).prop === p) {
                    get(i).nvalue = v
                    return
                }
            }
        }

        function getValueString(p) {
            for (var i = 0; i < count; i++) {
                if (get(i).prop === p) {
                    return get(i).svalue
                }
            }
        }

        function setValueString(p, sv) {
            for (var i = 0; i < count; i++) {
                if (get(i).prop === p) {
                    get(i).svalue = sv
                    return
                }
            }
        }

        function setEnabled(p, en) {
            for (var i = 0; i < count; i++) {
                if (get(i).prop === p) {
                    get(i).itemEnabled = en
                    return
                }
            }
        }
    }

    ListView {
        id: settingsList
        anchors.top: settingsOverlayHeader.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        boundsMovement: Flickable.StopAtBounds
        clip: true
        ScrollIndicator.vertical: ScrollIndicator {}
        model: settingsModel
        delegate: ColumnLayout {
            property real originalHeight: 0
            width: settingsList.width
            height: ((flags & settingsWindow.sf_title) ? (flags & settingsWindow.sf_help 
                                                      ? ((flags & settingsWindow.sf_warning) 
                                                      ? 12 : 14) : 24) : 56) * fontMetrics.getFontScaling()
            spacing: 0

            RowLayout {
                width: parent.width
                Text {
                    Layout.leftMargin: 10
                    Layout.alignment: Qt.AlignLeft
                    Layout.fillWidth: true
                    Layout.topMargin: ((flags & settingsWindow.sf_title) && 
                                      !(flags & settingsWindow.sf_help) ? 10 : 0)
                    text: name
                    wrapMode: Text.Wrap
                    font.pointSize: fontMetrics.normalize((flags & settingsWindow.sf_title) ? 
                                                               ((flags & settingsWindow.sf_help) ? 12 : 14) : 20)
                    font.bold: (flags & settingsWindow.sf_title) && !(flags & settingsWindow.sf_help)
                    font.italic: flags & settingsWindow.sf_help
                    color: (flags & settingsWindow.sf_title) ? 
                           ((flags & settingsWindow.sf_help) ? ((flags & settingsWindow.sf_warning) 
                                                             ? getUserTheme().settingsWarningColor : getTheme().primaryTextColor) : getUserTheme().settingsTitleColor) : getTheme().primaryTextColor

                    onContentWidthChanged: {
                        if (parent.parent.originalHeight >= contentHeight) {
                            parent.parent.height = parent.parent.originalHeight
                        }
                        // for multi-line text
                        if (parent.parent.height < contentHeight) {
                            parent.parent.originalHeight = parent.parent.height
                            parent.parent.height = contentHeight
                        }
                    }
                }

                Loader {
                    Component { 
                        id: settingsSwitchComponent

                        Switch {
                            id: settingsSwitch
                            Layout.alignment: Qt.AlignRight
                            checked: nvalue
                            enabled: itemEnabled

                            Binding {
                                target: settingsSwitch
                                property: "checked"
                                value: nvalue
                            }
                            onCheckedChanged: {
                                nvalue = checked
                            }
                        }
                    }

                    sourceComponent: (flags & settingsWindow.sf_switch) ? settingsSwitchComponent : undefined
                }

                Loader {
                    Component {
                        id: settingsTextInputComponent

                        TextField {
                            id: settingsTextInput
                            width: itemWidth
                            Layout.alignment: Qt.AlignRight
                            horizontalAlignment: TextInput.AlignHCenter
                            rightInset: 15
                            rightPadding: rightInset
                            text: svalue
                            placeholderText: (flags & settingsWindow.sf_placeholder) ? helperText : ""
                            inputMethodHints: (flags & settingsWindow.sf_numbers_only) ? Qt.ImhDigitsOnly 
                                            : ((flags & settingsWindow.sf_mask) ? Qt.ImhSensitiveData | Qt.ImhUppercaseOnly : Qt.ImhSensitiveData)
                            inputMask: (flags & settingsWindow.sf_mask) ? mask : ""
                            echoMode: (flags & settingsWindow.sf_password) ? TextInput.Password : TextInput.Normal
                            passwordCharacter: "*"
                            validator: fieldValidator === undefined ? default_validator : fieldValidator
                            color: acceptableInput ? "black" : "red"

                            Binding {
                                target: settingsTextInput
                                property: "text"
                                value: svalue
                            }

                            onAccepted: {
                                if ((flags & settingsWindow.sf_mask) && !acceptableInput) {
                                    return
                                }

                                svalue = text
                                focus = false

                                if (flags & settingsWindow.sf_acceptAction) {
                                    settingsModel.actions[acceptAction]()
                                }
                            }

                            onPressed: {
                                if (!window.keyboardActive) {
                                    focus = false
                                }

                                forceActiveFocus()
                                cursorPosition = positionAt(event.x, event.y)

                                if (selectedText.length > 0) {
                                    deselect()
                                    cursorPosition = positionAt(event.x, event.y)
                                }

                                event.accepted = false
                            }
                        }
                    }

                    sourceComponent: (flags & settingsWindow.sf_input) ? settingsTextInputComponent : undefined
                }
                Loader {
                    Component {
                        id: settingsButtonComponent

                        Button {
                            rightInset: 15
                            rightPadding: rightInset * 1.5
                            text: buttonText
                            onClicked: settingsModel.actions[clickAction]()
                        }
                    }

                    sourceComponent: (flags & settingsWindow.sf_button) ? settingsButtonComponent : undefined
                }
            }

            MenuSeparator { 
                implicitWidth: parent.width
                topPadding: 0
                bottomPadding: 0
                visible: !(flags & settingsWindow.sf_title) && index != settingsModel.count - 1
            }
        }
    }
}
