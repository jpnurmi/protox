#ifndef STATUSBAR_P_H
#define STATUSBAR_P_H

#include "QtStatusBar.h"

class QtStatusBarPrivate
{
public:
	static bool isAvailable_sys();
	static void setColor_sys(const QColor &color);
	static void setTheme_sys(QtStatusBar::Theme theme);

	static QColor color;
	static QtStatusBar::Theme theme;
};

#endif // STATUSBAR_P_H
