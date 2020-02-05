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
            messages.addTransitionEnabled = false
            bridge.retrieveChatLog()
            messages.scrollToEnd()
            messages.addTransitionEnabled = true
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
    readonly property real standardFontPointSize: 17.5

    //include: functions.qml

    /*
        Image buffers
    */

    // I don't need multiple images but this bug appears
    //https://forum.qt.io/topic/109114/qml-artifacts-android/9
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
        y: (window.height - height - keyboardHeight) * 0.5
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
            font.pointSize: standardFontPointSize
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
            font.pointSize: standardFontPointSize
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
        y: (window.height - height - keyboardHeight) * 0.5
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
            font.pointSize: standardFontPointSize
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
            font.pointSize: standardFontPointSize
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
        NumberAnimation on y {
            id: overlayHeaderSmoothMover
            running: false
        }

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
                y: contentHeight * 0.22

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
            anchors.centerIn: parent
            property int charsLimit: 20
            function setText(t) {
                var mult = !inPortrait ? 1.5 : 1.0
                text = limitString(t, Math.round(charsLimit * mult))
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
                    chatMessage.text += friendNickname.text
                }
            }
        }
        Label {
            id: friendStatus
            anchors.top: friendNickname.bottom
            anchors.horizontalCenter: friendNickname.horizontalCenter
            font.pointSize: 10
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

    //include: leftpanel.qml

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
