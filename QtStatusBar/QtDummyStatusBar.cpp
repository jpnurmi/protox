#include "QtStatusBar_p.h"

bool QtStatusBarPrivate::isAvailable_sys()
{
	return false;
}

void QtStatusBarPrivate::setColor_sys(const QColor &color)
{
	Q_UNUSED(color);
}

void QtStatusBarPrivate::setTheme_sys(QtStatusBar::Theme theme)
{
	Q_UNUSED(theme);
}
