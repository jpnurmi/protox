import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12

/*
  Left menu (drawer)
 */

/*[remove]*/ Item {

Drawer {
    id: drawer

    y: 0
    width: window.width * 0.5 / (inPortrait ? 1 : Screen.width / Screen.height)
    height: window.height

    modal: true
    interactive: true
    position: 0
    visible: false
    property bool dragEnabled: true
    dragMargin: dragEnabled ? 20 : 0
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
        function smartMove(slot1, slot2) {
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
                ItemDelegate {
                    id: accountName
                    leftPadding: 4
                    rightPadding: 4
                    font.pointSize: fontMetrics.normalize(12)
                    font.bold: true
                    Layout.alignment: Qt.AlignLeft
                    Layout.leftMargin: 4
                    Layout.fillWidth: true
                    implicitWidth: drawer.width * 0.6
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
                        model: [[qsTr("Online"), "lightgreen"],[qsTr("Away"), "yellow"],[qsTr("Busy"), "red"]/*,[qsTr("Offline"), "gray"]*/]
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
                                //if (index < 3) {
                                    bridge.setStatus(index)
                                //} 
                                statusIndicator.setStatus(index)
                                //bridge.changeConnection(index != 3)
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
                    Layout.rightMargin: 10
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
                    }
                    Text {
                        text: "\uE64B"
                        font.family: themify.name
                        font.pointSize: 10
                        font.bold: true
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
                    property bool dragActive: friendDragAreaIndicator.drag.active
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
                    
                    Rectangle {
                        id: friendItemStatusIndicatorBody
                        z: z_friend_icon
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
                            enabled: friendsModel.count > 1
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
                                    friendsModel.smartMove(index, leftBarLayout.draggedItem)
                                }
                            }
                        }
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
                                    friendsModel.smartMove(index, leftBarLayout.draggedItem)
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
    property variant friendPk: ""
    onYes: {
        friendsModel.remove(item_index)
        var error = bridge.addFriend(friendPk)
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
