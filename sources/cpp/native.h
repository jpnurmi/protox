#ifndef NATIVE_H
#define NATIVE_H

#include "common.h"

#if defined (Q_OS_ANDROID)
#include "native/android/toasts.h"
#include "native/android/photodialog.h"
#include "native/android/folderdialog.h"
#endif

#define JFUNC(type, name, ...) JNIEXPORT type JNICALL Java_org_protox_activity_QtActivityEx_##name (JNIEnv *, jobject, __VA_ARGS__)

namespace Native {
	void hideSplashScreen();
	void setKeyboardAdjustMode(bool adjustNothing);
	bool requestApplicationPermissions();
	QString uriToRealPath(const QString &uriString);
	void viewFile(const QString &path, const QString &type);
}

#endif // NATIVE_H
