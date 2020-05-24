#ifndef QTNOTIFICATION_H
#define QTNOTIFICATION_H

#include <QObject>
#include "QtAbstractNotifier.h"
#include <qqml.h>

/**
 * @brief The generic notification wrapper common for all platform
 */
class QtNotification : public QObject
{
	Q_OBJECT
	public:
		explicit QtNotification(QObject *parent = nullptr);
		~QtNotification();

	/// @see QtAbstractNotifier
	Q_INVOKABLE bool show(const QVariant &notificationParameters);
	Q_INVOKABLE bool cancel(const QVariant &notificationParameters);
	Q_INVOKABLE bool cancelAll();
	Q_INVOKABLE int getNotificationId(bool cancel = false);

	///! @brief The registry for QML object notification
	static void declareQML() ;

	enum Type {
		Text = 0,
		FileRequest = 1
	};
	Q_ENUM(Type)

	private:
		/// \brief The notifier object which maps to the notification methods for
		/// the respective platforms
		QtAbstractNotifier *_Notifier;
};

#endif // QTNOTIFICATION_H
