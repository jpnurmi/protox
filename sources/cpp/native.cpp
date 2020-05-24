#include "native.h"
#include "main.h"

#ifdef Q_OS_ANDROID
#include "deps/QtMobileNotification/QtNotification.h"
#endif

extern QmlCBridge *qmlbridge;

void cancelFileNotification(quint32 friend_number, quint32 file_number) {
	QVariantMap parameters;
	parameters["fileNumber"] = file_number;
	QVariantMap notificationParameters;
	notificationParameters["type"] = QtNotification::FileRequest;
	notificationParameters["id"] = friend_number;
	notificationParameters["parameters"] = parameters;
	QtNotification notification;
	notification.cancel(notificationParameters);
}

#ifdef Q_OS_ANDROID
extern "C" 
{
	JNIEXPORT void JNICALL Java_org_protox_activity_QtActivityEx_keyboardHeightChanged(JNIEnv *, jobject, jint height)
	{
		if (qmlbridge && !qmlbridge->getAppInactive()) {
			qmlbridge->setKeyboardHeight(height);
		}
	}
	JNIEXPORT void JNICALL Java_org_protox_activity_QtActivityEx_transferAccepted(JNIEnv *, jobject, 
																				  jint friend_number,
																				  jint file_number)
	{
		qmlbridge->acceptFile(friend_number, file_number);
		cancelFileNotification(friend_number, file_number);
	}
	JNIEXPORT void JNICALL Java_org_protox_activity_QtActivityEx_transferCanceled(JNIEnv *, jobject, 
																				  jint friend_number,
																				  jint file_number)
	{
		qmlbridge->controlFile(friend_number, file_number, TOX_FILE_CONTROL_CANCEL);
		cancelFileNotification(friend_number, file_number);
	}
}
#endif

namespace Native {

void hideSplashScreen()
{
#ifdef Q_OS_ANDROID
	QtAndroid::hideSplashScreen();
#endif
}

bool requestApplicationPermissions()
{
#if defined (Q_OS_ANDROID)
	const QStringList permission_list = { "android.permission.WRITE_EXTERNAL_STORAGE" };
	for (auto permission : permission_list) {
		auto permission_result = QtAndroid::checkPermission(permission);
		if(permission_result == QtAndroid::PermissionResult::Denied){
			QtAndroid::PermissionResultMap resultHash = QtAndroid::requestPermissionsSync(QStringList({permission}));
			if(resultHash[permission] == QtAndroid::PermissionResult::Denied) {
				return false;
			}
		}
	}
#endif
	return true;
}

void setKeyboardAdjustMode(bool adjustNothing)
{
#if defined (Q_OS_ANDROID)
	QtAndroid::runOnAndroidThread([=]() {
		QtAndroid::androidActivity().callMethod<void>("setKeyboardAdjustMode", "(Z)V", adjustNothing);
	});
#endif
}

QString uriToRealPath(const QString &uriString) 
{
	QString realPath;
#if defined (Q_OS_ANDROID)
	QtAndroid::runOnAndroidThreadSync([&]() {
		QAndroidJniObject javaString = QAndroidJniObject::fromString(uriString);
		QAndroidJniObject path = QAndroidJniObject::callStaticObjectMethod(
		"org/protox/activity/QtActivityEx",
		"convertMediaUriToPath",
		"(Ljava/lang/String;)Ljava/lang/String;", 
		javaString.object());
		realPath = path.toString();
	});
#endif
	return realPath;
}

void viewFile(const QString &path, const QString &type)
{
#if defined (Q_OS_ANDROID)
	QtAndroid::runOnAndroidThread([=]() {
		QAndroidJniObject javaString = QAndroidJniObject::fromString(path);
		QAndroidJniObject javaString2 = QAndroidJniObject::fromString(type);
		QtAndroid::androidActivity().callMethod<void>("viewFile", 
													  "(Ljava/lang/String;Ljava/lang/String;)V", 
													  javaString.object(), javaString2.object());
	});
#endif
}

}
