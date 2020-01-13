#include "QtNotification.h"
#include "QtNotifierFactory.h"

QtNotification::QtNotification(QObject *parent)
	: QObject(parent)
	, _Notifier(nullptr)
{
	_Notifier = QtNotifierFactory::GetPlatformDependencyNotifier();
}

QtNotification::~QtNotification()
{
	if (_Notifier != nullptr) {
		delete _Notifier;
	}
}

bool QtNotification::show(const QVariant &notificationParameters)
{
	return _Notifier == nullptr
			? false
			: _Notifier->show(notificationParameters);
}


int QtNotification::getNotificationId()
{
	return _Notifier == nullptr
			? -1
			: _Notifier->getNotificationId();
}


void QtNotification::declareQML()
{
	qmlRegisterType<QtNotification>("QtNotification", 1, 0, "Notification");
}
