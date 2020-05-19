#ifndef TOOLS_H
#define TOOLS_H

#include "common.h"

namespace Tools {
	void debug(const QString &msg);
	const QString getInternalStoragePath();
	const QString getProgDir(bool create = true);
	const QString replaceFileExtension(const QString &file, const QString &with);
	const QStringList qstringSplitUnicode(const QString &str, int limit_bytes);
	const QString getFilenameFromPath(const QString &path);
	class AsyncFileManager : public QThread
	{
		Q_OBJECT
	public:
		AsyncFileManager(QFile *file): m_file(file) {}
		~AsyncFileManager();
		QFile *getFile() { return m_file; }
		// setParent already exists
		void setObjectParent (void *pointer) { m_parent = pointer; }
	public slots:
		void onChunkRequest(quint64 position, quint32 length);
	signals:
		void fileChunkReady(void *parent, const QByteArray &data, quint64 position);
	private:
		QFile *m_file;
		void *m_parent;
	};
}


#endif // TOOLS_H
