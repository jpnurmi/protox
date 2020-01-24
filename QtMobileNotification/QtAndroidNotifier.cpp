#include "QtAndroidNotifier.h"

#include <QVariant>
#include <QtAndroidExtras/QAndroidJniEnvironment>
#include <QDebug>

bool QtAndroidNotifier::show(const QVariant &notificationParameters)
{
	QVariantMap parameters = notificationParameters.toMap();
	QString caption = parameters.value("caption", "").toString();
	QString title = parameters.value("title", "").toString();
	int id = parameters.value("id", 0).toInt();

	QAndroidJniObject jni_caption = QAndroidJniObject::fromString(caption);
	QAndroidJniObject jni_title = QAndroidJniObject::fromString(title);

	QAndroidJniObject::callStaticMethod<void>("notifications/QtAndroidNotifications",
											  "show",
											  "(Ljava/lang/String;Ljava/lang/String;I)V",
											  jni_title.object<jstring>(),
											  jni_caption.object<jstring>(),
											  static_cast<jint>(id));
	return true;
}

bool QtAndroidNotifier::cancel(int id)
{
	QAndroidJniObject::callStaticMethod<void>("notifications/QtAndroidNotifications",
											  "cancel",
											  "(I)V",
											  static_cast<jint>(id));

	return true;
}

int QtAndroidNotifier::getNotificationId(bool cancel)
{
	return QtAndroid::androidActivity().callMethod<int>("getNotificationId", "(Z)I", cancel);
}
