#include "tools.h"
#include "native.h"
#include "gitversion.h"

namespace Tools {

void debug(const QString &msg)
{
	qDebug() << msg;
}

const QString getProgDir()
{
	QString path = Native::getInternalStoragePath() + QString(".protox") + QDir::separator();
	QDir dir;

	if (!dir.exists(path))
		dir.mkdir(path);

	return path;
}

const QString getAvatarsDir()
{
	QString path = getProgDir() + "avatars" + QDir::separator();
	QDir dir;

	if (!dir.exists(path))
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

const QString getFilenameFromPath(const QString &path)
{
	return path.split(QDir::separator()).last();
}

const QString getDefaultDownloadsDirectory()
{
	QString path = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation) + QDir::separator() + "Protox";
	QDir dir;

	if (!dir.exists(path))
		dir.mkdir(path);

	return path;
}

const QSize getImageSize(const QString &path)
{
	QImageReader image(path);

	if (!image.canRead()) {
		return QSize(0, 0);
	}

	return image.size();
}

const QString checkFileImage(const QString &path)
{
	if (path.isEmpty()) {
		return QString();
	}

	QImageReader image(path);
	if (image.canRead()) {
		return "file://" + path;
	} else {
		return QString();
	}
}

bool checkFileExists(const QString &path)
{
	return QFile::exists(path);
}

quint64 getFileSize(const QString &path)
{
	QFile file(path);

	if (!file.open(QIODevice::ReadOnly)) {
		return 0;
	}

	quint64 size = file.size();
	return size;
}

const QString getUniqueFilepath(const QString &path)
{
	if (!QFile::exists(path)) {
		return path;
	}

	QFileInfo info(path);
	int number = 1;
	QDir dir = info.dir();
	const QString filename = path.split(QDir::separator()).last();

	QFileInfoList files = dir.entryInfoList(QStringList() << info.baseName() + " (*)." + info.completeSuffix(), QDir::Files);
	number += files.length();

	return info.absolutePath() + QDir::separator() 
			+ info.baseName() + " (" + QString::number(number) + ")." 
			+ info.completeSuffix();
}

const QString getCurrentCommitSha1()
{
	return GIT_COMMIT_SHA1;
}

}


