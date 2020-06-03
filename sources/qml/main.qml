import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.12
import QtMultimedia 5.12
import QtGraphicalEffects 1.0
import QtQuick.Controls.Styles 1.4
import QtQuick.Particles 2.12

import QtNotification 1.0
import QtStatusBar 1.0
import QtUtf8ByteLimitValidator 1.0
import QtToast 1.0
import QtPhotoDialog 1.0
import QtFolderDialog 1.0
import QZXing 2.3

import "qrc:/deps/jdenticon/jdenticon.js" as Jdenticon

ApplicationWindow {
    id: window
    visible: true
    readonly property string applicationVersion: "1.5beta"

    /*
      Window events
    */

    onInPortraitChanged: {
        Qt.inputMethod.hide()
        chatMessage.updateHeight()
    }

    onClosing: {
        // Keys.onBackPressed doesn't work
        attachFileButton.hideButtons()
        close.accepted = false
    }

    property bool appInactive
    onAppInactiveChanged: {
        if (!appInactive && keyboardActive) {
            Qt.inputMethod.show()
        }
        if (appInactive && absentTimer.interval > 0) {
            absentTimer.start()
        } else {
            absentTimer.stop()
            if (lastStatus != -1) {
                bridge.setStatus(lastStatus)
                statusIndicator.setStatus(lastStatus)
                lastStatus = -1
            }
        }
        if (!appInactive) {
            notification.cancel({ type : Notification.Text, id : bridge.getCurrentFriendNumber() })
        }
    }

    Connections {
        target: Qt.application
        onStateChanged: {
            // select friend when you click on notification
            if(Qt.application.state === Qt.ApplicationActive && notification.getNotificationId() !== -1) {
                settingsWindow.close()
                selectFriend(notification.getNotificationId(true))
            }
            appInactive = Qt.application.state === Qt.ApplicationSuspended
            bridge.setAppInactive(appInactive)
        }
    }

    property int lastStatus: -1
    Timer {
        id: absentTimer
        repeat: false
        interval: parseInt(safe_bridge().getSettingsValue("Client", "absent_timer_interval", 
                                          ptype_string, String("10"))) * 60 * 1000
        onTriggered: {
           lastStatus = bridge.getStatus()
           bridge.setStatus(1)
           statusIndicator.setStatus(1)
        }
    }

    property bool uiReady: false
    onUiReadyChanged: {
        if (uiReady) {
            var autoProfile = bridge.getSettingsValue("Profile", "auto_login_profile", ptype_string, String(""))
            if (autoProfile.length > 0) {
                loginWindow.login(autoProfile)
                return
            }
            loginWindow.open()
            bridge.hideSplashScreen()
        }
    }

    Component.onCompleted: {
        statusBar.theme = getTheme().Dark
        statusBar.color = getTheme().toolBarColor
    }

    Flickable {
        anchors.top: overlayHeader.bottom
        anchors.topMargin: 40
        width: parent.width
        height: parent.height
        contentWidth: parent.width
        contentHeight: overlayHeader.height + anchors.topMargin + welcomeImage.height + 
                       welcomeTextTitle.contentHeight + welcomeText.contentHeight + 
                       welcomeTextTitle.anchors.topMargin + welcomeText.anchors.topMargin
        enabled: cleanProfile
        flickableDirection: Flickable.VerticalFlick
        boundsMovement: Flickable.StopAtBounds
        Image {
            id: welcomeImage
            x: (window.width - width) * 0.5
            source: "resources/logo_big.png"
            smooth: true
            width: 142
            height: 142 * (sourceSize.height / sourceSize.width)
            visible: cleanProfile
        }
    
        Text {
            id: welcomeTextTitle
            x: (window.width - width) * 0.5
            width: window.width
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Welcome to Protox!")
            wrapMode: Text.Wrap
            font.bold: true
            font.pointSize: fontMetrics.normalizeAverage(32)
            anchors.top: welcomeImage.bottom
            anchors.topMargin: 40
            visible: cleanProfile
        }
    
        Text {
            id: welcomeText
            width: window.width
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("This is an alpha version of the Tox client.\nClick on the left button to open the friend list, then on «+» to add a new friend.\n\n Good luck!")
            wrapMode: Text.Wrap
            anchors.top: welcomeTextTitle.bottom
            anchors.topMargin: 20
            visible: cleanProfile
            leftPadding: 10
            rightPadding: leftPadding
        }
    }

    /*
      Basic elements
    */

    Notification {
        id: notification
    }

    StatusBar {
        id: statusBar
    }

    Toast {
        id: toast
    }

    FontLoader { 
        id: themify
        source: "resources/themify.ttf"
    }

    FontMetrics {
        id: fontMetrics
        property real defaultSize: 16
        function getFontScaling() {
            return font.pointSize / defaultSize
        }
        function normalize(size) {
            return size * getFontScaling()
        }
        function normalizeAverage(size) {
            return (defaultSize + normalize(size)) * 0.5
        }
    }

    // global properties
    property bool cleanProfile

    // global properties (static)
    readonly property bool inPortrait: window.width < window.height
    readonly property bool enableDrag: drawer.position === 0 && !contextMenuRight.visible
    readonly property int z_cloud: -1
    readonly property int z_friend_icon: -1
    readonly property int z_friend_item_background: 0
    readonly property int z_friend_item: 1
    readonly property int z_drawer: 2
    readonly property int z_overlay_header: 1
    readonly property int z_menu: 3
    readonly property int z_menu_elements: 4
    readonly property int z_top: Number.MAX_VALUE-1
    readonly property int z_splash: Number.MAX_VALUE
    readonly property real standardFontPointSize: 17.5
    readonly property int ptype_bool: 1
    readonly property int ptype_string: 10
    readonly property int fstate_request: 0
    readonly property int fstate_inprogress: 1
    readonly property int fstate_paused: 2
    readonly property int fstate_canceled: 3
    readonly property int fstate_finished: 4
    readonly property int fcontrol_resume: 0
    readonly property int fcontrol_pause: 1
    readonly property int fcontrol_cancel: 2
    readonly property int msgtype_text: 0
    readonly property int msgtype_file: 1

    /*
        Image buffers
    */

    // I don't need multiple images but this bug appears
    //https://forum.qt.io/topic/109114/qml-artifacts-android/9
    Repeater {
        id: canvasBuffer
        readonly property variant colors: ["lightgray", "orange", "lightblue"]
        model: colors
        property int imagesLoaded: 0
        readonly property bool ready: imagesLoaded === colors.length
        onReadyChanged: {
            if (ready) {
                uiReady = true
            }
        }
        delegate: Image { 
            id: cloudTailImageFrameBuffer 
            visible: false
            cache: true
            onStatusChanged: {
                if (status === Image.Ready) {
                    canvasBuffer.imagesLoaded++
                }
            }
            Canvas {
                id: cloudTailCanvas
                width: 256
                height: width
                visible: false
                onPaint: {
                    var cxt = getContext("2d");
                    cxt.beginPath();
                    cxt.moveTo(0, 0);
                    cxt.lineTo(0, height);
                    cxt.lineTo(width, 0);
                    cxt.closePath();
                    cxt.fillStyle = modelData;
                    cxt.fill();
                    grabToImage(function(result) { parent.source = result.url; });
                }
            }
        }
    }

    ListModel {
        id: identiconModel
        function appendIfNotExists(friend_number, self) {
            for (var i = 0; i < count; i++) {
                var identicon = get(i)
                if (identicon.friendNumber === friend_number && identicon.self === self) {
                    return
                }
            }
            append({"friendNumber" : friend_number, "self" : self})
        }
    }
    
    Repeater {
        id: identiconBuffer
        model: identiconModel
        function getImageSource(friend_number, self) {
            for (var i = 0; i < identiconModel.count; i++) {
                var identicon = identiconModel.get(i)
                if (identicon.friendNumber === friend_number && identicon.self === self) {
                    return identiconBuffer.itemAt(i).source
                }
            }
            return ""
        }
        delegate: Image {
            id: identiconImageFrameBuffer
            visible: false
            Canvas {
                id: identiconCanvas
                width: 256
                height: width
                visible: false
                onPaint: {
                    var cxt = getContext("2d");
                    var pk = self ? bridge.getToxId().substring(0, bridge.getToxPublicKeySizeHex()) 
                                  : bridge.getFriendPublicKeyHex(friendNumber)
                    Jdenticon.global.jdenticon_config = jdenticon_default_config
                    Jdenticon.global.jdenticon_config.hues = getJdenticonHues(pk)
                    Jdenticon.drawIcon(cxt, pk, width)
                    grabToImage(function(result) { parent.source = result.url; });
                }
            }
        }
    }

    //include: functions.qml
    //include: settings.qml
    //include: menus.qml
    //include: header.qml
    //include: leftpanel.qml
    //include: chatarea.qml
    //include: login.qml
}
