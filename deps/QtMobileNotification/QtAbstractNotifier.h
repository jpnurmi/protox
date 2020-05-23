
#ifndef QTABSTRACTNOTIFICATOR
#define QTABSTRACTNOTIFICATOR

#include <QObject>

/**
 * @class QtAbstractNotifier The interface for generic notification
 * @brief The class which contains properties for notifications such as
 *		hide, show notifications
 *
 * Each method returns a boolean indicating whether the notifications are
 * supported or not
 */

class QtAbstractNotifier : public QObject
{
	Q_OBJECT

public:
	virtual bool show(const QVariant &notificationParameters) = 0;
	virtual bool cancel(int type, int id) = 0;
	virtual bool cancelAll() = 0;
	virtual int getNotificationId(bool cancel = false) = 0;
};


#endif // QTABSTRACTNOTIFICATOR

