import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12

Popup {
    id: settingsWindow
    width: window.width
    height: window.height
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    visible: false
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

    enter: Transition {
        NumberAnimation { property: "x"; from: settingsWindow.width; to: 0; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "x"; from: 0; to: settingsWindow.width; easing.type: Easing.OutCubic }
    }
    readonly property int ptype_bool: 1
    readonly property int ptype_string: 10
    readonly property int sf_none: 0
    readonly property int sf_text: 1 // unused, text is always present
    readonly property int sf_title: 1 << 1
    readonly property int sf_switch: 1 << 2
    readonly property int sf_help: 1 << 3
    readonly property int sf_input: 1 << 4
    readonly property int sf_numbers_only: 1 << 5
    readonly property int sf_mask: 1 << 6
    readonly property int sf_placeholder: 1 << 7
    readonly property int sf_warning: 1 << 8
    readonly property int sf_reload_chat: 1 << 9
    readonly property int sf_button: 1 << 10
    Component.onCompleted: {
        settingsModel.actions = {
            "randomize_nospam" : function () {
                for (var i = 0; i < settingsModel.count; i++) {
                    if (settingsModel.get(i).prop === "no_spam_value") {
                        var hex_symbols = "0123456789ABCDEF"
                        var nospam = ""
                        for (var j = 0; j < 8; j++) {
                            nospam += hex_symbols.charAt(Math.floor(Math.random() * hex_symbols.length))
                        }
                        settingsModel.get(i).svalue = nospam
                        return
                    }
                }
            }
        }
        settingsModel.append({ flags: sf_text | sf_title, name: qsTr("Tox options") })
        settingsModel.append({ flags: sf_text | sf_title | sf_help | sf_warning, name: qsTr("These settings require client restart!") })
        settingsModel.append({ flags: sf_text | sf_switch, name: qsTr("Enable UDP"), prop: "udp_enabled", 
                    value: bridge.getSettingsValue("Toxcore", "udp_enabled", ptype_bool, Boolean(true)) })
        settingsModel.append({ flags: sf_text | sf_switch, name: qsTr("Enable IPv6"), prop: "ipv6_enabled", 
                    value: bridge.getSettingsValue("Toxcore", "ipv6_enabled", ptype_bool, Boolean(true)) })
        settingsModel.append({ flags: sf_text | sf_switch, name: qsTr("Enable LAN discovery"), prop: "local_discovery_enabled", 
                    value: bridge.getSettingsValue("Toxcore", "local_discovery_enabled", ptype_bool, Boolean(false)) })
        settingsModel.append({ flags: sf_text | sf_input | sf_placeholder, itemWidth: 128, 
                    name: qsTr("Custom nodes .json file"), prop: "nodes_json_file", helperText: "nodes.json",
                    svalue: bridge.getSettingsValue("Client", "nodes_json_file", ptype_string, String("")) })
        settingsModel.append({ flags: sf_text | sf_input | sf_numbers_only | sf_placeholder, numberMinLimit: 1, numberMaxLimit: 10000, itemWidth: 96, 
                    name: qsTr("Maximum bootstrap nodes"), prop: "max_bootstrap_nodes", helperText: "6",
                    svalue: bridge.getSettingsValue("Toxcore", "max_bootstrap_nodes", ptype_string, 6) })
        settingsModel.append({ flags: sf_text | sf_title, name: qsTr("Client options") })
        settingsModel.append({ flags: sf_text | sf_input | sf_numbers_only | sf_placeholder | sf_reload_chat, 
                    numberMinLimit: 5, numberMaxLimit: 10000, itemWidth: 96, 
                    name: qsTr("Recent messages limit"), prop: "last_messages_limit", helperText: "128",
                    svalue: bridge.getSettingsValue("Client", "last_messages_limit", ptype_string, 128) })
        settingsModel.append({ flags: sf_text | sf_title, name: qsTr("Privacy") })
        settingsModel.append({ flags: sf_text | sf_switch, name: qsTr("Keep chat history"), prop: "keep_chat_history", 
                    value: bridge.getSettingsValue("Privacy", "keep_chat_history", ptype_bool, Boolean(true)) })
        settingsModel.append({ flags: sf_text | sf_title | sf_help, 
                                 name: qsTr("NoSpam value is a part of your ToxID that can be changed at will.") + "\n" +
                                       qsTr("If you are getting spammed with friend requests, change this value.") + "\n" +
                                       qsTr("Only hexadecimal characters are allowed.")})
        settingsModel.append({ flags: sf_text | sf_input | sf_mask | sf_button, name: qsTr("NoSpam"), prop: "no_spam_value", 
                    svalue: bridge.getNospamValue(), itemWidth: 128, mask: ">HHHHHHHH;0", buttonText: qsTr("Randomize"), 
                    clickAction: "randomize_nospam"})
    }

    function open() {
        settingsWindow.visible = true
        drawer.close()
        drawer.dragEnabled = false
        leftOverlayButton.highlighted = false
        closeSettingsButton.highlighted = false
    }
    property bool reloadChatHistory: false
    function _close() {
        drawer.dragEnabled = true
        bridge.setSettingsValue("Toxcore", "udp_enabled", Boolean(settingsModel.getValue("udp_enabled")))
        bridge.setSettingsValue("Toxcore", "ipv6_enabled", Boolean(settingsModel.getValue("ipv6_enabled")))
        bridge.setSettingsValue("Toxcore", "local_discovery_enabled", Boolean(settingsModel.getValue("local_discovery_enabled")))
        bridge.setSettingsValue("Toxcore", "nodes_json_file", String(settingsModel.getValueString("nodes_json_file")))
        bridge.setSettingsValue("Toxcore", "max_bootstrap_nodes", String(settingsModel.getValueString("max_bootstrap_nodes")))
        bridge.setSettingsValue("Client", "last_messages_limit", settingsModel.getValueString("last_messages_limit"))
        bridge.setSettingsValue("Privacy", "keep_chat_history", Boolean(settingsModel.getValue("keep_chat_history")))
        bridge.setNospamValue(settingsModel.getValueString("no_spam_value"))
        if (reloadChatHistory) {
            messages.addTransitionEnabled = false
            bridge.retrieveChatLog()
            chatScrollToEnd()
            messages.addTransitionEnabled = true
            reloadChatHistory = false
        }
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
            Text {
                text: "\u2190"
                font.family: dejavuSans.name
                font.pointSize: 32
                font.bold: true
                color: parent.highlighted ? Material.highlightedButtonColor : "white"
                fontSizeMode: Text.Fit
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                leftPadding: 10
                topPadding: 5
            }
            onClicked: {
                closeSettingsButton.highlighted = true
                settingsWindow.close()
            }
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
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
        function getValue(p) {
            for (var i = 0; i < count; i++) {
                if (get(i).prop === p) {
                    return get(i).value
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
    }
    ListView {
        anchors.top: settingsOverlayHeader.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        boundsMovement: Flickable.StopAtBounds
        clip: true
        ScrollIndicator.vertical: ScrollIndicator {}
        model: settingsModel
        delegate: ColumnLayout {
            width: parent.width
            height: (flags & settingsWindow.sf_title) ? (flags & settingsWindow.sf_help 
                                                      ? ((flags & settingsWindow.sf_warning) 
                                                      ? 12 : 32) : 24) : 56
            spacing: 0
            RowLayout {
                width: parent.width
                Text {
                    Layout.leftMargin: 10
                    Layout.alignment: Qt.AlignLeft
                    Layout.fillWidth: true
                    Layout.topMargin: (flags & settingsWindow.sf_title) && !(flags & settingsWindow.sf_help) ? 10 : 0
                    text: name
                    font.pointSize: (flags & settingsWindow.sf_title) ? ((flags & settingsWindow.sf_help) ? 12 : 14) : 20
                    font.bold: (flags & settingsWindow.sf_title) && !(flags & settingsWindow.sf_help)
                    font.italic: flags & settingsWindow.sf_help
                    color: (flags & settingsWindow.sf_title) ? 
                           ((flags & settingsWindow.sf_help) ? ((flags & settingsWindow.sf_warning) 
                                                             ? "red" : "black") : "green") : "black"
                }
                Loader {
                    Component { 
                        id: settingsCheckBox
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: value
                            onCheckedChanged: {
                                value = checked
                                checked = value
                            }
                        }
                    }
                    sourceComponent: (flags & settingsWindow.sf_switch) ? settingsCheckBox : undefined
                }
                Loader {
                    Component {
                        id: settingsTextInput
                        TextField {
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
                            onAccepted: {
                                if ((flags & settingsWindow.sf_mask) && !acceptableInput) {
                                    return
                                }
                                var result = ""
                                if (flags & settingsWindow.sf_numbers_only) {
                                    if (text.length == 0 || isNaN(text)) {
                                        result = helperText
                                    } else if (parseInt(text) > numberMaxLimit) {
                                        result = numberMaxLimit
                                    } else if (parseInt(text) < numberMinLimit) {
                                        result = numberMinLimit
                                    }
                                }
                                if (flags & settingsWindow.sf_uppercase) {
                                    result = text.toUpperCase()
                                } else {
                                    result = text
                                }
                                svalue = result
                                focus = false
                                if (flags & settingsWindow.sf_reload_chat) {
                                    settingsWindow.reloadChatHistory = true
                                }
                            }
                            onPressed: {
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
                    sourceComponent: (flags & settingsWindow.sf_input) ? settingsTextInput : undefined
                }
                Loader {
                    Component {
                        id: settingsButton
                        Button {
                            rightInset: 15
                            rightPadding: rightInset * 1.5
                            text: buttonText
                            onClicked: settingsModel.actions[clickAction]()
                        }
                    }
                    sourceComponent: (flags & settingsWindow.sf_button) ? settingsButton : undefined
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
