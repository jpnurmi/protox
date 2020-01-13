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
	int getNotificationId();
};

#endif // QTANDROIDNotifier_H
