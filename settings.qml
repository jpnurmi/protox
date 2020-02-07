import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12

Drawer {
    id: settingsWindow
    width: window.width
    height: window.height
    z: z_settings_menu
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    edge: Qt.RightEdge
    dragMargin: 0
    interactive: false
    readonly property int ptype_bool: 1
    readonly property int ptype_int: 2
    readonly property int ptype_string: 10
    readonly property int sf_none: 0
    readonly property int sf_text: 1 // unused, text is always present
    readonly property int sf_title: 1 << 1
    readonly property int sf_checkbox: 1 << 2
    Component.onCompleted: {
        settingsModel.append({ flags: sf_text | sf_title, name: qsTr("Tox options") })
        settingsModel.append({ flags: sf_text | sf_checkbox, name: qsTr("UDP mode"), prop: "udp_enabled", 
                    value: bridge.getSettingsValue("Toxcore", "udp_enabled", ptype_bool, Boolean(true)) })
    }

    function open() {
        settingsWindow.visible = true
        drawer.close()
        drawer.disabled = true 
        leftOverlayButton.highlighted = false
    }
    function _close() {
        drawer.disabled = false
        bridge.setSettingsValue("Toxcore", "udp_enabled", Boolean(settingsModel.getValue("udp_enabled")))
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
                color: "white"
                fontSizeMode: Text.Fit
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                leftPadding: 10
                topPadding: 5
            }
            onClicked: {
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
        function getValue(p) {
            for (var i = 0; i < settingsModel.count; i++) {
                if (settingsModel.get(i).prop === p) {
                    return settingsModel.get(i).value
                }
            }
        }
        function setValue(p, v) {
            for (var i = 0; i < settingsModel.count; i++) {
                if (settingsModel.get(i).prop === p) {
                    var item = settingsModel.get(i)
                    item.value = v
                    settingsModel.set(i, item)
                    return
                }
            }
        }
    }
    ListView {
        anchors.top: settingsOverlayHeader.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        bottomMargin: 20
        topMargin: 20
        boundsMovement: Flickable.StopAtBounds
        clip: true
        ScrollIndicator.vertical: ScrollIndicator {}
        model: settingsModel
        delegate: ColumnLayout {
            width: parent.width
            RowLayout {
                width: parent.width
                Text {
                    Layout.leftMargin: 10
                    Layout.alignment: Qt.AlignLeft
                    Layout.fillWidth: true
                    text: name
                    font.pointSize: (flags & settingsWindow.sf_title) ? 14 : 20
                    font.bold: (flags & settingsWindow.sf_title) ? true : false
                    color: (flags & settingsWindow.sf_title) ? "green" : "black"
                }
                Loader {
                    Component { 
                        id: settingsCheckBox
                        CheckBox {
                            Layout.alignment: Qt.AlignRight
                            checked: value
                            onCheckedChanged: {
                                value = checked
                                checked = value
                            }
                        }
                    }
                    sourceComponent: (flags & settingsWindow.sf_checkbox) ? settingsCheckBox : undefined
                }
            }
            MenuSeparator { 
                implicitWidth: parent.width
                topPadding: 4
                bottomPadding: 4
                visible: !(flags & settingsWindow.sf_title) && index != settingsModel.count - 1
            }
        }
    }
}
