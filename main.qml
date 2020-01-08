import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2

import QtQuick.Layouts 1.3

import QtQuick.Window 2.12

ApplicationWindow {
    id: window
    width: 360
    height: 520
    visible: true
    title: qsTr("Side Panel")

    FontLoader { 
        id: dejavuSans; 
        source: "DejaVuSans.ttf"
    }
    readonly property bool inPortrait: window.width < window.height

    // global properties
    readonly property int z_cloud: -1
    readonly property int z_drawer: 2
    readonly property int z_overlay_header: 1

    // function callbacks
    function insertMessage(text, friend_number, self, message_id, time, unique_id, failed) {
        if (bridge.getCurrentFriendNumber() !== friend_number)
            return
        messagesModel.append({"msgText": text, 
                                 "msgSelf" : self, 
                                 "msgReceived" : false, 
                                 "msgId" : message_id, 
                                 "msgTime" : time, 
                                 "msgUniqueId" : unique_id,
                                 "msgFailed" : failed})
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
            onClicked: {
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
                text: qsTr("Copy ToxID")
                onClicked: {
                    bridge.copyToxIdToClipboard()
                }
            }
            MenuItem {
                text: qsTr("Test action")
                onClicked: {
                }
            }
            MenuItem {
                text: qsTr("Quit")
                onClicked: {
                    Qt.quit()
                }
            }
        }
        ToolButton {
            id: rightOverlayHeaderButton
            text: "\u22EE"
            font.family: dejavuSans.name
            font.pointSize: 30

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
            text: bridge.getFriendNickname(bridge.getCurrentFriendNumber())
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
                                    if (bridge.getCurrentFriendNumber() === friend_number) {
                                        return
                                    }
                                    bridge.setCurrentFriend(friend_number)
                                    friendNickname.text = bridge.getFriendNickname(friend_number)
                                    setCurrentFriendConnStatus(friend_number, bridge.getFriendConnStatus(friend_number))
                                    messagesModel.clear()
                                    bridge.retrieveChatLog()
                                }
                            }
                        }
                    }
                }
            ScrollIndicator.vertical: ScrollIndicator { }
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
                //contentY = contentHeight - flickable_margin
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
                        visible: false
                        function setCloudColor(newColor) {
                            color = newColor
                            cloudCornerRemover.color = newColor
                            cloudCornerRemover.requestPaint()
                            cloudTail.color = newColor
                            cloudTail.requestPaint()
                        }

                        Canvas {
                            id: cloudCornerRemover
                            z: z_cloud
                            width: parent.radius
                            height: width
                            renderStrategy: Canvas.Cooperative
                            property variant color: parent.color
                            Component.onCompleted: {
                                if (msgSelf)
                                    anchors.right = parent.right
                            }
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.fillStyle = color
                                ctx.fillRect(0, 0, width, height);
                            }
                        }
                        Canvas {
                            id: cloudTail
                            width: 10
                            height: width
                            property variant color: parent.color
                            renderStrategy: Canvas.Cooperative
                            Component.onCompleted: {
                                x = x - width
                                if (msgSelf)
                                    anchors.left = parent.right
                            }
                            onPaint: {
                                var cxt = getContext("2d");
                                cxt.beginPath();
                                cxt.moveTo(0, 0);
                                if (msgSelf) {
                                    cxt.lineTo(0, height);
                                    cxt.lineTo(width, 0);
                                } else {
                                    cxt.lineTo(width, 0);
                                    cxt.lineTo(width, height);
                                }
                                cxt.closePath();
                                cxt.fillStyle = color;
                                cxt.fill();
                            }
                            onPainted: {
                                parent.visible = true
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
                                //parent.implicitWidth = Math.max(parent.implicitWidth, contentWidth)
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
                    }
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

    Keys.onPressed: {
        if (event.key === Qt.Key_Back) {
            Qt.quit()
        }
    }
    Component.onCompleted: {
        chatFlickable.scrollToEnd()
    }
}
