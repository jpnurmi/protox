#ifndef MAIN_H
#define MAIN_H

#include "common.h"
#include "tox.h"

#include <QQmlApplicationEngine>
#include <QGuiApplication>

#include "tools.h"

#define QML_MAIN "qrc:/app.qml"

class QmlCBridge : public QObject
{
	Q_OBJECT
public:
	QmlCBridge();
	~QmlCBridge();
	void setComponent(QObject *_component);
	void insertMessage(const ToxVariantMessage &message, quint32 friend_number, const QDateTime &dt, bool self = false, quint32 message_id = 0, quint64 unique_id = 0, bool history = false, bool failed = false);
	void insertFriend(qint32 friend_number, const QString &nickName, bool request = false, const QString &request_message = "", const ToxPk &friendPk = "");
	void setMessageReceived(quint32 friend_number, quint32 message_id, bool use_uid = false, quint64 unique_id = 0);
	void setCurrentFriendConnStatus(quint32 friend_number, int conn_status);
	void updateFriendNickName(quint32 friend_number, const QString &nickname);
	void setFriendTyping(quint32 friend_number, bool typing);
	void setFriendStatusMessage(quint32 friend_number, const QString &message);
	void setFriendStatus(quint32 friend_number, quint32 status);
	void setConnStatus(int conn_status);
	QList<QVariant> getFriendsModelOrder();
	void setKeyboardHeight(int height);
	bool getAppInactive() { return app_inactive; }
	const Tox_Pass_Key *getToxPasswordKey() { return tox_pass_key; }
	const QString getProfilePassword() { return profile_password; }
	void updateToxPasswordKey();
	void tryReconnect();
public slots:
	Q_INVOKABLE void sendMessage(const QString &message);
	Q_INVOKABLE quint32 getCurrentFriendNumber();
	Q_INVOKABLE int getFriendConnStatus(quint32 friend_number);
	Q_INVOKABLE const QString getFriendNickname(quint32 friend_number);
	Q_INVOKABLE void setCurrentFriend(quint32 newFriend);
	Q_INVOKABLE void retrieveChatLog(quint32 start = 0, bool from = true, bool reverse = false);
	Q_INVOKABLE QString getToxId();
	Q_INVOKABLE void copyTextToClipboard(QString text);
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
	Q_INVOKABLE long getFriendsCount();
	Q_INVOKABLE quint32 getMessagesCount(quint32 friend_number);
	Q_INVOKABLE int getConnStatus();
	Q_INVOKABLE int addFriend(const QString &friendPk);
	Q_INVOKABLE int getFriendStatus(quint32 friend_number);
	Q_INVOKABLE QString getNospamValue();
	Q_INVOKABLE void setNospamValue(const QString &nospam);
	Q_INVOKABLE QVariant getSettingsValue(const QString &group, const QString &key, int type, const QVariant &default_value);
	Q_INVOKABLE void setSettingsValue(const QString &group, const QString &key, const QVariant &value);
	Q_INVOKABLE void setAppInactive(bool inactive) { app_inactive = inactive; }
	Q_INVOKABLE void setKeyboardAdjustMode(bool adjustNothing);
	Q_INVOKABLE int signInProfile(const QString &profile, bool create = false, const QString &password = "", bool autoLogin = false);
	Q_INVOKABLE QVariant getProfileList();
	Q_INVOKABLE bool checkProfileEncrypted(const QString &profile);
	Q_INVOKABLE void setToxPassword(const QString &password);
	Q_INVOKABLE void signOutProfile(bool remove = false);
	Q_INVOKABLE void saveProfile();
	Q_INVOKABLE const QString getCurrentProfile() { return current_profile; }
	Q_INVOKABLE bool checkFriendHistoryExists(quint32 friend_number);
	Q_INVOKABLE void updateDataBasePassword(const QString &password);
	Q_INVOKABLE const QString getToxcoreVersion();
	Q_INVOKABLE void test();
	Q_INVOKABLE quint32 getToxNodesCount();
	Q_INVOKABLE quint32 getFriendRequestMessageMaxLength();
	Q_INVOKABLE quint32 getNicknameMaxLength();
	Q_INVOKABLE quint32 getStatusMessageMaxLength();
	Q_INVOKABLE quint32 getToxAddressSizeHex();

public:
	ToxFriendsConnStatus friends_conn_status;
	ToxPendingMessages pending_messages;
private:
	quint32 current_friend_number;
	QString current_profile;
	QString profile_password;
	bool app_inactive;
private:
	QObject *component;
private:
	QTimer *toxcore_timer;
	QTimer *reconnection_timer;
private:
	// fixme: move to tox.cpp
	Tox *tox;
	Tox_Pass_Key *tox_pass_key;
};

#endif // MAIN_H
