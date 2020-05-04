import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12
import QtGraphicalEffects 1.0

import QtPhotoDialog 1.0

/*[remove]*/ Item {

ColumnLayout {
    anchors.fill: parent
    anchors.leftMargin: undefined
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
            Rectangle {
                id: messageRemovalLine
                x: -width
                property bool colision: false
                color: "#00000000"
                width: 5
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                NumberAnimation { id: messageRemovalLineIn; target: messageRemovalLine; property: "x"; 
                    from: -messageRemovalLine.width; to: 0; easing.type: Easing.OutCubic }
                NumberAnimation { id: messageRemovalLineOut; target: messageRemovalLine; property: "x"; 
                    from: 0; to: -messageRemovalLine.width; easing.type: Easing.OutCubic }
                LinearGradient {
                    anchors.fill: parent
                    start: Qt.point(parent.width, 0)
                    end: Qt.point(0, 0)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 1.0; color: messageRemovalLine.colision ? "red" : "#565656" }
                    }
                }
            }

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
            displaced: Transition {
                NumberAnimation { properties: "y"; duration: 400; easing.type: Easing.OutCubic }
            }
            model: messagesModel
            delegate: Rectangle {
                id: messageCloud
                color: !msgSelf ? "lightblue" : (msgReceived ? "orange" : "lightgray")
                radius: 10
                property int keptUniqueId
                NumberAnimation on x {
                    id: cloudRemoveAnimation
                    duration: 500
                    easing.type: Easing.OutCubic
                    running: false
                    to: -messageCloud.width - cloudTailImage.width - (msgSelf ? 0 : timeText.width)
                    onFinished: {
                        messagesModel.remove(index)
                        toast.show({ message : qsTr("Message removed!"), duration : Toast.Short })
                    }
                }
                Drag.dragType: Drag.Automatic
                MouseArea {
                    id: messageCloudArea
                    anchors.fill: parent
                    drag.axis: Drag.XAxis
                    drag.target: parent
                }
                property bool cloudTextAreaDragActive
                readonly property bool dragActive: cloudTextAreaDragActive || messageCloudArea.drag.active
                function getAdditionalWidth() {
                    var pos = 0
                    if (msgSelf) {
                        if (timeText.contentWidth > width) {
                            pos += timeText.contentWidth - width
                        }
                    } else {
                        pos += cloudTailImage.width
                    }
                    return pos
                }
                onXChanged: {
                    if (dragActive) {
                        messageRemovalLine.colision = dragActive && x < getAdditionalWidth()
                    }
                }
                onDragActiveChanged: {
                    if (dragActive) {
                        if (msgSelf && !msgReceived && bridge.getFriendConnStatus(bridge.getCurrentFriendNumber()) > 0) {
                            return
                        }
                        messageRemovalLine.visible = true
                        removeAnchors()
                        messageRemovalLineIn.start()
                    } else {
                        if (x < getAdditionalWidth()) {
                            var friend_number = bridge.getCurrentFriendNumber()
                            bridge.removeMessageFromPendingList(friend_number, msgUniqueId)
                            bridge.removeMessageFromDB(friend_number, msgUniqueId)
                            messageRemovalLineOut.start()
                            messageRemovalLine.colision = false
                            cloudRemoveAnimation.start() 
                        } else {
                            setDefaultAnchors()
                            if (messageRemovalLine.x === 0) {
                                messageRemovalLineOut.start()
                            }
                            messageRemovalLine.colision = false
                        }
                    }
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
                property real cloudTextWidth
                function calculateMaximumWidth() {
                    var cwidth = window.width - chatContent.cloud_margin * 2 - chatContent.chat_margin * 2
                    if (cloudTextWidth > cwidth)
                        implicitWidth = cwidth
                }
                function setDefaultAnchors() {
                    if (msgSelf) {
                        anchors.right = parent.right
                        anchors.rightMargin = chatContent.chat_margin
                    } else {
                        anchors.left = parent.left
                        anchors.leftMargin = chatContent.chat_margin
                    }
                }
                function removeAnchors() {
                    if (msgSelf) {
                        anchors.right = undefined
                        anchors.rightMargin = 0
                    } else {
                        anchors.left = undefined
                        anchors.leftMargin = 0
                    }
                }
                Connections {
                    target: window
                    onInPortraitChanged: calculateMaximumWidth()
                    onUpdatePendingChanged: {
                        if (!msgReceived) {
                            pending = safe_bridge().checkMessageInPendingList(
                                        safe_bridge().getCurrentFriendNumber(), 
                                        msgUniqueId)
                            msgHistory = true
                        }
                    }
                    onEnableDragChanged: {
                        if (dragActive) {
                            setDefaultAnchors()
                            messageRemovalLineOut.start()
                        }
                    }
                }
                Component.onCompleted: {
                    calculateMaximumWidth()
                    setDefaultAnchors()
                }
                property bool pending: safe_bridge().checkMessageInPendingList(
                                           safe_bridge().getCurrentFriendNumber(), 
                                           msgUniqueId)
                Image {
                    id: resendIndicator
                    source: "resources/resend.png"
                    visible: msgSelf && !msgReceived && msgHistory && !parent.pending
                    anchors.right: parent.left
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: width
                    mipmap: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            msgHistory = false
                            messagePendingIndicatorTimer.stop()
                            bridge.resendMessage(bridge.getCurrentFriendNumber(), msgUniqueId)
                        }
                    }
                }
                Timer {
                    id: messagePendingIndicatorTimer
                    interval: 1000
                    repeat: false
                    running: !msgHistory
                }
                Image {
                    id: messagePendingIndicator
                    source: "resources/pending-spinner.png"
                    visible: msgSelf 
                             && !msgReceived 
                             && (!msgHistory || (msgHistory && parent.pending)) 
                             && !messagePendingIndicatorTimer.running
                    anchors.right: parent.left
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: width
                    mipmap: true
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 500
                        loops: Animation.Infinite
                    }
                }
                Loader {
                    anchors.fill: parent
                    Component {
                        id: cloudTextComponent
                        Text {
                            id: cloudText
                            property string plainText: msgText
                            text: plainText
                            anchors.fill: parent
                            anchors.margins: chatContent.cloud_margin
                            font.family: "Helvetica"
                            font.pointSize: fontMetrics.normalize(standardFontPointSize)
                            MouseArea {
                                id: cloudTextArea
                                anchors.fill: parent
                                drag.target: messageCloud
                                drag.axis: Drag.XAxis
                                readonly property bool dragActive: drag.active
                                onDragActiveChanged: {
                                    messageCloud.cloudTextAreaDragActive = dragActive
                                }
                                onClicked: {
                                    var link = parent.linkAt(mouseX, mouseY)
                                    if (link.length > 0) {
                                        Qt.openUrlExternally(link)
                                        return
                                    }
                                    bridge.copyTextToClipboard(cloudText.plainText)
                                    toast.show({ message : qsTr("Text copied!"), duration : Toast.Short });
                                }
                                onPressAndHold: {
                                    chatMessage.forceActiveFocus()
                                    var add = cloudText.plainText.replace("\n", "\n> ")
                                    Qt.inputMethod.reset()
                                    if (chatMessage.text.length > 0) {
                                        chatMessage.append("\n> " + add + "\n")
                                    } else {
                                        chatMessage.append("> " + add + "\n")
                                    }
                                    if (chatMessage) {
                                        chatMessage.cursorPosition = chatMessage.length
                                    }
                                }
                            }
                            Component.onCompleted: {
                                messageCloud.cloudTextWidth = width
                                textFormat = Text.StyledText
                                wrapMode = Text.Wrap
                                text = processText(plainText)
                                messageCloud.implicitWidth = contentWidth + chatContent.cloud_margin * 2
                            }
                            onContentHeightChanged: {
                                messageCloud.implicitHeight = contentHeight + chatContent.cloud_margin * 2
                                messageCloud.implicitWidth = contentWidth + chatContent.cloud_margin * 2
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
                                    line = line.replace(/\*+(.*?)\*+(?=\s|$)/g, function(match, _text) {
                                        return '<b>' + _text + '</b>'
                                    })
                                    line = line.replace(/\~+(.*?)\~+(?=\s|$)/g, function(match, _text) {
                                        return '<s>' + _text + '</s>'
                                    })
                                    line = line.replace(/\_+(.*?)\_+(?=\s|$)/g, function(match, _text) {
                                        return '<u>' + _text + '</u>'
                                    })
                                    result += line
                                    // put back all next line operators
                                    if (i < lines.length - 1) { result += "\n" }
                                }
                                result = result.replace(/((http|https|ftp|sftp)?:\/\/[^\s]+)/g, function(url) {
                                    return '<font color="#0645AD"><a href="' + url + '">' + url + '</a></font>'
                                })
                                result = result.replace(/^(&gt;(.)*)/gm, function(quote) {
                                    return '<font color="#0b6623">' + quote + '</font>'
                                })
                                result = result.replace(/(\n)/gm, '<br>')
        
                                //console.log(result)
                                return result
                            }
                        }
                    }
                    sourceComponent: msgType ? undefined : cloudTextComponent
                }
                Text {
                    id: timeText
                    anchors.top: messageCloud.bottom
                    text: msgTime
                    font.pointSize: fontMetrics.normalize(10)
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
        onHeightChanged: {
            if (loginWindow.profileSelected) {
                attachFileButton.addiveHeight = (height - attachFileButton.implicitHeight) * 0.5
                attachFileButton.updateButtonsHeight()
            }
        }
        Button {
            id: attachFileButton
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 2
            visible: !cleanProfile && !littleSpace
            implicitWidth: chatMessage.defaultHeight * 0.75
            implicitHeight: implicitWidth
            background: Rectangle {
                visible: false
            }
            focusPolicy: Qt.NoFocus
            Image {
                id: attachFileButtonImage
                anchors.fill: parent
                anchors.margins: 4
                source: "resources/attach-file-button.png"
                mipmap: true
            }
            property real addiveHeight: 5.75
            property bool buttonsActivated: false
            readonly property bool littleSpace: !inPortrait && keyboardActive
            onLittleSpaceChanged: {
                if (littleSpace && buttonsActivated) {
                    hideButtons()
                }
            }
            Connections {
                target: drawer
                onOpenedChanged: {
                    if (drawer.opened && attachFileButton.buttonsActivated) {
                        attachFileButton.hideButtons()
                    }
                }
            }
            Connections {
                target: contextMenuRight
                onOpenedChanged: {
                    if (contextMenuRight.opened && attachFileButton.buttonsActivated) {
                        attachFileButton.hideButtons()
                    }
                }
            }
            readonly property int buttonsDistance: 80
            readonly property real fullOpacity: 0.75
            ParallelAnimation {
                id: sendAnyFileButtonMoveInAnimation
                NumberAnimation { target: sendAnyFileButton; property: "y"; 
                    from: 0; to: -attachFileButton.buttonsDistance - attachFileButton.addiveHeight; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendAnyFileButton; property: "opacity"; 
                    from: 0.0; to: attachFileButton.fullOpacity; easing.type: Easing.OutCubic }
            }
            ParallelAnimation {
                id: sendAnyFileButtonMoveOutAnimation
                NumberAnimation { target: sendAnyFileButton; property: "y"; 
                    from: -attachFileButton.buttonsDistance - attachFileButton.addiveHeight; to: 0; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendAnyFileButton; property: "opacity"; 
                    from: attachFileButton.fullOpacity; to: 0.0; easing.type: Easing.OutCubic }
                onFinished: {
                    sendAnyFileButton.visible = false
                }
            }
            ParallelAnimation {
                id: sendImageButtonMoveInAnimation
                NumberAnimation { target: sendImageButton; property: "x"; 
                    from: 0; to: attachFileButton.buttonsDistance * Math.cos(Math.PI * 0.25); easing.type: Easing.OutCubic }
                NumberAnimation { target: sendImageButton; property: "y"; 
                    from: 0; to: -attachFileButton.buttonsDistance * Math.sin(Math.PI * 0.25) - attachFileButton.addiveHeight; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendImageButton; property: "opacity"; 
                    from: 0.0; to: attachFileButton.fullOpacity; easing.type: Easing.OutCubic }
            }
            ParallelAnimation {
                id: sendImageButtonMoveOutAnimation
                NumberAnimation { target: sendImageButton; property: "x"; 
                    from: attachFileButton.buttonsDistance * Math.cos(Math.PI * 0.25); to: 0; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendImageButton; property: "y"; 
                    from: -attachFileButton.buttonsDistance * Math.sin(Math.PI * 0.25) - attachFileButton.addiveHeight; to: 0; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendImageButton; property: "opacity"; 
                    from: attachFileButton.fullOpacity; to: 0.0; easing.type: Easing.OutCubic }
                onFinished: {
                    sendImageButton.visible = false
                }
            }
            Rectangle {
                id: sendAnyFileButton
                visible: false
                width: 40
                height: width
                opacity: parent.fullOpacity
                radius: width * 0.5
                color: "white"
                Image {
                    anchors.fill: parent
                    anchors.margins: 6
                    source: "resources/send-any-file-button.png"
                    mipmap: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        attachFileButton.hideButtons()
                        chatFilePickerDialog.open()
                    }
                }
            }
            Rectangle {
                id: sendImageButton
                visible: false
                width: 40
                height: width
                opacity: parent.fullOpacity
                radius: width * 0.5
                color: "white"
                Image {
                    anchors.fill: parent
                    anchors.margins: 6
                    source: "resources/send-image-button.png"
                    mipmap: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        attachFileButton.hideButtons()
                        chatPhotoPickerDialog.open()
                    }
                }
            }
            DropShadow {
                anchors.fill: sendAnyFileButton
                visible: sendAnyFileButton.visible
                opacity: sendAnyFileButton.opacity
                radius: 8.0
                samples: 16
                color: "#80000000"
                source: sendAnyFileButton
            }
            DropShadow {
                anchors.fill: sendImageButton
                visible: sendImageButton.visible
                opacity: sendImageButton.opacity
                radius: 8.0
                samples: 16
                color: "#80000000"
                source: sendImageButton
            }
            function hideButtons() {
                buttonsActivated = false
                sendAnyFileButtonMoveOutAnimation.start()
                sendImageButtonMoveOutAnimation.start()
            }
            function updateButtonsHeight() {
                if (buttonsActivated) {
                    sendAnyFileButton.y = -attachFileButton.buttonsDistance - attachFileButton.addiveHeight
                    sendImageButton.y = -attachFileButton.buttonsDistance * Math.sin(Math.PI * 0.25) - attachFileButton.addiveHeight
                }
            }
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: {
                    if (parent.buttonsActivated) {
                        parent.hideButtons()
                    } else {
                        sendAnyFileButton.visible = true
                        sendImageButton.visible = true
                        sendAnyFileButtonMoveInAnimation.start()
                        sendImageButtonMoveInAnimation.start()
                        parent.buttonsActivated = true
                    }
                }
                grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.ApprovesTakeOverByHandlersOfDifferentType
            }
        }
        Flickable {
            id: chatFlickable
            readonly property real defaultHeight: 46
            height: defaultHeight
            Layout.fillWidth: true
            boundsBehavior: Flickable.DragAndOvershootBounds
            clip: true
            visible: !cleanProfile
            ScrollBar.vertical: ScrollBar {
                id: chatScrollBar
                width: 10
                policy: ScrollBar.AlwaysOn
                visible: false
                interactive: false
            }
            Component.onCompleted: returnToBounds()
            TextArea.flickable: TextArea {
                id: chatMessage
                selectByMouse: true
                readonly property real maxFontSize: 22
                font.pointSize: fontMetrics.normalize(standardFontPointSize) <= maxFontSize ?
                                    fontMetrics.normalize(standardFontPointSize) : maxFontSize
                leftPadding: 10
                rightPadding: leftPadding
                placeholderText: qsTr("Type something")
                wrapMode: Text.Wrap
                clip: true
                background: Rectangle {
                    visible: false
                }
                bottomPadding: 8
                verticalAlignment: Qt.AlignVCenter
                property int maxLines: inPortrait ? 4 : 2
                property real defaultHeight
                property real defaultContentHeight
                Component.onCompleted: {
                    defaultHeight = height
                    defaultContentHeight = contentHeight
                }
                onContentWidthChanged: {
                    updateTyping()
                }
                function updateHeight() {
                    maxLines = inPortrait ? 4 : 2
                    if (defaultContentHeight !== 0) {
                        var lines = contentHeight / defaultContentHeight
                        var actualHeight
                        if (lines > 1) {
                            actualHeight = chatFlickable.defaultHeight + defaultContentHeight * (lines - 1)
                        } else {
                            actualHeight = chatFlickable.defaultHeight
                        }
                        var maxHeight = chatFlickable.defaultHeight + defaultContentHeight * (maxLines - 1)
                        chatFlickable.implicitHeight = Math.min(actualHeight, maxHeight)
                        chatScrollBar.visible = actualHeight > maxHeight
                    }
                }
                onContentHeightChanged: {
                    messages.scrollToEnd()
                    updateTyping()
                    updateHeight()
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
        }
        Button {
            id: sendButton
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 2
            visible: !cleanProfile
            implicitWidth: chatMessage.defaultHeight * 0.75
            implicitHeight: implicitWidth
            background: Rectangle {
                visible: false
            }
            focusPolicy: Qt.NoFocus
            function sendMessage() {
                Qt.inputMethod.reset()
                if (chatMessage.text.length > 0) {
                    bridge.sendMessage(chatMessage.text)
                    chatMessage.clear()
                } else {
                    chatMessage.focus = false
                }
            }
            Image {
                id: sendButtomImage
                anchors.fill: parent
                anchors.margins: 4
                source: "resources/send-button.png"
                mipmap: true
            }
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: sendButton.sendMessage()
                grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.ApprovesTakeOverByHandlersOfDifferentType
            }
        }
    }
}

FileDialog {
    id: chatFilePickerDialog
    title: qsTr("Select a file")
    onAccepted: {
        toast.show({ message : bridge.uriToRealPath(fileUrl.toString()), duration : Toast.Short })
    }
}

PhotoDialog {
    id: chatPhotoPickerDialog
    title: qsTr("Select an image")
    onAccepted: {
        toast.show({ message : bridge.uriToRealPath(imageUrl.toString()), duration : Toast.Short })
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
    x: (parent.width - width) * 0.5
    y: chatSeparator.y - height - bottomMargin
    visible: false
    Text {
        id: nextPageButtonText
        text: "\u2193 " + qsTr("You have %n new message(s)", "", new_messages) + " \u2193"
        font.bold: true
        font.pointSize: fontMetrics.normalize(12.5)
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
