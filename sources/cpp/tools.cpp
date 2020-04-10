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

const QStringList qstringSplitUnicode(const QString &str, int limit_bytes)
{
	QStringList result;
	QByteArray split_bytes;
	QTextBoundaryFinder tbf(QTextBoundaryFinder::Grapheme, str);
	while(tbf.toNextBoundary() != -1)
	{
		int pos1 = tbf.toPreviousBoundary();
		int pos2 = tbf.toNextBoundary();
		QStringView symbol(str.constData() + pos1, pos2 - pos1);
		QByteArray bytes = symbol.toUtf8();
		// truncate if unicode symbol exceeds limit, don't make such symbols, pls
		if (bytes.length() > limit_bytes) {
			bytes.truncate(limit_bytes);
		}
		if (split_bytes.length() + bytes.length() > limit_bytes) {
			result.push_back(QString::fromUtf8(split_bytes));
			split_bytes.clear();
		}
		split_bytes.push_back(bytes);
	}
	if (!split_bytes.isEmpty()) {
		result.push_back(QString::fromUtf8(split_bytes));
	}
	return result;
}

}

