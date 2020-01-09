#ifndef MAIN_H
#define MAIN_H

#include "common.h"
#include "tox.h"

#include <QQmlApplicationEngine>
#include <QGuiApplication>

#include "tools.h"

#define QML_MAIN "qrc:/main.qml"

class QmlCBridge : public QObject
{
	Q_OBJECT
public:
	QmlCBridge(Tox *_tox);
	void setComponent(QObject *_component);
	void insertMessage(const QString &message, quint32 friend_number, bool self = false, quint32 message_id = 0, quint64 unique_id = 0, QDateTime dt = QDateTime::currentDateTime(), bool history = false, bool failed = false);
	void insertFriend(qint32 friend_number, const QString nickName);
	void setMessageReceived(quint32 friend_number, quint32 message_id, bool use_uid = false, quint64 unique_id = 0);
	void setCurrentFriendConnStatus(quint32 friend_number, int conn_status);
	void updateFriendNickName(quint32 friend_number, const QString nickname);
public slots:
	Q_INVOKABLE void sendMessage(const QString message);
	Q_INVOKABLE quint32 getCurrentFriendNumber();
	Q_INVOKABLE int getFriendConnStatus(quint32 friend_number);
	Q_INVOKABLE const QString getFriendNickname(quint32 friend_number);
	Q_INVOKABLE void setCurrentFriend(quint32 newFriend);
	Q_INVOKABLE void retrieveChatLog();
	Q_INVOKABLE void copyToxIdToClipboard();
	Q_INVOKABLE void copyTextToClipboard(const QString text);
	Q_INVOKABLE void makeFriendRequest(const QString toxId, const QString friendMessage);
	Q_INVOKABLE void deleteFriend(quint32 friend_number);
	Q_INVOKABLE void clearFriendChatHistory(quint32 friend_number);

public:
	ToxFriendsConnStatus friends_conn_status;
	ToxMessagesIdUid messages_id_uid;
	ToxMessagesDateTime messages_last_dt;
	ToxFriendsOnce friends_once;
private:
	quint32 current_friend_number;
private:
	QObject *component;
	Tox *tox;
};

#endif // MAIN_H
