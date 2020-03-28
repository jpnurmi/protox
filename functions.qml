/*
  Functions
*/

import QtQuick 2.12

/*[remove]*/ Item {

function checkLastMessage(friend_number) {
    if (!messagesModel.count) {
        return true
    }
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
            friendsModel.get(i).statusColor = color;
        }
    }
}

function setFriendStatusMessage(friend_number, message) {
    if (friend_number !== bridge.getCurrentFriendNumber())
        return
    friendStatusMessage.setText(message)
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
}

function updateFriendNickName(friend_number, nickname) {
    for (var i = 0; i < friendsModel.count; i++) {
        var friend = friendsModel.get(i)
        if (friend.friendNumber === friend_number && !friend.request) {
            friend.nickName = nickname
            friendsModel.set(i, friend)
        }
    }
    if (friend_number === bridge.getCurrentFriendNumber()) {
        friendNickname.setText(nickname)
    }
}
function sendFriendRequestStatus(status) {
    var msg = "";
    var color = "red";
    if (addFriendMenu.opened) {
        switch (status) {
        case 0:
            bridge.saveProfile()
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
    messages.scrollToEnd()
}

property variant each_friend_text: []
function selectFriend(friend_number) {
    if (bridge.getCurrentFriendNumber() === friend_number && checkLastMessage(friend_number)) {
        return
    }
    notification.cancel(friend_number)
    dropTypingTimer.stop()
    typingText.visible = false
    each_friend_text[bridge.getCurrentFriendNumber()] = chatMessage.text
    bridge.setCurrentFriend(friend_number)
    friendNickname.setText(bridge.getFriendNickname(friend_number))
    friendStatusMessage.setText(bridge.getFriendStatusMessage(friend_number))
    for (var i = 0; i < friendsModel.count; i++) {
        if (friendsModel.get(i).friendNumber === friend_number) {
            friendStatusIndicator.color = friendsModel.get(i).statusColor
            break
        }
    }
    messages.addTransitionEnabled = false
    bridge.retrieveChatLog()
    chatScrollToEnd()
    messages.addTransitionEnabled = true
    chatMessage.clear()
    if (each_friend_text[friend_number] !== undefined) {
        chatMessage.append(each_friend_text[friend_number])
    } 
}

property int new_messages: 0
function insertMessage(variantMessage, friend_number, self, message_id, time, unique_id, failed, history) {
    if (!self && !history && (appInactive || bridge.getCurrentFriendNumber() !== friend_number || settingsWindow.visible)) {
        if (!variantMessage.type) {
            notification.show({
                              caption : variantMessage.message,
                              title : qsTr("New message from ") + bridge.getFriendNickname(friend_number),
                              id : friend_number
                            });
        }
    }
    if (bridge.getCurrentFriendNumber() !== friend_number) {
        return
    }

    var dict = { "msgSelf" : self, 
        "msgReceived" : false, 
        "msgId" : message_id, 
        "msgTime" : time, 
        "msgUniqueId" : unique_id,
        "msgFailed" : failed,
        "msgHistory" : history}
    
    if (!variantMessage.type) {
        dict.msgText = variantMessage.message
    }
    messagesModel.append(dict)

    if (!history) {
        if (messages.atYEnd) {
            messages.scrollToEnd()
            // to make typingText disappear immediately
            if (!self) {
                typingText.visible = false
            }
        } else {
            new_messages += 1
            scrollToEndButton.visible = true
        }
    }
}
function insertFriend(friend_number, nickName, request, request_message, friendPk) {
    friendsModel.append({"friendNumber" : friend_number, 
                            "nickName" : nickName, 
                            "request" : request, 
                            "request_message" : request_message, 
                            "friendPk" : friendPk,
                            "statusColor" : "gray"})
    if (!request) {
        cleanProfile = bridge.getFriendsCount() === 0
    } 
    if (request && (appInactive || !drawer.opened || settingsWindow.visible)) {
        notification.show({
                          caption : request_message,
                          title : qsTr("A new friend request from ") + nickName,
                          id : -1
                        });
        leftOverlayButtonTextAnimation.start()
    }
    if (bridge.getFriendsCount() < 2 && !request) {
        selectFriend(0)
        friendNickname.setText(nickName)
    }
}

function setMessageReceived(friend_number, message_id, use_uid, unique_id) {
    if (bridge.getCurrentFriendNumber() !== friend_number) {
        return
    }
    for (var i = 0; i < messagesModel.count; i++) {
        var message = messagesModel.get(i)
        if (!message.msgSelf)
            continue;
        if ((!use_uid && message.msgId === message_id) || (use_uid && message.msgUniqueId === unique_id)) {
            message.msgReceived = true
            messagesModel.set(i, message)
        }
    }
}
function setCurrentFriendConnStatus(friend_number, conn_status) {
    setFriendStatus(friend_number, bridge.getFriendStatus(friend_number))
    if (bridge.getCurrentFriendNumber() === friend_number) {
        if (!conn_status) {
            friendStatusIndicator.color = "gray"
        }
    }

    for (var i = 0; i < friendsModel.count; i++) {
        if (friendsModel.get(i).friendNumber === friend_number) {
            if (!conn_status) {
                friendsModel.get(i).statusColor = "gray"
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

property real keyboardHeight: 0
property bool keyboardActive: false
/*
NumberAnimation on keyboardHeight {
    id: keyboardHeightSmoothMover
    running: false
}
*/
function setKeyboardHeight(height) {
    keyboardActive = height > 0
    keyboardHeight = height / Screen.devicePixelRatio
    if (keyboardActive && chatMessage.focus) {
        messages.scrollToEnd()
    }
}

function updateQRcode() {
    toxIDQRCodeImage.source = "image://QZXing/encode/" + "tox:" + bridge.getToxId() +
                              "?correctionLevel=M" +
                              "&format=qrcode"
}

function signInProfile(profile, create, password) {
    var error = bridge.signInProfile(profile, create, password)
    if (error > 0)
        return error
    var friend_number = bridge.getCurrentFriendNumber()
    cleanProfile = bridge.getFriendsCount() < 1
    // header
    friendNickname.setText(bridge.getFriendNickname(friend_number))
    friendStatusMessage.setText(bridge.getFriendStatusMessage(friend_number))
    // drawer
    accountName.text = bridge.getNickname(true)
    statusIndicator.setStatus(bridge.getStatus())
    // QR code
    updateQRcode()
    // chat log
    messages.addTransitionEnabled = false
    bridge.retrieveChatLog()
    messages.scrollToEnd()
    messages.addTransitionEnabled = true
    // menus
    myNickname.text = bridge.getNickname(false)
    myStatus.text = bridge.getStatusMessage()
    // settings
    settingsModel.setValueString("no_spam_value", bridge.getNospamValue())
    settingsWindow.setProfileEncrypted(bridge.checkProfileEncrypted(profile))
    return 0
}

function resetConnectionStatus()
{
    connectionStatus.text = qsTr("Bootstrapping...")
    connectionStatus.color = "orange"
}

function resetUI() {
    // the rest in signInProfile will be overwritten on login
    chatMessage.clear()
    each_friend_text = []
    friendsModel.clear()
    resetConnectionStatus()
    friendStatusIndicator.color = "gray"
    new_messages = 0
}

/*[remove]*/ }
