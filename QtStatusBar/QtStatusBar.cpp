#include "QtStatusBar.h"
#include "QtStatusBar_p.h"

#include <QQmlEngine>

QColor QtStatusBarPrivate::color;
QtStatusBar::Theme QtStatusBarPrivate::theme = QtStatusBar::Light;

QtStatusBar::QtStatusBar(QObject *parent) : QObject(parent)
{
}

bool QtStatusBar::isAvailable()
{
	return QtStatusBarPrivate::isAvailable_sys();
}

QColor QtStatusBar::color()
{
	return QtStatusBarPrivate::color;
}

void QtStatusBar::setColor(const QColor &color)
{
	QtStatusBarPrivate::color = color;
	QtStatusBarPrivate::setColor_sys(color);
}

QtStatusBar::Theme QtStatusBar::theme()
{
	return QtStatusBarPrivate::theme;
}

void QtStatusBar::setTheme(Theme theme)
{
	QtStatusBarPrivate::theme = theme;
	QtStatusBarPrivate::setTheme_sys(theme);
}

void QtStatusBar::declareQML()
{
	qmlRegisterType<QtStatusBar>("QtStatusBar", 1, 0, "StatusBar");
}
