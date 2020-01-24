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
	bool cancel(int id);
	int getNotificationId(bool cancel = false);
};

#endif // QTANDROIDNotifier_H
