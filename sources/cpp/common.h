#ifndef COMMON_H
#define COMMON_H

// C++
#include <iostream>
using std::unique_ptr;
using std::make_unique;

// Qt
#include <QString>
#include <QObject>
#include <QQmlContext>
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QQmlComponent>
#include <QTimer>
#include <QPointer>
#include <QtSql/QSqlDatabase>
#include <QtSql/QSqlQuery>
#include <QtSql/QSqlError>
#include <QDateTime>
#include <QClipboard>
#include <QtConcurrent/QtConcurrent>
#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTextBoundaryFinder>
#include <QImageReader>
#include <QAtomicInteger>

#if defined (Q_OS_ANDROID)
#include <QAndroidService>
#include <QtAndroid>
#include <QAndroidJniObject>
#include <QAndroidJniEnvironment>
#include <QAndroidIntent>
#include <QAndroidActivityResultReceiver>
#endif

#endif // COMMON_H
