import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12

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
                    Layout.leftMargin: 4
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
        Layout.fillWidth: true
        ToolButton {
            id: addFriendButton
            Layout.alignment: Qt.AlignLeft
            Text {
                text: "\uFF0B"
                anchors.fill: parent
                font.family: dejavuSans.name
                font.pointSize: 32
                font.bold: true
                fontSizeMode: Text.Fit
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
                text: "\u2302"
                anchors.fill: parent
                font.family: dejavuSans.name
                font.pointSize: 32
                font.bold: true
                fontSizeMode: Text.Fit
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                bottomPadding: 1
            }
            onClicked: {
                profileInfoMenu.popup()
            }
        }
        ToolButton {
            id: showSettingsButton
            Layout.alignment: Qt.AlignRight
            Text {
                text: "\u2699"
                anchors.fill: parent
                font.family: dejavuSans.name
                font.pointSize: 29
                font.bold: true
                fontSizeMode: Text.Fit
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                topPadding: 3
                rightPadding: 1
            }
            onClicked: {
                toast.show({ message: "Not implemented.", duration: Toast.Short })
            }
        }
    }
}
