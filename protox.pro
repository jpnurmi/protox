QT += quick sql androidextras
CONFIG += c++14 qzxing_qml

# The following define makes your compiler emit warnings if you use
# any Qt feature that has been marked deprecated (the exact warnings
# depend on your compiler). Refer to the documentation for the
# deprecated API to know how to port your code away from it.
DEFINES += QT_DEPRECATED_WARNINGS

# You can also make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
# You can also select to disable deprecated APIs only up to a certain version of Qt.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

SOURCES += \
	sources/cpp/db.cpp \
	sources/cpp/main.cpp \
	sources/cpp/toasts.cpp \
	sources/cpp/tools.cpp \
	sources/cpp/tox.cpp

HEADERS += \
	sources/cpp/common.h \
	sources/cpp/db.h \
	sources/cpp/main.h \
	sources/cpp/qtutf8bytelimitvalidator.h \
	sources/cpp/toasts.h \
	sources/cpp/tools.h \
	sources/cpp/tox.h

LIBS += -ltoxcore -ltoxencryptsave

RESOURCES += qml.qrc

extralib.target = extra
extralib.commands = echo "Running qmlcombiner.py"; \
                        cd $$PWD/sources/qml/; \
                        python3 $$PWD/tools/qmlcombiner.py $$PWD/sources/qml/main.qml $$PWD/.generated/app.qml

extralib.depends =

QMAKE_EXTRA_TARGETS += extralib
PRE_TARGETDEPS = extra

include(deps/QtMobileNotification/QtMobileNotification.pri)
include(deps/QtStatusBar/QtStatusBar.pri)
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
	android/src/activity/KeyboardProvider.java \
	tools/qmlcombiner.py \
	sources/qml/chatarea.qml \
	sources/qml/functions.qml \
	sources/qml/header.qml \
	sources/qml/leftpanel.qml \
	sources/qml/main.qml \
	sources/qml/menus.qml \
	sources/qml/settings.qml \
	sources/qml/login.qml

ANDROID_PACKAGE_SOURCE_DIR = \
	$$PWD/android

ANDROID_EXTRA_LIBS += \
	$$PWD/libs/armv7/libtoxcore.so \
	$$PWD/libs/armv7/libtoxencryptsave.so \
	$$PWD/libs/armv7/libsodium.so

ANDROID_EXTRA_LIBS += \
	$$PWD/libs/x86/libtoxcore.so \
	$$PWD/libs/x86/libtoxencryptsave.so \
	$$PWD/libs/x86/libsodium.so

contains(ANDROID_TARGET_ARCH,armeabi-v7a) {
	LIBS += -L$$PWD/libs/armv7
}

contains(ANDROID_TARGET_ARCH,x86) {
	LIBS += -L$$PWD/libs/x86
}







