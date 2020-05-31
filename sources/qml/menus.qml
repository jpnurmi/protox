import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12

import QtUtf8ByteLimitValidator 1.0

/*[remove]*/ Item {

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
    readonly property int margin: 25
    width: parent.width - margin * 2
    title: qsTr("Add a new friend")
    readonly property bool haveYSpace: keyboardHeight + height <= window.height
    x: (window.width - width) * 0.5
    y: (window.height - height - (haveYSpace ? keyboardHeight : 0)) * 0.5
    z: z_menu
    modal: true
    // enable adjustTop only for this menu
    Connections {
        target: window
        onKeyboardActiveChanged: {
            if (addFriendMenu.visible) {
                bridge.setKeyboardAdjustMode(!window.keyboardActive)
            }
        }
        onFocusObjectChanged: {
            if (addFriendMenu.visible && window.keyboardActive) {
                bridge.setKeyboardAdjustMode(false)
            }
        }
    }
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
        font.pointSize: fontMetrics.normalize(standardFontPointSize)
        leftPadding: 10
        rightPadding: leftPadding
        verticalAlignment: TextInput.AlignVCenter
        width: parent.width
        text: ""
        validator: Utf8ByteLimitValidator { length: safe_bridge().getToxAddressSizeHex(); prefix: "tox:"; less: false; typemore: true }
        color: acceptableInput ? "black" : "red"
        onAccepted: {
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
        font.pointSize: fontMetrics.normalize(standardFontPointSize)
        leftPadding: 10
        rightPadding: leftPadding
        verticalAlignment: TextInput.AlignVCenter
        width: parent.width
        placeholderText: qsTr("Add me to your friends. Maybe?")
        validator: Utf8ByteLimitValidator { length: safe_bridge().getFriendRequestMessageMaxLength() }
        onAccepted: {
            focus = false
            sendItem.send()
        }
    }
    Text {
        id: friendRequestStatusText
        padding: 5
        font.bold: true
        font.pointSize: fontMetrics.normalize(15)
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        text: ""
        wrapMode: Text.Wrap
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
                var toxId_text = toxId.text
                if(toxId_text.substring(0, 4).toUpperCase() === "tox:".toUpperCase()) {
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
MessageDialog {
    id: clearFriendHistoryDialog
    title: qsTr("Deleting chat history")
    text: qsTr("Do you want to delete chat history for this contact?")
    icon: StandardIcon.Question
    standardButtons: StandardButton.Yes | StandardButton.No
    visible: false
    property int currentFriendNumber: -1
    property bool keepActiveFileTransfers: false
    onYes: {
        bridge.clearFriendChatHistory(currentFriendNumber, keepActiveFileTransfers)
        if (bridge.getCurrentFriendNumber() === currentFriendNumber) {
            messagesModel.clear()
            if (keepActiveFileTransfers) {
                messages.addTransitionEnabled = false
                bridge.retrieveChatLog()
                chatScrollToEnd()
                messages.addTransitionEnabled = true
            }
        }
        toast.show({ message : qsTr("Chat history deleted!"), duration : Toast.Short });
    }
}
MessageDialog {
    id: removeFriendDialog
    title: qsTr("Removing current friend")
    property string nickName: ""
    text: qsTr("Are you really want to remove ") + nickName + qsTr(" from your contact list?")
    icon: StandardIcon.Question
    standardButtons: StandardButton.Yes | StandardButton.No
    visible: false
    onYes: {
        var friend_number = bridge.getCurrentFriendNumber()
        if (bridge.checkFriendHistoryExists(friend_number)) {
            clearFriendHistoryDialog.currentFriendNumber = friend_number
            clearFriendHistoryDialog.keepActiveFileTransfers = false
            clearFriendHistoryDialog.open()
        }
        bridge.deleteFriend(friend_number)
        bridge.saveProfile()
        for (var i = 0; i < friendsModel.count; i++) {
            var friend = friendsModel.get(i)
            if (friend.friendNumber === friend_number) {
                friendsModel.remove(i)
            }
        }
        toast.show({ message : qsTr("Friend removed!"), duration : Toast.Short });
        cleanProfile = bridge.getFriendsCount() < 1
        if (friendsModel.count > 0) {
            selectFriend(friendsModel.get(0).friendNumber)
        } else {
            friendNickname.setText("")
            friendStatusMessage.setText("")
        }
        friendInfoMenu.close()
    }
}
Menu {
    id: friendInfoMenu
    readonly property int margin: 25
    width: parent.width - margin * 2
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
        text: qsTr("Avatar")
    }
    RowLayout {
        spacing: 0
        Image {
            id: infoAvatar
            Layout.maximumWidth: 128
            Layout.maximumHeight: Layout.maximumWidth
            property int friendNumber
            readonly property string avatarPath: loginWindow.profileSelected && friendInfoMenu.visible ? 
                                                     safe_bridge().getFriendAvatarPath(friendNumber) : ""
            source: friendInfoMenu.visible ? (safe_bridge().checkFileExists(avatarPath) ? 
                                                  "file://" + avatarPath : infoIdenticonImageFrameBuffer.source) : ""
            Layout.alignment: Qt.AlignHCenter
            antialiasing: true
        }
        Image {
            id: infoIdenticonImageFrameBuffer
            visible: false
            Canvas {
                id: infoIdenticonCanvas
                width: 256
                height: width
                visible: false
                onPaint: {
                    if (!loginWindow.profileSelected) {
                        return
                    }
                    var cxt = getContext("2d");
                    var pk = bridge.getFriendPublicKeyHex(infoAvatar.friendNumber)
                    Jdenticon.global.jdenticon_config = jdenticon_default_config
                    Jdenticon.global.jdenticon_config.hues = getJdenticonHues(pk)
                    Jdenticon.drawIcon(cxt, pk, width)
                    grabToImage(function(result) { parent.source = result.url; });
                }
            }
        }
    }
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
        Text {
            anchors.centerIn: parent
            visible: parent.text.length === 0
            text: qsTr("<empty>")
            font.italic: true
        }
    }
    Text {
        padding: 10
        font.bold: true
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        text: qsTr("Status message")
    }
    Text {
        id: infoStatus
        padding: 10
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        wrapMode: Text.Wrap
        Text {
            anchors.centerIn: parent
            visible: parent.text.length === 0
            text: qsTr("<empty>")
            font.italic: true
        }
    }
    Text {
        padding: 10
        font.bold: true
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        text: qsTr("Public key")
    }
    Text {
        id: infoPublicKey
        padding: 10
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        wrapMode: Text.Wrap
    }
    Button {
        text: qsTr("Delete chat history")
        leftInset: 10
        rightInset: leftInset
        onClicked: {
            var friend_number = bridge.getCurrentFriendNumber()
            if (!bridge.checkFriendHistoryExists(friend_number)) {
                toast.show({ message : qsTr("Nothing to delete."), duration : Toast.Short });
                return
            }
            clearFriendHistoryDialog.currentFriendNumber = friend_number
            clearFriendHistoryDialog.keepActiveFileTransfers = true
            clearFriendHistoryDialog.open()
        }
    }
    Button {
        Text {
            anchors.centerIn: parent
            text: qsTr("Remove this friend")
            color: "red"
            font.pointSize: parent.font.pointSize
            font.bold: true
        }
        leftInset: 10
        rightInset: leftInset
        onClicked: {
            removeFriendDialog.nickName = bridge.getFriendNickname(bridge.getCurrentFriendNumber())
            removeFriendDialog.open()
        }
    }
}

/*
    Profile menu
*/
Menu {
    id: profileMenu
    readonly property int margin: 25
    width: parent.width - margin * 2
    title: "My profile"
    readonly property bool haveYSpace: keyboardHeight + height <= window.height
    x: (window.width - width) * 0.5
    y: (window.height - height - (haveYSpace ? keyboardHeight : 0)) * 0.5
    z: z_menu
    modal: true
    // enable adjustTop only for this menu
    Connections {
        target: window
        onKeyboardActiveChanged: {
            if (profileMenu.visible) {
                bridge.setKeyboardAdjustMode(!window.keyboardActive)
            }
        }
        onFocusObjectChanged: {
            if (profileMenu.visible && window.keyboardActive) {
                bridge.setKeyboardAdjustMode(false)
            }
        }
    }
    onClosed: {
        currentIndex = -1
        myNickname.focus = false
        myStatusMessage.focus = false
        myNickname.text = bridge.getNickname(false)
        myStatusMessage.text = bridge.getStatusMessage()
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
        font.pointSize: fontMetrics.normalize(standardFontPointSize)
        leftPadding: 10
        rightPadding: leftPadding
        verticalAlignment: TextInput.AlignVCenter
        width: parent.width
        validator: Utf8ByteLimitValidator { length: safe_bridge().getNicknameMaxLength() }
        onAccepted: {
            myStatusMessage.focus = true
        }
    }
    Text {
        padding: 10
        font.bold: true
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        text: qsTr("Status message")
    }
    TextField {
        id: myStatusMessage
        font.pointSize: fontMetrics.normalize(standardFontPointSize)
        leftPadding: 10
        rightPadding: leftPadding
        verticalAlignment: TextInput.AlignVCenter
        width: parent.width
        onAccepted: profileMenuApplyItem.onTriggered()
        validator: Utf8ByteLimitValidator { length: safe_bridge().getStatusMessageMaxLength() }
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
            id: profileMenuApplyItem
            Layout.fillWidth: true
            Text {
                anchors.centerIn: parent
                text: qsTr("Apply")
            }
            onTriggered: {
                bridge.setNickname(myNickname.text)
                accountName.text = bridge.getNickname(true)
                bridge.setStatusMessage(myStatusMessage.text)
                bridge.saveProfile()
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
    width: 260
    title: qsTr("My profile info")
    x: (window.width - width) * 0.5
    y: (window.height - height) * 0.5
    z: z_menu
    modal: true
    Image {
        id: toxIDQRCodeImage
        anchors.centerIn: parent
        sourceSize.width: 196
        sourceSize.height: 196
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
        wrapMode: Text.Wrap
        topPadding: 10
    }
}

/*[remove]*/ }
