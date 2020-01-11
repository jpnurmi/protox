#ifndef COMMON_H
#define COMMON_H

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
#include <QFuture>
#include <QtConcurrent/QtConcurrent>

#if defined (Q_OS_ANDROID)
#include <QAndroidService>
#include <QtAndroid>
#include <QAndroidJniObject>
#include <QAndroidJniEnvironment>
#include <QAndroidIntent>
#endif

// Toxcore
#include "tox/tox.h"
#include "tox/toxencryptsave.h"

#endif // COMMON_H
