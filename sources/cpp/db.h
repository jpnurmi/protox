#ifndef DB_H
#define DB_H

#include "common.h"
#include "tox.h"

class ChatDataBase : public QObject
{
	Q_OBJECT
public:
	ChatDataBase(const QString &fileName, const QString &password = "");
	quint64 insertMessage(const ToxVariantMessage &variantMessage, const QDateTime &dt, const ToxPk &public_key, bool temporary, bool self);
	void setMessageReceived(quint64 unique_id, const ToxPk &public_key);
	quint64 getFriendMessagesCount(const ToxPk &public_key, quint32 limit, quint32 start, bool preload);
	const ToxMessages getFriendMessages(const ToxPk &public_key, quint32 limit, quint32 start, bool preload);
	quint64 getFileSize(quint64 unique_id, const ToxPk &public_key);
	const ToxTextMessage getTextMessage(quint64 unique_id, const ToxPk &public_key);
	bool updateFileMessageState(quint64 unique_id, const ToxPk &public_key, ToxFileState state);
	void removeMessage(quint64 unique_id, const ToxPk &public_key);
	quint64 getMessagesCountFriend(const ToxPk &public_key);
	void clearFriendChatHistory(const ToxPk &public_key, bool keep_active_file_transfers = false);
	void updatePassword(const QString &password);
	bool checkEncrypted();
	static void registerSQLDriver();
	~ChatDataBase();
private:
	void removeAllTemporaryMessages();
	void upgradeFromV4toV5();
	void execQuery(QSqlQuery &query);
	const QSqlQuery execQuery(const QString &query_string);
private:
	QSqlDatabase db;
};

#endif // DB_H
