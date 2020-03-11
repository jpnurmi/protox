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
    closePolicy: profileCreation ? Popup.NoAutoClose : Popup.CloseOnEscape
    property bool profileSelected: false
    property bool profileCreation: false
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
        id: loginBackground
        anchors.fill: parent
        source: "login.png"

        Image {
            id: loginBackgroundNewProfile
            anchors.fill: parent
            source: "profileCreation.png"
            opacity: 0
        }

        NumberAnimation { id: loginFadeIn; target: loginBackgroundNewProfile; property: "opacity"; from: 0.0; to: 1.0 }
        NumberAnimation { id: loginFadeOut; target: loginBackgroundNewProfile; property: "opacity"; from: 1.0; to: 0.0 }

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
                        loginPassword.visible = bridge.checkProfileEncrypted(modelData)
                        loginPassword.clear()
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
            visible: !loginWindow.profileCreation
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No profile selected"
            onClicked: {
                accountMenu.popup(x, y)
            }
        }

        TextField {
            id: loginUsername
            visible: loginWindow.profileCreation
            width: parent.width * 0.75
            placeholderText: qsTr("Username")
            anchors.centerIn: accountSelectionButton
            inputMethodHints: Qt.ImhSensitiveData
            color: "white"
            placeholderTextColor: "gray"
            horizontalAlignment: TextInput.AlignHCenter
            background: Rectangle {
                color: loginUsername.activeFocus ? Material.primaryHighlightedTextColor : "gray"
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

        TextField {
            id: loginPassword
            visible: false
            property bool lastVisible: false
            width: parent.width * 0.75
            placeholderText: qsTr("Password")
            anchors.top: accountSelectionButton.bottom
            anchors.topMargin: 32
            anchors.horizontalCenter: accountSelectionButton.horizontalCenter
            inputMethodHints: Qt.ImhSensitiveData
            color: "white"
            placeholderTextColor: "gray"
            echoMode: TextInput.Password
            passwordCharacter: "*"
            horizontalAlignment: TextInput.AlignHCenter
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
            onAccepted: {
                focus = false
            }
        }

        Button {
            id: loginButton
            width: parent.width * 0.75
            y: (parent.height - height) * 0.8
            anchors.horizontalCenter: loginPassword.horizontalCenter
            text: (loginWindow.profileCreation ? qsTr("Create") : qsTr("Select")) + " " + qsTr("profile")
            onClicked: {
                if (loginWindow.profileCreation && loginPassword.text.length === 0) {
                    toast.show({ message : qsTr("Specify a user name."), duration : Toast.Short })
                    return
                }
                var profile = loginWindow.profileCreation ? loginUsername.text + ".tox" : accountSelectionButton.text
                var error = signInProfile(profile, loginWindow.profileCreation, loginPassword.text)
                if (error > 0) {
                    var reason;
                    switch (error) {
                    case 1: reason = qsTr("Profile loading failed."); break;
                    case 2: reason = qsTr("Wrong password."); break;
                    case 3: reason = qsTr("Profile doesn't exist."); break;
                    }
                    toast.show({ message : reason, duration : Toast.Short });
                    return
                }
                loginWindow.profileSelected = true
                loginWindow.close()
            }
        }
        Button {
            id: createNewProfileButton
            width: parent.width * 0.75
            visible: !loginWindow.profileCreation
            anchors.top: loginButton.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: loginButton.horizontalCenter
            text: qsTr("Create profile")
            onClicked: {
                loginWindow.profileCreation = true
                loginPassword.lastVisible = loginPassword.visible
                loginPassword.visible = true
                loginFadeIn.start()
            }
        }
        Keys.onBackPressed: {
            loginWindow.profileCreation = false
            loginPassword.visible = loginPassword.lastVisible
            loginFadeOut.start()
        }
    }

    onClosed: {
        if (!profileSelected) {
            Qt.quit()
        }
    }
}
