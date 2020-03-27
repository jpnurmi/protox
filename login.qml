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
    NumberAnimation { id: loginWindowReopenAnimation; target: loginWindow; property: "opacity"; from: 0.0; to: 1.0 }
    function reopen(remove) {
        notification.cancelAll()
        profileSelected = false
        open()
        loginWindowReopenAnimation.start()
        resetUI()
        goBack(false, remove)
        loginPassword.visible = bridge.checkProfileEncrypted(accountMenu.profileName)
    }
    function goBack(fadeout, logout) {
        loginWindow.profileCreation = false
        loginPassword.visible = loginPassword.lastVisible
        if (fadeout) {
            loginFadeOut.start()
        } else {
            loginBackgroundNewProfile.opacity = 0
        }
        loginUsername.focus = false
        loginPassword.focus = false
        profileRepeater.updateList(logout)
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

        ToolButton {
            id: goBackButton
            visible: loginWindow.profileCreation
            Text {
                text: "\uE629"
                anchors.centerIn: parent
                font.family: themify.name
                font.pointSize: 28
                font.bold: true
                color: parent.highlighted ? Material.highlightedButtonColor : "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                highlighted = true
                loginWindow.goBack(true, false)
            }
            anchors.left: parent.left
            anchors.top: parent.top
        }

        Menu {
            id: accountMenu
            z: z_top
            implicitWidth: accountSelectionButton.width
            property string profileName
            Repeater {
                id: profileRepeater
                model: []
                MenuItem {
                    text: modelData
                    onClicked: {
                        accountMenu.profileName = modelData
                        accountSelectionButton.text = modelData
                        loginPassword.visible = bridge.checkProfileEncrypted(modelData)
                        loginPassword.clear()
                    }
                }
                function updateList(select) {
                    var list = bridge.getProfileList()
                    model = list
                    if (list.length > 0) {
                        if (select || list.length === 1) {
                            accountSelectionButton.text = list[0]
                            accountMenu.profileName = list[0]
                        }
                        loginPassword.visible = bridge.checkProfileEncrypted(accountMenu.profileName)
                        accountSelectionButton.additiveVisible = true
                    } else {
                        accountSelectionButton.text = ""
                        accountMenu.profileName = ""
                        accountSelectionButton.additiveVisible = false
                    }
                }
                Component.onCompleted: {
                    profileRepeater.updateList(true)
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
            property bool additiveVisible: true
            visible: !loginWindow.profileCreation && additiveVisible
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
            onAccepted: {
                focus = false
                loginPassword.focus = true
            }
        }

        TextField {
            id: loginPassword
            visible: false
            property bool lastVisible: false
            width: parent.width * 0.75
            placeholderText: qsTr("Password") + (loginWindow.profileCreation ? " " + qsTr("(optional)") : "")
            anchors.top: accountSelectionButton.bottom
            anchors.topMargin: 16
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
                // disabled due to graphical bug
                /*
                if (!loginWindow.profileCreation) {
                    loginButton.login()
                    return
                }
                */
                loginImage.focus = true
            }
        }

        Button {
            id: loginButton
            width: parent.width * 0.75
            y: (parent.height - height) * 0.8
            anchors.horizontalCenter: loginPassword.horizontalCenter
            text: (loginWindow.profileCreation ? qsTr("Create") : qsTr("Select")) + " " + qsTr("profile")
            visible: loginWindow.profileCreation || accountMenu.profileName.length > 0
            function login() {
                if (loginWindow.profileCreation && loginUsername.text.length === 0) {
                    toast.show({ message : qsTr("Specify a user name."), duration : Toast.Long })
                    return
                }
                var profile = loginWindow.profileCreation ? loginUsername.text + ".tox" : accountMenu.profileName
                loginWindow.enabled = false
                if (loginPassword.text.length > 0 && !loginWindow.profileCreation) {
                    toast.show({ message : qsTr("Decrypting profile..."), duration : Toast.Short })
                }
                var error = signInProfile(profile, loginWindow.profileCreation, loginPassword.text)
                if (error > 0) {
                    var reason;
                    switch (error) {
                    case 1: reason = qsTr("Profile loading failed."); break;
                    case 2: reason = qsTr("Wrong password."); break;
                    case 3: reason = qsTr("Profile doesn't exist."); break;
                    case 4: reason = qsTr("Profile with this name already exists."); break;
                    case 5: reason = qsTr("Password is empty."); break;
                    }
                    toast.show({ message : reason, duration : Toast.Short });
                    loginWindow.enabled = true
                    return
                }
                loginWindow.profileSelected = true
                loginWindow.close()
                loginPassword.clear()
                loginUsername.clear()
            }
            onClicked: login()
        }
        Button {
            id: createNewProfileButton
            width: parent.width * 0.75
            visible: !loginWindow.profileCreation
            anchors.top: loginButton.bottom
            anchors.topMargin: 48
            anchors.horizontalCenter: loginButton.horizontalCenter
            text: qsTr("Create profile")
            background: Rectangle {
                color: createNewProfileButton.pressed ? Material.highlightedButtonColor : "green"
                radius: 2
            }
            onClicked: {
                loginWindow.profileCreation = true
                loginPassword.lastVisible = loginPassword.visible
                loginPassword.visible = true
                loginFadeIn.start()
                loginPassword.focus = false
                goBackButton.highlighted = false
            }
        }
        Keys.onBackPressed: {
            loginWindow.goBack(true, false)
        }
    }

    onAboutToHide: {
        if (!profileSelected) {
            Qt.quit()
        }
    }
    onClosed: {
        loginWindow.enabled = true
    }
}
