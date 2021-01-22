#include "statusbar.h"

// fixme: move this code somewhere else?

// WindowManager.LayoutParams
#define FLAG_TRANSLUCENT_STATUS 0x04000000
#define FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS 0x80000000

QAndroidJniObject QtStatusBar::getAndroidWindow()
{
	QAndroidJniObject window = QtAndroid::androidActivity().callObjectMethod("getWindow", "()Landroid/view/Window;");
	window.callMethod<void>("addFlags", "(I)V", FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
	window.callMethod<void>("clearFlags", "(I)V", FLAG_TRANSLUCENT_STATUS);
	return window;
}

void QtStatusBar::setColor(const QColor &color)
{
	QtAndroid::runOnAndroidThread([=]() {
		QAndroidJniObject window = getAndroidWindow();
		window.callMethod<void>("setStatusBarColor", "(I)V", color.rgba());
	});
}

void QtStatusBar::setTheme(Theme theme)
{
	if (QtAndroid::androidSdkVersion() < 23)
		return;

	QtAndroid::runOnAndroidThread([=]() {
		QAndroidJniObject window = getAndroidWindow();
		QAndroidJniObject view = window.callObjectMethod("getDecorView", "()Landroid/view/View;");
		int visibility = view.callMethod<jint>("getSystemUiVisibility", "()I");

		if (theme == QtStatusBar::Theme::Light) {
			visibility |= SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
		} else {
			visibility &= ~SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
		}
		
		view.callMethod<void>("setSystemUiVisibility", "(I)V", visibility);
	});
}

void QtStatusBar::declareQML()
{
	qmlRegisterType<QtStatusBar>("QtStatusBar", 1, 0, "StatusBar");
}
