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

bool QtNotification::cancel(int id)
{
	return _Notifier == nullptr
			? false
			: _Notifier->cancel(id);
}

int QtNotification::getNotificationId(bool cancel)
{
	return _Notifier == nullptr
			? -1
			: _Notifier->getNotificationId(cancel);
}


void QtNotification::declareQML()
{
	qmlRegisterType<QtNotification>("QtNotification", 1, 0, "Notification");
}
