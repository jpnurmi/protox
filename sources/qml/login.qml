import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12
import QtGraphicalEffects 1.0
import QtQuick.Controls.Styles 1.4
import QtQuick.Particles 2.12

Popup {
    id: loginWindow
    z: z_top
    width: window.width
    height: window.height
    visible: true
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    closePolicy: profileCreation ? Popup.NoAutoClose : Popup.CloseOnEscape
    property bool profileSelected: false
    property bool profileCreation: false
    onProfileCreationChanged: {
        if (profileCreation) {
            if (inPortrait) {
                statusBar.color = getApplicationTheme().loginProfileCreationPrimaryColor
            } else {
                statusBar.color = getApplicationTheme().loginProfileCreationPrimaryLandscapeColor
            }
        } else {
            statusBar.color = getApplicationTheme().loginPrimaryColor
        }
    }
    property bool instantFadeOut: false
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
        onInPortraitChanged: {
            if (loginWindow.profileCreation) {
                if (inPortrait) {
                    statusBar.color = getApplicationTheme().loginProfileCreationPrimaryColor
                } else {
                    statusBar.color = getApplicationTheme().loginProfileCreationPrimaryLandscapeColor
                }
            }
        }
    }
    enter: Transition {}
    exit: Transition { 
        NumberAnimation { property: "opacity"; from: loginWindow.instantFadeOut ? 0 : 1.0; to: 0.0 } 
    }
    NumberAnimation { id: loginWindowReopenAnimation; target: loginWindow; property: "opacity"; from: 0.0; to: 1.0 }
    // tip: "remove" means: select the first available profile entry
    function reopen(remove, instant) {
        instantFadeOut = false
        enabled = true
        notification.cancelAll()
        profileSelected = false
        statusBar.color = getApplicationTheme().loginPrimaryColor
        open()
        if (instant) {
            opacity = 1.0
        } else {
            loginWindowReopenAnimation.start()
        }
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
    function login(profileName) {
        if (loginWindow.profileCreation && loginUsername.text.length === 0) {
            toast.show({ message : qsTr("Specify a user name."), duration : Toast.Long })
            return
        }
        var profile
        var doAutoLogin = profileName !== undefined && profileName.length > 0
        if (doAutoLogin) {
            profile = profileName
        } else {
            profile = loginWindow.profileCreation ? loginUsername.text + ".tox" : accountMenu.profileName
        }
        loginWindow.enabled = false
        if (loginPassword.text.length > 0 && !loginWindow.profileCreation) {
            toast.show({ message : qsTr("Decrypting profile..."), duration : Toast.Short })
        }
        var error = signInProfile(profile, loginWindow.profileCreation, loginPassword.text, 
                                  doAutoLogin || (loginCheckbox.checked && loginCheckbox.visible))
        if (error > 0) {
            var reason;
            switch (error) {
            case 1: reason = qsTr("Profile loading failed."); break;
            case 2: reason = qsTr("Wrong password."); break;
            case 3: reason = qsTr("The profile doesn't exist."); break;
            case 4: reason = qsTr("A profile with this name already exists."); break;
            case 5: reason = (doAutoLogin ? qsTr("A password is required for this profile.") : qsTr("The password is empty.")); break;
            }
            toast.show({ message : reason, duration : Toast.Short });
            loginWindow.enabled = true
            if (doAutoLogin) {
                reopen(true, true)
                toast.show({ message : qsTr("Auto login failed!"), duration : Toast.Short });
            }
            return
        }
        loginWindow.profileSelected = true
        if (doAutoLogin) {
            instantFadeOut = true
        }
        statusBar.color = getTheme().primaryColor
        loginWindow.close()
        loginPassword.clear()
        loginUsername.clear()
    }

    Image {
        id: loginBackground
        anchors.fill: parent
        source: inPortrait ? "resources/login.png" : "resources/login_ls.png"

        Image {
            id: loginBackgroundNewProfile
            anchors.fill: parent
            source: inPortrait ? "resources/profileCreation.png" : "resources/profileCreation_ls.png"
            opacity: 0
        }

        ParticleSystem { id: particleSystem }
        Emitter {
            anchors.fill: loginImage
            startTime: 15000
            system: particleSystem
            emitRate: 2
            lifeSpan: 15000
            acceleration: PointDirection{
                y: -12
                xVariation: 2 
                yVariation: 2 
            }
            size: 24
            sizeVariation: 16
        }
    
        ImageParticle {
            source: "resources/particle.png"
            system: particleSystem
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
                color: parent.highlighted ? getTheme().highlightedButtonColor : "white"
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
            Connections {
                target: window
                onInPortraitChanged: {
                    accountMenu.visible = false
                }
            }
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
                        loginCheckbox.checked = bridge.getSettingsValue("Profile", "auto_login_profile", ptype_string, String("")) === modelData
                        bridge.setSettingsValue("Profile", "last_selected_profile", modelData)
                    }
                }
                function updateList(select) {
                    var list = bridge.getProfileList()
                    model = list
                    if (list.length > 0) {
                        if (select || list.length === 1) {
                            var last_selected_profile = bridge.getSettingsValue("Profile", "last_selected_profile", 
                                                                                ptype_string, String(""))
                            if (last_selected_profile.length > 0 && list.includes(last_selected_profile)) {
                                accountSelectionButton.text = last_selected_profile
                                accountMenu.profileName = last_selected_profile
                            } else {
                                accountSelectionButton.text = list[0]
                                accountMenu.profileName = list[0]
                            }
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
            source: "resources/logo_big.png"
            smooth: true
            x: inPortrait ? (parent.width - width) * 0.5 : (parent.width - width) * 0.15
            y: inPortrait ? (parent.height - height) * 0.1 : (parent.height - height) * 0.5
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

        ColumnLayout {
            x: inPortrait ? 0 : (parent.width - width) * 0.8
            y: (height + parent.height) * 0.3
            anchors.verticalCenter: inPortrait ? undefined : parent.verticalCenter
            anchors.horizontalCenter: inPortrait ? parent.horizontalCenter : undefined
            width: parent.width * (inPortrait ? 0.75 : 0.4)
            Button {
                id: accountSelectionButton
                height: 50
                property bool additiveVisible: true
                visible: !loginWindow.profileCreation && additiveVisible
                text: "No profile selected"
                Layout.fillWidth: true
                Layout.topMargin: 6
                onClicked: {
                    accountMenu.popup(parent.x, parent.y)
                }
            }
            TextField {
                id: loginUsername
                visible: loginWindow.profileCreation
                Layout.fillWidth: true
                Layout.topMargin: 6
                placeholderText: qsTr("Username")
                inputMethodHints: Qt.ImhSensitiveData
                color: "white"
                placeholderTextColor: "gray"
                horizontalAlignment: TextInput.AlignHCenter
                opacity: enabled ? 1.0 : 0.5
                background: Rectangle {
                    opacity: loginUsername.opacity
                    color: loginUsername.activeFocus ? getTheme().primaryHighlightedTextColor : "gray"
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
                placeholderText: loginWindow.profileCreation ? qsTr("Password (optional)") : qsTr("Password")
                inputMethodHints: Qt.ImhSensitiveData
                color: "white"
                placeholderTextColor: "gray"
                echoMode: TextInput.Password
                passwordCharacter: "*"
                horizontalAlignment: TextInput.AlignHCenter
                opacity: enabled ? 1.0 : 0.5
                Layout.fillWidth: true
                Layout.topMargin: 6
                background: Rectangle {
                    opacity: loginPassword.opacity
                    color: loginPassword.activeFocus ? getTheme().primaryHighlightedTextColor : "gray"
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
            CheckBox {
                id: loginCheckbox
                visible: !loginPassword.visible && profileRepeater.count > 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                implicitHeight: loginPassword.height
                enabled: loginButton.enabled
                opacity: enabled ? 1.0 : 0.5
                indicator: Rectangle {
                    opacity: loginCheckbox.opacity
                    implicitWidth: 20
                    implicitHeight: 20
                    x: loginCheckbox.leftPadding
                    y: parent.height / 2 - height / 2
                    border.color: loginCheckbox.down ? "#dark" : "#F5F5F5"
                    radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "\u2713"
                        font.bold: true
                        font.pointSize: 16
                        color: getTheme().highlightedButtonColor
                        visible: loginCheckbox.checked
                    }
                }
                contentItem: Text {
                    leftPadding: loginCheckbox.indicator.width + 4
                    text: qsTr("Auto-login")
                    wrapMode: Text.Wrap
                    color: "white"
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Button {
                id: loginButton
                text: loginWindow.profileCreation ? qsTr("Create profile") : qsTr("Log in")
                visible: loginWindow.profileCreation || accountMenu.profileName.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 24
                onClicked: loginWindow.login()
            }
            Button {
                id: createNewProfileButton
                visible: !loginWindow.profileCreation
                text: qsTr("Create profile")
                Layout.fillWidth: true
                Layout.topMargin: 42
                implicitHeight: loginButton.height
                opacity: enabled ? 1.0 : 0.5
                background: Rectangle {
                    opacity: createNewProfileButton.opacity
                    color: createNewProfileButton.pressed ? getTheme().highlightedButtonColor : getApplicationTheme().profileCreationButtonColor
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
        bridge.hideSplashScreen()
    }
}
