CONFIG += c++11
INCLUDEPATH += $$PWD

HEADERS += \
    $$PWD/QtStatusBar.h \
    $$PWD/QtStatusBar_p.h

SOURCES += \
    $$PWD/QtStatusBar.cpp

android {
    QT += androidextras

    SOURCES += \
        $$PWD/QtAndroidStatusBar.cpp
} else:ios {
    LIBS += -framework UIKit

    OBJECTIVE_SOURCES += \
        $$PWD/QtIosStatusBar.mm
} else {
    SOURCES += \
        $$PWD/QtDummyStatusBar.cpp
}
