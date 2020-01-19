#include "tools.h"

void Debug(const QString msg)
{
	qDebug() << msg;
}


char *String_To_ToxPk(const char *hex_string)
{
	size_t len = strlen(hex_string);
	char *val = (char*)malloc(len);

	size_t i;

	for (i = 0; i < len; ++i, hex_string += 2) {
		sscanf(hex_string, "%2hhx", &val[i]);
	}
	return val;
}

ToxId QString_To_ToxId(const QString str)
{
	return ToxId(String_To_ToxPk(str.toStdString().c_str()), tox_address_size());
}

const QString ToxId_To_QString(ToxId user_id)
{
	QString result;
	for (int i = 0; i < user_id.size(); ++i) {
		char d[3];
		snprintf(d, sizeof(d), "%02X", user_id[i] & 0xff);
		result += d;
	}
	return result;
}

const QString GetProgDir(bool create)
{
	QString path = QDir::separator() + QString("sdcard") + QDir::separator() + QString(".protox") + QDir::separator();
	QDir dir;
	if (create && !dir.exists(path))
		dir.mkdir(path);
	return path;
}
