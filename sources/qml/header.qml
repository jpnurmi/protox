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
    z: z_overlay_header
    width: parent.width

    ToolButton {
        id: leftOverlayButton
        Text {
            id: leftOverlayButtonText
            text: "\uE68E"
            anchors.centerIn: parent
            font.family: themify.name
            font.pointSize: 28
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: parent.highlighted ? getTheme().highlightedButtonColor : getTheme().toolTextColor
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
                    to: getTheme().toolTextColor
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
        modal: true
        dim: false
        onOpened: {
            chatMessage.focus = false
        }
        onClosed: {
            currentIndex = -1
            rightOverlayButton.highlighted = false
        }

        Connections {
            target: window
            onInPortraitChanged: {
                contextMenuRight.visible = false
            }
        }

        /*
        MenuItem {
            text: qsTr("Debug: colors")
            onClicked: {
                colorDebugDialog.open()
            }
        }

        MenuSeparator {}
        */

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
        
        onClicked: {
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
        property string realText
        function updateText() {
            var wh = Screen.width / Screen.height
            text = limitString(realText, Math.round(charsLimit * (inPortrait ? 1 : wh) / fontMetrics.getFontScaling()))
        }
        function setText(t) {
            realText = t
            updateText()
        }
        Connections {
            target: window
            onInPortraitChanged: friendNickname.updateText()
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!cleanProfile) {
                    chatMessage.focus = false
                    friendInfoMenu.prepareAndOpen(bridge.getCurrentFriendNumber())
                }
            }
            onPressAndHold: {
                chatMessage.forceActiveFocus()
                Qt.inputMethod.reset()
                chatMessage.text += bridge.getFriendNickname(bridge.getCurrentFriendNumber())
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
        property string realText
        function updateText() {
            var wh = Screen.width / Screen.height
            text = limitString(realText, Math.round(charsLimit * (inPortrait ? 1 : wh) / fontMetrics.getFontScaling()))
        }
        function setText(t) {
            realText = t
            updateText()
        }
        Connections {
            target: window
            onInPortraitChanged: friendStatusMessage.updateText()
        }
    }
}
