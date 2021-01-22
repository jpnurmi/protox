#ifndef NOTIFICATION_H
#define NOTIFICATION_H

#include "sources/cpp/common.h"

class QtNotification : public QObject
{
	Q_OBJECT

public:
	explicit QtNotification() {}

	Q_INVOKABLE void show(const QVariant &notificationParameters);
	Q_INVOKABLE void cancel(const QVariant &notificationParameters);
	Q_INVOKABLE void cancelAll();
	Q_INVOKABLE int getNotificationId(bool cancel = false);

	static void declareQML() ;

	enum Type {
		Text,
		FileRequest,
		FileProgress
	};
	Q_ENUM(Type)
};

#endif // NOTIFICATION_H
