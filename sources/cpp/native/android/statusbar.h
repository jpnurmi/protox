#ifndef STATUSBAR_H
#define STATUSBAR_H

#include "sources/cpp/common.h"

#define SYSTEM_UI_FLAG_LIGHT_STATUS_BAR 0x00002000

class QtStatusBar : public QObject
{
	Q_OBJECT

public:
	explicit QtStatusBar() {}

	enum Theme {
		Light,
		Dark
	};
	Q_ENUM(Theme)

	Q_INVOKABLE void setColor(const QColor &color);
	Q_INVOKABLE void setTheme(Theme theme);

	static void declareQML();

private:
	QAndroidJniObject getAndroidWindow();
};

#endif // STATUSBAR_H
