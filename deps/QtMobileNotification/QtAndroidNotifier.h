#ifndef QTANDROIDNotifier_H
#define QTANDROIDNotifier_H

#include "QtAbstractNotifier.h"

#include <QtAndroid>

class QtAndroidNotifier : public QtAbstractNotifier
{
public:
	QtAndroidNotifier() {}

public:
	bool show(const QVariant &notificationParameters);
	bool cancel(const QVariant &notificationParameters);
	bool cancelAll();
	int getNotificationId(bool cancel = false);
private:
	jobject qVariantMapToJObject(const QVariantMap &map);
};

#endif // QTANDROIDNotifier_H
