#include "notification.h"

#include "sources/cpp/native/android/qandroidjniobjecttools.h"

bool QtNotification::show(const QVariant &notificationParameters)
{
	QVariantMap parameters = notificationParameters.toMap();
	QString caption = parameters.value("caption").toString();
	QString title = parameters.value("title").toString();
	int id = parameters.value("id").toInt();
	int type = parameters.value("type").toInt();
	QVariantMap additionalParameters = parameters.value("parameters").toMap();

	QAndroidJniObject javaCaption = QAndroidJniObject::fromString(caption);
	QAndroidJniObject javaTitle = QAndroidJniObject::fromString(title);
	QAndroidJniObject javaParameters = QAndroidJniObjectTools::fromVariantMap(additionalParameters);

	QAndroidJniObject::callStaticMethod<void>("notifications/QtAndroidNotifications",
											  "show",
											  "(Ljava/lang/String;Ljava/lang/String;IILjava/util/HashMap;)V",
											  javaTitle.object(),
											  javaCaption.object(),
											  (jint)id,
											  (jint)type,
											  javaParameters.object());
	return true;
}

bool QtNotification::cancel(const QVariant &notificationParameters)
{
	QVariantMap parameters = notificationParameters.toMap();
	int id = parameters.value("id").toInt();
	int type = parameters.value("type").toInt();
	QVariantMap additionalParameters = parameters.value("parameters").toMap();
	QAndroidJniObject javaParamteres = QAndroidJniObjectTools::fromVariantMap(additionalParameters);

	QAndroidJniObject::callStaticMethod<void>("notifications/QtAndroidNotifications",
											  "cancel",
											  "(IILjava/util/HashMap;)V",
											  (jint)type,
											  (jint)id,
											  javaParamteres.object());

	return true;
}

bool QtNotification::cancelAll()
{
	QAndroidJniObject::callStaticMethod<void>("notifications/QtAndroidNotifications",
											  "cancelAll");

	return true;
}

int QtNotification::getNotificationId(bool cancel)
{
	return QtAndroid::androidActivity().callMethod<jint>("getNotificationId", "(Z)I", cancel);
}

void QtNotification::declareQML()
{
	qmlRegisterType<QtNotification>("QtNotification", 1, 0, "Notification");
}
