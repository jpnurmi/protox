import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12

Popup {
    id: loginWindow
    z: z_top
    width: window.width
    height: window.height
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    property bool profileSelected: false
    // enable adjustTop only for this window
    Connections {
        target: window
        onKeyboardActiveChanged: {
            if (loginWindow.visible) {
                bridge.setKeyboardAdjustMode(!window.keyboardActive)
            }
        }
        onFocusObjectChanged: {
            if (loginWindow.visible && window.keyboardActive) {
                bridge.setKeyboardAdjustMode(false)
            }
        }
    }
    enter: Transition {}
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0 }
        onRunningChanged: {
            if (!running) {
                splashImageDestroyAnimation.start()
            }
        }
    }

    Image {
        anchors.fill: parent
        source: "login.png"

        Menu {
            id: accountMenu
            z: z_top
            implicitWidth: accountSelectionButton.width
            Repeater {
                id: profileRepeater
                model: bridge.getProfileList()
                MenuItem {
                    text: modelData
                    onClicked: {
                        accountSelectionButton.text = modelData
                    }
                }
            }
        }

        Button {
            id: accountSelectionButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: (height + parent.height) * 0.5
            text: "No profile selected"
            Layout.alignment: Qt.AlignCenter
            onClicked: {
                accountMenu.popup(x, y)
            }
        }
        Button {
            id: loginButton
            anchors.top: accountSelectionButton.bottom
            anchors.horizontalCenter: accountSelectionButton.horizontalCenter
            text: qsTr("Select profile")
            Layout.alignment: Qt.AlignCenter
            onClicked: {
                loginWindow.profileSelected = true
                signInProfile(accountSelectionButton.text)
                loginWindow.close()
            }
        }
    }
    onClosed: {
        if (!profileSelected) {
            Qt.quit()
        }
    }
}
