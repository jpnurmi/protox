#include "tools.h"

void Debug(const QString &msg)
{
	qDebug() << msg;
}

const ToxId QString_To_ToxId(const QString &str)
{
	return ToxId::fromHex(str.toLatin1().toUpper());
}

const QString ToxId_To_QString(const ToxId &user_id)
{
	return QString(user_id.toHex().toUpper());
}

const QString GetProgDir(bool create)
{
	QString path = QDir::separator() + QString("sdcard") + QDir::separator() + QString(".protox") + QDir::separator();
	QDir dir;
	if (create && !dir.exists(path))
		dir.mkdir(path);
	return path;
}
