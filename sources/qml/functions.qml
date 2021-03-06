/*
  Functions
*/

import QtQuick 2.12

import "qrc:/deps/jdenticon/jdenticon.js" as Jdenticon

/*[remove]*/ Item {

function makeMultBy(size, value) {
    if (size <= value / 2) {
        return Math.ceil(size / value) * value
    }
    return Math.round(size / value) * value
}

readonly property variant jdenticon_default_config: {
    "backColor" : "#00000000",
    "lightness" : {
        color: [0.4, 0.8],
        grayscale: [0.3, 0.9]
    },
    "saturation" : {
        color: 0.75,
        grayscale: 0
    },
    "padding" : 0.08
};

function getJdenticonHues(pk) {
    var hash = Jdenticon.sha1(pk)
    var result = []

    for (var i = 0; i < hash.length; i += 8) {
        result.push(parseInt(hash.substring(i, i + 8), 16) / 4294967295 * 360)
    }

    return result
}

function formatBytes(bytes, decimals = 2) {
    const sizes = [qsTr("Bytes"), qsTr("KB"), qsTr("MB"), qsTr("GB"), qsTr("TB"), qsTr("PB"), qsTr("EB"), qsTr("ZB"), qsTr("YB")]

    if (bytes === 0) {
        return "0 " + sizes[0];
    }

    const k = 1024
    const dm = decimals < 0 ? 0 : decimals
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i]
}

function getApplicationTheme() {
    return {
        "loginPrimaryColor" : "#12273b",
        "loginProfileCreationPrimaryColor" : "#000036",
        "loginProfileCreationPrimaryLandscapeColor" : "#432364",
        "profileCreationButtonColor" : "#9cdb53"
    }
}

function getUserTheme() {
    return {
        "messageCloudSelfColor" : "#ffb340",
        "messageCloudFriendColor" : "lightblue",
        "messageCloudPendingColor" : "lightgray",
        "settingsWarningColor" : "#f52b1d",
        "settingsTitleColor" : "#3ab03e",
        "importantButtonTextColor" : "#f52b1d",
        "buttonDisabledColor" : "gray",
        "onlineStatusColor" : "lightgreen",
        "awayStatusColor" : "yellow",
        "busyStatusColor" : "red",
        "offlineStatusColor" : "gray",
        "quotesColor" : "green",
        "linksColor" : "#043b94",
        "messageRemoveLineActiveColor" : "#f52b1d",
        "messageRemoveLineColor" : "#565656",
        "fileAcceptButtonColor" : "#3ab03e",
        "fileCancelButtonColor" : "#f52b1d",
        "transferSuccededTextColor" : "green",
        "transferCanceledTextColor" : "#f52b1d",
        "transferRemotePausedTextColor" : "#404040",
        "typingTextIndicatorActiveColor" : "black",
        "typingTextIndicatorColor" : "gray",
        "actionTextColor" : "#b30b8c"
    }
}

function getTheme() {
    return Material
}

function safe_bridge() {
    if (bridge !== null) {
        return bridge
    }

    var empty_bridge = {}
    empty_bridge.getToxAddressSizeHex = function() { return 0 }
    empty_bridge.getStatusMessageMaxLength = function() { return 0 }
    empty_bridge.getNicknameMaxLength = function() { return 0 }
    empty_bridge.getFriendRequestMessageMaxLength = function() { return 0 }
    empty_bridge.getHostnameMaxLength = function() { return 0 }
    empty_bridge.checkMessageInPendingList = function() { return 0 }
    empty_bridge.getCurrentFriendNumber = function() { return 0 }
    empty_bridge.getSettingsValue = function() { return 0 }
    empty_bridge.getSettingsValueDefault = function() { return 0 }
    empty_bridge.checkFileImage = function() { return "" }
    empty_bridge.checkFileExists = function() { return 0 }
    empty_bridge.getFriendAvatarPath = function() { return "" }
    empty_bridge.getImageSize = function() { return Qt.size(0, 0) }

    return empty_bridge
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

function scrollToEnd() {
    messages.scrollToEndWithTypingText()
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
    case 0: color = getUserTheme().onlineStatusColor; break;
    case 1: color = getUserTheme().awayStatusColor; break;
    case 2: color = getUserTheme().busyStatusColor; break;
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
            typingText.text = qsTr("A friend is typing")
        } else {
            typingText.text = qsTr("%1 is typing").arg(nick)
        }

        if (!typingText.visible) {
            typingText.visible = true
        }
    } else {
        typingText.text = ""

        if (typingText.visible) {
            typingText.visible = false
        }
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

Timer {
    id: scrollToEndTimer
    interval: 1
    repeat: !messages.atYEnd
    onTriggered: {
        messages.scrollToEndWithTypingText()
        if (!messages.addTransitionEnabled) {
            addTransitionEnableTimer.start()
        }
    }
}

Timer {
    id: addTransitionEnableTimer
    interval: 1
    repeat: false
    onTriggered: {
        messages.addTransitionEnabled = true
    }
}

property variant each_friend_text: []
function selectFriend(friend_number) {
    if (bridge.getCurrentFriendNumber() === friend_number) {
        return
    }

    notification.cancel({ type : Notification.Text, id : friend_number })
    dropTypingTimer.stop()

    typingText.text = ""
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
    scrollToEndTimer.start()
    chatMessage.clear()

    if (each_friend_text[friend_number] !== undefined) {
        chatMessage.append(each_friend_text[friend_number])
    }
}

property int new_messages: 0
function insertMessage(variantMessage, friend_number, self, time, unique_id, failed, history, preload) {
    if (!self && !history && (appInactive || bridge.getCurrentFriendNumber() !== friend_number || settingsWindow.visible)) {
        if (!variantMessage.type) {
            notification.show({
                              caption : variantMessage.action 
                                        ? bridge.getFriendNickname(friend_number) + " " + variantMessage.message
                                        : variantMessage.message,
                              title : qsTr("New message from %1").arg(bridge.getFriendNickname(friend_number)),
                              type : Notification.Text,
                              id : friend_number,
                              parameters : {
                                  "replyButtonText" : qsTr("Reply"),
                                  "replyPlaceholderText" : qsTr("Enter your reply here")
                                  }
                            });
        } else {
            notification.show({
                              caption : variantMessage.name + " (" + formatBytes(variantMessage.size) + ")",
                              title : qsTr("File transfer request from %1").arg(bridge.getFriendNickname(friend_number)),
                              type : Notification.FileRequest,
                              id : friend_number,
                              parameters : {
                                      "fileNumber" : variantMessage.file_number,
                                      "acceptButtonText" : qsTr("Accept"),
                                      "cancelButtonText" : qsTr("Cancel")
                                  }
                            });
        }
    }

    if (bridge.getCurrentFriendNumber() !== friend_number) {
        return
    }

    var dict = { "msgSelf" : self, 
        "msgReceived" : false, 
        "msgTime" : time, 
        "msgUniqueId" : unique_id,
        "msgFailed" : failed,
        "msgHistory" : history,
        "msgType" : variantMessage.type,
        "msgFiletsize" : 0,
        "msgRemotepaused" : false }

    if (!variantMessage.type) {
        dict.msgFilepath = ""
        dict.msgFilename = ""
        dict.msgFilesize = 0
        dict.msgFilestate = 0
        dict.msgFilenumber = 0

        if (variantMessage.action) {
            let nick = self ? bridge.getNickname() : bridge.getFriendNickname(friend_number)
            dict.msgText = nick + " " + variantMessage.message
        } else {
            dict.msgText = variantMessage.message
        }

        dict.msgAction = variantMessage.action
    } else {
        dict.msgText = ""
        dict.msgAction = false
        dict.msgFilepath = variantMessage.file_path
        dict.msgFilename = variantMessage.name
        dict.msgFilesize = variantMessage.size
        dict.msgFilestate = variantMessage.state
        dict.msgFilenumber = variantMessage.file_number
    }

    if (preload) {
        messagesModel.insert(0, dict)
    } else {
        messagesModel.append(dict)
    }

    if (!history) {
        if ((keyboardActive || variantMessage.type === msgtype_file) && self) {
            messages.scrollToEndWithTypingText()
        } else if (messages.atYEnd && !self) {
            // to make typingText disappear immediately
            typingText.visible = false
            messages.scrollToEnd()
        } else if (messages.exceedsHeight()) {
            new_messages += 1
            scrollToEndButton.visible = true
        }
    }
}

function insertFriend(friend_number, nickName, request, request_message, friendToxIdHex) {
    identiconModel.appendIfNotExists(friend_number, false)
    friendsModel.append({"friendNumber" : friend_number, 
                            "nickName" : nickName, 
                            "request" : request, 
                            "request_message" : request_message, 
                            "friendToxIdHex" : friendToxIdHex,
                            "statusColor" : "gray", 
                            "updateAvatar" : false})

    if (!request) {
        cleanProfile = bridge.getFriendsCount() === 0
    } 

    if (request && (appInactive || !drawer.opened || settingsWindow.visible)) {
        notification.show({
                          caption : request_message,
                          title : qsTr("A new friend request from %1").arg(nickName),
                          type : Notification.Text,
                          id : -1
                        });
        leftOverlayButtonTextAnimation.start()
    }

    if (bridge.getFriendsCount() < 2 && !request) {
        selectFriend(0)
        friendNickname.setText(nickName)
    }
}

function setMessageReceived(friend_number, unique_id) {
    if (bridge.getCurrentFriendNumber() !== friend_number) {
        return
    }

    for (var i = 0; i < messagesModel.count; i++) {
        var message = messagesModel.get(i)

        if (!message.msgSelf && message.msgType === msgtype_text)
            continue;

        if (message.msgUniqueId === unique_id) {
            message.msgReceived = true
            message.msgFailed = false
            messagesModel.set(i, message)
        }
    }
}

property bool updatePending: false
function setCurrentFriendConnStatus(friend_number, conn_status) {
    setFriendStatus(friend_number, bridge.getFriendStatus(friend_number))

    if (bridge.getCurrentFriendNumber() === friend_number) {
        updatePending = !updatePending

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

function setConnectionStatus(status) {
    var text, color;

    switch (status) {
    case -1: text = qsTr("Bootstrapping..."); color = "orange"; break;
    case 0: text = qsTr("Connection lost"); color = "red"; break;
    case 1: text = qsTr("Connected (TCP)"); color = "green"; break;
    case 2: text = qsTr("Connected (UDP)"); color = "green"; break;
    }

    connectionStatus.text = text;
    connectionStatus.color = color;
}

property real keyboardHeight: 0
property real keyboardHeightSmooth: 0
property bool keyboardActive: false

Behavior on keyboardHeightSmooth {
    NumberAnimation {
        duration: 100
        easing.type: Easing.OutCubic
    }
}

function setKeyboardHeight(height) {
    keyboardActive = height > 0
    keyboardHeight = height / Screen.devicePixelRatio
    keyboardHeightSmooth = height / Screen.devicePixelRatio
}

function updateQRcode() {
    toxIDQRCodeImage.source = "image://QZXing/encode/" + "tox:" + bridge.getToxId() +
                              "?correctionLevel=M" +
                              "&format=qrcode"
}

function signInProfile(profile, create, password, autoLogin) {
    var error = bridge.signInProfile(profile, create, password, autoLogin)

    if (error > 0)
        return error

    var friend_number = bridge.getCurrentFriendNumber()
    cleanProfile = bridge.getFriendsCount() < 1
    // header
    friendNickname.setText(bridge.getFriendNickname(friend_number))
    friendStatusMessage.setText(bridge.getFriendStatusMessage(friend_number))
    // drawer
    identiconModel.appendIfNotExists(0, true)
    accountAvatar.avatarPath = bridge.getSelfAvatarPath()
    accountName.text = bridge.getNickname()
    statusIndicator.setStatus(bridge.getStatus())
    // QR code
    updateQRcode()
    // chat log
    messages.addTransitionEnabled = false
    bridge.retrieveChatLog()
    scrollToEndTimer.start()
    // menus
    myNickname.text = bridge.getNickname(false)
    myStatusMessage.text = bridge.getStatusMessage()
    // settings
    settingsModel.setValueString("no_spam_value", bridge.getNospamValue())
    settingsModel.setValueNumber("auto_login_enabled", autoLogin)
    settingsModel.setEnabled("auto_login_enabled", password.length === 0)
    settingsWindow.setProfileEncrypted(bridge.checkProfileEncrypted(profile))
    settingsWindow.setAvailableNodes(bridge.getToxNodesCount())
    return error
}

function resetUI() {
    // the rest in signInProfile will be overwritten on login
    chatMessage.clear()
    each_friend_text = []
    friendsModel.clear()
    setConnectionStatus(-1)
    friendStatusIndicator.color = getUserTheme().offlineStatusColor
    new_messages = 0
    identiconModel.clear()
    typingText.text = ""

    if (typingText.visible) {
        typingText.visible = false
    }
}

function fileControlUpdateMessage(friend_number, unique_id, control, remote) {
    if (bridge.getCurrentFriendNumber() !== friend_number) {
        return
    }
    for (var i = 0; i < messagesModel.count; i++) {
        var message = messagesModel.get(i)

        if (message.msgType !== msgtype_file || message.msgFilestate === fstate_canceled || message.msgFilestate === fstate_finished) {
            continue
        }

        if (message.msgUniqueId === unique_id) {
            switch (control) {
            case fcontrol_cancel: message.msgFilestate = fstate_canceled; message.msgReceived = true; break;
            case fcontrol_pause:
                if (remote) {
                    message.msgRemotepaused = true
                } else {
                    message.msgFilestate = fstate_paused
                }

                message.msgReceived = false
                break;

            case fcontrol_resume:
                if (remote) {
                    message.msgRemotepaused = false
                } else {
                    message.msgFilestate = fstate_inprogress
                }

                message.msgReceived = false
                break;
            }

            messagesModel.set(i, message)
            break
        }
    }
}

function changeFileProgress(friend_number, file_number, bytesTransfered, finished) {
    if (bridge.getCurrentFriendNumber() !== friend_number) {
        return
    }

    for (var i = 0; i < messagesModel.count; i++) {
        var message = messagesModel.get(i)

        if (message.msgType !== msgtype_file 
                || message.msgFilestate === fstate_canceled 
                || message.msgFilestate === fstate_finished
                || message.msgFilestate === fstate_paused) {
            continue
        }

        if (message.msgFilenumber === file_number) {
            message.msgFiletsize = bytesTransfered

            if (!finished) {
                message.msgFilestate = fstate_inprogress
            } else {
                message.msgFilestate = fstate_finished
                message.msgReceived = true
            }

            messagesModel.set(i, message)
            break
        }
    }
}

function sendFile(fileUrl) {
    var result = bridge.sendFile(bridge.getCurrentFriendNumber(), bridge.uriToRealPath(fileUrl.toString()))
    var msg = ""

    switch (result) {
    case 0: msg = qsTr("File sent!"); break;
    case 1: msg = qsTr("Failed to open a file."); break;
    case 2: msg = qsTr("Failed. Too many file transfer requests."); break;
    case 3: msg = qsTr("Failed. Filename is too long."); break;
    case 4: msg = qsTr("The friend is not online."); break;
    case 5: msg = qsTr("Unexpected error."); break;
    }

    toast.show({ message : msg, duration : Toast.Long })
}

function updateFriendAvatar(friend_number) {
    for (var i = 0; i < friendsModel.count; i++) {
        var friend = friendsModel.get(i)

        if (friend.friendNumber === friend_number && !friend.request) {
            friend.updateAvatar = true
            friendsModel.set(i, friend)
        }
    }
}

/*[remove]*/ }
