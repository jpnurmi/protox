#ifndef PHOTOPICKER_H
#define PHOTOPICKER_H

#include "sources/cpp/common.h"

class QtFolderDialogActivityResultReceiver;

class QtFolderDialog : public QObject
{
	Q_OBJECT
	Q_PROPERTY(QString folderUrl READ getFolderUrl)

public:
	explicit QtFolderDialog();
	~QtFolderDialog();
	Q_INVOKABLE void open();

	void setFolderUrl(const QString &folderUrl) { m_folderUrl = folderUrl; }
	QString getFolderUrl() { return m_folderUrl; }

	static void declareQML();
signals:
	void accepted();
private:
	QString m_folderUrl;
	QtFolderDialogActivityResultReceiver *m_activityResultReceiver;
};

class QtFolderDialogActivityResultReceiver : public QAndroidActivityResultReceiver {
public:
	explicit QtFolderDialogActivityResultReceiver(QtFolderDialog *photoPickerDialog);
	void handleActivityResult(int requestCode, int resultCode, const QAndroidJniObject &data);
private:
	QtFolderDialog *m_folderDialog;
};

#endif // PHOTOPICKER_H
