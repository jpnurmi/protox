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
	QmlCBridge(Tox *_tox, QTimer *_toxcore_timer, quint32 last_friend_number);
	void setComponent(QObject *_component);
	void insertMessage(const QString &message, quint32 friend_number, bool self = false, quint32 message_id = 0, quint64 unique_id = 0, QDateTime dt = QDateTime::currentDateTime(), bool history = false, bool failed = false);
	void insertFriend(qint32 friend_number, const QString &nickName, bool request = false, const QString &request_message = "", const ToxPk &friendPk = "");
	void setMessageReceived(quint32 friend_number, quint32 message_id, bool use_uid = false, quint64 unique_id = 0);
	void setCurrentFriendConnStatus(quint32 friend_number, int conn_status);
	void updateFriendNickName(quint32 friend_number, const QString &nickname);
	void setFriendTyping(quint32 friend_number, bool typing);
	void setFriendStatusMessage(quint32 friend_number, const QString &message);
	void setFriendStatus(quint32 friend_number, quint32 status);
	void setConnStatus(int conn_status);
	QList<QVariant> getFriendsModelOrder();
public slots:
	Q_INVOKABLE void sendMessage(const QString &message);
	Q_INVOKABLE quint32 getCurrentFriendNumber();
	Q_INVOKABLE int getFriendConnStatus(quint32 friend_number);
	Q_INVOKABLE const QString getFriendNickname(quint32 friend_number);
	Q_INVOKABLE void setCurrentFriend(quint32 newFriend);
	Q_INVOKABLE void retrieveChatLog(quint32 start = 0, bool from = true, bool reverse = false);
	Q_INVOKABLE QString getToxId();
	Q_INVOKABLE void copyTextToClipboard(const QString &text);
	Q_INVOKABLE void makeFriendRequest(const QString &toxId, const QString &friendMessage);
	Q_INVOKABLE void deleteFriend(quint32 friend_number);
	Q_INVOKABLE void clearFriendChatHistory(quint32 friend_number);
	Q_INVOKABLE void setTypingFriend(quint32 friend_number, bool typing);
	Q_INVOKABLE const QString getFriendStatusMessage(quint32 friend_number);
	Q_INVOKABLE const QString getNickname(bool toxId = false);
	Q_INVOKABLE void setNickname(const QString &nickname);
	Q_INVOKABLE const QString getStatusMessage();
	Q_INVOKABLE void setStatusMessage(const QString &statusMessage);
	Q_INVOKABLE int getStatus();
	Q_INVOKABLE void setStatus(quint32 status);
	Q_INVOKABLE void changeConnection(bool online);
	Q_INVOKABLE long getFriendsCount();
	Q_INVOKABLE quint32 getMessagesCount(quint32 friend_number);
	Q_INVOKABLE int getConnStatus();
	Q_INVOKABLE void addFriend(const QString &friendPk);

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
	QTimer *toxcore_timer;
};

#endif // MAIN_H
