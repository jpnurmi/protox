#include "main.h"

#include "tools.h"
#include "db.h"

#include "QtNotification.h"

QPointer <QmlCBridge> qmlbridge;
QPointer <ChatDataBase> chat_db;
QPointer <QSettings> settings;

QmlCBridge::QmlCBridge(Tox *_tox, quint32 last_friend_number)
{
	tox = _tox;
	current_friend_number = last_friend_number;
}

void QmlCBridge::setComponent(QObject *_component)
{
	component = _component;
}

void QmlCBridge::insertMessage(const QString &message, quint32 friend_number, bool self, quint32 message_id, quint64 unique_id, QDateTime dt, bool history, bool failed)
{
	QVariant returnedValue;
	if (!friends_once[friend_number]) {
		friends_once[friend_number] = true;
	}
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

void QmlCBridge::insertFriend(qint32 friend_number, const QString nickName)
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "insertFriend",
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, nickName));
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

void QmlCBridge::sendMessage(const QString message)
{
	ToxPk friend_pk = toxcore_get_friend_public_key(tox, current_friend_number);
	bool failed;
	quint32 message_id = toxcore_send_message(tox, current_friend_number, message, failed);
	quint64 new_unique_id = chat_db->getMessagesCountFriend(friend_pk) + 1;
	QDateTime dt = QDateTime::currentDateTime();
	insertMessage(message, current_friend_number, true, message_id, new_unique_id, dt, false, failed);
	messages_id_uid[message_id] = new_unique_id;
	chat_db->insertMessage(message, dt, friend_pk, true, new_unique_id, failed);
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
	return toxcore_get_friend_name(tox, friend_number);
}

void QmlCBridge::setCurrentFriend(quint32 newFriend)
{
	current_friend_number = newFriend;
}

const QString QmlCBridge::getFriendStatusMessage(quint32 friend_number)
{
	return toxcore_get_friend_status_message(tox, friend_number);
}

void QmlCBridge::retrieveChatLog()
{
	ToxMessages messages = chat_db->getFriendMessagesFromDateTime(toxcore_get_friend_public_key(tox, current_friend_number), 
											QDateTime::fromSecsSinceEpoch(0));
	for (auto msg : messages) {
		insertMessage(msg.message, current_friend_number, msg.self, 0, msg.unique_id, msg.dt, true);
		if (!msg.self || msg.received)
			setMessageReceived(current_friend_number, 0, true, msg.unique_id);
	}
}

void QmlCBridge::copyToxIdToClipboard()
{
	QClipboard *clipboard = QGuiApplication::clipboard(); 
	clipboard->setText(ToxId_To_QString(toxcore_get_self_address(tox)));
}

void QmlCBridge::copyTextToClipboard(const QString text)
{
	QClipboard *clipboard = QGuiApplication::clipboard(); 
	clipboard->setText(text);
}

void QmlCBridge::makeFriendRequest(const QString toxId, const QString friendMessage)
{
	int error = toxcore_make_friend_request(tox, QString_To_ToxId(toxId), friendMessage);
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "sendFriendRequestStatus",
		Q_RETURN_ARG(QVariant, returnedValue), Q_ARG(QVariant, error));
}

void QmlCBridge::deleteFriend(quint32 friend_number)
{
	toxcore_delete_friend(tox, friend_number);
}

void QmlCBridge::clearFriendChatHistory(quint32 friend_number)
{
	chat_db->clearFriendChatHistory(toxcore_get_friend_public_key(tox, friend_number));
}

void QmlCBridge::updateFriendNickName(quint32 friend_number, const QString nickname)
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
	toxcore_set_typing_friend(tox, friend_number, typing);
}

void QmlCBridge::setFriendStatusMessage(quint32 friend_number, const QString message)
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
	return toxcore_get_nickname(tox, toxId);
}

void QmlCBridge::setNickname(const QString nickname)
{
	toxcore_set_nickname(tox, nickname);
}

const QString QmlCBridge::getStatusMessage()
{
	return toxcore_get_status_message(tox);
}

void QmlCBridge::setStatusMessage(const QString statusMessage)
{
	toxcore_set_status_message(tox, statusMessage);
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

int main(int argc, char *argv[])
{
	settings = new QSettings(GetProgDir() + "settings.ini", QSettings::IniFormat);
	Tox *tox = toxcore_create();
	toxcore_bootstrap_DHT(tox);
	Debug("My address: " + ToxId_To_QString(toxcore_get_self_address(tox)));

	chat_db = new ChatDataBase("chat.db");

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

	settings->beginGroup("Global");
	ToxPk friendPk = settings->value("last_friend", toxcore_get_friend_public_key(tox, 0)).toByteArray();
	settings->endGroup();
	ToxFriends friends = toxcore_get_friends(tox);

	quint32 last_friend_number = 0;
	if (!friendPk.isEmpty()) {
		for (auto _friend : friends) {
			if (toxcore_get_friend_public_key(tox, _friend) == friendPk) {
				last_friend_number = _friend;
				break;
			}
		}
	}

	qmlbridge = new QmlCBridge(tox, last_friend_number);
	QQmlContext *root = engine.rootContext();
	root->setContextProperty("bridge", qmlbridge);
	QtNotification::declareQML();
	engine.load(url);
	QObject *component = engine.rootObjects().first();
	qmlbridge->setComponent(component);

	for (auto _friend : friends) {
		qmlbridge->insertFriend(_friend, toxcore_get_friend_name(tox, _friend));
	}

	QTimer *toxcore_timer = toxcore_create_qtimer(tox);
	toxcore_timer->start();

	int result = app.exec();
	settings->beginGroup("Global");
	settings->setValue("last_friend", toxcore_get_friend_public_key(tox, qmlbridge->getCurrentFriendNumber()));
	settings->endGroup();
	settings->sync();
	toxcore_timer->stop();
	toxcore_destroy(tox);
	delete qmlbridge;
	delete chat_db;
	Debug("Program exited successfully.");

	return result;
}
