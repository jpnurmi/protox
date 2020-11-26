import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12
import QtGraphicalEffects 1.0

import QtUtf8ByteLimitValidator 1.0
import QtPhotoDialog 1.0
import QtQRCodeScanner 1.0

/*[remove]*/ Item {

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
    y: (window.height - height - (haveYSpace ? keyboardHeightSmooth : 0)) * 0.5
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
        color: getTheme().primaryTextColor
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
        color: acceptableInput ? getTheme().primaryTextColor : "red"
        onAccepted: {
            addFriendMessage.focus = true
        }
    }

    Button {
        id: scanQRCodeButton
        leftInset: 15
        rightInset: leftInset
        text: qsTr("Scan QR code")
        onClicked: {
            toxIDCodeScanner.open()
        }
    }

    Text {
        padding: 10
        font.bold: true
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        text: qsTr("Messsage")
        color: getTheme().primaryTextColor
    }

    TextField {
        id: addFriendMessage
        color: getTheme().primaryTextColor
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
    property string friendPkHex: ""

    onYes: {
        bridge.clearFriendChatHistory(currentFriendNumber, friendPkHex, keepActiveFileTransfers)

        if (bridge.getCurrentFriendNumber() === currentFriendNumber) {
            messagesModel.clear()

            if (keepActiveFileTransfers) {
                messages.addTransitionEnabled = false
                bridge.retrieveChatLog()
                chatScrollToEnd()
                addTransitionEnableTimer.start()
            }
        }

        toast.show({ message : qsTr("Chat history deleted!"), duration : Toast.Short });
    }
}

MessageDialog {
    id: removeFriendDialog
    title: qsTr("Removing current friend")
    property int currentFriendNumber
    property string nickName: ""
    text: qsTr("Are you really want to remove ") + nickName + qsTr(" from your contact list?")
    icon: StandardIcon.Question
    standardButtons: StandardButton.Yes | StandardButton.No
    visible: false

    onYes: {
        var selected_friend_number = bridge.getCurrentFriendNumber()

        if (bridge.checkFriendHistoryExists(currentFriendNumber)) {
            clearFriendHistoryDialog.currentFriendNumber = -1
            clearFriendHistoryDialog.friendPkHex = bridge.getFriendPublicKeyHex(currentFriendNumber)
            clearFriendHistoryDialog.keepActiveFileTransfers = false
            clearFriendHistoryDialog.open()
        }

        bridge.deleteFriend(currentFriendNumber)
        bridge.saveProfile()

        for (var i = 0; i < friendsModel.count; i++) {
            var friend = friendsModel.get(i)
            if (friend.friendNumber === currentFriendNumber) {
                friendsModel.remove(i)
                break
            }
        }

        toast.show({ message : qsTr("Friend removed!"), duration : Toast.Short });
        cleanProfile = bridge.getFriendsCount() < 1

        if (selected_friend_number === currentFriendNumber) {
            if (friendsModel.count > 0) {
                selectFriend(friendsModel.get(0).friendNumber)
            } else {
                friendNickname.setText("")
                friendStatusMessage.setText("")
                messagesModel.clear()
            }
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
    property int currentFriendNumber

    // enable adjustTop only for this menu
    Connections {
        target: window

        onKeyboardActiveChanged: {
            if (friendInfoMenu.visible) {
                bridge.setKeyboardAdjustMode(!window.keyboardActive)
            }
        }

        onFocusObjectChanged: {
            if (friendInfoMenu.visible && window.keyboardActive) {
                bridge.setKeyboardAdjustMode(false)
            }
        }
    }

    function prepareAndOpen(friend_number) {
        currentFriendNumber = friend_number
        var avatar_path = bridge.getFriendAvatarPath(friend_number)
        infoAvatar.source = bridge.checkFileImage(avatar_path) ? 
                    "file://" + avatar_path : identiconBuffer.getImageSource(friend_number, false)
        infoNickname.text = bridge.getFriendNickname(friend_number, false)
        infoNickname.font.italic = bridge.checkFriendCustomNickname(friend_number)
        infoStatus.text = bridge.getFriendStatusMessage(friend_number)
        infoPublicKey.text = bridge.getFriendPublicKeyHex(friend_number)
        friendInfoMenu.popup()
    }

    onClosed: {
        infoNickname.focus = false
    }

    Text {
        padding: 10
        font.bold: true
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        text: qsTr("Avatar")
        color: getTheme().primaryTextColor
    }

    RowLayout {
        spacing: 0

        Image {
            id: infoAvatar
            Layout.maximumWidth: 128
            Layout.maximumHeight: Layout.maximumWidth
            Layout.alignment: Qt.AlignHCenter
            antialiasing: true
            layer.enabled: true

            Rectangle {
                id: infoAvatarMask
                anchors.fill: parent
                radius: width * 0.1
                visible: false
            }

            layer.effect: OpacityMask {
                maskSource: infoAvatarMask
            }
        }
    }

    Text {
        padding: 10
        font.bold: true
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        text: qsTr("Nickname")
        color: getTheme().primaryTextColor
    }

    TextField {
        id: infoNickname
        padding: 10
        width: parent.width
        color: getTheme().primaryTextColor
        font.pointSize: fontMetrics.normalize(standardFontPointSize)
        leftPadding: 10
        rightPadding: leftPadding
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: Qt.AlignHCenter

        onAccepted: {
            focus = false
            var friend_number = friendInfoMenu.currentFriendNumber

            if (text.length === 0) {
                bridge.setSettingsValue("Client_" + bridge.getCurrentProfile(), 
                                        "name_" + bridge.getFriendPublicKeyHex(friend_number),
                                        "")
                var name = bridge.getFriendNickname(friend_number, false)
                text = name
                updateFriendNickName(friend_number, name)
            } else {
                bridge.setSettingsValue("Client_" + bridge.getCurrentProfile(), 
                                        "name_" + bridge.getFriendPublicKeyHex(friend_number),
                                        text)
                updateFriendNickName(friend_number, bridge.getFriendNickname(friend_number, false))
            }

            font.italic = bridge.checkFriendCustomNickname(friend_number)
        }
    }

    Text {
        padding: 10
        font.bold: true
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        text: qsTr("Status message")
        color: getTheme().primaryTextColor
    }

    Text {
        id: infoStatus
        padding: 10
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        wrapMode: Text.Wrap
        color: getTheme().primaryTextColor

        Text {
            anchors.centerIn: parent
            visible: parent.text.length === 0
            text: qsTr("<empty>")
            font.italic: true
            color: getTheme().primaryTextColor
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                if (parent.text.length > 0) {
                    bridge.copyTextToClipboard(parent.text)
                    toast.show({ message : qsTr("Text copied to clipboard."), duration : Toast.Short });
                }
            }
        }
    }

    Text {
        padding: 10
        font.bold: true
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        text: qsTr("Public key")
        color: getTheme().primaryTextColor
    }

    Text {
        id: infoPublicKey
        padding: 10
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        wrapMode: Text.Wrap
        color: getTheme().primaryTextColor

        MouseArea {
            anchors.fill: parent

            onClicked: {
                if (parent.text.length > 0) {
                    bridge.copyTextToClipboard(parent.text)
                    toast.show({ message : qsTr("Text copied to clipboard."), duration : Toast.Short });
                }
            }
        }
    }

    Button {
        text: qsTr("Delete chat history")
        leftInset: 10
        rightInset: leftInset

        onClicked: {
            if (!bridge.checkFriendHistoryExists(friendInfoMenu.currentFriendNumber)) {
                toast.show({ message : qsTr("Nothing to delete."), duration : Toast.Short });
                return
            }

            clearFriendHistoryDialog.friendPkHex = ""
            clearFriendHistoryDialog.currentFriendNumber = friendInfoMenu.currentFriendNumber
            clearFriendHistoryDialog.keepActiveFileTransfers = true
            clearFriendHistoryDialog.open()
        }
    }

    Button {
        leftInset: 10
        rightInset: leftInset

        Text {
            anchors.centerIn: parent
            text: qsTr("Remove this friend")
            color: getUserTheme().importantButtonTextColor
            font.pointSize: parent.font.pointSize
            font.bold: true
        }

        onClicked: {
            removeFriendDialog.currentFriendNumber = friendInfoMenu.currentFriendNumber
            removeFriendDialog.nickName = bridge.getFriendNickname(friendInfoMenu.currentFriendNumber)
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
    y: (window.height - height - (haveYSpace ? keyboardHeightSmooth : 0)) * 0.5
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
        color: getTheme().primaryTextColor
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
        color: getTheme().primaryTextColor
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
                accountName.text = bridge.getNickname()
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
                toast.show({ message : qsTr("Tox ID copied!"), duration : Toast.Short });
            }
        }
    }

    Text {
        id: toxIDHelperText
        horizontalAlignment: Qt.AlignHCenter
        text: qsTr("Tap on image to copy your Tox ID.")
        wrapMode: Text.Wrap
        topPadding: 10
        color: getTheme().primaryTextColor
    }
}

/*
  Change avatar menu
*/

Menu {
    id: changeAvatarMenu
    readonly property int margin: 25
    width: 300
    title: "Change avatar"
    x: (window.width - width) * 0.5
    y: (window.height - height) * 0.5
    z: z_menu
    modal: true

    Rectangle {
        width: parent.width
        height: 15
        visible: false
    }

    ColumnLayout {
        spacing: 0

        Image {
            id: changeAvatarImage
            Layout.maximumWidth: 128
            Layout.maximumHeight: Layout.maximumWidth
            width: 128
            height: width
            Layout.alignment: Qt.AlignHCenter
            antialiasing: true
            cache: false
            layer.enabled: true

            Rectangle {
                id: changeAvatarImageMask
                anchors.fill: parent
                radius: width * 0.1
                visible: false
            }

            layer.effect: OpacityMask {
                maskSource: changeAvatarImageMask
            }

            MouseArea {
                anchors.fill: parent

                onClicked: {
                    avatarPickerDialog.open()
                }
            }
        }
    }

    Text {
        id: changeAvatarHelperText
        horizontalAlignment: Qt.AlignHCenter
        text: qsTr("Tap on image to change your avatar.")
        wrapMode: Text.Wrap
        topPadding: 15
    }

    Button {
        id: removeAvatarButton
        leftInset: 10
        rightInset: leftInset
        enabled: safe_bridge().checkFileImage(accountAvatar.avatarPath)

        Text {
            anchors.centerIn: parent
            text: qsTr("Remove avatar")
            color: parent.enabled ? getUserTheme().importantButtonTextColor : getUserTheme().buttonDisabledColor
            font.pointSize: parent.font.pointSize
            font.bold: true
        }

        onClicked: {
            bridge.changeSelfAvatar("")
            var avatar_path = accountAvatar.avatarPath
            var file_image = bridge.checkFileImage(avatar_path)
            accountAvatar.source = changeAvatarImage.source = file_image ? 
                        "file://" + avatar_path : identiconBuffer.getImageSource(0, true)
            enabled = file_image
        }
    }
}

PhotoDialog {
    id: avatarPickerDialog
    title: qsTr("Select an image")
    selectMultiple: false

    onAccepted: {
        bridge.changeSelfAvatar(bridge.uriToRealPath(imageUrl.toString()))
        var avatar_path = accountAvatar.avatarPath
        var file_image = bridge.checkFileImage(avatar_path)
        accountAvatar.source = changeAvatarImage.source = file_image ? 
                    "file://" + avatar_path : identiconBuffer.getImageSource(0, true)
        removeAvatarButton.enabled = file_image
    }
}

QRCodeScanner {
    id: toxIDCodeScanner
    onTriggered: {
        toxId.text = result
    }
}

/*[remove]*/ }
