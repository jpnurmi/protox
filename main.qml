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

ApplicationWindow {
    id: window
    width: 360
    height: 520
    visible: true

    /*
      Window events
    */
    property bool _inPortrait: inPortrait
    on_InPortraitChanged: {
        drawer.width = width * 0.5 * (!inPortrait ? (Screen.height / Screen.width) : 1.0)
        for (var i = 0; i < messagesModel.count; i++) {
            messages.itemAt(i).calculateMaximumWidth()
        }
    }

    onClosing: {
        close.accepted = false
    }

    Connections {
        target: Qt.application
        onStateChanged: {
            if (splashImageDestroyAnimation !== null) {
                splashImageDestroyAnimation.start()
            }
            // select friend when you click on notification
            if(Qt.application.state === Qt.ApplicationActive && notification.getNotificationId() !== -1) {
                selectFriend(notification.getNotificationId(true))
            }
        }
    }

    Component.onCompleted: {
        initTimer.start()
    }

    Timer {
        id: initTimer
        repeat: false
        interval: 1
        onTriggered: {
            bridge.retrieveChatLog()
            chatFlickable.scrollToEnd()
            destroy()
        }
    }

    /*
      Splash image
    */

    Image {
        id: splashImage
        source: "splash.png"
        anchors.fill: parent
        z: z_splash
        cache: true
        NumberAnimation on opacity {
            id: splashImageDestroyAnimation
            to: 0
            duration: 200
            running: false
            onRunningChanged: {
                 if (!running) {
                     splashImage.destroy()
                 }
            }
        }
    }

    Text {
        id: welcomeTextTitle
        x: (window.width - width) / 2
        text: qsTr("Welcome to Protox!")
        font.bold: true
        font.pointSize: 32
        anchors.top: overlayHeader.bottom
        anchors.topMargin: 40
        visible: clean_profile
    }

    Text {
        id: welcomeText
        text: qsTr("This is alpha version of a tox client.\nClick on «\u2630» to open contact menu and on «\uFF0B» to add a new friend.\n\n Good luck!")
        wrapMode: Text.Wrap
        anchors.top: welcomeTextTitle.bottom
        anchors.topMargin: 20
        visible: clean_profile
        width: window.width
        horizontalAlignment: Text.AlignHCenter
    }

    /*
      Basic elements
    */

    Notification {
        id: notification
    }

    StatusBar {
        id: statusBar
        theme: Material.Dark
        color: Material.toolBarColor
    }

    Toast {
        id: toast
    }

    FontLoader { 
        id: dejavuSans; 
        source: "DejaVuSans.ttf"
    }

    // global properties
    property bool clean_profile: bridge.getFriendsCount() === 0

    // global properties (static)
    readonly property bool inPortrait: window.width < window.height
    readonly property int z_cloud: -1
    readonly property int z_friend_item_background: 0
    readonly property int z_friend_item: 1
    readonly property int z_drawer: 2
    readonly property int z_overlay_header: 1
    readonly property int z_menu: 3
    readonly property int z_menu_elements: 4
    readonly property int z_splash: Number.MAX_VALUE

    /*
      Functions
    */

    function checkLastMessage(friend_number) {
        return bridge.getMessagesCount(friend_number) === messagesModel.get(messagesModel.count - 1).msgUniqueId
    }

    function limitString(str, limit) {
        if (str.length > limit) {
            return str.slice(0, limit) + "..."
        }
        return str
    }

    function clearChatContent() {
        messagesModel.clear()
    }

    function getFriendsModelOrder() {
        var order = [];
        for (var i = 0; i < friendsModel.count; i++) {
            if (friendsModel.get(i).request) {
                continue
            }
            order[i] = friendsModel.get(i).friendNumber;
        }
        return order
    }

    // function callbacks
    function setFriendStatus(friend_number, status) {
        var color;
        switch (status) {
        case 0: color = "lightgreen"; break;
        case 1: color = "yellow"; break;
        case 2: color = "red"; break;
        }
        if (bridge.getCurrentFriendNumber() === friend_number) {
            friendStatusIndicator.color = color;
        }

        for (var i = 0; i < friendsModel.count; i++) {
            var friend = friendsModel.get(i)
            if (friend.friendNumber === friend_number) {
                friends.itemAt(i).setFriendStatusIndicatorColor(color)
            }
        }
    }

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
        chatFlickable.scrollToEndVK()
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
            case 0:
                toast.show({ message : qsTr("Request sent!"), duration : Toast.Short }); 
                addFriendMenu.close();
                toxId.clear()
                addFriendMessage.clear()
                break;
            case 4: msg = qsTr("You cannot send a friend request to yourself."); break;
            case 5: msg = qsTr("The friend is already on the friend list."); break;
            case 6: msg = qsTr("The friend address is invalid."); break;
            case 7: msg = qsTr("The friend has a different nospam value."); break;
            default: msg = qsTr("Failed! error code: ") + status.toString(); break;
            }
            friendRequestStatusText.color = color
            friendRequestStatusText.text = msg
        }
    }

    function chatScrollToEnd() {
        chatFlickable.scrollToEnd()
    }

    property variant each_friend_text: []
    function selectFriend(friend_number) {
        if (bridge.getCurrentFriendNumber() === friend_number && checkLastMessage(friend_number)) {
            return
        }
        notification.cancel(friend_number)
        dropTypingTimer.stop()
        bridge.setTypingFriend(bridge.getCurrentFriendNumber(), false)
        each_friend_text[bridge.getCurrentFriendNumber()] = chatMessage.text
        bridge.setCurrentFriend(friend_number)
        friendNickname.text = limitString(bridge.getFriendNickname(bridge.getCurrentFriendNumber()), friendNickname.charsLimit)
        friendStatus.text = limitString(bridge.getFriendStatusMessage(bridge.getCurrentFriendNumber()), friendStatus.charsLimit)
        setCurrentFriendConnStatus(friend_number, bridge.getFriendConnStatus(friend_number))
        bridge.retrieveChatLog()
        chatScrollToEnd()
        chatMessage.clear()
        if (each_friend_text[friend_number] !== undefined) {
            chatMessage.text = each_friend_text[friend_number]
        } 
    }

    function insertMessage(text, friend_number, self, message_id, time, unique_id, failed, history) {

        if (!self && !history && (Application.state === Qt.ApplicationHidden || (Application.state !== Qt.ApplicationHidden 
                                                      && bridge.getCurrentFriendNumber() !== friend_number))) {
            notification.show({
                              caption : text,
                              title : qsTr("New message from ") + bridge.getFriendNickname(friend_number),
                              id : friend_number
                            });
        }
        if (bridge.getCurrentFriendNumber() !== friend_number) {
            return
        }
        if (!history && messagesModel.count > 0 && !checkLastMessage(friend_number)) {
            return
        }
        messagesModel.append({"msgText": text, 
                                 "msgSelf" : self, 
                                 "msgReceived" : false, 
                                 "msgId" : message_id, 
                                 "msgTime" : time, 
                                 "msgUniqueId" : unique_id,
                                 "msgFailed" : failed})
        if (!history)
            chatFlickable.scrollToEndVK()
    }
    function insertFriend(friend_number, nickName, request, request_message, friendPk) {
        friendsModel.append({"friendNumber" : friend_number, "nickName" : nickName, "request" : request, "request_message" : request_message, "friendPk" : friendPk})
        if (!request) {
            clean_profile = bridge.getFriendsCount() === 0
        } 
        if (request && (Application.state === Qt.ApplicationHidden || !drawer.opened)) {
            notification.show({
                              caption : request_message,
                              title : qsTr("A new friend request from ") + nickName,
                              id : -1
                            });
            leftOverlayButtonTextAnimation.start()
        }
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

    function setConnStatus(conn_status) {
        var text, color;
        switch (conn_status) {
        case 0: text = qsTr("Connection lost"); color = "red"; break;
        case 1: text = qsTr("Connected (TCP)"); color = "green"; break;
        case 2: text = qsTr("Connected (UDP)"); color = "green"; break;
        }
        connectionStatus.text = text;
        connectionStatus.color = color;
    }

    /*
        Image buffers
    */

    Repeater {
        id: canvasBuffer
        model: ["lightgray", "orange", "lightblue"]
        delegate: Image { 
            id: cloudTailImageFrameBuffer 
            visible: false
            cache: true
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
        QRCode capture & decoding
    */

    /*
    Menu {
        id: qrScannerMenu
        z: z_splash
        width: window.width
        height: window.height
        Camera{
            id: camera
        }
        Rectangle {
            anchors.fill: parent
            VideoOutput {
                source: camera
                anchors.fill: parent
                focus : visible
            }
        }


    }


    QZXing {
        id: qrDecoder
        enabledDecoders: QZXing.DecoderFormat_QR_COD
        onDecodingStarted: console.log("Decoding of image started...")
        onTagFound: console.log("Barcode data: " + tag)
        onDecodingFinished: console.log("Decoding finished " + (succeeded==true ? "successfully" :    "unsuccessfully") )
    }
        */

    /*
        Add friend menu
    */
    Menu {
        id: addFriendMenu
        width: 300
        title: qsTr("Add a new friend")
        x: (window.width - width) * 0.5
        y: (window.height - height) * 0.5
        z: z_menu
        modal: true
        onClosed: {
            currentIndex = -1
            toxId.focus = false
            addFriendMessage.focus = false
            friendRequestStatusText.text = ""
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
        /*
        Button {
            text: qsTr("Scan QRCode")
            onClicked: {
                qrScannerMenu.popup()
            }
        }
        */
        Text {
            padding: 10
            font.bold: true
            width: parent.width
            horizontalAlignment: Qt.AlignHCenter
            text: qsTr("Messsage")
        }
        TextField {
            id: addFriendMessage
            selectByMouse: true
            font.pixelSize: 20
            leftPadding: 10
            rightPadding: leftPadding
            verticalAlignment: TextInput.AlignVCenter
            width: parent.width
            placeholderText: qsTr("Add me to your friends. Maybe?")
        }
        Text {
            id: friendRequestStatusText
            padding: 5
            font.bold: true
            font.pointSize: 15
            width: parent.width
            horizontalAlignment: Qt.AlignHCenter
            text: ""
        }
        RowLayout {
            MenuItem {
                Layout.fillWidth: true
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Cancel")
                }
                onTriggered: {
                    addFriendMenu.close()
                }
            }
            MenuItem {
                Layout.fillWidth: true
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Send")
                }
                onTriggered: {
                    if (bridge.getConnStatus() < 1) {
                        toast.show({ message : qsTr("You are not connected to the tox network."), duration : Toast.Short });
                        return
                    }
                    var toxId_text = toxId.text
                    if(toxId_text.substring(0, 4) === "tox:") {
                        toxId_text = toxId_text.slice(4, toxId_text.length())
                    }
                    bridge.makeFriendRequest(toxId_text.toUpperCase(), 
                                             addFriendMessage.text.length > 0 ? addFriendMessage.text : addFriendMessage.placeholderText)
                }
            }
        }
    }

    /*
        Profile menu
    */
    Menu {
        id: profileMenu
        width: 300
        title: "My profile"
        x: (window.width - width) * 0.5
        y: (window.height - height) * 0.5
        z: z_menu
        modal: true
        onClosed: {
            currentIndex = -1
            myNickname.focus = false
            myStatus.focus = false
            myNickname.text = bridge.getNickname(false)
            myStatus.text = bridge.getStatusMessage()
        }

        Text {
            padding: 10
            font.bold: true
            width: parent.width
            horizontalAlignment: Qt.AlignHCenter
            text: qsTr("Nickname")
        }
        TextField {
            id: myNickname
            selectByMouse: true
            font.pixelSize: 20
            leftPadding: 10
            rightPadding: leftPadding
            verticalAlignment: TextInput.AlignVCenter
            width: parent.width
            text: bridge.getNickname(false)
        }
        Text {
            padding: 10
            font.bold: true
            width: parent.width
            horizontalAlignment: Qt.AlignHCenter
            text: qsTr("Status")
        }
        TextField {
            id: myStatus
            selectByMouse: true
            font.pixelSize: 20
            leftPadding: 10
            rightPadding: leftPadding
            verticalAlignment: TextInput.AlignVCenter
            width: parent.width
            text: bridge.getStatusMessage()
        }
        RowLayout {
            MenuItem {
                Layout.fillWidth: true
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Cancel")
                }
                onTriggered: {
                    profileMenu.close()
                }
            }
            MenuItem {
                Layout.fillWidth: true
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Apply")
                }
                onTriggered: {
                    bridge.setNickname(myNickname.text)
                    accountName.text = bridge.getNickname(true)
                    bridge.setStatusMessage(myStatus.text)
                    profileMenu.close()
                }
            }
        }
    }

    /*
      Profile info menu
    */

    Menu {
        id: profileInfoMenu
        width: 300
        title: qsTr("My profile info")
        x: (window.width - width) * 0.5
        y: (window.height - height) * 0.5
        z: z_menu
        modal: true
        Image {
            id: toxIDQRCodeImage
            anchors.centerIn: parent
            source: "image://QZXing/encode/" + "tox:" + bridge.getToxId() +
                    "?correctionLevel=M" +
                    "&format=qrcode"
            sourceSize.width: 196
            sourceSize.height: 196
            cache: false
            width: 196
            height: width
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    bridge.copyTextToClipboard(bridge.getToxId())
                    toast.show({ message : qsTr("ToxID copied!"), duration : Toast.Short });
                }
            }
        }
        Text {
            id: toxIDHelperText
            horizontalAlignment: Qt.AlignHCenter
            text: qsTr("Click on image to copy your ToxID.")
        }
}

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
                text: "\u2630"
                font.family: dejavuSans.name
                font.pointSize: 30
                font.bold: true
                x: contentWidth * 0.35
                y: contentHeight * 0.2
                
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
                rightOverlayHeaderButton.highlighted = false
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
                    toast.show({ message : qsTr("Friend removed!"), duration : Toast.Short });
                    clean_profile = bridge.getFriendsCount() === 0
                    if (friendsModel.count > 0) {
                        selectFriend(friendsModel.get(0).friendNumber)
                    } else {
                        friendNickname.text = ""
                        friendStatus.text = ""
                    }
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
            visible: !clean_profile
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

    MessageDialog {
        id: addFriendDialog
        title: qsTr("A new friend request")
        icon: StandardIcon.Question
        standardButtons: StandardButton.Yes | StandardButton.No | StandardButton.Close
        visible: false
        property int item_index: -1
        property variant friendPk: ""
        onYes: {
            friendsModel.remove(item_index)
            bridge.addFriend(friendPk)
        }
        onNo: {
            friendsModel.remove(item_index)
        }
    }

    /*
      Left menu (drawer)
     */

    Drawer {
        id: drawer

        y: 0
        width: window.width * 0.5
        height: window.height

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
            function swap(slot1, slot2) {
                var min = Math.min(slot1, slot2);
                var max = Math.max(slot1, slot2);
                move(min, max, 1);
                move(max - 1, min, 1);
            }
        }
        Item {
            anchors.fill: parent
            ColumnLayout {
                id: leftBarLayout
                RowLayout {
                    id: accountLayout
                    Layout.alignment: Qt.AlignTop
                    ItemDelegate {
                        id: accountName
                        text: bridge.getNickname(true)
                        font.pointSize: 12
                        font.bold: true
                        Layout.alignment: Qt.AlignLeft
                        implicitWidth: drawer.width * 0.6
                        onClicked: {
                            profileMenu.open()
                        }
                    }
                    Menu {
                        id: accountStatusMenu
                        z: z_menu_elements
                        implicitWidth: 100
                        Repeater {
                            model: [[qsTr("Online"), "lightgreen"],[qsTr("Away"), "yellow"],[qsTr("Busy"), "red"],[qsTr("Offline"), "gray"]]
                            delegate: MenuItem {
                                text: modelData[0]
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: modelData[1]
                                    width: 15
                                    height: width
                                    border.color: "black"
                                    border.width: 1
                                    radius: width * 0.5
                                }
                                onClicked: {
                                    if (index < 3) {
                                        bridge.setStatus(index)
                                    }
                                    statusIndicator.setStatus(index)
                                    bridge.changeConnection(index != 3)
                                }
                            }
                        }
                        onClosed: {
                            currentIndex = -1
                        }
                    }
                    Button {
                        id: accountStatus
                        Layout.alignment: Qt.AlignRight
                        Rectangle {
                            id: statusIndicator
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 15
                            height: width
                            border.color: "black"
                            border.width: 1
                            radius: width * 0.5
                            property int index: -1
                            function setStatus(status) {
                                switch (status) {
                                case 0: color = "lightgreen"; break;
                                case 1: color = "yellow"; break;
                                case 2: color = "red"; break;
                                case 3: color = "gray"; break;
                                }
                                index = status
                            }
                            Component.onCompleted: {
                                setStatus(bridge.getStatus())
                            }
                        }
                        Text {
                            text: "\u25BC"
                            font.pointSize: 10
                            anchors.left: statusIndicator.right
                            anchors.leftMargin: 20
                            anchors.verticalCenter: statusIndicator.verticalCenter
                        }
                        onPressed: {
                            accountStatusMenu.currentIndex = statusIndicator.index
                            accountStatusMenu.popup(accountStatus.x, accountStatus.y + accountStatus.height)
                        }
                    }
                }
                Text {
                    id: connectionStatus
                    text: qsTr("Bootstrapping...")
                    color: "orange"
                    font.italic: true
                    font.pointSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }
                MenuSeparator { 
                    id: drawerSeparator
                    implicitWidth: drawer.width 
                }
                property int draggedItem: -1
                Flickable {
                    id: friendsFlickable
                    anchors.top: drawerSeparator.bottom
                    ScrollIndicator.vertical: ScrollIndicator { }
                    contentHeight: 100
                    ColumnLayout  {
                        anchors.top: parent.top
                        spacing: 1
                        Repeater {
                            id: friends
                            model: friendsModel
                            delegate: RowLayout {
                                id: friendLayout
                                property bool dragEntered: false
                                property bool dragStarted: false
                                property int default_x
                                property int default_y
                                function savePosition() {
                                    default_x = x
                                    default_y = y
                                }
                                Component.onCompleted: {
                                    savePosition()
                                }
                                function resetPosition() {
                                    x = default_x
                                    y = default_y
                                }

                                property int animation_duration: 200
                                Behavior on x {
                                    id: friendItemAnimationXBehavior
                                    enabled: false
                                    NumberAnimation {
                                        duration: friendLayout.animation_duration
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on y {
                                    id: friendItemAnimationYBehavior
                                    enabled: false
                                    NumberAnimation {
                                        duration: friendLayout.animation_duration
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Drag.dragType: Drag.Automatic
                                property bool dragActive: friendDragArea.drag.active
                                onDragActiveChanged: {
                                    if (dragActive) {
                                        friendItemAnimationXBehavior.enabled = true
                                        friendItemAnimationYBehavior.enabled = true
                                        savePosition()
                                        leftBarLayout.draggedItem = index
                                        dragStarted = true
                                        Drag.start()
                                    } else {
                                        if (Drag.target !== null) {
                                            friendItemAnimationXBehavior.enabled = false
                                            friendItemAnimationYBehavior.enabled = false
                                        }
                                        Drag.drop()
                                        if (dragStarted) {
                                            resetPosition()
                                            dragStarted = false
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    id: friendItemStatusIndicatorBody
                                    z: -1
                                    width: parent.height
                                    height: parent.height
                                    Layout.alignment: Qt.AlignLeft
                                    color: parent.dragEntered ? "lightgray" : "#00000000"
                                    visible: !request
                                    Component.onCompleted: {
                                        if (request) {
                                            width = height = 0
                                        }
                                    }
                                    MouseArea {
                                        id: friendDragArea
                                        anchors.fill: parent
                                        drag.target: friendLayout
                                    }
                                    Rectangle {
                                        id: friendItemStatusIndicator
                                        color: "gray"
                                        width: 15
                                        height: width
                                        border.color: "black"
                                        border.width: 1
                                        radius: width * 0.5
                                        anchors.centerIn: parent
                                        visible: parent.visible
                                    }
                                }
                                
                                function setFriendStatusIndicatorColor(color) {
                                    friendItemStatusIndicator.color = color
                                }
                                ItemDelegate {
                                    id: friendItem
                                    background.z: z_friend_item
                                    z: z_friend_item
                                    text: nickName
                                    property int friend_number: friendNumber
                                    Layout.alignment: Qt.AlignCenter
                                    Layout.leftMargin: friendItemStatusIndicatorBody.width
                                    onClicked: {
                                        if (request) {
                                            if (request_message.length > 0) {
                                                addFriendDialog.text = request_message
                                            } else {
                                                addFriendMessage.text = qsTr("(no request message specified)")
                                            }
                                            addFriendDialog.friendPk = friendPk
                                            addFriendDialog.item_index = index
                                            addFriendDialog.open()
                                            return
                                        }
                                        if (inPortrait) {
                                            drawer.close()
                                        }
                                        selectFriend(friend_number)
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: request ? "lightgreen" : "lightgray"
                                        visible: request || parent.parent.dragEntered
                                        z: z_friend_item_background
                                    }
                                    Component.onCompleted: {
                                        implicitWidth = drawer.width
                                        if (!request) {
                                            implicitWidth -= friendItemStatusIndicatorBody.width
                                        }
                                    }
                                    DropArea {
                                        anchors.fill: parent
                                        onEntered: {
                                            if (!request) {
                                                parent.parent.dragEntered = true
                                            }
                                        }
                                        onExited: {
                                            if (!request) {
                                                parent.parent.dragEntered = false
                                            }
                                        }
                                        onDropped: {
                                            if (!request) {
                                                parent.parent.dragEntered = false
                                                friendsModel.get(leftBarLayout.draggedItem).dragStarted = false
                                                friendsModel.swap(index, leftBarLayout.draggedItem)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        RowLayout {
            id: controlsLayout
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
            ToolButton {
                id: showMyInfoButton
                text: "\u2302"
                font.family: dejavuSans.name
                font.pointSize: 30
                font.bold: true
                antialiasing: true
                onClicked: {
                    profileInfoMenu.popup()
                }
            }
        }
    }
    Rectangle {
        id: prevPageButton
        z: 9999
        width: 50
        height: width
        radius: width * 0.5
        color: "white"
        property real alpha: 0.9
        opacity: alpha
        anchors.top: overlayHeader.bottom
        anchors.topMargin: 15
        anchors.horizontalCenter: overlayHeader.horizontalCenter
        visible: messagesModel.count > 0 && messagesModel.count < bridge.getMessagesCount(bridge.getCurrentFriendNumber()) && (checkLastMessage(bridge.getCurrentFriendNumber()) || messagesModel.get(0).msgUniqueId > 1) && chatFlickable.contentY === -chatFlickable.flickable_margin
        Timer {
            id: prevPageButtonFadeOutAnimationTimer
            repeat: false
            interval: 2000
            onTriggered: {
                prevPageButtonFadeOutAnimation.start()
            }
        }
        NumberAnimation on opacity {
            id: prevPageButtonFadeOutAnimation
            to: 0
            duration: 500
            running: false
        }
        onVisibleChanged: {
            if (visible) {
                prevPageButtonFadeOutAnimation.stop()
                prevPageButtonFadeOutAnimationTimer.stop()
                opacity = alpha
                prevPageButtonFadeOutAnimationTimer.start()
            }
        }
        Text {
            id: prevPageButtonText
            text: "\u2191"
            font.bold: true
            font.pointSize: 30
            opacity: parent.opacity
            anchors.centerIn: parent
        }

        MouseArea {
            anchors.fill: parent
            enabled: parent.opacity > 0
            onPressed: {
                prevPageButtonFadeOutAnimationTimer.stop()
                prevPageButtonFadeOutAnimation.stop()
                parent.opacity = parent.alpha
                var from = messagesModel.get(0).msgUniqueId
                bridge.retrieveChatLog(from, true, true)
                chatScrollToEnd()
                prevPageButtonFadeOutAnimationTimer.start()
            }
        }
    }
    DropShadow {
        anchors.fill: prevPageButton
        visible: prevPageButton.visible
        opacity: prevPageButton.opacity
        radius: 8.0
        samples: 16
        color: "#80000000"
        source: prevPageButton
    }
    Rectangle {
        id: nextPageButton
        z: 9999
        width: 50
        height: width
        radius: width * 0.5
        color: "white"
        property real alpha: 0.9
        property int bottomMargin: 15
        opacity: alpha
        x: prevPageButton.x
        y: chatSeparator.y - height - bottomMargin
        visible: messagesModel.count > 0 && (chatFlickable.checkAtEnd() || (messagesModel.get(0).msgUniqueId === 1 && !chatFlickable.checkExceedsHeight())) && !checkLastMessage(bridge.getCurrentFriendNumber())
        Timer {
            id: nextPageButtonFadeOutAnimationTimer
            repeat: false
            interval: 2000
            onTriggered: {
                nextPageButtonFadeOutAnimation.start()
            }
        }
        NumberAnimation on opacity {
            id: nextPageButtonFadeOutAnimation
            to: 0
            duration: 500
            running: false
        }
        onVisibleChanged: {
            if (visible) {
                nextPageButtonFadeOutAnimation.stop()
                nextPageButtonFadeOutAnimationTimer.stop()
                opacity = alpha
                if (chatFlickable.checkExceedsHeight()) {
                    nextPageButtonFadeOutAnimationTimer.start()
                }
            }
        }
        Text {
            id: nextPageButtonText
            text: "\u2193"
            font.bold: true
            font.pointSize: 30
            opacity: parent.opacity
            anchors.centerIn: parent
        }

        MouseArea {
            anchors.fill: parent
            enabled: parent.opacity > 0
            onPressed: {
                nextPageButtonFadeOutAnimationTimer.stop()
                nextPageButtonFadeOutAnimation.stop()
                parent.opacity = parent.alpha
                var from = messagesModel.get(messagesModel.count - 1).msgUniqueId
                bridge.retrieveChatLog(from, false)
                chatFlickable.scrollToStart()
                nextPageButtonFadeOutAnimationTimer.start()
            }
        }
    }
    DropShadow {
        anchors.fill: nextPageButton
        visible: nextPageButton.visible
        opacity: nextPageButton.opacity
        radius: 8.0
        samples: 16
        color: "#80000000"
        source: nextPageButton
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: !inPortrait ? drawer.width : undefined
        Flickable {
            id: chatFlickable

            // fixme: convert to Layout.
            anchors.fill: parent
            anchors.topMargin: overlayHeader.height
            anchors.bottomMargin: chatLayout.height + chatSeparator.separator_margin * 2 + chatSeparator.height

            property int flickable_margin: 20
            topMargin: flickable_margin
            bottomMargin: flickable_margin
            contentHeight: chatContent.height
            clip: true
            boundsMovement: Flickable.StopAtBounds

            function checkAtEnd() {
                return contentHeight - height - contentY === -flickable_margin
            }
            function checkExceedsHeight() {
                return contentHeight > height
            }
            function scrollToStart() {
                contentY = -flickable_margin
            }

            function scrollToEnd() {
                if (checkExceedsHeight())
                    contentY = contentHeight
                returnToBounds()
            }
            function scrollToEndVK() {
                if (virtualKeyboard.keyboardActive && !checkExceedsHeight()) {
                    scrollToEnd()
                    boundsMovement = Flickable.DragOverBounds
                    contentY -= virtualKeyboard.keyboardHeight - chatLayout.height - chatSeparator.height - chatContent.cloud_margin
                    if (contentHeight > virtualKeyboard.keyboardHeight + chatLayout.height + chatSeparator.height - (flickable_margin + chatSeparator.separator_margin)) {
                        contentY += contentHeight - (virtualKeyboard.keyboardHeight + chatLayout.height + chatSeparator.height) + flickable_margin + chatSeparator.separator_margin
                    }
                } else {
                    boundsMovement = Flickable.StopAtBounds
                    scrollToEnd()
                }
            }

            ColumnLayout {
                id: chatContent
                spacing: 20
                property int chat_margin: 15
                property int cloud_margin: 5
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

                        function calculateMaximumWidth() {
                            if (cloudText.width > window.width - chatContent.cloud_margin -  chatContent.chat_margin - (!inPortrait ? drawer.width : 0))
                                Layout.maximumWidth = window.width - chatContent.cloud_margin - chatContent.chat_margin - (!inPortrait ? drawer.width : 0)
                        }

                        Component.onCompleted: {
                            calculateMaximumWidth()
                            if (msgSelf)
                                anchors.right = parent.right
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
                            font.pointSize: 20
                            onContentHeightChanged: {
                                parent.implicitHeight = contentHeight + chatContent.cloud_margin * 2
                                parent.implicitWidth = contentWidth + chatContent.cloud_margin * 2
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
                Text {
                    id: typingText
                    font.italic: true
                    visible: false
                    Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
                    Layout.fillHeight: true
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
            visible: !clean_profile
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
                visible: !clean_profile
                Item {
                    id: virtualKeyboard
                    property int keyboardHeight: 0
                    property bool keyboardActive: false
                    onKeyboardActiveChanged: {
                        chatFlickable.interactive = !keyboardActive
                        chatFlickable.scrollToEndVK()
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
                visible: !clean_profile
                background: Rectangle {
                    implicitWidth: chatMessage.height * 0.75
                    implicitHeight: implicitWidth
                    visible: false
                }
                function sendMessage() {
                    if (chatMessage.text.length > 0) {
                        if (!checkLastMessage(bridge.getCurrentFriendNumber())) {
                            bridge.retrieveChatLog()
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
}
