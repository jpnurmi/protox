#ifndef MAIN_H
#define MAIN_H

#include "common.h"
#include "tox.h"
#include "db.h"

#include <QQmlApplicationEngine>
#include <QGuiApplication>

#include "tools.h"

#define QML_MAIN "qrc:/.app.qml"

class QmlCBridge : public QObject
{
	Q_OBJECT
public:
	explicit QmlCBridge();
	~QmlCBridge();
	void setComponent(QObject *_component);
	void insertMessage(const ToxVariantMessage &message, quint32 friend_number, const QDateTime &dt, bool self = false, quint64 unique_id = 0, bool history = false, bool failed = false, bool preload = false);
	void insertFriend(qint32 friend_number, const QString &nickName, bool request = false, const QString &request_message = "", const ToxPk &friendToxId = "");
	void setMessageReceived(quint32 friend_number, quint64 unique_id = 0);
	void setCurrentFriendConnStatus(quint32 friend_number, int conn_status);
	void updateFriendNickName(quint32 friend_number, const QString &nickname);
	void setFriendTyping(quint32 friend_number, bool typing);
	void setFriendStatusMessage(quint32 friend_number, const QString &message);
	void setFriendStatus(quint32 friend_number, quint32 status);
	void setConnectionStatus(int conn_status);
	QList<QVariant> getFriendsModelOrder();
	void setKeyboardHeight(int height);
	bool getAppInactive() { return app_inactive; }
	void tryReconnect();
	void sendPendingMessages(quint32 friend_number);
	void removeNonFailedPendingMessages(quint32 friend_number);
	void changeFileProgress(quint32 friend_number, quint32 file_number, quint32 bytesTransfered, bool finished);
	void fileControlUpdateMessage(quint32 friend_number, quint64 unique_id, quint32 control, bool remote);
	void cancelFileNotification(quint32 friend_number, quint32 file_number);
	void cancelTextNotification(quint32 friend_number);
	void createFileProgressNotification(quint32 friend_number, quint32 file_number);
	void updateFriendAvatar(quint32 friend_number);
	void createTimers();
	ChatDataBase *getChatDB() { return chat_db; }
private:
	void updateToxPasswordKey();
	const QString formatBytes(quint64 bytes);
public slots:
	Q_INVOKABLE void sendMessage(quint32 friend_number, const QString &message, bool reply = false);
	Q_INVOKABLE quint32 getCurrentFriendNumber();
	Q_INVOKABLE int getFriendConnStatus(quint32 friend_number);
	Q_INVOKABLE const QString getFriendNickname(quint32 friend_number, bool publicKey = true);
	Q_INVOKABLE bool checkFriendCustomNickname(quint32 friend_number);
	Q_INVOKABLE void setCurrentFriend(quint32 newFriend);
	Q_INVOKABLE bool checkRemainingMessages(quint32 start);
	Q_INVOKABLE void retrieveChatLog(quint32 start = 0, bool preload = false);
	Q_INVOKABLE QString getToxId();
	Q_INVOKABLE void copyTextToClipboard(QString text);
	Q_INVOKABLE void makeFriendRequest(const QString &toxId, const QString &friendMessage);
	Q_INVOKABLE void deleteFriend(quint32 friend_number);
	Q_INVOKABLE void clearFriendChatHistory(quint32 friend_number, bool keep_active_file_transfers);
	Q_INVOKABLE void setTypingFriend(quint32 friend_number, bool typing);
	Q_INVOKABLE const QString getFriendStatusMessage(quint32 friend_number);
	Q_INVOKABLE const QString getNickname(bool toxPk = true);
	Q_INVOKABLE void setNickname(const QString &nickname);
	Q_INVOKABLE const QString getStatusMessage();
	Q_INVOKABLE void setStatusMessage(const QString &statusMessage);
	Q_INVOKABLE int getStatus();
	Q_INVOKABLE void setStatus(quint32 status);
	Q_INVOKABLE long getFriendsCount();
	Q_INVOKABLE int getConnectionStatus();
	Q_INVOKABLE quint32 addFriend(const QString &friendToxIdHex);
	Q_INVOKABLE int getFriendStatus(quint32 friend_number);
	Q_INVOKABLE QString getNospamValue();
	Q_INVOKABLE void setNospamValue(const QString &nospam);
	Q_INVOKABLE QVariant getSettingsValue(const QString &group, const QString &key, int type, const QVariant &default_value);
	Q_INVOKABLE QVariant getSettingsValueDefault(const QString &group, const QString &key, int type);
	Q_INVOKABLE void setSettingsValue(const QString &group, const QString &key, const QVariant &value);
	Q_INVOKABLE void setAppInactive(bool inactive) { app_inactive = inactive; }
	Q_INVOKABLE void setKeyboardAdjustMode(bool adjustNothing);
	Q_INVOKABLE int signInProfile(const QString &profile, bool create_new = false, const QString &password = "", bool autoLogin = false);
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
	Q_INVOKABLE quint32 getToxPublicKeySizeHex();
	Q_INVOKABLE quint32 getHostnameMaxLength();
	Q_INVOKABLE QString getSystemLocale();
	Q_INVOKABLE void hideSplashScreen();
	Q_INVOKABLE bool checkMessageInPendingList(quint32 friend_number, quint64 unique_id);
	Q_INVOKABLE void resendMessage(quint32 friend_number, quint64 unique_id);
	Q_INVOKABLE void removeMessageFromPendingList(quint32 friend_number, quint64 unique_id);
	Q_INVOKABLE void removeMessageFromDB(quint32 friend_number, quint64 unique_id);
	Q_INVOKABLE QString uriToRealPath(const QString &uriString);
	Q_INVOKABLE quint32 sendFile(quint32 friend_number, const QString &file_path);
	Q_INVOKABLE bool controlFile(quint32 friend_number, quint32 file_number, quint32 control);
	Q_INVOKABLE QString getDefaultDownloadsDirectory();
	Q_INVOKABLE QString checkFileImage(const QString &path);
	Q_INVOKABLE bool viewFile(const QString &path, const QString &type);
	Q_INVOKABLE int acceptFile(quint32 friend_number, quint32 file_number);
	Q_INVOKABLE bool checkFileExists(const QString &path);
	Q_INVOKABLE QString getFriendPublicKeyHex(quint32 friend_number);
	Q_INVOKABLE const QString getFriendAvatarPath(quint32 friend_number);
	Q_INVOKABLE const QString getSelfAvatarPath();
	Q_INVOKABLE void changeSelfAvatar(const QString &path);
	Q_INVOKABLE const QSize getImageSize(const QString &path);
	Q_INVOKABLE const QString getCurrentCommitSha1();
	Q_INVOKABLE void setTranslation(const QString &translation);
	Q_INVOKABLE void scrollToEnd();
	Q_INVOKABLE QString importProfile(const QString &path);

public:
	ToxBootstrapingThread bootstrapping_thread;
	QAtomicInteger <bool> abort_bootstrapping;
public:
	ToxPendingMessages pending_messages;
	ToxFileTransfers transfers;
	ToxFileMessages file_messages;
	ToxSelfCanceledTransfers self_canceled_transfers;
private:
	quint32 current_friend_number;
	QString current_profile;
	QString profile_password;
	bool app_inactive;
private:
	ChatDataBase *chat_db;
private:
	QObject *component;
	QTranslator *translator;
	QTimer *toxcore_timer;
	QTimer *reconnection_timer;
private:
	Tox *tox;
	Tox_Pass_Key *tox_pass_key;
	Tox_Options *tox_opts;
};

#endif // MAIN_H
