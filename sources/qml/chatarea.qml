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
    spacing: 0

    Item {
        id: chatContent
        readonly property int chat_margin: 15
        readonly property int cloud_margin: 5
        Layout.alignment: Qt.AlignTop
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: overlayHeader.height

        ListModel {
            id: messagesModel
        }

        ListView {
            id: messages
            anchors.fill: parent
            readonly property int flickable_margin: 25
            topMargin: flickable_margin
            spacing: 20
            clip: true
            boundsMovement: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator {}
            displayMarginBeginning: 32
            bottomMargin: typingText.visible 
                          ? flickable_margin + typingText.height + typingText.margin 
                          : flickable_margin

            onBottomMarginChanged: {
                if (typingText.visible && wasAtYEnd) {
                    contentY += typingText.height + typingText.margin 
                }
            }

            Behavior on bottomMargin {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: typingText
                height: 20
                visible: false
                opacity: alpha
                z: z_top
                radius: height * 0.5
                anchors.left: parent.left
                anchors.leftMargin: chatContent.chat_margin
                anchors.right: parent.right
                anchors.rightMargin: chatContent.chat_margin
                anchors.bottom: parent.bottom
                anchors.bottomMargin: margin
                color: "white"
                readonly property int margin: 5
                readonly property real alpha: 0.9
                property string text

                Timer {
                    id: typingTextAnimationTimer
                    running: parent.visible
                    repeat: true
                    readonly property int timerInterval: 500
                    interval: timerInterval
                    property int symbol: 1

                    onTriggered: {
                        symbol++
                        if (symbol > 3) {
                            symbol = 1
                        }
                    }

                    onRunningChanged: {
                        if (!running) {
                            symbol = 1
                        }
                    }
                }

                Text {
                    id: typingTextReal
                    anchors.left: parent.left
                    anchors.leftMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.text
                    font.italic: true
                    visible: parent.visible
                    readonly property int typingTextIndicatorSize: 6
                    readonly property int typingTextIndicatorAnimationDuration: 250

                    Rectangle {
                        id: typingTextIndicator1
                        width: parent.typingTextIndicatorSize
                        height: width
                        radius: height * 0.5
                        ColorAnimation on color { to: getUserTheme().typingTextIndicatorActiveColor; duration: typingTextReal.typingTextIndicatorAnimationDuration; 
                            running: typingTextAnimationTimer.symbol === 1 }
                        ColorAnimation on color { to: getUserTheme().typingTextIndicatorColor; duration: typingTextReal.typingTextIndicatorAnimationDuration; 
                            running: typingTextAnimationTimer.symbol !== 1 }
                        color: getUserTheme().typingTextIndicatorColor
                        anchors.left: parent.right
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        id: typingTextIndicator2
                        width: parent.typingTextIndicatorSize
                        height: width
                        radius: height * 0.5
                        ColorAnimation on color { to: getUserTheme().typingTextIndicatorActiveColor; duration: typingTextReal.typingTextIndicatorAnimationDuration; 
                            running: typingTextAnimationTimer.symbol === 2 }
                        ColorAnimation on color { to: getUserTheme().typingTextIndicatorColor; duration: typingTextReal.typingTextIndicatorAnimationDuration; 
                            running: typingTextAnimationTimer.symbol !== 2 }
                        color: getUserTheme().typingTextIndicatorColor
                        anchors.left: typingTextIndicator1.right
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        id: typingTextIndicator3
                        width: parent.typingTextIndicatorSize
                        height: width
                        radius: height * 0.5
                        ColorAnimation on color { to: getUserTheme().typingTextIndicatorActiveColor; duration: typingTextReal.typingTextIndicatorAnimationDuration; 
                            running: typingTextAnimationTimer.symbol === 3 }
                        ColorAnimation on color { to: getUserTheme().typingTextIndicatorColor; duration: typingTextReal.typingTextIndicatorAnimationDuration; 
                            running: typingTextAnimationTimer.symbol !== 3 }
                        color: getUserTheme().typingTextIndicatorColor
                        anchors.left: typingTextIndicator2.right
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
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
                    from: 0; to: -messageRemovalLine.width; easing.type: Easing.OutCubic; }

                LinearGradient {
                    anchors.fill: parent
                    start: Qt.point(parent.width, 0)
                    end: Qt.point(0, 0)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 1.0; color: messageRemovalLine.colision 
                                                             ? getUserTheme().messageRemoveLineActiveColor 
                                                             : getUserTheme().messageRemoveLineColor }
                    }
                }
            }

            onContentYChanged: {
                if (atYEnd) {
                    scrollToEndButton.visible = false
                }
            }

            function exceedsHeight() {
                return contentHeight > height
            }

            property bool wasAtYEnd
            function scrollToEnd() {
                positionViewAtEnd()
                contentY += flickable_margin
                wasAtYEnd = true
            }

            function scrollToEndWithTypingText() {
                if (typingText.visible) {
                    typingText.visible = false
                }

                scrollToEnd()

                if (!typingText.visible && typingText.text.length > 0) {
                    typingText.visible = true
                }

                if (typingText.visible) {
                    contentY += typingText.height + typingText.margin 
                }
            }
            
            onFlickStarted: {
                wasAtYEnd = false
            }

            onFlickEnded: {
                wasAtYEnd = atYEnd
            }

            Timer {
                id: preloadingTimer
                interval: 1
                onTriggered: {
                    var uniqueId = messagesModel.get(0).msgUniqueId
                    messages.addTransitionEnabled = false
                    bridge.retrieveChatLog(uniqueId, true)
                    addTransitionEnableTimer.start()

                    // fixme: move this code to function(s) in the future
                    for (var i = 0; i < messagesModel.count; i++) {
                        if (messagesModel.get(i).msgUniqueId === uniqueId) {
                            messages.positionViewAtIndex(i, ListView.Beginning)
                            messages.contentY -= parent.flickable_margin
                            break
                        }
                    }

                    messagesLoadingNotification.visible = false
                }
            }

            function preloadHistory() {
                if (atYBeginning && messagesModel.count > 0) {
                    var uniqueId = messagesModel.get(0).msgUniqueId

                    if (!bridge.checkRemainingMessages(uniqueId)) {
                        return
                    }

                    messagesLoadingNotification.visible = true
                    preloadingTimer.start()
                }
            }

            onAtYBeginningChanged: {
                if (atYBeginning) {
                    preloadHistory()
                }
            }

            property int defaultHeight
            Component.onCompleted: {
                defaultHeight = height
            }

            onHeightChanged: {
                var cond1 = height === defaultHeight - keyboardHeight 
                        && keyboardActive 
                        && (!chatFlickable.backToDefaultHeight)
                var cond2 = height < defaultHeight - keyboardHeight && wasAtYEnd

                if (cond1 || cond2) {
                    scrollToEndWithTypingText()
                }
            }

            property bool addTransitionEnabled: true
            add: Transition {
                enabled: messages.addTransitionEnabled
                NumberAnimation { property: "scale"; from: 0; to: 1.0; duration: 300 }
            }

            displaced: Transition {
                NumberAnimation { properties: "y"; duration: 400; easing.type: Easing.OutCubic; }
            }

            model: messagesModel
            delegate: Rectangle {
                id: messageCloud
                color: !msgSelf ? getUserTheme().messageCloudFriendColor 
                                : ((msgReceived || msgType) ? getUserTheme().messageCloudSelfColor 
                                                            : getUserTheme().messageCloudPendingColor)
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
                        var self = msgType === msgtype_file ? true : msgSelf
                        if (self && !msgReceived && bridge.getFriendConnStatus(bridge.getCurrentFriendNumber()) > 0) {
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

                            if (messageRemovalLine.x > -messageRemovalLine.width) {
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
                    source: msgSelf ? ((msgReceived || msgType) ? canvasBuffer.itemAt(1).source : canvasBuffer.itemAt(0).source) : canvasBuffer.itemAt(2).source
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
                readonly property int reservedWidth: resendIndicator.width + resendIndicator.anchors.rightMargin

                function calculateMaximumWidth() {
                    var cwidth = window.width 
                            - chatContent.cloud_margin * 2 
                            - chatContent.chat_margin * 2 
                            - reservedWidth
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
                    onInPortraitChanged: {
                        if (msgType === msgtype_file) {
                            return
                        }
                        if (messageCloud.implicitWidth < messageCloud.cloudTextWidth) {
                            messageCloud.implicitWidth = messageCloud.cloudTextWidth
                        }
                        messageCloud.calculateMaximumWidth()
                    }

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
                    if (msgType === msgtype_text) {
                        calculateMaximumWidth()
                    }

                    setDefaultAnchors()
                }

                property bool pending: safe_bridge().checkMessageInPendingList(
                                           safe_bridge().getCurrentFriendNumber(), 
                                           msgUniqueId)

                Image {
                    id: resendIndicator
                    source: "resources/resend.png"
                    visible: msgSelf && !msgReceived && msgHistory && !parent.pending && !msgType
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
                             && !msgType
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
                            font.pointSize: fontMetrics.normalize(standardFontPointSize)
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText

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

                                if (msgAction) {
                                    text = '<i><font color="' + getUserTheme().actionTextColor + '">' + text + '</font></i>'
                                } else {
                                    text = processText(plainText)
                                }

                                messageCloud.implicitWidth = contentWidth + chatContent.cloud_margin * 2
                            }

                            onContentHeightChanged: {
                                messageCloud.implicitHeight = contentHeight + chatContent.cloud_margin * 2
                                messageCloud.implicitWidth = contentWidth + chatContent.cloud_margin * 2
                            }

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
                                    return '<font color="' + getUserTheme().linksColor + '"><a href="' + url + '">' + url + '</a></font>'
                                })
                                result = result.replace(/^(&gt;(.)*)/gm, function(quote) {
                                    return '<font color="' + getUserTheme().quotesColor + '">' + quote + '</font>'
                                })
                                result = result.replace(/(\n)/gm, '<br>')
        
                                //console.log(result)
                                return result
                            }
                        }
                    }

                    Component {
                        id: cloudFileComponent

                        Column {
                            id: fileLayout
                            anchors.fill: parent
                            anchors.leftMargin: chatContent.chat_margin * 0.5
                            anchors.rightMargin: chatContent.chat_margin * 0.75
                            spacing: 0
                            readonly property real maxWidth: messages.width * 0.5
                            readonly property real verticalMargins: chatContent.chat_margin * 0.35

                            Timer {
                                id: speedCalcTimer
                                running: msgFilestate === fstate_inprogress
                                interval: 1000
                                repeat: true
                                property int lastFileSize: 0
                                onTriggered: {
                                    parent.transferSpeed = formatBytes(msgFiletsize - lastFileSize)
                                    lastFileSize = msgFiletsize
                                }
                            }

                            Rectangle { opacity: 0; width: parent.width; height: fileLayout.verticalMargins }

                            Text {
                                id: fileName
                                text: msgFilename
                                font.pointSize: fontMetrics.normalize(standardFontPointSize)
                                wrapMode: Text.Wrap
                                width: parent.width
                            }

                            Text {
                                id: fileSize
                                text: formatBytes(msgFilesize)
                                font.pointSize: fontMetrics.normalize(standardFontPointSize)
                                wrapMode: Text.Wrap
                                width: parent.width
                            }

                            property string transferSpeed: qsTr("Transferring...")
                            function addSpeedString() {
                                if (transferSpeed !== qsTr("Transferring...")) {
                                    return qsTr("/s")
                                }
                                return ""
                            }

                            Text {
                                id: fileStatus
                                visible: msgFilestate !== fstate_request && !msgRemotepaused 
                                color: msgFilestate === fstate_finished ? getUserTheme().transferSuccededTextColor : 
                                      (msgFilestate === fstate_inprogress 
                                       || msgFilestate == fstate_paused ? "black" : getUserTheme().transferCanceledTextColor)
                                font.pointSize: fontMetrics.normalize(standardFontPointSize)
                                text: msgFilestate === fstate_canceled ? qsTr("File transfer canceled.") : 
                                      (msgFilestate === fstate_finished ? qsTr("Transfer succeeded.") : 
                                      (msgFailed ? qsTr("File transfer failed.") : parent.transferSpeed + parent.addSpeedString()))
                                wrapMode: Text.Wrap
                                width: parent.width
                            }

                            Text {
                                id: remotePausedText
                                visible: msgRemotepaused 
                                         && msgFilestate !== fstate_finished 
                                         && msgFilestate !== fstate_canceled
                                text: qsTr("Remote paused.")
                                color: getUserTheme().transferRemotePausedTextColor
                                font.pointSize: fontMetrics.normalize(standardFontPointSize)
                                wrapMode: Text.Wrap
                                width: parent.width
                            }

                            Rectangle { opacity: 0; visible: fileButtonsLayout.visible; width: parent.width; height: 8 }

                            ProgressBar {
                                id: fileProgress
                                width: parent.width
                                value: msgFiletsize / msgFilesize
                                visible: msgFilestate === fstate_inprogress || msgFilestate == fstate_paused

                                Behavior on value {
                                    SmoothedAnimation { velocity: 200 }
                                }
                            }
                            Rectangle { opacity: 0; visible: fileButtonsLayout.visible; width: parent.width; height: 8 }

                            Rectangle {
                                id: filePreviewImageRectangle
                                readonly property int margins: 2
                                width: reservedImageSpace.width + margins * 2
                                height: reservedImageSpace.height + margins * 2
                                radius: 2
                                color: getTheme().highlightedButtonColor
                                visible: filePreviewImage.status !== Image.Null && reservedImageSpace.width > 0

                                Item {
                                    id: reservedImageSpace
                                    anchors.centerIn: parent
                                    property variant imageSize: msgFilestate === fstate_finished 
                                                                ? safe_bridge().getImageSize(msgFilepath)
                                                                : Qt.size(0, 0)
                                    readonly property real ratio: imageSize.height / imageSize.width
                                    width: makeMultBy(fileLayout.width, filePreviewImageAlphaLayer.magicSize)
                                    height: makeMultBy(fileLayout.width * ratio, filePreviewImageAlphaLayer.magicSize)
                                    visible: filePreviewImage.status !== Image.Ready
                                }

                                Image {
                                    id: filePreviewImageAlphaLayer
                                    readonly property int magicSize: 16 // size of this image
                                    anchors.centerIn: parent
                                    source: "resources/checkerboard.png"
                                    width: reservedImageSpace.width
                                    height: reservedImageSpace.height
                                    fillMode: Image.Tile
                                    horizontalAlignment: Image.AlignLeft
                                    verticalAlignment: Image.AlignTop
                                    smooth: false
                                }

                                Image {
                                    id: filePreviewImage
                                    anchors.centerIn: parent
                                    source: msgFilestate === fstate_finished 
                                            ? safe_bridge().checkFileImage(msgFilepath) : ""
                                    readonly property real ratio: sourceSize.height / sourceSize.width
                                    width: makeMultBy(fileLayout.width, filePreviewImageAlphaLayer.magicSize)
                                    height: makeMultBy(fileLayout.width * ratio, filePreviewImageAlphaLayer.magicSize)
                                    asynchronous: true
                                    mipmap: true

                                    LinearGradient {
                                        id: moreHeightGradient
                                        property bool allowRender: false
                                        visible: parent.status === Image.Ready && allowRender
                                        anchors.fill: parent
                                        start: Qt.point(0, 0)
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "#00000000" }
                                            GradientStop { position: 0.75; color: "#00000000" }
                                            GradientStop { position: 1.0; color: getTheme().highlightedButtonColor }
                                        }
                                    }

                                    onHeightChanged: {
                                        var h = makeMultBy(fileLayout.width * ratio, filePreviewImageAlphaLayer.magicSize)
                                        if (height === h && height > messages.height) {
                                            let requiredHeight = makeMultBy(messages.height, filePreviewImageAlphaLayer.magicSize)
                                            height = requiredHeight
                                            reservedImageSpace.height = requiredHeight
                                            fillMode = Image.PreserveAspectCrop
                                            verticalAlignment = Image.AlignTop
                                            moreHeightGradient.allowRender = true
                                            moreHeightGradient.end = Qt.point(0, requiredHeight)
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            bridge.viewFile(msgFilepath, "image/*")
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                width: parent.width
                                height: 1
                                visible: fileButtonsLayout.visible
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#00000000" }
                                    GradientStop { position: 0.25; color: "white" }
                                    GradientStop { position: 0.75; color: "white" }
                                    GradientStop { position: 1.0; color: "#00000000" }
                                }
                            }

                            RowLayout {
                                spacing: 0
                                visible: filePauseButton.visible
                                width: parent.width
                                height: fileLayout.verticalMargins
                                Rectangle {
                                    width: 1
                                    visible: parent.visible
                                    Layout.fillHeight: true
                                    Layout.alignment: Qt.AlignHCenter
                                    color: "white"
                                }
                            }

                            RowLayout {
                                id: fileButtonsLayout
                                width: parent.width
                                spacing: 0
                                visible: fileCancelButton.visible || filePauseButton.visible

                                ToolButton {
                                    id: filePauseButton
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: msgFilestate !== fstate_request 
                                             && msgFilestate !== fstate_canceled 
                                             && msgFilestate !== fstate_finished

                                    Text {
                                        id: filePauseButtonText
                                        anchors.centerIn: parent
                                        font.family: themify.name
                                        font.pointSize: 24
                                        text: msgFilestate === fstate_paused ? "\uE761" : "\uE762"
                                        color: "black"
                                    }

                                    onClicked: {
                                        var control
                                        if (msgFilestate === fstate_inprogress) {
                                            control = fcontrol_pause
                                        } else if (msgFilestate === fstate_paused) {
                                            control = fcontrol_resume
                                        }

                                        bridge.controlFile(bridge.getCurrentFriendNumber(), 
                                                           msgFilenumber, control)
                                    }
                                }

                                ToolButton {
                                    id: fileAcceptButton
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: !msgSelf && msgFilestate === fstate_request

                                    onClicked: {
                                        var control = bridge.acceptFile(bridge.getCurrentFriendNumber(), 
                                                                        msgFilenumber)
                                        if (control === -1) {
                                            toast.show({ message : qsTr("Failed to resume a transfer."), duration : Toast.Long })
                                        } else if (control === fcontrol_cancel) {
                                            toast.show({ message : qsTr("Failed to open a file."), duration : Toast.Long })
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: themify.name
                                        font.pointSize: 24
                                        text: "\uE64C"
                                        color: getUserTheme().fileAcceptButtonColor
                                    }
                                }

                                Rectangle {
                                    width: 1
                                    Layout.fillHeight: true
                                    visible: filePauseButton.visible || fileAcceptButton.visible
                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop { position: 0.0; color: "white" }
                                        GradientStop { position: 1.0; color: "#00000000" }
                                    } 
                                }

                                ToolButton {
                                    id: fileCancelButton
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: msgFilestate !== fstate_canceled && msgFilestate !== fstate_finished

                                    onClicked: {
                                        bridge.controlFile(bridge.getCurrentFriendNumber(), 
                                                           msgFilenumber, fcontrol_cancel)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: themify.name
                                        font.pointSize: 24
                                        text: (!msgSelf && msgFilestate === fstate_request) ? "\uE646" : "\uE760"
                                        color: getUserTheme().fileCancelButtonColor
                                    }
                                }
                            }

                            ToolButton {
                                id: viewFileButton
                                visible: msgFilestate === fstate_finished 
                                         && safe_bridge().checkFileExists(msgFilepath) 
                                         && filePreviewImage.status === Image.Null

                                onClicked: {
                                    if (!bridge.viewFile(msgFilepath, "*")) {
                                        toast.show({ message : qsTr("No application found for this file type."), duration : Toast.Short })
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    font.family: themify.name
                                    font.pointSize: 24
                                    text: "\uE6A4"
                                    color: "black"
                                }
                            }

                            Text {
                                id: fileNotExistsText
                                visible: msgFilestate === fstate_finished && !safe_bridge().checkFileExists(msgFilepath)
                                text: qsTr("File not found.")
                                font.pointSize: fontMetrics.normalize(standardFontPointSize)
                                wrapMode: Text.Wrap
                                width: parent.width
                            }

                            Rectangle { opacity: 0; width: parent.width; height: fileLayout.verticalMargins }

                            property real lastImplicitHeight
                            Component.onCompleted: {
                                messageCloud.implicitWidth = maxWidth
                                messageCloud.implicitHeight = implicitHeight
                                lastImplicitHeight = implicitHeight
                            }

                            Connections {
                                target: window
                                onInPortraitChanged: {
                                    messageCloud.implicitWidth = fileLayout.maxWidth
                                }
                            }

                            onImplicitHeightChanged: {
                                if (implicitHeight > lastImplicitHeight && messages.atYEnd) {
                                    messages.contentY += implicitHeight - lastImplicitHeight
                                }

                                lastImplicitHeight = implicitHeight
                            }

                            Binding {
                                target: messageCloud
                                property: "implicitHeight"
                                value: implicitHeight
                            }
                        }
                    }

                    sourceComponent: msgType ? cloudFileComponent : cloudTextComponent
                }

                Text {
                    id: timeText
                    color: getTheme().primaryTextColor
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
        Layout.fillWidth: true
        visible: !cleanProfile
    }

    RowLayout {
        id: chatLayout
        Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
        readonly property int margin: 5
        Layout.margins: margin

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
            focusPolicy: Qt.NoFocus
            background: Rectangle {
                visible: false
            }

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
                if (littleSpace) {
                    hideButtons()
                }
            }

            Connections {
                target: drawer
                onOpenedChanged: {
                    if (drawer.opened) {
                        attachFileButton.hideButtons()
                    }
                }
            }

            Connections {
                target: contextMenuRight
                onOpenedChanged: {
                    if (contextMenuRight.opened) {
                        attachFileButton.hideButtons()
                    }
                }
            }

            readonly property int buttonsDistance: 80
            readonly property real fullOpacity: 0.9

            ParallelAnimation {
                id: sendAnyFileButtonMoveInAnimation
                NumberAnimation { target: sendAnyFileButton; property: "y"; 
                    from: 0; to: -attachFileButton.buttonsDistance - attachFileButton.addiveHeight; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendAnyFileButton; property: "opacity"; 
                    from: 0.0; to: attachFileButton.fullOpacity; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendAnyFileButton; property: "scale"; 
                    from: 0.0; to: 1.0; easing.type: Easing.Linear }
            }

            ParallelAnimation {
                id: sendAnyFileButtonMoveOutAnimation
                NumberAnimation { target: sendAnyFileButton; property: "y"; 
                    from: -attachFileButton.buttonsDistance - attachFileButton.addiveHeight; to: 0; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendAnyFileButton; property: "opacity"; 
                    from: attachFileButton.fullOpacity; to: 0.0; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendAnyFileButton; property: "scale"; 
                    from: 1.0; to: 0.0; easing.type: Easing.Linear }
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
                NumberAnimation { target: sendImageButton; property: "scale"; 
                    from: 0.0; to: 1.0; easing.type: Easing.Linear }
            }

            ParallelAnimation {
                id: sendImageButtonMoveOutAnimation
                NumberAnimation { target: sendImageButton; property: "x"; 
                    from: attachFileButton.buttonsDistance * Math.cos(Math.PI * 0.25); to: 0; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendImageButton; property: "y"; 
                    from: -attachFileButton.buttonsDistance * Math.sin(Math.PI * 0.25) - attachFileButton.addiveHeight; to: 0; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendImageButton; property: "opacity"; 
                    from: attachFileButton.fullOpacity; to: 0.0; easing.type: Easing.OutCubic }
                NumberAnimation { target: sendImageButton; property: "scale"; 
                    from: 1.0; to: 0.0; easing.type: Easing.Linear }
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
                if (buttonsActivated) {
                    buttonsActivated = false
                    sendAnyFileButtonMoveOutAnimation.start()
                    sendImageButtonMoveOutAnimation.start()
                    return true
                }

                return false
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
                    if (!parent.hideButtons()) {
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
                interactive: true
            }

            property bool backToDefaultHeight: false
            property real lastHeight

            Connections {
                target: window
                onKeyboardActiveChanged: {
                    if (!keyboardActive) {
                        chatFlickable.backToDefaultHeight = false
                    }
                }
            }

            onHeightChanged: {
                if (lastHeight > height && height === defaultHeight) {
                    backToDefaultHeight = true
                } else {
                    backToDefaultHeight = false
                }
                lastHeight = height
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

                onTextChanged: {
                    updateTyping()
                }

                function updateHeight() {
                    var atYEnd = messages.atYEnd
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
                    if (bridge.getConnectionStatus() < 1) {
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
            focusPolicy: Qt.NoFocus
            background: Rectangle {
                visible: false
            }

            function sendMessage() {
                Qt.inputMethod.reset()

                if (chatMessage.text.length > 0) {
                    bridge.sendMessage(bridge.getCurrentFriendNumber(), chatMessage.text)
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

    Rectangle {
        id: keyboardSpace
        opacity: 0
        Layout.alignment: Qt.AlignBottom
        Layout.fillWidth: true
        implicitHeight: chatMessage.focus ? keyboardHeight : 0
        onImplicitHeightChanged: {
            if (implicitHeight > 0) {
                messages.scrollToEnd()
                scrollToEndTimer.start()
            }
        }
    }
}

FileDialog {
    id: chatFilePickerDialog
    title: qsTr("Select a file")
    selectMultiple: true
    onAccepted: {
        messages.addTransitionEnabled = fileUrls.length === 1

        for (var i = 0; i < fileUrls.length; i++) {
            sendFile(fileUrls[i])
        }

        messages.addTransitionEnabled = true
    }
}

PhotoDialog {
    id: chatPhotoPickerDialog
    title: qsTr("Select an image")
    selectMultiple: true
    onAccepted: {
        messages.addTransitionEnabled = imageUrls.length === 1

        for (var i = 0; i < imageUrls.length; i++) {
            sendFile(imageUrls[i])
        }

        addTransitionEnableTimer.start()
    }
}

Rectangle {
    id: scrollToEndButton
    z: z_top
    readonly property real padding: 10
    width: nextPageButtonText.contentWidth + padding * 2
    height: nextPageButtonText.contentHeight + padding * 2
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

Rectangle {
    id: messagesLoadingNotification
    z: z_top
    readonly property real padding: 10
    width: messagesLoadingNotificationText.contentWidth + padding * 2
    height: messagesLoadingNotificationText.contentHeight + padding * 2
    radius: height * 0.5
    color: "white"
    readonly property real alpha: 0.9
    readonly property int topMargin: 15
    opacity: alpha
    x: (parent.width - width) * 0.5
    y: overlayHeader.height + topMargin
    visible: false

    Text {
        id: messagesLoadingNotificationText
        text: qsTr("Loading history...")
        font.bold: true
        font.pointSize: fontMetrics.normalize(12.5)
        opacity: parent.opacity
        anchors.centerIn: parent
    }
}

DropShadow {
    anchors.fill: messagesLoadingNotification
    visible: messagesLoadingNotification.visible
    opacity: messagesLoadingNotification.opacity
    radius: 8.0
    samples: 16
    color: "#80000000"
    source: messagesLoadingNotification
}

/*[remove]*/ }
