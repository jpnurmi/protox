#include "toast.h"

void QtToast::show(const QVariant &toastParameters)
{
	QVariantMap parameters = toastParameters.toMap();
	QString message = parameters.value("message").toString();
	int duration = parameters.value("duration").toInt();

	QtAndroid::runOnAndroidThread([message, duration] {
		QAndroidJniObject javaString = QAndroidJniObject::fromString(message);
		QAndroidJniObject toast = QAndroidJniObject::callStaticObjectMethod("android/widget/Toast", "makeText",
																			"(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;",
																			QtAndroid::androidActivity().object(),
																			javaString.object(),
																			(jint)duration);
		toast.callMethod<void>("show");
	});
}

void QtToast::declareQML()
{
	qmlRegisterType<QtToast>("QtToast", 1, 0, "Toast");
}
