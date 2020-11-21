#include "qrcodescanner.h"

QtQRCodeScanner::QtQRCodeScanner()
{
	m_activityResultReceiver = new QtQRCodeScannerActivityResultReceiver(this);
}

QtQRCodeScanner::~QtQRCodeScanner()
{
	delete m_activityResultReceiver;
}

void QtQRCodeScanner::open()
{
	QtAndroid::runOnAndroidThread([=]() {
		QAndroidJniObject intent = QAndroidJniObject::callStaticObjectMethod(
		"org/protox/activity/QtActivityEx",
		"createScanQRCodeIntent",
		"()Landroid/content/Intent;");

		if (intent.object()) {
			QtAndroid::startActivity(intent, 12051978, m_activityResultReceiver);
		} else {
			QtAndroid::androidActivity().callMethod<void>("browseForQRCodeScanner", "()V");
		}
	});
}

QtQRCodeScannerActivityResultReceiver::QtQRCodeScannerActivityResultReceiver(QtQRCodeScanner *qRCodeDialog)
{
	m_qRCodeDialog = qRCodeDialog;
}

void QtQRCodeScannerActivityResultReceiver::handleActivityResult(int requestCode, int resultCode, const QAndroidJniObject &data)
{
		Q_UNUSED(requestCode)

		if (resultCode == -1) {
			QAndroidJniObject result = data.callObjectMethod(
						"getStringExtra",
						"(Ljava/lang/String;)Ljava/lang/String;", 
						QAndroidJniObject::fromString("SCAN_RESULT").object());
			m_qRCodeDialog->setResult(result.toString());
			emit m_qRCodeDialog->triggered();
		}
}

void QtQRCodeScanner::declareQML()
{
	qmlRegisterType<QtQRCodeScanner>("QtQRCodeScanner", 1, 0, "QRCodeScanner");
}
