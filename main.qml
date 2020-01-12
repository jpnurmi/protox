import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3

import QtNotification 1.0

ApplicationWindow {
    id: window
    width: 360
    height: 520
    visible: true
    title: qsTr("Side Panel")

    Timer {
        id: initTimer
        repeat: false
        interval: 1
        onTriggered: {
            bridge.retrieveChatLog()
            splashImageDestroyAnimation.start()
            chatFlickable.scrollToEnd()
        }
    }
    
    Image {
        id: splashImage
        source: "splash.png"
        anchors.fill: parent
        cache: true
        z: z_splash
        NumberAnimation on opacity {
            id: splashImageDestroyAnimation
            to: 0
            duration: 200
            running: false
            onRunningChanged: {
                 if (!running) {
                     splashImage.destroy();
                 }
            }
        }
    }

    Notification {
        id: notification
    }

    FontLoader { 
        id: dejavuSans; 
        source: "DejaVuSans.ttf"
    }
    readonly property bool inPortrait: window.width < window.height

    // global properties
    readonly property int z_cloud: -1
    readonly property int z_drawer: 2
    readonly property int z_overlay_header: 1
    readonly property int z_menu: 3
    readonly property int z_splash: Number.MAX_VALUE

    function limitString(str, limit) {
        if (str.length > limit) {
            return str.slice(0, limit) + "..."
        }
        return str
    }

    // function callbacks
    function setFriendStatusMessage(friend_number, message) {
        if (friend_number !== bridge.getCurrentFriendNumber())
            return
        friendStatus.text = limitString(message, friendStatus.charsLimit)
    }

    function setFriendTyping(friend_number, typing) {
        if (friend_number !== bridge.getCurrentFriendNumber())
            return
        if (typing) {
            var nick = bridge.getFriendNickname(friend_number)
            // don't print long nicks
            if (nick.length > friendNickname.charsLimit) {
                nick = qsTr("A friend")
            }
            typingText.text = nick + qsTr(" is typing...")
            typingText.visible = true
        } else {
            typingText.text = ""
            typingText.visible = false
        }
        chatFlickable.scrollToEnd()
    }

    function updateFriendNickName(friend_number, nickname) {
        for (var i = 0; i < friendsModel.count; i++) {
            var friend = friendsModel.get(i)
            if (friend.friendNumber === friend_number) {
                friend.nickName = nickname
                friendsModel.set(i, friend)
            }
        }
        if (friend_number === bridge.getCurrentFriendNumber()) {
            friendNickname.text = limitString(nickname, friendNickname.charsLimit)
        }
    }
    function sendFriendRequestStatus(status) {
        var msg = "";
        var color = "red";
        if (addFriendMenu.opened) {
            switch (status) {
            case 0: msg = qsTr("Request sent!"); color = "green"; break;
            case 4: msg = qsTr("You cannot send friend request to yourself."); break;
            case 5: msg = qsTr("The friend is already on the friend list."); break;
            case 6: msg = qsTr("The friend address is invalid."); break;
            case 7: msg = qsTr("The friend has different nospam value."); break;
            default: msg = qsTr("Failed! error code: ") + status.toString(); break;
            }
            friendRequestStatusText.color = color
            friendRequestStatusText.text = msg
        }
    }

    function chatScrollToEnd() {
        chatFlickable.scrollToEnd()
    }

    function selectFriend(friend_number) {
        if (bridge.getCurrentFriendNumber() === friend_number) {
            return
        }
        dropTypingTimer.stop()
        bridge.setTypingFriend(bridge.getCurrentFriendNumber(), false)
        bridge.setCurrentFriend(friend_number)
        friendNickname.text = limitString(bridge.getFriendNickname(bridge.getCurrentFriendNumber()), friendNickname.charsLimit)
        friendStatus.text = limitString(bridge.getFriendStatusMessage(bridge.getCurrentFriendNumber()), friendStatus.charsLimit)
        setCurrentFriendConnStatus(friend_number, bridge.getFriendConnStatus(friend_number))
        messagesModel.clear()
        bridge.retrieveChatLog()
        chatScrollToEnd()
    }

    function insertMessage(text, friend_number, self, message_id, time, unique_id, failed, history) {
        if (!self && !history && (!window.visibility || (window.visibility && bridge.getCurrentFriendNumber() !== friend_number))) {
            notification.show({
                              caption : text,
                              title : qsTr("New message from ") + bridge.getFriendNickname(friend_number),
                              id : friend_number
                            });
        }
        if (bridge.getCurrentFriendNumber() !== friend_number)
            return
        messagesModel.append({"msgText": text, 
                                 "msgSelf" : self, 
                                 "msgReceived" : false, 
                                 "msgId" : message_id, 
                                 "msgTime" : time, 
                                 "msgUniqueId" : unique_id,
                                 "msgFailed" : failed})
        if (!history)
            chatFlickable.scrollToEnd()
    }
    function insertFriend(friend_number, nickName) {
        friendsModel.append({"friendNumber" : friend_number, "nickName" : nickName})
    }

    function setMessageReceived(friend_number, message_id, use_uid, unique_id) {
        for (var i = 0; i < messagesModel.count; i++) {
            var message = messagesModel.get(i)
            if (!message.msgSelf)
                continue;
            if ((!use_uid && message.msgId === message_id) || (use_uid && message.msgUniqueId === unique_id)) {
                message.msgReceived = true
                messagesModel.set(i, message)
                messages.itemAt(i).setCloudColor("orange")
            }
        }
    }
    function setCurrentFriendConnStatus(friend_number, conn_status) {
        if (bridge.getCurrentFriendNumber() === friend_number) {
            if (conn_status > 0) {
                friendStatusIndicator.color = "lightgreen"
            } else {
                friendStatusIndicator.color = "gray"
            }
        }

        for (var i = 0; i < friendsModel.count; i++) {
            var friend = friendsModel.get(i)
            if (friend.friendNumber === friend_number) {
                if (conn_status > 0) {
                    friends.itemAt(i).setFriendStatusIndicatorColor("lightgreen")
                } else {
                    friends.itemAt(i).setFriendStatusIndicatorColor("gray")
                }
            }
        }
    }

    Repeater {
        id: canvasBuffer
        model: ["lightgray", "orange", "lightblue"]
        delegate: Image { 
            id: cloudTailImageFrameBuffer 
            visible: false
            Canvas {
                id: cloudTailCanvas
                width: 256
                height: width
                visible: false
                onPaint: {
                    var cxt = getContext("2d");
                    cxt.beginPath();
                    cxt.moveTo(0, 0);
                    cxt.lineTo(0, height);
                    cxt.lineTo(width, 0);
                    cxt.closePath();
                    cxt.fillStyle = modelData;
                    cxt.fill();
                    grabToImage(function(result) { parent.source = result.url; });
                }
            }
        }
    }

    /*
      
        Add friend menu
      
    */
    Menu {
        id: addFriendMenu
        width: 300
        title: "Add new friend"
        x: window.width / 2 - width / 2
        y: window.height / 2 - height / 2
        z: z_menu
        modal: true
        onClosed: {
            currentIndex = -1
            toxId.focus = false
            addFriendMessage.focus = false
        }

        Text {
            padding: 10
            font.bold: true
            width: parent.width
            horizontalAlignment: Qt.AlignHCenter
            text: qsTr("Tox ID")
        }
        TextField {
            id: toxId
            selectByMouse: true
            font.pixelSize: 20
            leftPadding: 10
            rightPadding: leftPadding
            verticalAlignment: TextInput.AlignVCenter
            width: parent.width
            text: ""
        }
        Text {
            padding: 10
            font.bold: true
            width: parent.width
            horizontalAlignment: Qt.AlignHCenter
            text: "Messsage"
        }
        TextField {
            id: addFriendMessage
            selectByMouse: true
            font.pixelSize: 20
            leftPadding: 10
            rightPadding: leftPadding
            verticalAlignment: TextInput.AlignVCenter
            width: parent.width
            text: "Add me to your friends. Maybe?"
            maximumLength: 1016 // fixme
        }
        Text {
            id: friendRequestStatusText
            padding: 5
            font.bold: true
            width: parent.width
            horizontalAlignment: Qt.AlignHCenter
            text: ""
        }
        RowLayout {
            MenuItem {
                Layout.fillWidth: true
                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                }
                onTriggered: {
                    addFriendMenu.close()
                }
            }
            MenuItem {
                Layout.fillWidth: true
                Text {
                    anchors.centerIn: parent
                    text: "Send"
                }
                onTriggered: {
                    bridge.makeFriendRequest(toxId.text, addFriendMessage.text)
                }
            }
        }
    }

    ToolBar {
        id: overlayHeader

        z: z_overlay_header
        width: parent.width
        parent: window.overlay
        ToolButton {
            id: leftOverlayButton
            text: "\u2630"
            font.family: dejavuSans.name
            font.pointSize: 30
            font.bold: true
            onClicked: {
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
                rightOverlayHeaderButton.highlighted = false
            }

            MenuItem {
                text: qsTr("Copy My ToxID")
                onClicked: {
                    bridge.copyToxIdToClipboard()
                }
            }
            MenuItem {
                text: qsTr("Delete this friend")
                onClicked: {
                    bridge.clearFriendChatHistory(bridge.getCurrentFriendNumber())
                    bridge.deleteFriend(bridge.getCurrentFriendNumber())
                    for (var i = 0; i < friendsModel.count; i++) {
                        var friend = friendsModel.get(i)
                        if (friend.friendNumber === bridge.getCurrentFriendNumber()) {
                            friendsModel.remove(i)
                        }
                    }
                    selectFriend(friendsModel.get(0).friendNumber)
                }
            }
            MenuSeparator {}
            MenuItem {
                text: qsTr("Quit")
                onClicked: {
                    window.visible = false
                    Qt.quit()
                }
            }
        }
        ToolButton {
            id: rightOverlayHeaderButton
            text: "\u22EE"
            font.family: dejavuSans.name
            font.pointSize: 30
            font.bold: true
            onClicked: {
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
        }

        Label {
            id: friendNickname
            anchors.centerIn: parent
            property int charsLimit: 16
            text: limitString(bridge.getFriendNickname(bridge.getCurrentFriendNumber()), charsLimit)
        }
        Label {
            id: friendStatus
            anchors.top: friendNickname.bottom
            anchors.horizontalCenter: friendNickname.horizontalCenter
            font.pixelSize: 10
            font.italic: true
            property int charsLimit: 48
            text: limitString(bridge.getFriendStatusMessage(bridge.getCurrentFriendNumber()), charsLimit)
        }
    }

    Drawer {
        id: drawer

        // fixme: button overlaps with drawer. Qt bug?
        y: 0//overlayHeader.height
        width: window.width / 2
        height: window.height //- overlayHeader.height

        modal: inPortrait
        interactive: inPortrait
        position: inPortrait ? 0 : 1
        visible: !inPortrait
        dragMargin: 20
        z: z_drawer

        onOpened: {
            chatMessage.focus = false
        }
        onClosed: {
            leftOverlayButton.highlighted = false
        }

        ListModel {
            id: friendsModel
        }
        Flickable {
            id: friendsFlickable
            ColumnLayout {
                id: leftBarLayout
                    Repeater {
                        id: friends
                        model: friendsModel

                        delegate: RowLayout {
                            id: friendLayout
                            Rectangle {
                                id: friendItemStatusIndicator
                                color: "gray"
                                width: 15
                                height: width
                                border.color: "black"
                                border.width: 1
                                radius: width * 0.5
                                Layout.alignment: Qt.AlignLeft | Qt.AlignCenter
                                property int indicator_margin: 10
                                Layout.leftMargin: indicator_margin
                            }
                            function setFriendStatusIndicatorColor(color) {
                                friendItemStatusIndicator.color = color
                            }
                            ItemDelegate {
                                id: friendItem
                                text: nickName
                                property int friend_number: friendNumber
                                Layout.alignment: Qt.AlignCenter
                                implicitWidth: drawer.width - friendItemStatusIndicator.width - friendItemStatusIndicator.indicator_margin * 1.5
                                onClicked: {
                                    drawer.close()
                                    selectFriend(friend_number)
                                }
                            }
                        }
                    }
                }
            ScrollIndicator.vertical: ScrollIndicator { }
        }
        RowLayout {
            y: window.height - height
            ToolButton {
                id: addFriendButton
                text: "\uFF0B"
                font.family: dejavuSans.name
                font.pointSize: 30
                font.bold: true
                antialiasing: true
                onClicked: {
                    addFriendMenu.popup()
                }
            }
        }
    }
    ColumnLayout {
        anchors.fill: parent
        Flickable {
            id: chatFlickable

            // fixme: convert to Layout.
            anchors.fill: parent
            anchors.topMargin: overlayHeader.height
            anchors.bottomMargin: chatLayout.height + chatSeparator.separator_margin * 2 + chatSeparator.height
            anchors.leftMargin: !inPortrait ? drawer.width : undefined

            property int flickable_margin: 20
            topMargin: flickable_margin
            bottomMargin: flickable_margin
            contentHeight: chatContent.height
            clip: true
            boundsMovement: Flickable.StopAtBounds

            function scrollToEnd() {
                if (contentHeight > height)
                    contentY = contentHeight
                returnToBounds()
            }

            ColumnLayout {
                id: chatContent
                spacing: 20
                property int chat_margin: 15
                // fixme: convert to Layout.
                anchors.margins: chat_margin
                anchors.left: parent.left
                anchors.right: parent.right
                ListModel {
                    id: messagesModel
                }
                Repeater {
                    id: messages
                    model: messagesModel
                    delegate: Rectangle {
                        id: messageCloud
                        property int cloud_margin: 5
                        color: !msgSelf ? "lightblue" : "lightgray"
                        radius: 10
                        function setCloudColor(newColor) {
                            color = newColor
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


                        Component.onCompleted: {
                            if (cloudText.width > window.width - cloud_margin -  chatContent.chat_margin)
                                Layout.maximumWidth = window.width - cloud_margin - chatContent.chat_margin
                            if (msgSelf)
                                anchors.right = parent.right
                        }

                        Text {
                            id: cloudText
                            text: msgText
                            anchors.fill: parent
                            anchors.margins: parent.cloud_margin
                            font.family: "Helvetica"
                            font.pointSize: 20
                            onContentHeightChanged: {
                                parent.implicitHeight = contentHeight + parent.cloud_margin * 2
                                parent.implicitWidth = contentWidth + parent.cloud_margin * 2
                            }
                            wrapMode: Text.Wrap
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
                        Text {
                            id: failedText
                            text: "!"
                            color: "red"
                            font.pointSize: 20
                            font.bold: true
                            visible: msgFailed
                            anchors.right: parent.left
                        }
                        MouseArea {
                            id: cloudMouseArea
                            anchors.fill: parent
                            onClicked: {
                                bridge.copyTextToClipboard(cloudText.text)
                            }
                        }
                    }
                }
                Text {
                    id: typingText
                    font.italic: true
                    visible: false
                    Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
                }
            }
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        Rectangle {
            id: chatSeparator
            width: window.width
            height: 1
            color: "gray"
            anchors.left: parent.left
            anchors.bottom: chatLayout.top
            property int separator_margin: 5
            anchors.bottomMargin: separator_margin
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
                onAccepted: send.sendMessage()
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
                background: Rectangle {
                    implicitWidth: chatMessage.height * 0.75
                    implicitHeight: implicitWidth
                    visible: false
                }
                function sendMessage() {
                    if (chatMessage.text.length > 0) {
                        bridge.sendMessage(chatMessage.text)
                        chatMessage.text = ""
                    }
                }
                Image {
                    id: send_arrow
                    anchors.fill: parent
                    source: "send-button.png"
                    smooth: true
                    antialiasing: true
                }
                onPressed: sendMessage()
            }
        }
    }

    onClosing: {
        close.accepted = false
    }

    Component.onCompleted: {
        initTimer.start()
    }

}
