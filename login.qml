import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12
import QtGraphicalEffects 1.0
import QtQuick.Controls.Styles 1.4

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
                        loginPassword.visible = bridge.checkProfileEncrypted(modelData + ".tox")
                    }
                }
            }
        }

        Image {
            id: loginImage
            source: "logo_big.png"
            smooth: true
            anchors.bottom: accountSelectionButton.top
            anchors.bottomMargin: 48
            anchors.horizontalCenter: accountSelectionButton.horizontalCenter
            width: 142
            height: 142 * (sourceSize.height / sourceSize.width)
        }

        DropShadow {
            id: loginImageGlow
            anchors.fill: loginImage
            radius: 8
            spread: 0.4
            samples: 17
            horizontalOffset: 0
            verticalOffset: 0
            color: "#C400AB"
            source: loginImage
            property int duration: 4000
            SequentialAnimation {
                id: loginImageGlowAnimation
                running: true
                loops: Animation.Infinite
                NumberAnimation { target: loginImageGlow; property: "spread"; to: 0.4; duration: loginImageGlow.duration * 0.5 }
                NumberAnimation { target: loginImageGlow; property: "spread"; to: 0; duration: loginImageGlow.duration * 0.5 }
            }
        }

        Button {
            id: accountSelectionButton
            y: (height + parent.height) * 0.4
            width: parent.width * 0.75
            height: 50
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No profile selected"
            Layout.alignment: Qt.AlignCenter
            onClicked: {
                accountMenu.popup(x, y)
            }
        }

        TextField {
            id: loginPassword
            width: parent.width * 0.75
            anchors.top: accountSelectionButton.bottom
            anchors.topMargin: 32
            anchors.horizontalCenter: accountSelectionButton.horizontalCenter
            inputMethodHints: Qt.ImhSensitiveData
            color: "white"
            background: Rectangle {
                color: loginPassword.activeFocus ? Material.primaryHighlightedTextColor : "gray"
                height: 2
                width: parent.width
                anchors.bottom: parent.bottom
            }
            onPressed: {
                if (!window.keyboardActive) {
                    focus = false
                }
                forceActiveFocus()
                cursorPosition = positionAt(event.x, event.y)
                if (selectedText.length > 0) {
                    deselect()
                    cursorPosition = positionAt(event.x, event.y)
                }
                event.accepted = false
            }
        }

        Button {
            id: loginButton
            width: parent.width * 0.75
            y: (parent.height - height) * 0.9
            anchors.horizontalCenter: loginPassword.horizontalCenter
            text: qsTr("Select profile")
            Layout.alignment: Qt.AlignCenter
            onClicked: {
                if (!signInProfile(accountSelectionButton.text)) {
                    toast.show({ message : qsTr("Profile loading failed."), duration : Toast.Short });
                    return
                }
                loginWindow.profileSelected = true
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
