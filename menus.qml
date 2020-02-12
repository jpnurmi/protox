import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12

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
        font.pointSize: standardFontPointSize
        leftPadding: 10
        rightPadding: leftPadding
        verticalAlignment: TextInput.AlignVCenter
        width: parent.width
        text: ""
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
MessageDialog {
    id: clearFriendHistoryDialog
    title: qsTr("Clearing char history")
    text: qsTr("Do you want to remove chat history for this contact?")
    icon: StandardIcon.Question
    standardButtons: StandardButton.Yes | StandardButton.No
    visible: false
    property int currentFriendNumber: -1
    onYes: {
        bridge.clearFriendChatHistory(currentFriendNumber)
        if (bridge.getCurrentFriendNumber() === currentFriendNumber) {
            messagesModel.clear()
        }
        toast.show({ message : qsTr("Chat history removed!"), duration : Toast.Short });
    }
}
MessageDialog {
    id: removeFriendDialog
    title: qsTr("Deleting current friend")
    property string nickName: ""
    text: qsTr("Are you really want to delete ") + nickName + qsTr(" from your contact list?")
    icon: StandardIcon.Question
    standardButtons: StandardButton.Yes | StandardButton.No
    visible: false
    onYes: {
        clearFriendHistoryDialog.currentFriendNumber = bridge.getCurrentFriendNumber()
        clearFriendHistoryDialog.open()
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
        text: qsTr("Status message")
    }
    Text {
        id: infoStatus
        padding: 10
        width: parent.width
        horizontalAlignment: Qt.AlignHCenter
        wrapMode: Text.Wrap
    }
    Button {
        text: qsTr("Clear chat history")
        leftInset: 10
        rightInset: leftInset
        onClicked: {
            clearFriendHistoryDialog.currentFriendNumber = bridge.getCurrentFriendNumber()
            clearFriendHistoryDialog.open()
        }
    }
    Button {
        Text {
            anchors.centerIn: parent
            text: qsTr("Delete this friend")
            color: "red"
            font.pointSize: 14
            font.capitalization: Font.AllUppercase
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
        font.pointSize: standardFontPointSize
        leftPadding: 10
        rightPadding: leftPadding
        verticalAlignment: TextInput.AlignVCenter
        width: parent.width
        //text: bridge.getNickname(false)
        onAccepted: {
            myStatus.focus = true
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
        id: myStatus
        font.pointSize: standardFontPointSize
        leftPadding: 10
        rightPadding: leftPadding
        verticalAlignment: TextInput.AlignVCenter
        width: parent.width
        //text: bridge.getStatusMessage()
        onAccepted: profileMenuApplyItem.onTriggered()
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
    width: 260
    title: qsTr("My profile info")
    x: (window.width - width) * 0.5
    y: (window.height - height) * 0.5
    z: z_menu
    modal: true
    Image {
        id: toxIDQRCodeImage
        anchors.centerIn: parent
        //source: "image://QZXing/encode/" + "tox:" + bridge.getToxId() +
        //        "?correctionLevel=M" +
        //        "&format=qrcode"
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
        topPadding: 10
    }
}

/*[remove]*/ }
