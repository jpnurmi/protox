import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12
import QtGraphicalEffects 1.0

/*[remove]*/ Item {

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
            anchors.bottomMargin: (chatMessage.focus ? keyboardHeight : 0) + chatLayout.height + chatSeparator.separator_margin * 2 + chatSeparator.height + margin
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
                if (messages.atYEnd) {
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
            property int flickable_margin: 25
            property bool lastItemVisible: false
            anchors.topMargin: overlayHeader.height
            anchors.bottomMargin: (chatMessage.focus ? keyboardHeight : 0) + chatLayout.height + chatSeparator.separator_margin * 2 + chatSeparator.height
            topMargin: flickable_margin
            bottomMargin: flickable_margin
            spacing: 20
            clip: true
            boundsMovement: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator {}
            onContentYChanged: {
                if (atYEnd) {
                    scrollToEndButton.visible = false
                }
            }
            function checkExceedsHeight() {
                return contentHeight > height
            }
            function scrollToStart() {
                positionViewAtBeginning()
                contentY -= flickable_margin
            }
            function scrollToEnd() {
                positionViewAtEnd()
                contentY += flickable_margin + (typingText.visible ? typingText.height + typingText.margin : 0) +
                        chatLayout.height + chatSeparator.separator_margin * 2 + chatSeparator.height
            }
            property bool addTransitionEnabled: true
            add: Transition {
                enabled: messages.addTransitionEnabled
                NumberAnimation { property: "scale"; from: 0; to: 1.0; duration: 300 }
            }
            model: messagesModel
            delegate: Rectangle {
                id: messageCloud
                color: !msgSelf ? "lightblue" : (msgReceived ? "orange" : "lightgray")
                radius: 10
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
                    property string plainText: msgText
                    text: plainText
                    anchors.fill: parent
                    anchors.margins: chatContent.cloud_margin
                    font.family: "Helvetica"
                    font.pointSize: standardFontPointSize
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var link = parent.linkAt(mouseX, mouseY)
                            if (link.length > 0) {
                                Qt.openUrlExternally(link)
                                return
                            }
                            bridge.copyTextToClipboard(cloudText.plainText)
                            toast.show({ message : "Text copied!", duration : Toast.Short });
                        }
                        onPressAndHold: {
                            chatMessage.forceActiveFocus()
                            var add = cloudText.plainText.replace("\n", "\n> ")
                            Qt.inputMethod.reset()
                            if (chatMessage.text.length > 0) {
                                chatMessage.text += "\n> " + add + "\n"
                            } else {
                                chatMessage.text += "> " + add + "\n"
                            }
                            chatMessage.cursorPosition = chatMessage.length
                        }
                    }
                    Component.onCompleted: {
                        textFormat = Text.StyledText
                        wrapMode = Text.Wrap
                        text = processText(plainText)
                        parent.implicitWidth = contentWidth + chatContent.cloud_margin * 2
                    }
                    onContentHeightChanged: {
                        parent.implicitHeight = contentHeight + chatContent.cloud_margin * 2
                        parent.implicitWidth = contentWidth + chatContent.cloud_margin * 2
                    }
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    function processText(t) {
                        String.prototype.replaceAll = function(search, replace) {
                            return this.split(search).join(replace);
                        }
                        var str = String(t)
                        // deHTML input
                        str = str.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll("\"", "&quot;")
                        var result = "";
                        var lines = str.split("\n")
                        // parse each line separately
                        for (var i = 0; i < lines.length; i++) {
                            var line = lines[i]
                            // skip formatting in quote lines
                            if (line.charAt(0) === '>') {
                                line = line.replaceAll(">", "&gt;")
                                result += line
                                // put back all next line operators
                                if (i < lines.length - 1) { result += "\n" }
                                continue
                            }
                            line = line.replaceAll(">", "&gt;")
                            line = line.replace(/(\*{2,2})(.*?)\1/g, function(bold) {
                                return '<b>' + bold.replace(/^.{2}/, '').replace(/.{2}$/, '') + '</b>'
                            })
                            /*
                            line = line.replace(/\B\/(.+)\/\B/g, function(italic) {
                                return '<i>' + italic.replace(/^.{2}/, '').replace(/.{2}$/, '') + '</i>'
                            })
                            */
                            line = line.replace(/(\~{2,2})(.*?)\1/g, function(strike) {
                                return '<s>' + strike.replace(/^.{2}/, '').replace(/.{2}$/, '') + '</s>'
                            })
                            line = line.replace(/(\_{2,2})(.*?)\1/g, function(underline) {
                                return '<u>' + underline.replace(/^.{2}/, '').replace(/.{2}$/, '') + '</u>'
                            })
                            result += line
                            // put back all next line operators
                            if (i < lines.length - 1) { result += "\n" }
                        }
                        result = result.replace(/((http|https|ftp|sftp)?:\/\/[^\s]+)/g, function(url) {
                            return '<font color="blue"><a href="' + url + '">' + url + '</a></font>'
                        })
                        result = result.replace(/(&gt;(.)*)/g, function(quote) {
                            return '<font color="#0b6623">' + quote + '</font>'
                        })
                        result = result.replace(/(\n)/gm, '<br>')

                        //console.log(result)
                        return result
                    }
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
        anchors.right: parent.right
        anchors.bottom: chatLayout.top
        property int separator_margin: 5
        anchors.bottomMargin: separator_margin
        visible: !cleanProfile
    }

    RowLayout {
        id: chatLayout
        Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
        property int margin: 5
        Layout.leftMargin: margin
        Layout.rightMargin: margin
        Layout.topMargin: margin
        Layout.bottomMargin: (chatMessage.focus ? keyboardHeight : 0) + margin

        TextArea {
            id: chatMessage
            Layout.fillWidth: true
            selectByMouse: true
            font.pointSize: standardFontPointSize
            leftPadding: 10
            verticalAlignment: TextInput.AlignVCenter
            placeholderText: qsTr("Type something")
            visible: !cleanProfile
            property real defaultHeight
            property real defaultContentHeight
            wrapMode: Text.Wrap
            Component.onCompleted: {
                defaultHeight = height
                defaultContentHeight = contentHeight
            }
            onContentWidthChanged: {
                updateTyping()
            }
            onContentHeightChanged: {
                messages.scrollToEnd()
                updateTyping()
            }
            Keys.onBackPressed: {
                focus = false
            }

            Timer {
                id: dropTypingTimer
                interval: 2000
                repeat: false
                onTriggered: {
                    bridge.setTypingFriend(bridge.getCurrentFriendNumber(), false)
                }
            }

            function updateTyping() {
                if (bridge.getConnStatus() < 1) {
                    return
                }
                dropTypingTimer.stop()
                if (contentWidth > 0 || contentHeight > defaultContentHeight) {
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
            Layout.alignment: Qt.AlignVCenter
            visible: !cleanProfile
            background: Rectangle {
                implicitWidth: chatMessage.defaultHeight * 0.75
                implicitHeight: implicitWidth
                visible: false
            }
            focusPolicy: Qt.NoFocus
            function sendMessage() {
                Qt.inputMethod.reset()
                if (chatMessage.text.length > 0) {
                    if (bridge.getFriendConnStatus(bridge.getCurrentFriendNumber()) < 1) {
                        toast.show({ message : qsTr("The friend is not online."), duration: Toast.Short })
                        return
                    }
                    if (bridge.getConnStatus() < 1) {
                        toast.show({ message : qsTr("You are not connected to tox network!"), duration: Toast.Short })
                        return
                    }
                    bridge.sendMessage(chatMessage.text)
                    chatMessage.clear()
                } else {
                    chatMessage.focus = false
                }
            }
            Image {
                id: send_arrow
                anchors.fill: parent
                source: "send-button.png"
                antialiasing: true
            }
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: { send.sendMessage() }
                grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.ApprovesTakeOverByHandlersOfDifferentType
            }
        }
    }
}

Rectangle {
    id: scrollToEndButton
    z: z_top
    width: 200
    height: 40
    radius: height * 0.5
    color: "white"
    property real alpha: 0.9
    property int bottomMargin: 30
    opacity: alpha
    x: (parent.width - width) * (inPortrait ? 0.5 : 0.7)
    y: chatSeparator.y - height - bottomMargin
    visible: false
    Text {
        id: nextPageButtonText
        text: "\u2193 " + qsTr("You have ") + new_messages + qsTr(" new messages") + " \u2193"
        font.bold: true
        font.pointSize: 12.5
        opacity: parent.opacity
        anchors.centerIn: parent
    }
    onVisibleChanged: {
        if (!visible) {
            new_messages = 0
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: parent.visible
        onPressed: {
            messages.scrollToEnd()
        }
    }
}
DropShadow {
    anchors.fill: scrollToEndButton
    visible: scrollToEndButton.visible
    opacity: scrollToEndButton.opacity
    radius: 8.0
    samples: 16
    color: "#80000000"
    source: scrollToEndButton
}

/*[remove]*/ }
