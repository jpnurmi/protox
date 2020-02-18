#ifndef DB_H
#define DB_H

#include "common.h"
#include "tox.h"

class ChatDataBase : public QObject
{
public:
	ChatDataBase(const QString &fileName);
	void insertMessage(const ToxVariantMessage &variantMessage, QDateTime dt, const ToxPk &public_key, bool self = false, quint64 unique_id = 0, bool failed = false);
	void setMessageReceived(quint64 unique_id, const ToxPk &public_key);
	ToxMessages getFriendMessages(const ToxPk &public_key, quint32 limit, quint32 start, bool from, bool reverse, QDate fromDate = QDate(1, 1, 1));
	quint64 getMessagesCountFriend(const ToxPk &public_key);
	void clearFriendChatHistory(const ToxPk &public_key);
	~ChatDataBase();
private:
	QSqlDatabase db;
};

#endif // DB_H
