#include "db.h"
#include "tools.h"

#define DATABASE_VERSION 1
#define APPLICATION_ID ('P' << 24) + ('T' << 16) + ('O' << 8) + 'X'

ChatDataBase::ChatDataBase(const QString fileName)
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

	const QString create_command_last_msg =
			"CREATE TABLE IF NOT EXISTS LastMessage\n"
			"(\n"
			"	public_key BLOB,\n"
			"	datetime INTEGER,\n"
			"	PRIMARY KEY(public_key)\n"
			");\n"
			"";
	query = db.exec(create_command_last_msg);

	/*
	const QString create_command_friends =
			"CREATE TABLE IF NOT EXISTS Friends\n"
			"(\n"
			"	public_key BLOB,\n"
			"	name TEXT,\n"
			"	PRIMARY KEY(public_key)\n"
			");\n"
			"";
	query = db.exec(create_command_friends);
	*/
	db.commit();
}

void ChatDataBase::asyncCommit()
{
	if (future.isRunning()) {
		if (commitRequests)
			return;
		commitRequests = true;
		another_future = QtConcurrent::run([=]() {
			while (future.isRunning()) {}
			db.commit();
			commitRequests = false;
		});
	}
	if (another_future.isRunning())
	{
		if (commitAnotherRequests)
			return;
		commitAnotherRequests = true;
		future = QtConcurrent::run([=]() {
			while (another_future.isRunning()) {}
			db.commit();
			commitAnotherRequests = false;
		});
	}
	future = QtConcurrent::run([=]() {
		db.commit();
	});
}

quint64 ChatDataBase::getMessagesCountFriend(ToxPk public_key)
{
	QSqlQuery query(db);
	query.prepare("SELECT COUNT(*) FROM Messages WHERE (public_key = :public_key)");
	query.bindValue(":public_key", public_key);
	query.exec();
	query.first();
	return query.value(0).toULongLong();
}

void ChatDataBase::insertMessage(const QString message, QDateTime dt, ToxPk public_key, bool self, quint64 unique_id, bool failed)
{
	Debug("message: " + message + " uid:" + QString::number(unique_id));
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
	Debug("error: " + query.lastError().text());

	query.prepare("INSERT OR REPLACE INTO LastMessage (public_key, datetime) "
				  "VALUES (:public_key, :datetime)");
	query.bindValue(":public_key", public_key);
	query.bindValue(":datetime", dt.toSecsSinceEpoch());
	query.exec();
	db.commit();
}

void ChatDataBase::setMessageReceived(quint64 unique_id, ToxPk public_key)
{
	QSqlQuery query(db);
	query.prepare("UPDATE Messages SET received = 1 WHERE unique_id = :unique_id AND public_key = :public_key");
	query.bindValue(":unique_id", unique_id);
	query.bindValue(":public_key", public_key);
	query.exec();
	db.commit();
}

ToxMessages ChatDataBase::getFriendMessagesFromDateTime(ToxPk public_key, QDateTime dt)
{
	ToxMessages messages;
	QSqlQuery query(db);
	query.prepare("SELECT message,datetime,self,received,unique_id,failed FROM Messages WHERE (public_key = :public_key) AND (datetime >= :datetime)");
	query.bindValue(":public_key", public_key);
	query.bindValue(":datetime", dt.toSecsSinceEpoch());
	query.exec();
	while (query.next()) {
		messages.push_back(ToxMessage(query.value(0).toString(),
									  QDateTime::fromSecsSinceEpoch(query.value(1).toULongLong()),
									  query.value(2).toBool(),
									  query.value(3).toBool(),
									  query.value(4).toULongLong()));
	}
	std::sort(messages.begin(), messages.end(), [](const auto &a, const auto &b) { return a.unique_id < b.unique_id; });
	return messages;
}

void ChatDataBase::clearFriendChatHistory(ToxPk public_key)
{
	QSqlQuery query(db);
	query.prepare("DELETE FROM Messages WHERE public_key = :public_key");
	query.bindValue(":public_key", public_key);
	query.exec();
	query.prepare("DELETE FROM LastMessage WHERE public_key = :public_key");
	query.bindValue(":public_key", public_key);
	query.exec();
	db.commit();
}

/*
void ChatDataBase::insertFriend(ToxPk public_key, const QString name)
{
	QSqlQuery query;
	query.prepare("INSERT INTO Friends (public_key, name)"
				  "VALUES (:public_key, :name)"
				  "ON DUPLICATE KEY UPDATE name = :name;");
	query.bindValue(":public_key", public_key);
	query.bindValue(":name", name);
	query.exec();
	Debug("test: " + query.lastError().text());

	db.commit();
}
*/

ChatDataBase::~ChatDataBase()
{
	db.close();
}
