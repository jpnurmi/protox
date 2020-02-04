QT += quick sql androidextras multimedia
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
        db.cpp \
        main.cpp \
        toasts.cpp \
        tools.cpp \
        tox.cpp

LIBS += -L$$PWD/libs/ -ltoxcore

RESOURCES += qml.qrc

extralib.target = extra
extralib.commands = echo "Running qmlcombiner.py"; \
                        cd $$PWD; \
                        python3 $$PWD/qmlcombiner.py $$PWD/main.qml $$PWD/app.qml

extralib.depends =

QMAKE_EXTRA_TARGETS += extralib
PRE_TARGETDEPS = extra

include(QtMobileNotification/QtMobileNotification.pri)
include(QtStatusBar/QtStatusBar.pri)
include(QZXing/QZXing.pri)


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
	qmlcombiner.py

contains(ANDROID_TARGET_ARCH,armeabi-v7a) {
	ANDROID_PACKAGE_SOURCE_DIR = \
		$$PWD/android

	ANDROID_EXTRA_LIBS = \
		$$PWD/libs/libtoxcore.so \
		$$PWD/libs/libtoxencryptsave.so \
		$$PWD/libs/libsodium.so
}

HEADERS += \
	common.h \
	db.h \
	main.h \
	toasts.h \
	tools.h \
	tox.h





