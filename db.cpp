#include "db.h"
#include "tools.h"

#define DATABASE_VERSION 1
#define APPLICATION_ID ('P' << 24) + ('T' << 16) + ('O' << 8) + 'X'

ChatDataBase::ChatDataBase(const QString &fileName)
{
	commitRequests = 0;
	commitAnotherRequests = 0;
	db = QSqlDatabase::addDatabase("QSQLITE");
	db.setDatabaseName(GetProgDir() + fileName);
	db.open();

	QSqlQuery query;
	query = db.exec(QString("PRAGMA application_id=%1").arg(APPLICATION_ID));
	query = db.exec(QString("PRAGMA user_version=%1").arg(DATABASE_VERSION));
	const QString create_command_messages =
			"CREATE TABLE IF NOT EXISTS Messages\n"
			"(\n"
			"	public_key BLOB,\n"
			"	message TEXT,\n"
			"	self INTEGER,\n"
			"	received INTEGER,\n"
			"	datetime INTEGER,\n"
			"	unique_id INTEGER,\n"
			"	failed INTEGER,\n"
			"	PRIMARY KEY(public_key, unique_id)\n"
			");\n"
			"";
	query = db.exec(create_command_messages);
	db.commit();
}

quint64 ChatDataBase::getMessagesCountFriend(const ToxPk &public_key)
{
	QSqlQuery query(db);
	query.prepare("SELECT COUNT(*) FROM Messages WHERE (public_key = :public_key)");
	query.bindValue(":public_key", public_key);
	query.exec();
	query.first();
	return query.value(0).toULongLong();
}

void ChatDataBase::insertMessage(const QString &message, QDateTime dt, const ToxPk &public_key, bool self, quint64 unique_id, bool failed)
{
	QSqlQuery query(db);
	query.prepare("INSERT INTO Messages (public_key, message, self, received, datetime, unique_id) "
				  "VALUES (:public_key, :message, :self, :received, :datetime, :unique_id)");
	query.bindValue(":public_key", public_key);
	query.bindValue(":message", message);
	query.bindValue(":self", self);
	query.bindValue(":received", false);
	query.bindValue(":datetime", dt.toSecsSinceEpoch());
	query.bindValue(":unique_id", unique_id);
	query.bindValue(":failed", failed);
	query.exec();

	db.commit();
}

void ChatDataBase::setMessageReceived(quint64 unique_id, const ToxPk &public_key)
{
	QSqlQuery query(db);
	query.prepare("UPDATE Messages SET received = 1 WHERE unique_id = :unique_id AND public_key = :public_key");
	query.bindValue(":unique_id", unique_id);
	query.bindValue(":public_key", public_key);
	query.exec();
	db.commit();
}

ToxMessages ChatDataBase::getFriendMessages(const ToxPk &public_key, quint32 limit, quint32 start, bool from, bool reverse, QDate fromDate)
{
	ToxMessages messages;
	QSqlQuery query(db);
	query.prepare(QString("SELECT * FROM ("
				  "SELECT message,datetime,self,received,unique_id,failed FROM Messages WHERE public_key = :public_key AND unique_id %1 :start ORDER BY unique_id %2 LIMIT :limit"
				  ") ORDER BY unique_id ASC").arg(reverse ? "<" : ">", from ? "DESC" : "ASC"));
	query.bindValue(":public_key", public_key);
	query.bindValue(":start", start);
	query.bindValue(":limit", limit);
	query.exec();
	while (query.next()) {
		messages.push_back(ToxMessage(query.value(0).toString(),
									  QDateTime::fromSecsSinceEpoch(query.value(1).toULongLong()),
									  query.value(2).toBool(),
									  query.value(3).toBool(),
									  query.value(4).toULongLong()));
	}
	return messages;
}

void ChatDataBase::clearFriendChatHistory(const ToxPk &public_key)
{
	QSqlQuery query(db);
	query.prepare("DELETE FROM Messages WHERE public_key = :public_key");
	query.bindValue(":public_key", public_key);
	query.exec();
	db.commit();
}

ChatDataBase::~ChatDataBase()
{
	db.close();
}
