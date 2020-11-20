#include "QtStatusBar_p.h"

#include <QtAndroid>

// WindowManager.LayoutParams
#define FLAG_TRANSLUCENT_STATUS 0x04000000
#define FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS 0x80000000
// View
#define SYSTEM_UI_FLAG_LIGHT_STATUS_BAR 0x00002000

static QAndroidJniObject getAndroidWindow()
{
	QAndroidJniObject window = QtAndroid::androidActivity().callObjectMethod("getWindow", "()Landroid/view/Window;");
	window.callMethod<void>("addFlags", "(I)V", FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
	window.callMethod<void>("clearFlags", "(I)V", FLAG_TRANSLUCENT_STATUS);
	return window;
}

bool QtStatusBarPrivate::isAvailable_sys()
{
	return QtAndroid::androidSdkVersion() >= 21;
}

void QtStatusBarPrivate::setColor_sys(const QColor &color)
{
	if (QtAndroid::androidSdkVersion() < 21)
		return;

	QtAndroid::runOnAndroidThread([=]() {
		QAndroidJniObject window = getAndroidWindow();
		window.callMethod<void>("setStatusBarColor", "(I)V", color.rgba());
	});
}

void QtStatusBarPrivate::setTheme_sys(QtStatusBar::Theme theme)
{
	if (QtAndroid::androidSdkVersion() < 23)
		return;

	QtAndroid::runOnAndroidThread([=]() {
		QAndroidJniObject window = getAndroidWindow();
		QAndroidJniObject view = window.callObjectMethod("getDecorView", "()Landroid/view/View;");
		int visibility = view.callMethod<int>("getSystemUiVisibility", "()I");
		if (theme == QtStatusBar::Theme::Light)
			visibility |= SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
		else
			visibility &= ~SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
		view.callMethod<void>("setSystemUiVisibility", "(I)V", visibility);
	});
}
