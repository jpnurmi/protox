#ifndef DB_H
#define DB_H

#include "common.h"
#include "tox.h"

class ChatDataBase : public QObject
{
public:
	ChatDataBase(const QString &fileName);
	void asyncCommit();
	void insertMessage(const QString &message, QDateTime dt, const ToxPk &public_key, bool self = false, quint64 unique_id = 0, bool failed = false);
	void setMessageReceived(quint64 unique_id, const ToxPk &public_key);
	ToxMessages getFriendMessages(const ToxPk &public_key, quint32 limit);
	quint64 getMessagesCountFriend(ToxPk &public_key);
	void clearFriendChatHistory(const ToxPk &public_key);
	//void insertFriend(ToxPk public_key, const QString name);
	~ChatDataBase();
private:
	QFuture<void> future;
	QFuture<void> another_future;
	quint32 commitRequests;
	quint32 commitAnotherRequests;
	QSqlDatabase db;
};

#endif // DB_H
