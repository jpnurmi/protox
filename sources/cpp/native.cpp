#include "native.h"
#include "main.h"

#ifdef Q_OS_ANDROID
#include "deps/QtMobileNotification/QtNotification.h"
#endif

extern QmlCBridge *qmlbridge;

#ifdef Q_OS_ANDROID
JFUNC(void, keyboardHeightChanged, jint height)
{
	if (qmlbridge && !qmlbridge->getAppInactive()) {
		qmlbridge->setKeyboardHeight(height);
	}
}
JFUNC(void, transferAccepted, jint friend_number, jint file_number)
{
	QMetaObject::invokeMethod(qmlbridge, "acceptFile", Qt::QueuedConnection, 
							  Q_ARG(quint32, friend_number),
							  Q_ARG(quint32, file_number));
	qmlbridge->cancelFileNotification(friend_number, file_number); // fixme: move to Qt thread?
}
JFUNC(void, transferCanceled, jint friend_number, jint file_number)
{
	QMetaObject::invokeMethod(qmlbridge, "controlFile", Qt::QueuedConnection, 
							  Q_ARG(quint32, friend_number),
							  Q_ARG(quint32, file_number),
							  Q_ARG(quint32, TOX_FILE_CONTROL_CANCEL));
	qmlbridge->cancelFileNotification(friend_number, file_number); // fixme: move to Qt thread?
}
JFUNC(jlong, getBytesTransfered, jint friend_number, jint file_number)
{
	for (const auto transfer : qmlbridge->transfers) {
		if (transfer->friend_number == (quint32)friend_number && transfer->file_number == (quint32)file_number) {
			return transfer->bytesTransfered;
		}
	}
	return 0;
}
JFUNC(jboolean, checkFileTransferInProgress, jint friend_number, jint file_number)
{
	for (const auto transfer : qmlbridge->transfers) {
		if (transfer->friend_number == (quint32)friend_number && transfer->file_number == (quint32)file_number) {
			return true;
		}
	}
	return false;
}
JFUNC(jboolean, checkFileTransferSelfCanceled, jint friend_number, jint file_number)
{
	ToxSelfCanceledTransfer self_canceled_transfer((quint32)friend_number, (quint32)file_number);
	bool exists = qmlbridge->self_canceled_transfers.contains(self_canceled_transfer);
	qmlbridge->self_canceled_transfers.removeOne(self_canceled_transfer);
	return exists;
}
JFUNC(void, messageReplied, jint friend_number, jstring quote_text, jstring reply_text)
{
	QAndroidJniObject javaQuoteString("java/lang/String", "(Ljava/lang/String;)V", quote_text);
	QAndroidJniObject javaReplyString("java/lang/String", "(Ljava/lang/String;)V", reply_text);
	const QString finalReplyText = "> " + 
			javaQuoteString.toString().replace("\n", "\n> ") + 
			"\n" + 
			javaReplyString.toString();
	QMetaObject::invokeMethod(qmlbridge, "sendMessage", Qt::QueuedConnection, 
							  Q_ARG(quint32, (quint32)friend_number),
							  Q_ARG(QString, finalReplyText),
							  Q_ARG(bool, true));
}
#endif

namespace Native {

void hideSplashScreen()
{
#ifdef Q_OS_ANDROID
	QtAndroid::hideSplashScreen();
#endif
}

bool requestApplicationPermissions()
{
#if defined (Q_OS_ANDROID)
	const QStringList permission_list = { "android.permission.WRITE_EXTERNAL_STORAGE", 
										  "android.permission.READ_EXTERNAL_STORAGE" };
	for (auto permission : permission_list) {
		auto permission_result = QtAndroid::checkPermission(permission);
		if(permission_result == QtAndroid::PermissionResult::Denied){
			QtAndroid::PermissionResultMap resultHash = QtAndroid::requestPermissionsSync(QStringList({permission}));
			if(resultHash[permission] == QtAndroid::PermissionResult::Denied) {
				return false;
			}
		}
	}
#endif
	return true;
}

void setKeyboardAdjustMode(bool adjustNothing)
{
#if defined (Q_OS_ANDROID)
	QtAndroid::runOnAndroidThread([=]() {
		QtAndroid::androidActivity().callMethod<void>("setKeyboardAdjustMode", "(Z)V", adjustNothing);
	});
#endif
}

QString uriToRealPath(const QString &uriString) 
{
	QString realPath;
#if defined (Q_OS_ANDROID)
	QtAndroid::runOnAndroidThreadSync([&]() {
		QAndroidJniObject javaString = QAndroidJniObject::fromString(uriString);
		QAndroidJniObject path = QAndroidJniObject::callStaticObjectMethod(
		"org/protox/activity/QtActivityEx",
		"convertMediaUriToPath",
		"(Ljava/lang/String;)Ljava/lang/String;", 
		javaString.object());
		realPath = path.toString();
	});
#endif
	return realPath;
}

void viewFile(const QString &path, const QString &type)
{
#if defined (Q_OS_ANDROID)
	QtAndroid::runOnAndroidThread([=]() {
		QAndroidJniObject javaString = QAndroidJniObject::fromString(path);
		QAndroidJniObject javaString2 = QAndroidJniObject::fromString(type);
		QtAndroid::androidActivity().callMethod<void>("viewFile", 
													  "(Ljava/lang/String;Ljava/lang/String;)V", 
													  javaString.object(), javaString2.object());
	});
#endif
}

void startProtoxService()
{
	QAndroidJniObject::callStaticMethod<void>(
		"org/protox/ProtoxService",
		"startBackgroundService",
		"(Landroid/content/Context;)V",
		QtAndroid::androidActivity().object());
}

const QString getInternalStoragePath() 
{
	return QDir::separator() + QString("storage") + QDir::separator() + QString("emulated") + QDir::separator() + QString("0") + QDir::separator();
}

}
