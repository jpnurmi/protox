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

quint64 pack_quint64(quint32 low, quint32 high)
{
	return (((quint64)high) << 32) | ((quint64)low);
}

quint32 quint64_low(quint64 combined)
{
	quint64 mask = std::numeric_limits<uint32_t>::max();
	return mask & combined; // fixme: or just return combined?
}

quint32 quint64_high(uint64_t combined)
{
	return combined >> 32;
}
