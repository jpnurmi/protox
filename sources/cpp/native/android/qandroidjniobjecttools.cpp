#include "qandroidjniobjecttools.h"

namespace QAndroidJniObjectTools {

QAndroidJniObject fromBool(bool value) 
{
	QAndroidJniEnvironment env;
	jclass booleanClass = env.findClass("java/lang/Boolean");
	jmethodID boolConstructorID = env->GetMethodID(booleanClass, "<init>", "(Z)V");
	return env->NewObject(booleanClass, boolConstructorID, value);
}

QAndroidJniObject fromInt(int value)
{
	QAndroidJniEnvironment env;
	jclass integerClass = env.findClass("java/lang/Integer");
	jmethodID intConstructorID = env->GetMethodID(integerClass, "<init>", "(I)V");
	return env->NewObject(integerClass, intConstructorID, value);
}

QAndroidJniObject fromLong(long long value)
{
	QAndroidJniEnvironment env;
	jclass longClass = env.findClass("java/lang/Long");
	jmethodID longConstructorID = env->GetMethodID(longClass, "<init>", "(J)V");
	return env->NewObject(longClass, longConstructorID, value);
}

// fixme: only a few types supported
QAndroidJniObject fromVariantMap(const QVariantMap &value)
{
	QAndroidJniEnvironment env;
	jclass mapClass = env.findClass("java/util/HashMap");

	jmethodID mapConstructorID = env->GetMethodID(mapClass, "<init>", "()V");
	jmethodID putMethodID = env->GetMethodID(mapClass, "put", 
											 "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
	QAndroidJniObject result = env->NewObject(mapClass, mapConstructorID);

	for (auto it = value.begin(); it != value.end(); ++it) {
		QAndroidJniObject key = QAndroidJniObject::fromString(it.key()).object();
		QAndroidJniObject value;

		switch (it.value().type()) {
			case QVariant::Bool: value = fromBool(it.value().toBool()); break;
			case QVariant::UInt: value = fromInt(it.value().toUInt()); break;
			case QVariant::Int: value = fromInt(it.value().toInt()); break;
			case QVariant::LongLong: value = fromLong(it.value().toLongLong()); break;
			case QVariant::ULongLong: value = fromLong(it.value().toULongLong()); break;
			default: value = QAndroidJniObject::fromString(it.value().toString()); break;
		}

		env->CallObjectMethod(result.object(), putMethodID, key.object(), value.object());
	}

	return result;
}



};
