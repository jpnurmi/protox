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
        var friend_number = bridge.getCurrentFriendNumber()
        drawer.width = width * 0.5 * (!inPortrait ? (Screen.height / Screen.width) : 1.0)
        friendNickname.setText(bridge.getFriendNickname(friend_number))
        friendStatus.setText(bridge.getFriendStatusMessage(friend_number))
    }

    onClosing: {
        close.accepted = false
    }

    property bool appInactive
    Connections {
        target: Qt.application
        onStateChanged: {
            if (bridge.getConnStatus() < 1) {
                bridge.bootstrapDHT()
                connectionStatus.text = qsTr("Bootstrapping...")
            }
            if (splashImageDestroyAnimation !== null) {
                statusBar.theme = Material.Dark
                statusBar.color = Material.toolBarColor
                splashImageDestroyAnimation.start()
            }
            // select friend when you click on notification
            if(Qt.application.state === Qt.ApplicationActive && notification.getNotificationId() !== -1) {
                selectFriend(notification.getNotificationId(true))
            }
            appInactive = Qt.application.state === Qt.ApplicationSuspended
        }
    }

    Component.onCompleted: {
        cleanProfile = bridge.getFriendsCount() < 1
        initTimer.start()
    }

    Timer {
        id: initTimer
        repeat: false
        interval: 1
        onTriggered: {
            bridge.retrieveChatLog()
            messages.scrollToEnd()
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
        visible: cleanProfile
    }

    Text {
        id: welcomeText
        text: qsTr("This is alpha version of a tox client.\nClick on «\u2630» to open contact menu and on «\uFF0B» to add a new friend.\n\n Good luck!")
        wrapMode: Text.Wrap
        anchors.top: welcomeTextTitle.bottom
        anchors.topMargin: 20
        visible: cleanProfile
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
    }

    Toast {
        id: toast
    }

    FontLoader { 
        id: dejavuSans; 
        source: "DejaVuSans.ttf"
    }

    // global properties
    property bool cleanProfile

    // global properties (static)
    readonly property bool inPortrait: window.width < window.height
    readonly property int z_cloud: -1
    readonly property int z_friend_item_background: 0
    readonly property int z_friend_item: 1
    readonly property int z_drawer: 2
    readonly property int z_overlay_header: 1
    readonly property int z_menu: 3
    readonly property int z_menu_elements: 4
    readonly property int z_top: Number.MAX_VALUE-1
    readonly property int z_splash: Number.MAX_VALUE

    //include: functions.qml

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
            onAccepted: {
                focus = false
                addFriendMessage.focus = true
            }
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
            onAccepted: {
                focus = false
                sendItem.send()
            }
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
                id: sendItem
                Layout.fillWidth: true
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Send")
                }
                function send() {
                    if (bridge.getConnStatus() < 1) {
                        toast.show({ message : qsTr("You are not connected to the tox network."), duration : Toast.Short });
                        return
                    }
                    var toxId_text = toxId.text
                    if(toxId_text.substring(0, 4) === "tox:") {
                        toxId_text = toxId_text.slice(4, toxId.text.length)
                    }
                    bridge.makeFriendRequest(toxId_text.toUpperCase(), 
                                             addFriendMessage.text.length > 0 ? addFriendMessage.text : addFriendMessage.placeholderText)
                }
                onTriggered: {
                    sendItem.send()
                }
            }
        }
    }
    /*
        Friend info menu
    */
    Menu {
        id: friendInfoMenu
        width: 300
        title: "My profile"
        x: (window.width - width) * 0.5
        y: (window.height - height) * 0.5
        z: z_menu
        modal: true
        Text {
            padding: 10
            font.bold: true
            width: parent.width
            horizontalAlignment: Qt.AlignHCenter
            text: qsTr("Nickname")
        }
        Text {
            id: infoNickname
            padding: 10
            width: parent.width
            horizontalAlignment: Qt.AlignHCenter
            wrapMode: Text.Wrap
        }
        Text {
            padding: 10
            font.bold: true
            width: parent.width
            horizontalAlignment: Qt.AlignHCenter
            text: qsTr("Status")
        }
        Text {
            id: infoStatus
            padding: 10
            width: parent.width
            horizontalAlignment: Qt.AlignHCenter
            wrapMode: Text.Wrap
        }
        Button {
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
                cleanProfile = bridge.getFriendsCount() < 1
                if (friendsModel.count > 0) {
                    selectFriend(friendsModel.get(0).friendNumber)
                } else {
                    friendNickname.text = ""
                    friendStatus.text = ""
                }
                friendInfoMenu.close()
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
                text: qsTr("Clear chat")
                onClicked: {
                    messagesModel.clear()
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
            visible: !cleanProfile
        }

        Label {
            id: friendNickname
            anchors.centerIn: parent
            property int charsLimit: 20
            function setText(t) {
                var mult = !inPortrait ? 1.5 : 1.0
                text = limitString(t, Math.round(charsLimit * mult))
            }
            MouseArea {
                anchors.fill: parent
                onPressed: {
                    if (!cleanProfile) {
                        infoNickname.text = bridge.getFriendNickname(bridge.getCurrentFriendNumber())
                        infoStatus.text = bridge.getFriendStatusMessage(bridge.getCurrentFriendNumber())
                        friendInfoMenu.popup()
                    }
                }
            }
        }
        Label {
            id: friendStatus
            anchors.top: friendNickname.bottom
            anchors.horizontalCenter: friendNickname.horizontalCenter
            font.pixelSize: 10
            font.italic: true
            property int charsLimit: 52
            function setText(t) {
                var mult = !inPortrait ? 1.5 : 1.0
                text = limitString(t, Math.round(charsLimit * mult))
            }
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
            notification.cancel(-1)
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
                    spacing: 0
                    Layout.alignment: Qt.AlignTop
                    ItemDelegate {
                        id: accountName
                        leftPadding: 4
                        rightPadding: 4
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
                            if (accountStatusMenu.visible) {
                                accountStatusMenu.close()
                                return
                            }
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
                    implicitHeight: 200
                    ScrollIndicator.vertical: ScrollIndicator { }
                    ColumnLayout {
                        anchors.top: parent.top
                        spacing: 0
                        Repeater {
                            id: friends
                            model: friendsModel
                            delegate: RowLayout {
                                id: friendLayout
                                spacing: 0
                                property int itemHeight: 40
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
                                property bool dragActive: friendDragAreaIndicator.drag.active
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
                                    width: parent.itemHeight
                                    height: parent.itemHeight
                                    Layout.alignment: Qt.AlignLeft
                                    color: (parent.dragEntered && !parent.dragActive) ? "lightgray" : "#00000000"
                                    visible: !request
                                    Component.onCompleted: {
                                        if (request) {
                                            width = height = 0
                                        }
                                    }
                                    MouseArea {
                                        id: friendDragAreaIndicator
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
                                    DropArea {
                                        anchors.fill: parent
                                        enabled: !parent.parent.dragActive
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

                                function setFriendStatusIndicatorColor(color) {
                                    friendItemStatusIndicator.color = color
                                }
                                function getFriendStatusIndicatorColor() {
                                    return friendItemStatusIndicator.color
                                }
                                ItemDelegate {
                                    id: friendItem
                                    background.z: z_friend_item
                                    z: z_friend_item
                                    text: nickName
                                    leftPadding: 4
                                    rightPadding: 6
                                    property int friend_number: friendNumber
                                    Layout.alignment: Qt.AlignRight
                                    implicitHeight: parent.itemHeight
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
                                        visible: request || (parent.parent.dragEntered && !parent.parent.dragActive)
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
            ToolButton {
                id: showSettingsButton
                text: "\u2699"
                font.family: dejavuSans.name
                font.pointSize: 24
                font.bold: true
                antialiasing: true
                onClicked: {
                    toast.show({ message: "Not implemented.", duration: Toast.Short })
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

    //include: chatarea.qml
}
