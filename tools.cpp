#include "tools.h"

namespace Tools {

void debug(const QString &msg)
{
	qDebug() << msg;
}

const QString getProgDir(bool create)
{
	QString path = QDir::separator() + QString("sdcard") + QDir::separator() + QString(".protox") + QDir::separator();
	QDir dir;
	if (create && !dir.exists(path))
		dir.mkdir(path);
	return path;
}

}


