import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12

/*
    Toolbar (header)
*/

ToolBar {
    id: overlayHeader
    leftPadding: !inPortrait ? drawer.width : undefined
    z: z_overlay_header
    width: parent.width

    ToolButton {
        id: leftOverlayButton
        visible: inPortrait
        Text {
            id: leftOverlayButtonText
            text: "\uE68E"
            anchors.centerIn: parent
            font.family: themify.name
            font.pointSize: 28
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            color: parent.highlighted ? Material.highlightedButtonColor : "white"
            SequentialAnimation {
                id: leftOverlayButtonTextAnimation
                loops: Animation.Infinite
                PropertyAnimation {
                    target: leftOverlayButtonText
                    property: "color"
                    to: "lightgreen"
                    duration: 1000
                }
                PropertyAnimation {
                    target: leftOverlayButtonText
                    property: "color"
                    to: "white"
                    duration: 1000
                }
            }
        }
        onClicked: {
            leftOverlayButtonTextAnimation.stop()
            highlighted = true
            drawer.open()
        }
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        antialiasing: true
    }
    Menu {
        id: contextMenuRight
        onOpened: {
            chatMessage.focus = false
        }
        onClosed: {
            currentIndex = -1
            rightOverlayButton.highlighted = false
        }

        MenuItem {
            text: qsTr("Clear chat")
            onClicked: {
                messagesModel.clear()
            }
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Logout")
            onClicked: {
                bridge.signOutProfile()
                loginWindow.reopen()
            }
        }
        MenuItem {
            text: qsTr("Quit")
            onClicked: {
                window.visible = false
                Qt.quit()
            }
        }
    }
    ToolButton {
        id: rightOverlayButton
        text: "\uE6E2"
        font.family: themify.name
        font.pointSize: 28
        
        onPressed: {
            if (contextMenuRight.visible) {
                contextMenuRight.close()
                return
            }
            highlighted = true
            contextMenuRight.popup(window.width - contextMenuRight.implicitWidth, overlayHeader.height)
        }
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        antialiasing: true
    }
    Rectangle {
        id: friendStatusIndicator
        color: "gray"
        width: 15
        height: width
        border.color: "black"
        border.width: 1
        radius: width * 0.5
        anchors.right: friendNickname.left
        anchors.rightMargin: 10
        anchors.verticalCenter: friendNickname.verticalCenter
        visible: !cleanProfile
    }

    Label {
        id: friendNickname
        anchors.top: parent.top
        anchors.topMargin: parent.height - height - friendStatusMessage.height
        anchors.horizontalCenter: parent.horizontalCenter
        property int charsLimit: 20
        function setText(t) {
            var mult = !inPortrait ? 1.5 : 1.0
            text = limitString(t, Math.round(charsLimit * mult / fontMetrics.getFontScaling()))
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!cleanProfile) {
                    infoNickname.text = bridge.getFriendNickname(bridge.getCurrentFriendNumber())
                    infoStatus.text = bridge.getFriendStatusMessage(bridge.getCurrentFriendNumber())
                    friendInfoMenu.popup()
                }
            }
            onPressAndHold: {
                chatMessage.forceActiveFocus()
                Qt.inputMethod.reset()
                chatMessage.text += friendNickname.text
                if (chatMessage) {
                    chatMessage.cursorPosition = chatMessage.length
                }
            }
        }
    }
    Label {
        id: friendStatusMessage
        anchors.top: friendNickname.bottom
        anchors.horizontalCenter: friendNickname.horizontalCenter
        font.pointSize: fontMetrics.normalize(10)
        font.italic: true
        property int charsLimit: 52
        function setText(t) {
            var mult = !inPortrait ? 1.5 : 1.0
            text = limitString(t, Math.round(charsLimit * mult / fontMetrics.getFontScaling()))
        }
    }
}