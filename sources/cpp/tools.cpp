#include "tools.h"

namespace Tools {

void debug(const QString &msg)
{
	qDebug() << msg;
}

const QString getBaseStoragePath()
{
#if defined (Q_OS_ANDROID)
	return QDir::separator() + 
			QString("storage") + 
			QDir::separator();
#endif
}

const QString getInternalStoragePath() 
{
#if defined (Q_OS_ANDROID)
	return getBaseStoragePath() + QString("emulated") + QDir::separator() + QString("0") + QDir::separator();
#endif
}

const QString getProgDir(bool create)
{
	QString path = getInternalStoragePath() + QString(".protox") + QDir::separator();
	QDir dir;
	if (create && !dir.exists(path))
		dir.mkdir(path);
	return path;
}



const QString replaceFileExtension(const QString &file, const QString &with)
{
	return file.split(".").first() + with;
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


