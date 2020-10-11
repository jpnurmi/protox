#ifndef ASYNCFILEMANAGER_H
#define ASYNCFILEMANAGER_H

#include "tools.h"

namespace Tools {
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

#endif // ASYNCFILEMANAGER_H
