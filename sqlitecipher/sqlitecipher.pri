QT += sql-private
CONFIG += c++11

INCLUDEPATH += $$PWD/sqlite

include(sqlite3/sqlite3.pri)

HEADERS += \
    $$PWD/sqlcachedresult_p.h \
    $$PWD/sqlitecipher_global.h \
    $$PWD/sqlitecipher_p.h

SOURCES += \
    $$PWD/sqlcachedresult.cpp \
    $$PWD/sqlitecipher.cpp

android {
    QT += androidextras

} else:ios {
    LIBS += -framework UIKit
}

