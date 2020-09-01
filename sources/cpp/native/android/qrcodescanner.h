#ifndef QTQRCODESCANNER_H
#define QTQRCODESCANNER_H

#include "sources/cpp/common.h"

class QtQRCodeScannerActivityResultReceiver;

class QtQRCodeScanner : public QObject
{
	Q_OBJECT
	Q_PROPERTY(QString result READ getResult)

public:
	explicit QtQRCodeScanner();
	~QtQRCodeScanner();
	Q_INVOKABLE void open();

	QString getResult() { return m_result; }
	void setResult(const QString &result) { m_result = result; }

	static void declareQML();

signals:
	void triggered();
private:
	QString m_result;
	QtQRCodeScannerActivityResultReceiver *m_activityResultReceiver;
};

class QtQRCodeScannerActivityResultReceiver : public QAndroidActivityResultReceiver {
public:
	explicit QtQRCodeScannerActivityResultReceiver(QtQRCodeScanner *qRCodeDialog);
	void handleActivityResult(int requestCode, int resultCode, const QAndroidJniObject &data);
private:
	QtQRCodeScanner *m_qRCodeDialog;
};

#endif // QTQRCODESCANNER_H
