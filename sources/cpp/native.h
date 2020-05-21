#ifndef NATIVE_H
#define NATIVE_H

#include "common.h"

#if defined (Q_OS_ANDROID)
#include "native/android/toasts.h"
#include "native/android/photodialog.h"
#include "native/android/folderdialog.h"
#endif

namespace Native {
	void hideSplashScreen();
	void setKeyboardAdjustMode(bool adjustNothing);
	bool requestApplicationPermissions();
	QString uriToRealPath(const QString &uriString);
	void viewFile(const QString &path, const QString &type);
}

#endif // NATIVE_H
