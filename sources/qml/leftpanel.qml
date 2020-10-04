import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12
import QtGraphicalEffects 1.0

/*
  Left menu (drawer)
 */

/*[remove]*/ Item {

Drawer {
    id: drawer

    y: 0
    width: window.width * 0.7 / (inPortrait ? 1 : Screen.width / Screen.height)
    height: window.height

    modal: true
    interactive: true
    position: 0
    visible: false
    property bool dragEnabled: true
    dragMargin: dragEnabled ? 20 : 0
    z: z_drawer
    Behavior on position {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutCubic
        }
    }

    onOpened: {
        chatMessage.focus = false
        notification.cancel(Notification.Text, -1)
    }
    onClosed: {
        leftOverlayButton.highlighted = false
    }

    ListModel {
        id: friendsModel
        function swap(slot1, slot2) {
            var min = Math.min(slot1, slot2);
            var max = Math.max(slot1, slot2);
            if (slot1 > slot2) {
                move(min, max, 1);
            } else {
                move(max, min, 1);
            }
        }
    }
    Item {
        anchors.fill: parent
        ColumnLayout {
            id: leftBarLayout
            spacing: 0
            RowLayout {
                id: accountLayout
                spacing: 0
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 4
                Image {
                    id: accountAvatar
                    Layout.alignment: Qt.AlignLeft
                    Layout.leftMargin: 4
                    Layout.maximumHeight: accountName.height
                    Layout.maximumWidth: accountName.height
                    antialiasing: true
                    cache: false
                    property string avatarPath
                    source: safe_bridge().checkFileImage(avatarPath) ? 
                                "file://" + avatarPath : identiconBuffer.getImageSource(0, true)
                    layer.enabled: true
                    Rectangle {
                        id: accountAvatarMask
                        anchors.fill: parent
                        radius: width * 0.1
                        visible: false
                    }
                    layer.effect: OpacityMask {
                        maskSource: accountAvatarMask
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            changeAvatarImage.source = bridge.checkFileImage(parent.avatarPath) ? 
                                        "file://" + parent.avatarPath : identiconBuffer.getImageSource(0, true)
                            changeAvatarMenu.open()
                        }
                    }
                }
                ItemDelegate {
                    id: accountName
                    leftPadding: 4
                    rightPadding: 4
                    font.pointSize: fontMetrics.normalize(12)
                    font.bold: true
                    Layout.alignment: Qt.AlignLeft
                    Layout.fillWidth: true
                    implicitWidth: drawer.width * 0.5
                    onClicked: {
                        profileMenu.open()
                    }
                }
                Menu {
                    id: accountStatusMenu
                    z: z_menu_elements
                    property real textWidth
                    width: textWidth + 50
                    Repeater {
                        model: [[qsTr("Online"), getUserTheme().onlineStatusColor],
                            [qsTr("Away"), getUserTheme().awayStatusColor],
                            [qsTr("Busy"), getUserTheme().busyStatusColor]]
                        delegate: MenuItem {
                            RowLayout {
                                anchors.fill: parent
                                Text {
                                    Layout.alignment: Qt.AlignLeft
                                    Layout.leftMargin: 10
                                    text: modelData[0]
                                    wrapMode: Text.Wrap
                                    Component.onCompleted: {
                                        accountStatusMenu.textWidth = Math.max(accountStatusMenu.textWidth, contentWidth)
                                    }
                                }
                                Rectangle {
                                    Layout.alignment: Qt.AlignRight
                                    Layout.rightMargin: 10
                                    color: modelData[1]
                                    width: 15
                                    height: width
                                    border.color: "black"
                                    border.width: 1
                                    radius: width * 0.5
                                }
                            }
                            onClicked: {
                                bridge.setStatus(index)
                                statusIndicator.setStatus(index)
                            }
                        }
                    }
                    onClosed: {
                        currentIndex = -1
                    }
                }
                Button {
                    id: accountStatus
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.rightMargin: 10
                    Rectangle {
                        id: statusIndicator
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15
                        height: width
                        border.color: getTheme().primaryTextColor
                        border.width: 1
                        radius: width * 0.5
                        property int index: -1
                        function setStatus(status) {
                            switch (status) {
                            case 0: color = getUserTheme().onlineStatusColor; break;
                            case 1: color = getUserTheme().awayStatusColor; break;
                            case 2: color = getUserTheme().busyStatusColor; break;
                            case 3: color = getUserTheme().offlineStatusColor; break;
                            }
                            index = status
                        }
                    }
                    Text {
                        id: statusArrow
                        text: "\uE64B"
                        font.family: themify.name
                        font.pointSize: 10
                        font.bold: true
                        anchors.left: statusIndicator.right
                        anchors.leftMargin: 20
                        anchors.verticalCenter: statusIndicator.verticalCenter
                        transform: Rotation { 
                            origin.x: statusArrow.width * 0.5
                            origin.y: statusArrow.height * 0.5
                            angle: accountStatusMenu.visible ? -180 : 0
                            Behavior on angle {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.Linear
                                }
                            }
                        }
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
                font.pointSize: fontMetrics.normalize(12)
                Layout.alignment: Qt.AlignHCenter
            }
            MenuSeparator { 
                id: drawerSeparator
                implicitWidth: drawer.width 
                bottomPadding: 0
            }
            property int draggedItem: -1
            ListView {
                id: friends
                model: friendsModel
                flickableDirection: Flickable.VerticalFlick
                boundsMovement: Flickable.StopAtBounds
                clip: true
                ScrollIndicator.vertical: ScrollIndicator {}
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignBottom
                Layout.preferredHeight: window.height - 
                                        controlsLayout.height -
                                        accountLayout.height -
                                        connectionStatus.height - connectionStatus.topPadding - connectionStatus.bottomPadding -
                                        drawerSeparator.height - drawerSeparator.topPadding
                delegate: RowLayout {
                    id: friendLayout
                    spacing: 0
                    property int itemHeight: 40
                    property bool dragEntered: false
                    property bool dragStarted: false
                    property int default_x
                    property int default_y
                    property real addWidth
                    function savePosition() {
                        default_x = x
                        default_y = y
                    }
                    Component.onCompleted: {
                        if (friends.contentHeight > friends.Layout.preferredHeight) {
                            var count = Math.floor(friends.Layout.preferredHeight / itemHeight)
                            friends.Layout.preferredHeight = itemHeight * count
                        }
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
                    property bool dragActive: false
                    onDragActiveChanged: {
                        if (dragActive) {
                            friendItemAnimationXBehavior.enabled = true
                            friendItemAnimationYBehavior.enabled = true
                            savePosition()
                            leftBarLayout.draggedItem = index
                            dragStarted = true
                            Drag.start()
                            z = z_top
                        } else {
                            if (Drag.target === this) {
                                return
                            }
                            if (Drag.target !== null) {
                                friendItemAnimationXBehavior.enabled = false
                                friendItemAnimationYBehavior.enabled = false
                                Drag.drop()
                                if (dragStarted) {
                                    x = default_x
                                    dragStarted = false
                                }
                            } else {
                                Drag.cancel()
                                resetPosition()
                                dragStarted = false
                            }
                            z = z_friend_item
                        }
                    }
                    Loader {
                        Component {
                            id: friendItemStatusIndicatorComponent
                            Rectangle {
                                id: friendItemStatusIndicatorBody
                                z: z_friend_icon
                                width: friendLayout.itemHeight
                                height: friendLayout.itemHeight
                                Layout.alignment: Qt.AlignLeft
                                color: (friendLayout.dragEntered && !friendLayout.dragActive) ? "lightgray" : "#00000000"
                                Component.onCompleted: {
                                    friendLayout.addWidth += width
                                }
                                MouseArea {
                                    id: friendDragAreaIndicator
                                    anchors.fill: parent
                                    drag.target: friendLayout
                                    enabled: friendsModel.count > 1
                                    readonly property bool dragActive: drag.active
                                    onDragActiveChanged: {
                                        friendLayout.dragActive = dragActive
                                    }
                                }
                                Rectangle {
                                    id: friendItemStatusIndicator
                                    color: statusColor
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
                                    enabled: !friendLayout.dragActive
                                    onEntered: {
                                        if (!request) {
                                            friendLayout.dragEntered = true
                                        }
                                    }
                                    onExited: {
                                        if (!request) {
                                            friendLayout.dragEntered = false
                                        }
                                    }
                                    onDropped: {
                                        if (!request) {
                                            friendLayout.dragEntered = false
                                            friendsModel.get(leftBarLayout.draggedItem).dragStarted = false
                                            friendsModel.swap(index, leftBarLayout.draggedItem)
                                        }
                                    }
                                }
                            }
                        }
                        sourceComponent: request ? undefined : friendItemStatusIndicatorComponent
                    }
                    Loader {
                        Component {
                            id: friendItemAvatarComponent
                            Rectangle {
                                id: avatarContent
                                width: friendItem.height
                                height: width
                                color: (friendLayout.dragEntered && !friendLayout.dragActive) ? "lightgray" : "#00000000"
                                Layout.alignment: Qt.AlignLeft
                                Component.onCompleted: {
                                    friendLayout.addWidth += width
                                }
                                property bool updateFriendItemAvatar
                                Binding {
                                    target: avatarContent
                                    property: "updateFriendItemAvatar"
                                    value: updateAvatar
                                    when: !avatarContent.updateFriendItemAvatar
                                    delayed: true
                                }
                                onUpdateFriendItemAvatarChanged: {
                                    if (updateFriendItemAvatar) {
                                        friendItemAvatar.source = bridge.checkFileImage(friendItemAvatar.avatarPath) ? 
                                                    "file://" + friendItemAvatar.avatarPath : identiconBuffer.getImageSource(friendNumber, false)
                                        updateAvatar = false
                                        updateFriendItemAvatar = false
                                    }
                                }
                                Image {
                                    anchors.fill: parent
                                    id: friendItemAvatar
                                    readonly property string avatarPath: safe_bridge().getFriendAvatarPath(friendNumber)
                                    source: safe_bridge().checkFileImage(avatarPath) ? 
                                                "file://" + avatarPath : identiconBuffer.getImageSource(friendNumber, false)
                                    antialiasing: true
                                    layer.enabled: true
                                    Rectangle {
                                        id: friendItemAvatarMask
                                        anchors.fill: parent
                                        radius: width * 0.1
                                        visible: false
                                    }
                                    layer.effect: OpacityMask {
                                        maskSource: friendItemAvatarMask
                                    }
                                }
                                MouseArea {
                                    id: friendDragAreaAvatar
                                    anchors.fill: parent
                                    drag.target: friendLayout
                                    drag.axis: friendsModel.count > 1 ? Drag.XAndYAxis : Drag.None
                                    readonly property bool dragActive: drag.active
                                    onDragActiveChanged: {
                                        friendLayout.dragActive = dragActive
                                    }
                                    onClicked: {
                                        friendInfoMenu.prepareAndOpen(friendNumber)
                                    }
                                }
                                DropArea {
                                    anchors.fill: parent
                                    enabled: !friendLayout.dragActive
                                    onEntered: {
                                        if (!request) {
                                            friendLayout.dragEntered = true
                                        }
                                    }
                                    onExited: {
                                        if (!request) {
                                            friendLayout.dragEntered = false
                                        }
                                    }
                                    onDropped: {
                                        if (!request) {
                                            friendLayout.dragEntered = false
                                            friendsModel.get(leftBarLayout.draggedItem).dragStarted = false
                                            friendsModel.swap(index, leftBarLayout.draggedItem)
                                        }
                                    }
                                }
                            }
                        }
                        sourceComponent: request ? undefined : friendItemAvatarComponent
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
                                addFriendDialog.friendToxIdHex = friendToxIdHex
                                addFriendDialog.item_index = index
                                addFriendDialog.open()
                                return
                            }
                            drawer.close()
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
                                implicitWidth -= parent.addWidth
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
            RowLayout {
                id: controlsLayout
                Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter
                Layout.rightMargin: 8
                Layout.topMargin: 10
                ToolButton {
                    id: addFriendButton
                    Layout.alignment: Qt.AlignLeft
                    Text {
                        text: "\uE61A"
                        color: getTheme().primaryTextColor
                        anchors.centerIn: parent
                        font.family: themify.name
                        font.pointSize: 24
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        addFriendMenu.popup()
                    }
                }
                ToolButton {
                    id: showMyInfoButton
                    Layout.alignment: Qt.AlignCenter
                    Text {
                        text: "\uE602"
                        color: getTheme().primaryTextColor
                        anchors.centerIn: parent
                        font.family: themify.name
                        font.pointSize: 24
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        profileInfoMenu.popup()
                    }
                }
                ToolButton {
                    id: showSettingsButton
                    Layout.alignment: Qt.AlignRight
                    Text {
                        text: "\uE60F"
                        color: getTheme().primaryTextColor
                        anchors.centerIn: parent
                        font.family: themify.name
                        font.pointSize: 24
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        settingsWindow.open()
                    }
                }
            }
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
    property variant friendToxIdHex: ""
    onYes: {
        friendsModel.remove(item_index)
        var error = bridge.addFriend(friendToxIdHex)
        if (error > 0) {
            toast.show({ message : qsTr("addFriend failed, error code: ") + error, duration : Toast.Long });
        } else {
            bridge.saveProfile()
        }
    }
    onNo: {
        friendsModel.remove(item_index)
    }
}

/*[remove]*/ }
