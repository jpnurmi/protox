import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12
import QtMultimedia 5.12
import QtGraphicalEffects 1.0
import QtNotification 1.0
import QtStatusBar 1.0
import QtToast 1.0
import QZXing 2.3

ColumnLayout {
    anchors.fill: parent
    anchors.leftMargin: !inPortrait ? drawer.width : undefined
    spacing: 0
    Item {
        id: chatContent
        property int chat_margin: 15
        property int cloud_margin: 5
        // fixme: convert to Layout.
        anchors.fill: parent
        Rectangle {
            id: typingText
            property int margin: 5
            property real alpha: 0.9
            height: 20
            opacity: alpha
            z: z_top
            radius: height * 0.5
            anchors.left: parent.left
            anchors.leftMargin: parent.chat_margin
            anchors.right: parent.right
            anchors.rightMargin: parent.chat_margin
            anchors.bottom: parent.bottom
            anchors.bottomMargin: chatLayout.height + chatSeparator.separator_margin * 2 + chatSeparator.height + margin
            color: "white"
            property string text
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                text: parent.text
                font.italic: true
                visible: parent.visible
            }
            visible: false
            onVisibleChanged: {
                if (messages.lastItemVisible) {
                    messages.scrollToEnd()
                }
                if (visible) {
                    messages.bottomMargin += height + margin
                } else {
                    messages.bottomMargin -= height + margin
                }
            }
        }
        DropShadow {
            anchors.fill: typingText
            visible: typingText.visible
            opacity: typingText.opacity
            radius: 8.0
            samples: 16
            color: "#80000000"
            source: typingText
        }
        ListModel {
            id: messagesModel
        }
        ListView {
            id: messages
            anchors.fill: parent
            property int flickable_margin: 20
            property bool lastItemVisible: false
            anchors.topMargin: overlayHeader.height
            anchors.bottomMargin: chatLayout.height + chatSeparator.separator_margin * 2 + chatSeparator.height
            topMargin: flickable_margin
            bottomMargin: flickable_margin
            spacing: 20
            clip: true
            boundsMovement: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator {}
            onContentYChanged: {
                if (lastItemVisible) {
                    scrollToEndButton.visible = false
                }
            }
            function checkExceedsHeight() {
                return contentHeight > height
            }
            function scrollToStart() {
                contentY = 0
                positionViewAtBeginning()
                contentY -= chatLayout.height + chatSeparator.separator_margin * 2 + chatSeparator.height
            }
            function scrollToEnd() {
                contentY = 0
                positionViewAtEnd()
                contentY += chatLayout.height + chatSeparator.separator_margin * 2 + chatSeparator.height
            }
            /*
            function scrollToEndVK() {
                
                if (virtualKeyboard.keyboardActive && !checkExceedsHeight()) {
                    boundsMovement = Flickable.DragOverBounds
                } else {
                    console.log("closed")
                    //anchors.topMargin = overlayHeader.height
                    boundsMovement = Flickable.StopAtBounds
                    scrollToEnd()
                }
            }
            */
            model: messagesModel
            property real span : contentY + height
            delegate: Rectangle {
                id: messageCloud
                color: !msgSelf ? "lightblue" : (msgReceived ? "orange" : "lightgray")
                radius: 10
                property bool fullyVisible: y > messages.contentY && y < messages.span
                onFullyVisibleChanged: {
                    if (bridge.getMessagesCount(bridge.getCurrentFriendNumber()) !== index+1) {
                        return
                    }
                    messages.lastItemVisible = fullyVisible
                }

                Rectangle {
                    id: cloudCornerRemover
                    z: z_cloud
                    width: parent.radius
                    height: width
                    color: parent.color
                    anchors.top: parent.top
                    Component.onCompleted: {
                        if (msgSelf) {
                            anchors.right = parent.right
                        } else {
                            anchors.left = parent.left
                        }
                    }
                }
                Image {
                    id: cloudTailImage
                    width: 10
                    height: width
                    source: msgSelf ? (msgReceived ? canvasBuffer.itemAt(1).source : canvasBuffer.itemAt(0).source) : canvasBuffer.itemAt(2).source
                    mirror: !msgSelf
                    smooth: true
                    Component.onCompleted: {
                        if (msgSelf) {
                            anchors.left = parent.right
                        } else {
                            anchors.right = parent.left
                        }
                    }
                }
                
                function calculateMaximumWidth() {
                    if (cloudText.width > window.width - chatContent.cloud_margin * 2 -  chatContent.chat_margin - (!inPortrait ? drawer.width : 0))
                        implicitWidth = window.width - chatContent.cloud_margin * 2 - chatContent.chat_margin - (!inPortrait ? drawer.width : 0)
                }
                
                Component.onCompleted: {
                    calculateMaximumWidth()
                    if (msgSelf) {
                        anchors.right = parent.right
                        anchors.rightMargin = chatContent.chat_margin
                    } else {
                        anchors.left = parent.left
                        anchors.leftMargin = chatContent.chat_margin
                    }
                    if (msgFailed) {
                        Qt.createQmlObject("import QtQuick 2.12; Text {
                                                    text: \"!\"
                                                    color: \"red\"
                                                    font.pointSize: 20
                                                    font.bold: true
                                                    anchors.right: parent.left
                                                }", this, "failedText")
                    }
                }
                
                Text {
                    id: cloudText
                    text: msgText
                    anchors.fill: parent
                    anchors.margins: chatContent.cloud_margin
                    font.family: "Helvetica"
                    font.pointSize: 17.5
                    onContentHeightChanged: {
                        parent.implicitHeight = contentHeight + chatContent.cloud_margin * 2
                        parent.implicitWidth = contentWidth + chatContent.cloud_margin * 2
                    }
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                }
                Text {
                    id: timeText
                    anchors.top: messageCloud.bottom
                    text: msgTime
                    font.pointSize: 10
                    Component.onCompleted: {
                        if (!msgSelf) {
                            anchors.left = parent.left
                        } else {
                            anchors.right = parent.right
                        }
                    }
                }
                MouseArea {
                    id: cloudMouseArea
                    anchors.fill: parent
                    onClicked: {
                        bridge.copyTextToClipboard(cloudText.text)
                        toast.show({ message : "Text copied!", duration : Toast.Short });
                    }
                }
            }
        }
    }

    Rectangle {
        id: chatSeparator
        width: window.width
        height: 1
        color: "gray"
        opacity: 0.5
        anchors.left: parent.left
        anchors.bottom: chatLayout.top
        property int separator_margin: 5
        anchors.bottomMargin: separator_margin
        visible: !cleanProfile
    }

    RowLayout {
        id: chatLayout
        Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
        Layout.margins: 5

        TextField {
            Layout.fillWidth: true
            id: chatMessage
            selectByMouse: true
            font.pixelSize: 20
            leftPadding: 10
            verticalAlignment: TextInput.AlignVCenter
            placeholderText: qsTr("Type something")
            onAccepted: { send.sendMessage(); focus = false }
            visible: !cleanProfile
            Item {
                id: virtualKeyboard
                property int keyboardHeight: 0
                property bool keyboardActive: false
                onKeyboardActiveChanged: {
                    //messages.interactive = !keyboardActive
                    messages.scrollToEnd()
                    var hmove = keyboardHeight - chatLayout.height - chatSeparator.height - chatContent.cloud_margin
                    if (keyboardActive) {
                        overlayHeader.y = hmove + overlayHeader.height
                        messages.anchors.topMargin += 0//overlayHeader.height
                        if (!messages.checkExceedsHeight()) {
                            messages.anchors.topMargin += hmove
                        }
                    } else {
                        messages.anchors.topMargin = overlayHeader.height
                        overlayHeader.y = 0
                    }
                }

                Connections {
                    target: Qt.inputMethod
                    onKeyboardRectangleChanged: {
                        virtualKeyboard.keyboardHeight = Qt.inputMethod.keyboardRectangle.height / Screen.devicePixelRatio
                        virtualKeyboard.keyboardActive = virtualKeyboard.keyboardHeight > 0
                    }
                }
            }


            Timer {
                id: dropTypingTimer
                interval: 2000
                repeat: false
                onTriggered: {
                    bridge.setTypingFriend(bridge.getCurrentFriendNumber(), false)
                }
            }
            onDisplayTextChanged: {
                dropTypingTimer.stop()
                if (displayText.length > 0) {
                    dropTypingTimer.start()
                    bridge.setTypingFriend(bridge.getCurrentFriendNumber(), true)
                } else {
                    bridge.setTypingFriend(bridge.getCurrentFriendNumber(), false)
                }
            }
        }
        Button {
            id: send
            Layout.rightMargin: 5
            visible: !cleanProfile
            background: Rectangle {
                implicitWidth: chatMessage.height * 0.75
                implicitHeight: implicitWidth
                visible: false
            }
            function sendMessage() {
                if (chatMessage.text.length > 0) {
                    if (bridge.getConnStatus() < 1) {
                        toast.show({ message : qsTr("You are not connected to tox network!"), duration: Toast.Short })
                        return
                    }
                    bridge.sendMessage(chatMessage.text)
                    chatMessage.clear()
                }
            }
            Image {
                id: send_arrow
                anchors.fill: parent
                source: "send-button.png"
                antialiasing: true
            }
            onPressed: sendMessage()
        }
    }
}
