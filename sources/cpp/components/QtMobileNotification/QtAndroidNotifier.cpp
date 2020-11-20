#include "QtAndroidNotifier.h"

#include <QVariant>
#include <QtAndroidExtras/QAndroidJniEnvironment>
#include <QDebug>

jobject QtAndroidNotifier::qVariantMapToJObject(const QVariantMap &map) 
{
	QAndroidJniEnvironment env;
	jclass mapClass = env.findClass("java/util/HashMap");
	jclass booleanClass = env.findClass("java/lang/Boolean");
	jclass integerClass = env.findClass("java/lang/Integer");
	jclass longClass = env.findClass("java/lang/Long");
	jmethodID mapConstructorID = env->GetMethodID(mapClass, "<init>", "()V");
	jmethodID putMethodID = env->GetMethodID(mapClass, "put", 
											 "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
	jmethodID boolConstructorID = env->GetMethodID(booleanClass, "<init>", "(Z)V");
	jmethodID intConstructorID = env->GetMethodID(integerClass, "<init>", "(I)V");
	jmethodID longConstructorID = env->GetMethodID(longClass, "<init>", "(J)V");
	jobject javaMap = env->NewObject(mapClass, mapConstructorID);

	for (auto it = map.begin(); it != map.end(); ++it) {
		QAndroidJniObject key = QAndroidJniObject::fromString(it.key()).object();
		QAndroidJniObject value;
		switch (it.value().type()) {
			case QVariant::Bool: value = env->NewObject(booleanClass, boolConstructorID, it.value().toBool()); break;
			case QVariant::UInt: value = env->NewObject(integerClass, intConstructorID, it.value().toUInt()); break;
			case QVariant::Int: value = env->NewObject(integerClass, intConstructorID, it.value().toInt()); break;
			case QVariant::LongLong: value = env->NewObject(longClass, longConstructorID, it.value().toLongLong()); break;
			case QVariant::ULongLong: value = env->NewObject(longClass, longConstructorID, it.value().toULongLong()); break;
			default: value = QAndroidJniObject::fromString(it.value().toString()); break;
		}
		env->CallObjectMethod(javaMap, putMethodID, key.object(), value.object());
	}

	return javaMap;
}

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
	QAndroidJniObject jni_parameters = qVariantMapToJObject(additionalParameters);

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
	QAndroidJniObject jni_parameters = qVariantMapToJObject(additionalParameters);
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
