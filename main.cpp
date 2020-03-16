#include "main.h"

#include "tools.h"
#include "db.h"

#include "QtNotification.h"
#include "QtStatusBar.h"
#include "QZXing.h"
#include "toasts.h"

QmlCBridge *qmlbridge = nullptr;
ChatDataBase *chat_db = nullptr;
QSettings *settings = nullptr;

QmlCBridge::QmlCBridge()
{
	component = nullptr;
	tox = nullptr;
	toxcore_timer = nullptr;
	tox_pass_key = nullptr;
	app_inactive = true;
	current_profile = "";
	current_friend_number = 0;
	profile_password = "";
}

void QmlCBridge::setComponent(QObject *_component)
{
	component = _component;
}

void QmlCBridge::insertMessage(const ToxVariantMessage &message, quint32 friend_number, bool self, quint32 message_id, quint64 unique_id, QDateTime dt, bool history, bool failed)
{
	QVariant returnedValue;

	QMetaObject::invokeMethod(component, "insertMessage", 
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, message), 
							  Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, self),
							  Q_ARG(QVariant, message_id),
							  Q_ARG(QVariant, dt.toString("d MMMM hh:mm:ss")),
							  Q_ARG(QVariant, unique_id),
							  Q_ARG(QVariant, failed),
							  Q_ARG(QVariant, history));
}

void QmlCBridge::insertFriend(qint32 friend_number, const QString &nickName, bool request, const QString &request_message, const ToxPk &friendPk)
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "insertFriend",
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, nickName), 
							  Q_ARG(QVariant, request),
							  Q_ARG(QVariant, request_message),
							  Q_ARG(QVariant, QString::fromLatin1(friendPk)));
}

void QmlCBridge::setMessageReceived(quint32 friend_number, quint32 message_id, bool use_uid, quint64 unique_id)
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "setMessageReceived",
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, message_id),
							  Q_ARG(QVariant, use_uid),
							  Q_ARG(QVariant, unique_id));
}

void QmlCBridge::setCurrentFriendConnStatus(quint32 friend_number, int conn_status)
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "setCurrentFriendConnStatus",
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, friend_number), Q_ARG(QVariant, conn_status));
}

void QmlCBridge::sendMessage(const QString &message)
{
	ToxPk friend_pk = Toxcore::get_friend_public_key(tox, current_friend_number);
	bool failed;
	quint32 message_id = Toxcore::send_message(tox, current_friend_number, message, failed);
	quint64 new_unique_id = chat_db->getMessagesCountFriend(friend_pk) + 1;
	QDateTime dt = QDateTime::currentDateTime();
	ToxVariantMessage variantMessage;
	variantMessage.insert("type", ToxVariantMessageType::TOXMSG_TEXT);
	variantMessage.insert("message", message);
	insertMessage(variantMessage, current_friend_number, true, message_id, new_unique_id, dt, false, failed);
	messages_id_uid[message_id] = new_unique_id;
	settings->beginGroup("Privacy");
	bool keep_chat_history = settings->value("keep_chat_history", true).toBool();
	settings->endGroup();
	if (keep_chat_history) {
		chat_db->insertMessage(variantMessage, dt, friend_pk, true, new_unique_id, failed);
	}
}

quint32 QmlCBridge::getCurrentFriendNumber()
{
	return current_friend_number;
}

int QmlCBridge::getFriendConnStatus(quint32 friend_number)
{
	return friends_conn_status[friend_number];
}

const QString QmlCBridge::getFriendNickname(quint32 friend_number)
{
	return Toxcore::get_friend_name(tox, friend_number);
}

void QmlCBridge::setCurrentFriend(quint32 newFriend)
{
	current_friend_number = newFriend;
}

const QString QmlCBridge::getFriendStatusMessage(quint32 friend_number)
{
	return Toxcore::get_friend_status_message(tox, friend_number);
}

int QmlCBridge::getFriendStatus(quint32 friend_number)
{
	return Toxcore::get_friend_status(tox, friend_number);
}

void QmlCBridge::retrieveChatLog(quint32 start, bool from, bool reverse)
{
	settings->beginGroup("Client");
	quint32 limit = settings->value("last_messages_limit", 128).toUInt();
	settings->endGroup();
	ToxMessages messages = chat_db->getFriendMessages(Toxcore::get_friend_public_key(tox, current_friend_number), limit, start, from, reverse);
	QMetaObject::invokeMethod(component, "clearChatContent");
	if (messages.isEmpty()) {
		return;
	}
	for (auto msg : messages) {
		insertMessage(msg.variantMessage, current_friend_number, msg.self, 0, msg.unique_id, msg.dt, true, false);
		if (!msg.self || msg.received)
			setMessageReceived(current_friend_number, 0, true, msg.unique_id);
	}
}

void QmlCBridge::copyTextToClipboard(QString text)
{
	QClipboard *clipboard = QGuiApplication::clipboard(); 
	clipboard->setText(text);
}

void QmlCBridge::makeFriendRequest(const QString &toxId, const QString &friendMessage)
{
	int error = Toxcore::make_friend_request(tox, QString_To_ToxId(toxId), friendMessage);
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "sendFriendRequestStatus",
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, error));
}

void QmlCBridge::deleteFriend(quint32 friend_number)
{
	Toxcore::delete_friend(tox, friend_number);
}

void QmlCBridge::clearFriendChatHistory(quint32 friend_number)
{
	chat_db->clearFriendChatHistory(Toxcore::get_friend_public_key(tox, friend_number));
}

void QmlCBridge::updateFriendNickName(quint32 friend_number, const QString &nickname)
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "updateFriendNickName",
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, friend_number), Q_ARG(QVariant, nickname));
}

void QmlCBridge::setFriendTyping(quint32 friend_number, bool typing)
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "setFriendTyping",
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, friend_number), Q_ARG(QVariant, typing));
}

void QmlCBridge::setTypingFriend(quint32 friend_number, bool typing)
{
	Toxcore::set_typing_friend(tox, friend_number, typing);
}

void QmlCBridge::setFriendStatusMessage(quint32 friend_number, const QString &message)
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "setFriendStatusMessage",
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, friend_number), Q_ARG(QVariant, message));
}

void QmlCBridge::setFriendStatus(quint32 friend_number, quint32 status)
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "setFriendStatus",
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, friend_number), Q_ARG(QVariant, status));
}

const QString QmlCBridge::getNickname(bool toxId)
{
	return Toxcore::get_nickname(tox, toxId);
}

void QmlCBridge::setNickname(const QString &nickname)
{
	Toxcore::set_nickname(tox, nickname);
}

const QString QmlCBridge::getStatusMessage()
{
	return Toxcore::get_status_message(tox);
}

void QmlCBridge::setStatusMessage(const QString &statusMessage)
{
	Toxcore::set_status_message(tox, statusMessage);
}

int QmlCBridge::getStatus()
{
	return Toxcore::get_status(tox);
}

void QmlCBridge::setStatus(quint32 status)
{
	Toxcore::set_status(tox, status);
}

QString QmlCBridge::getToxId()
{
	return ToxId_To_QString(Toxcore::get_address(tox));
}

long QmlCBridge::getFriendsCount()
{
	return Toxcore::get_friends_count(tox);
}

quint32 QmlCBridge::getMessagesCount(quint32 friend_number)
{
	return chat_db->getMessagesCountFriend(Toxcore::get_friend_public_key(tox, friend_number));
}

void QmlCBridge::setConnStatus(int conn_status)
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "setConnStatus",
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, conn_status));
}

int QmlCBridge::getConnStatus()
{
	return Toxcore::get_connection_status();
}

void QmlCBridge::addFriend(const QString &friendPk)
{
	quint32 friend_number = Toxcore::add_friend(tox, friendPk.toLatin1());
	insertFriend(friend_number, Toxcore::get_friend_name(tox, friend_number));
}

QList<QVariant> QmlCBridge::getFriendsModelOrder()
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "getFriendsModelOrder",
		Q_RETURN_ARG(QVariant, returnedValue));
	return returnedValue.toList();
}

void QmlCBridge::bootstrapDHT()
{
	Toxcore::bootstrap_DHT(tox);
}

void QmlCBridge::setKeyboardHeight(int height)
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "setKeyboardHeight", Qt::UniqueConnection,
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, height));
}

QVariant QmlCBridge::getSettingsValue(const QString &group, const QString &key, int type, const QVariant &default_value)
{
	QVariant result;
	settings->beginGroup(group);
	result = settings->value(key, default_value);
	settings->endGroup();
	switch (type) {
	case QVariant::Bool: return result.toBool(); break;
	case QVariant::String: return result.toString(); break;
	default: return result; break;
	}
}

void QmlCBridge::setSettingsValue(const QString &group, const QString &key, const QVariant &value)
{
	settings->beginGroup(group);
	settings->setValue(key, value);
	settings->endGroup();
}

void QmlCBridge::setKeyboardAdjustMode(bool adjustNothing)
{
#if defined (Q_OS_ANDROID)
	QtAndroid::runOnAndroidThread([=]() {
		QtAndroid::androidActivity().callMethod<void>("setKeyboardAdjustMode", "(Z)V", adjustNothing);
	});
#endif
}

bool QmlCBridge::checkProfileEncrypted(const QString &profile)
{
	return Toxcore::check_profile_encrypted(profile);
}

QString QmlCBridge::getNospamValue()
{
	quint32 nospam = Toxcore::get_nospam(tox);
	ToxId nospam_bytes;
	nospam_bytes.append((nospam >> 24) & 0xFF);
	nospam_bytes.append((nospam >> 16) & 0xFF);
	nospam_bytes.append((nospam >> 8) & 0xFF);
	nospam_bytes.append(nospam & 0xFF);
	return ToxId_To_QString(nospam_bytes);
}

void QmlCBridge::setNospamValue(const QString &nospam)
{
	ToxId bytes = QString_To_ToxId(nospam);
	quint32 value = bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3];
	Toxcore::set_nospam(tox, value);
}

void QmlCBridge::generateToxPasswordKey(const QString &password)
{
	profile_password = password;
	regenerateToxPasswordKey();
}

void QmlCBridge::saveProfile()
{
	Toxcore::save_data(tox, GetProgDir() + current_profile);
}

void QmlCBridge::regenerateToxPasswordKey()
{
	tox_pass_key = Toxcore::generate_pass_key(profile_password);
}

bool QmlCBridge::checkFriendHistoryExists(quint32 friend_number)
{
	return chat_db->getMessagesCountFriend(Toxcore::get_friend_public_key(tox, friend_number)) > 0;
}

void QmlCBridge::updateDataBasePassword(const QString &password)
{
	chat_db->updatePassword(password);
}

const QString QmlCBridge::getToxcoreVersion()
{
	return Toxcore::get_version_string();
}

static const QtMessageHandler QT_DEFAULT_MESSAGE_HANDLER = qInstallMessageHandler(0);

void customMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString & msg)
{
	switch (type) {
	case QtWarningMsg: {
		if (!msg.contains("Detected anchors on an item that is managed by a layout.")){
			(*QT_DEFAULT_MESSAGE_HANDLER)(type, context, msg);
		}
	}
	break;
	default:
		(*QT_DEFAULT_MESSAGE_HANDLER)(type, context, msg);
		break;
	}
}

#ifdef Q_OS_ANDROID
extern "C" 
{
	JNIEXPORT void JNICALL Java_org_protox_activity_QtActivityEx_keyboardHeightChanged(JNIEnv *, jobject, jint height)
	{
		if (qmlbridge && !qmlbridge->getAppInactive()) {
			qmlbridge->setKeyboardHeight(height);
		}
	}
}
#endif

int QmlCBridge::signInProfile(const QString &profile, bool create, const QString &password)
{
	current_profile = profile;
	profile_password = password;
	regenerateToxPasswordKey();
	ToxProfileLoadingError error;
	tox = Toxcore::create(error, create);
	if (!tox) {
		current_profile.clear();
		return error;
	}
	chat_db = new ChatDataBase("chat_" + QString(current_profile).replace(".tox", ".db"), password);
	Toxcore::bootstrap_DHT(tox);
	Debug("My address: " + ToxId_To_QString(Toxcore::get_address(tox)));

	// load config
	settings->beginGroup("Client_" + current_profile);
	ToxPk friendPk = settings->value("last_friend", Toxcore::get_friend_public_key(tox, 0)).toByteArray();
	QList <QVariant> friend_list = settings->value("friend_list", QList <QVariant>()).toList();
	settings->endGroup();
	ToxFriends friends = Toxcore::get_friends(tox);

	for (auto _friend : friends) {
		if (friend_list.lastIndexOf(_friend) < 0) {
			friend_list.append(_friend);
		}
	}
	for (auto _friend : friend_list) {
		if (friends.lastIndexOf(_friend.toUInt()) < 0) {
			friend_list.removeOne(_friend);
		}
	}

	if (!friendPk.isEmpty()) {
		for (auto _friend : friend_list) {
			if (Toxcore::get_friend_public_key(tox, _friend.toUInt()) == friendPk) {
				current_friend_number = _friend.toUInt();
				break;
			}
		}
	}

	for (auto _friend : friend_list) {
		qmlbridge->insertFriend(_friend.toUInt(), Toxcore::get_friend_name(tox, _friend.toUInt()));
	}

	toxcore_timer = Toxcore::create_qtimer(tox);
	toxcore_timer->start();
	return 0;
}

QmlCBridge::~QmlCBridge()
{
	if (current_profile.isEmpty()) {
		return;
	}
	signOutProfile();
}

QVariant QmlCBridge::getProfileList()
{
	QDir directory(GetProgDir());
	return directory.entryList(QStringList() << "*.tox", QDir::Files);
}

void QmlCBridge::signOutProfile(bool remove)
{
	Debug("Logout.");
	settings->beginGroup("Client_" + current_profile);
	if (remove) {
		settings->remove("");
	} else {
		settings->setValue("last_friend", Toxcore::get_friend_public_key(tox, qmlbridge->getCurrentFriendNumber()));
		settings->setValue("friend_list", qmlbridge->getFriendsModelOrder());
	}
	settings->endGroup();
	settings->sync();

	toxcore_timer->stop();
	delete toxcore_timer;
	Toxcore::destroy(tox);

	delete chat_db;
	profile_password.clear();

	if (remove) {
		QFile::remove(GetProgDir() + current_profile);
		QFile::remove(GetProgDir() + "chat_" + QString(current_profile).replace(".tox", ".db"));
	}
	current_profile.clear();
}

int main(int argc, char *argv[])
{
	QtStatusBar::setColor(QColor("#3F51B5"));
#if defined (Q_OS_ANDROID)
	const QString permission_write = "android.permission.WRITE_EXTERNAL_STORAGE";
	auto permission_result = QtAndroid::checkPermission(permission_write);
	if(permission_result == QtAndroid::PermissionResult::Denied){
		QtAndroid::PermissionResultMap resultHash = QtAndroid::requestPermissionsSync(QStringList({permission_write}));
		if(resultHash[permission_write] == QtAndroid::PermissionResult::Denied) {
			return 1;
		}
	}
#endif
	ChatDataBase::registerSQLDriver();
	settings = new QSettings(GetProgDir() + "settings.ini", QSettings::IniFormat);

	Debug("App started.");
	QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

	QGuiApplication app(argc, argv);
	qInstallMessageHandler(customMessageHandler);

	QQmlApplicationEngine engine;
	const QUrl url(QStringLiteral(QML_MAIN));
	QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
					 &app, [url](QObject *obj, const QUrl &objUrl) {
		if (!obj && url == objUrl)
			QCoreApplication::exit(-1);
	}, Qt::QueuedConnection);

	qmlbridge = new QmlCBridge;
	QQmlContext *root = engine.rootContext();
	root->setContextProperty("bridge", qmlbridge);
	QtNotification::declareQML();
	QtStatusBar::declareQML();
	QtToast::declareQML();
	QZXing::registerQMLTypes();
	QZXing::registerQMLImageProvider(engine);
	engine.load(url);
#ifdef Q_OS_ANDROID
	QtAndroid::hideSplashScreen();
#endif
	QObject *component = engine.rootObjects().first();
	qmlbridge->setComponent(component);

	int result = app.exec();
	delete qmlbridge;
	delete settings;
	Debug("Program exited successfully.");

	return result;
}
