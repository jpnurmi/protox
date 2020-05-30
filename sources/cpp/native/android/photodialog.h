#ifndef PHOTODIALOG_H
#define PHOTODIALOG_H

#include "sources/cpp/common.h"

class QtPhotoDialogActivityResultReceiver;

class QtPhotoDialog : public QObject{
	Q_OBJECT
	Q_PROPERTY(QString imageUrl READ getImageUrl)
	Q_PROPERTY(QStringList imageUrls READ getImageUrls)
	Q_PROPERTY(QString title READ getTitle WRITE setTitle)
	Q_PROPERTY(bool selectMultiple READ getSelectMultiple WRITE setSelectMultiple)

public:
	explicit QtPhotoDialog();
	~QtPhotoDialog();
	Q_INVOKABLE bool open();

	QString getImageUrl() { return m_imageUrl; }
	void setImageUrl(const QString &imageUrl) { m_imageUrl = imageUrl; }
	
	QStringList getImageUrls() { return m_imageUrls; }
	void setImageUrls(const QStringList &imageUrls) { m_imageUrls = imageUrls; }

	void setTitle(const QString title) { m_title = title; }
	QString getTitle() { return m_title; }

	void setSelectMultiple(bool selectMultiple) { m_selectMultiple = selectMultiple; }
	bool getSelectMultiple() { return m_selectMultiple; }

	static void declareQML();
signals:
	void accepted();
private:
	QString m_imageUrl;
	QStringList m_imageUrls;
	QString m_title;
	bool m_selectMultiple;
	QtPhotoDialogActivityResultReceiver *m_activityResultReceiver;
};

class QtPhotoDialogActivityResultReceiver : public QAndroidActivityResultReceiver {
public:
	explicit QtPhotoDialogActivityResultReceiver(QtPhotoDialog *photoPickerDialog);
	void handleActivityResult(int requestCode, int resultCode, const QAndroidJniObject &data);
private:
	QtPhotoDialog *m_photoDialog;
};



#endif // PHOTODIALOG_H
