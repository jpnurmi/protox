#ifndef QANDROIDJNIOBJECTTOOLS_H
#define QANDROIDJNIOBJECTTOOLS_H

#include "sources/cpp/common.h"

namespace QAndroidJniObjectTools {
	QAndroidJniObject fromBool(bool value);
	QAndroidJniObject fromInt(int value);
	QAndroidJniObject fromLong(long long value);
	QAndroidJniObject fromVariantMap(const QVariantMap &value);
}

#endif // QANDROIDJNIOBJECTTOOLS_H
