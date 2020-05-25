#include "tools.h"

extern QFile *logfile;

namespace Tools {

void debug(const QString &msg)
{
	if (logfile && logfile->isOpen()) {
		QString dt_str = QDateTime::currentDateTime().toString("[dd.MM.yyyy - hh:mm:ss] ") + msg + "\n";
		logfile->write(dt_str.toUtf8());
		logfile->flush();
	}
	qDebug() << msg;
}

const QString getInternalStoragePath() 
{
#if defined (Q_OS_ANDROID)
	return QDir::separator() + QString("storage") + QDir::separator() + QString("emulated") + QDir::separator() + QString("0") + QDir::separator();
#endif
}

const QString getProgDir()
{
	QString path = getInternalStoragePath() + QString(".protox") + QDir::separator();
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

const QString checkFileImage(const QString &path)
{
	QImageReader reader(path);
	if (reader.canRead()) {
		return "file://" + path;
	} else {
		return QString();
	}
}

bool checkFileExists(const QString &path)
{
	return QFile::exists(path);
}

void AsyncFileManager::onChunkReadRequest(quint64 position, quint32 length)
{
	if (!length) {
		emit fileTransferEnded(m_parent);
		return;
	}
	m_file->seek(position);
	QByteArray data = m_file->read(length);
	emit fileChunkReady(m_parent, data, position);
}

void AsyncFileManager::onChunkWriteRequest(quint64 position, const QByteArray &data)
{
	if (!data.length()) {
		emit fileTransferEnded(m_parent);
		return;
	}
	m_file->seek(position);
	m_file->write(data);
}

void AsyncFileManager::onFileTransferStarted(bool &result)
{
	result = m_file->open(QIODevice::WriteOnly);
}

AsyncFileManager::~AsyncFileManager()
{
	m_file->close();
	delete m_file;
	quit();
	if (!wait(1000)) {
		terminate();
		wait();
	}
}

}


