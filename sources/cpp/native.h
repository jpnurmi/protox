#ifndef NATIVE_H
#define NATIVE_H

#include "common.h"

#if defined (Q_OS_ANDROID)
#include "native/android/toasts.h"
#include "native/android/photodialog.h"
#include "native/android/folderdialog.h"
#include "native/android/qrcodescanner.h"
#endif

#define JFUNC(type, name, ...) extern "C" JNIEXPORT type JNICALL Java_org_protox_activity_QtActivityEx_##name (JNIEnv *, jobject, __VA_ARGS__)
#define JFUNC_SERVICE_NO_ARGS(type, name) extern "C" JNIEXPORT type JNICALL Java_org_protox_service_ProtoxService_##name (JNIEnv *, jobject)

namespace Native {
	void hideSplashScreen();
	void setKeyboardAdjustMode(bool adjustNothing);
	bool requestApplicationPermissions();
	QString uriToRealPath(const QString &uriString);
	void viewFile(const QString &path, const QString &type);
	void startProtoxService();
	const QString getInternalStoragePath();
}

#endif // NATIVE_H
