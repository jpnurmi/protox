#ifndef TOOLS_H
#define TOOLS_H

#include "common.h"

namespace Tools {
	void debug(const QString &msg);
	const QString getInternalStoragePath();
	const QString getProgDir();
	const QString getAvatarsDir();
	const QString replaceFileExtension(const QString &file, const QString &with);
	const QStringList qstringSplitUnicode(const QString &str, int limit_bytes);
	const QString getFilenameFromPath(const QString &path);
	const QString getDefaultDownloadsDirectory();
	const QString checkFileImage(const QString &path);
	bool checkFileExists(const QString &path);
	quint64 getFileSize(const QString &path);
	const QSize getImageSize(const QString &path);
	const QString getUniqueFilepath(const QString &path);
	const QString getCurrentCommitSha1();
	class AsyncFileManager : public QThread
	{
		Q_OBJECT
	public:
		AsyncFileManager(QFile *file);
		~AsyncFileManager();
		QFile *getFile() { return m_file; }
		// setParent already exists
		void setObjectParent (void *pointer) { m_parent = pointer; }
	public slots:
		void onChunkReadRequest(quint64 position, quint32 length);
		void onChunkWriteRequest(quint64 position, const QByteArray &data);
		bool onFileTransferStarted();
		void onCloseFileRequest();
	signals:
		void fileChunkReady(void *parent, const QByteArray &data, quint64 position);
		void fileTransferEnded(void *parent);
	private:
		QFile *m_file;
		void *m_parent;
	};
}


#endif // TOOLS_H
