


#include "main.h"

#include "tools.h"
#include "db.h"

QPointer <QmlCBridge> qmlbridge;
QPointer <ChatDataBase> chat_db;

QmlCBridge::QmlCBridge(Tox *_tox)
{
	tox = _tox;

	//fixme
	current_friend_number = 0;
}

void QmlCBridge::setComponent(QObject *_component)
{
	component = _component;
}

void QmlCBridge::insertMessage(const QString &message, quint32 friend_number, bool self, quint32 message_id, quint64 unique_id, QDateTime dt, bool failed)
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
							  Q_ARG(QVariant, failed));
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
	insertMessage(message, current_friend_number, true, message_id, new_unique_id, dt, failed);
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

void QmlCBridge::retrieveChatLog()
{
	ToxMessages messages = chat_db->getFriendMessagesFromDateTime(toxcore_get_friend_public_key(tox, current_friend_number), 
											QDateTime::fromSecsSinceEpoch(0));
	for (auto msg : messages) {
		insertMessage(msg.message, current_friend_number, msg.self, 0, msg.unique_id, msg.dt);
	if (!msg.self || msg.received)
		setMessageReceived(current_friend_number, 0, true, msg.unique_id);
	}
}

int main(int argc, char *argv[])
{
	Tox *tox = toxcore_create();
	toxcore_bootstrap_DHT(tox);
	Debug("My address: " + ToxId_To_QString(toxcore_get_self_address(tox)));

	chat_db = new ChatDataBase("chat.db");

	QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
	
	QGuiApplication app(argc, argv);
	
	QQmlApplicationEngine engine;
	const QUrl url(QStringLiteral(QML_MAIN));
	QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
					 &app, [url](QObject *obj, const QUrl &objUrl) {
		if (!obj && url == objUrl)
			QCoreApplication::exit(-1);
	}, Qt::QueuedConnection);

	qmlbridge = new QmlCBridge(tox);
	QQmlContext *root = engine.rootContext();
	root->setContextProperty("bridge", qmlbridge);
	engine.load(url);
	QObject *component = engine.rootObjects().first();
	qmlbridge->setComponent(component);

	ToxFriends friends = toxcore_get_friends(tox);
	for (int i = 0; i < friends.count(); i++) {
		qmlbridge->insertFriend(friends[i], toxcore_get_friend_name(tox, friends[i]));
	}

	qmlbridge->retrieveChatLog();

	QTimer *toxcore_timer = toxcore_create_qtimer(tox);
	toxcore_timer->start();
	int result = app.exec();
	toxcore_timer->stop();
	toxcore_destroy(tox);
	delete qmlbridge;
	delete chat_db;
	Debug("Program exited.");
	return result;
}
