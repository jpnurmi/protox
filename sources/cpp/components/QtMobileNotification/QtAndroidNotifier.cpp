#include "QtAndroidNotifier.h"

#include <QVariant>
#include <QtAndroidExtras/QAndroidJniEnvironment>
#include <QDebug>

#include "sources/cpp/native/android/qandroidjniobjecttools.h"

bool QtAndroidNotifier::show(const QVariant &notificationParameters)
{
	QVariantMap parameters = notificationParameters.toMap();
	QString caption = parameters.value("caption", "").toString();
	QString title = parameters.value("title", "").toString();
	int id = parameters.value("id", 0).toInt();
	int type = parameters.value("type",0).toInt();
	QVariantMap additionalParameters = parameters.value("parameters", QVariantMap()).toMap();

	QAndroidJniObject jni_caption = QAndroidJniObject::fromString(caption);
	QAndroidJniObject jni_title = QAndroidJniObject::fromString(title);
	QAndroidJniObject jni_parameters = QAndroidJniObjectTools::fromVariantMap(additionalParameters);

	QAndroidJniObject::callStaticMethod<void>("notifications/QtAndroidNotifications",
											  "show",
											  "(Ljava/lang/String;Ljava/lang/String;IILjava/util/HashMap;)V",
											  jni_title.object<jstring>(),
											  jni_caption.object<jstring>(),
											  static_cast<jint>(id),
											  static_cast<jint>(type),
											  jni_parameters.object());
	return true;
}

bool QtAndroidNotifier::cancel(const QVariant &notificationParameters)
{
	QVariantMap parameters = notificationParameters.toMap();
	int id = parameters.value("id", 0).toInt();
	int type = parameters.value("type",0).toInt();
	QVariantMap additionalParameters = parameters.value("parameters", QVariantMap()).toMap();
	QAndroidJniObject jni_parameters = QAndroidJniObjectTools::fromVariantMap(additionalParameters);
	QAndroidJniObject::callStaticMethod<void>("notifications/QtAndroidNotifications",
											  "cancel",
											  "(IILjava/util/HashMap;)V",
											  static_cast<jint>(type),
											  static_cast<jint>(id),
											  jni_parameters.object());

	return true;
}

bool QtAndroidNotifier::cancelAll()
{
	QAndroidJniObject::callStaticMethod<void>("notifications/QtAndroidNotifications",
											  "cancelAll");

	return true;
}

int QtAndroidNotifier::getNotificationId(bool cancel)
{
	return QtAndroid::androidActivity().callMethod<int>("getNotificationId", "(Z)I", cancel);
}
