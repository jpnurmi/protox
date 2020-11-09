#include "asyncfilemanager.h"

namespace Tools {

AsyncFileManager::AsyncFileManager(QFile *file)
{
	moveToThread(this);
	m_file = file;
	m_file->moveToThread(this);
	start();
	Tools::debug("File manager thread started 0x" + 
				 QString::number((quint64)m_file->thread(), 16) + 
				 ": " + m_file->fileName() + ".");
}

void AsyncFileManager::onChunkReadRequest(quint64 position, quint32 length)
{
	if (!length) {
		m_file->close();
		emit fileTransferEnded(m_parent);
		return;
	}
	if (!m_file->seek(position)) {
		Tools::debug("File manager thread 0x" + 
					 QString::number((quint64)m_file->thread(), 16) + 
					 " error - seek failed: " + m_file->fileName() + ".");
	}
	QByteArray data;
	data.resize(length);
	if (m_file->read(data.data(), length) == -1) {
		Tools::debug("File manager thread 0x" + 
					 QString::number((quint64)m_file->thread(), 16) + 
					 " error - read failed: " + m_file->fileName() + ".");
	}
	emit fileChunkReady(m_parent, data, position);
}

void AsyncFileManager::onChunkWriteRequest(quint64 position, const QByteArray &data)
{
	if (!data.length()) {
		m_file->close();
		emit fileTransferEnded(m_parent);
		return;
	}
	if (!m_file->seek(position)) {
		Tools::debug("File manager thread 0x" + 
					 QString::number((quint64)m_file->thread(), 16) + 
					 " error - seek failed: " + m_file->fileName() + ".");
	}
	if (m_file->write(data) == -1) {
		Tools::debug("File manager thread 0x" + 
					 QString::number((quint64)m_file->thread(), 16) + 
					 " error - write failed: " + m_file->fileName() + ".");
	}
}

bool AsyncFileManager::onFileTransferStarted()
{
	return m_file->open(QIODevice::WriteOnly);
}

void AsyncFileManager::onCloseFileRequest()
{
	if(m_file->isWritable() && !m_file->flush()) {
		Tools::debug("File manager thread 0x" + 
					 QString::number((quint64)m_file->thread(), 16) + 
					 " error - flush failed: " + m_file->fileName() + ".");
	}
	delete m_file;
}

AsyncFileManager::~AsyncFileManager()
{
	Tools::debug("Destroying file manager thread 0x" + 
				 QString::number((quint64)m_file->thread(), 16) + ".");
	QMetaObject::invokeMethod(this, "onCloseFileRequest", Qt::DirectConnection);
	quit();
	if (!wait()) {
		terminate();
		wait();
	}
}

}
