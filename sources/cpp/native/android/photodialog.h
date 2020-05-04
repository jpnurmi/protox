#ifndef PHOTOPICKER_H
#define PHOTOPICKER_H

#include "sources/cpp/common.h"

class QtPhotoDialogActivityResultReceiver;

class QtPhotoDialog : public QObject{
	Q_OBJECT
	Q_PROPERTY(QString imageUrl READ getImageUrl)
	Q_PROPERTY(QString title READ getTitle WRITE setTitle)

public:
	explicit QtPhotoDialog();
	~QtPhotoDialog();
	Q_INVOKABLE bool open();

	void setImageUrl(const QString &imageUrl) { m_imageUrl = imageUrl; }
	QString getImageUrl() { return m_imageUrl; }

	void setTitle(const QString title) { m_title = title; }
	QString getTitle() { return m_title; }

	static void declareQML();
signals:
	void accepted();
private:
	QString m_imageUrl;
	QString m_title;
	QtPhotoDialogActivityResultReceiver *m_activityResultReceiver;
};

class QtPhotoDialogActivityResultReceiver : public QAndroidActivityResultReceiver {
public:
	explicit QtPhotoDialogActivityResultReceiver(QtPhotoDialog *photoPicketDialog);
	void handleActivityResult(int requestCode, int resultCode, const QAndroidJniObject &data);
private:
	QtPhotoDialog *m_photoDialog;
};



#endif // PHOTOPICKER_H
