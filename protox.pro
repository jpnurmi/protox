QT += quick sql androidextras
CONFIG += c++17 qzxing_qml silent

# Generate git sha1 hash for version
DEFINES += GIT_COMMIT_SHA1="\\\"$(shell git -C \""$$_PRO_FILE_PWD_"\" rev-parse --short HEAD)\\\""

# The following define makes your compiler emit warnings if you use
# any Qt feature that has been marked deprecated (the exact warnings
# depend on your compiler). Refer to the documentation for the
# deprecated API to know how to port your code away from it.
DEFINES += QT_DEPRECATED_WARNINGS

# You can also make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
# You can also select to disable deprecated APIs only up to a certain version of Qt.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

# Program sources

SOURCES += \
	sources/cpp/asyncfilemanager.cpp \
	sources/cpp/db.cpp \
	sources/cpp/main.cpp \
	sources/cpp/native.cpp \
	sources/cpp/qtutf8bytelimitvalidator.cpp \
	sources/cpp/settings.cpp \
	sources/cpp/tools.cpp \
	sources/cpp/tox.cpp

HEADERS += \
	sources/cpp/asyncfilemanager.h \
	sources/cpp/common.h \
	sources/cpp/db.h \
	sources/cpp/gitversion.h \
	sources/cpp/main.h \
	sources/cpp/native.h \
	sources/cpp/qtutf8bytelimitvalidator.h \
	sources/cpp/settings.h \
	sources/cpp/tools.h \
	sources/cpp/tox.h

# Native sources

android {
SOURCES += sources/cpp/native/android/photodialog.cpp \
	sources/cpp/native/android/folderdialog.cpp \
	sources/cpp/native/android/toasts.cpp \
	sources/cpp/native/android/qrcodescanner.cpp \
	sources/cpp/native/android/qandroidjniobjecttools.cpp
HEADERS += sources/cpp/native/android/photodialog.h \
	sources/cpp/native/android/folderdialog.h \
	sources/cpp/native/android/toasts.h \
	sources/cpp/native/android/qrcodescanner.h \
	sources/cpp/native/android/qandroidjniobjecttools.h
}

# Components 

SOURCES += \ 
	# Notifications
	sources/cpp/components/QtMobileNotification/QtNotification.cpp \
	sources/cpp/components/QtMobileNotification/QtNotifierFactory.cpp \
	# StatusBar
	sources/cpp/components/QtStatusBar/QtStatusBar.cpp
HEADERS += \ 
	# Notifications
	sources/cpp/components/QtMobileNotification/QtNotification.h \
	sources/cpp/components/QtMobileNotification/QtAbstractNotifier.h \
	sources/cpp/components/QtMobileNotification/QtNotifierFactory.h \
	# StatusBar
	sources/cpp/components/QtStatusBar/QtStatusBar.h \
	sources/cpp/components/QtStatusBar/QtStatusBar_p.h

android {
SOURCES += \
	# Notifications
	sources/cpp/components/QtMobileNotification/QtAndroidNotifier.cpp \
	# StatusBar
	sources/cpp/components/QtStatusBar/QtAndroidStatusBar.cpp
HEADERS += sources/cpp/components/QtMobileNotification/QtAndroidNotifier.h
}

LIBS += -ltoxcore -ltoxencryptsave

RESOURCES += qml.qrc

extralib.target = extra
extralib.commands = echo "Running qmlcombiner.py"; \
                        python3 $$PWD/tools/qmlcombiner.py $$PWD/sources/qml/main.qml $$PWD/.app.qml

extralib.depends =

QMAKE_EXTRA_TARGETS += extralib
PRE_TARGETDEPS = extra

include(translations/translations.pri)

include(deps/QZXing/QZXing.pri)
include(deps/sqlitecipher/sqlitecipher.pri)

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

DISTFILES += \
	android/AndroidManifest.xml \
	android/build.gradle \
	android/gradle/wrapper/gradle-wrapper.jar \
	android/gradle/wrapper/gradle-wrapper.properties \
	android/gradlew \
	android/gradlew.bat \
	android/res/values/libs.xml \
	android/src/notifications/QtAndroidNotifications.java \
	android/src/activity/QtActivityEx.java \
	android/src/activity/PersistentNotification.java \
	android/src/activity/ProtoxService.java \
	tools/qmlcombiner.py \
	sources/qml/chatarea.qml \
	sources/qml/functions.qml \
	sources/qml/header.qml \
	sources/qml/leftpanel.qml \
	sources/qml/main.qml \
	sources/qml/menus.qml \
	sources/qml/settings.qml \
	sources/qml/login.qml \
	sources/qml/debug.qml

ANDROID_PACKAGE_SOURCE_DIR = \
	$$PWD/android

ANDROID_ABIS = armeabi-v7a arm64-v8a

contains(ANDROID_ABIS, armeabi-v7a) {
	ANDROID_EXTRA_LIBS += \
		$$PWD/libs/armv7-a/libtoxcore.so \
		$$PWD/libs/armv7-a/libtoxencryptsave.so \
		$$PWD/libs/armv7-a/libsodium.so
}

contains(ANDROID_ABIS, arm64-v8a) {
	ANDROID_EXTRA_LIBS += \
		$$PWD/libs/armv8-a/libtoxcore.so \
		$$PWD/libs/armv8-a/libtoxencryptsave.so \
		$$PWD/libs/armv8-a/libsodium.so
}

contains(ANDROID_ABIS, x86) {
	ANDROID_EXTRA_LIBS += \
		$$PWD/libs/x86/libtoxcore.so \
		$$PWD/libs/x86/libtoxencryptsave.so \
		$$PWD/libs/x86/libsodium.so
}

contains(ANDROID_TARGET_ARCH, armeabi-v7a) {
	LIBS += -L$$PWD/libs/armv7-a
}

contains(ANDROID_TARGET_ARCH, arm64-v8a) {
	LIBS += -L$$PWD/libs/armv8-a
}

contains(ANDROID_TARGET_ARCH, x86) {
	LIBS += -L$$PWD/libs/x86
}
