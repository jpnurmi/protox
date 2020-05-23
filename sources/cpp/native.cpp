#include "native.h"
#include "main.h"

extern QmlCBridge *qmlbridge;

#ifdef Q_OS_ANDROID
extern "C" 
{
	JNIEXPORT void JNICALL Java_org_protox_activity_QtActivityEx_keyboardHeightChanged(JNIEnv *, jobject, jint height)
	{
		if (qmlbridge && !qmlbridge->getAppInactive()) {
			qmlbridge->setKeyboardHeight(height);
		}
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
/*
jobject qVariantMapsToJObject(QVariantMap &map) 
{
	QAndroidJniEnvironment env;
	jclass mapClass = env.findClass("java/util/Map");
	jclass stringClass = env.findClass("java/lang/String");
	jmethodID putMethodID = env->GetMethodID(mapClass, "put", 
											 "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
	jmethodID stringConstructorID = env->GetMethodID(stringClass, "<init>", "(Ljava/lang/String;)V");
	
	for (const auto &pair : map) {
		jobject key = env->NewObject(stringClass, stringConstructorID, map.c);
		jobject value = env->NewObject(stringClass, stringConstructorID, map.);
	}
	
}
*/
}
