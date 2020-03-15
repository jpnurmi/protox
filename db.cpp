#include "db.h"
#include "tools.h"

#define DATABASE_VERSION 2
#define APPLICATION_ID ('P' << 24) + ('T' << 16) + ('O' << 8) + 'X'

ChatDataBase::ChatDataBase(const QString &fileName, const QString &password)
{
	db = QSqlDatabase::addDatabase("SQLITECIPHER");
	db.setDatabaseName(GetProgDir() + fileName);

	if (!password.isEmpty()) {
		db.setPassword(password);
		if (!checkEncrypted()) {
			db.setConnectOptions("QSQLITE_CREATE_KEY");
		}
	}
	db.open();

	QSqlQuery query;
	query = db.exec(QString("PRAGMA application_id=%1").arg(APPLICATION_ID));
	query = db.exec(QString("PRAGMA user_version=%1").arg(DATABASE_VERSION));
	const QString create_command_messages =
			"CREATE TABLE IF NOT EXISTS Messages\n"
			"(\n"
			"	public_key BLOB,\n"
			"	type INTEGER,\n"
			"	reference_id INTEGER,\n"
			"	self INTEGER,\n"
			"	received INTEGER,\n"
			"	datetime INTEGER,\n"
			"	unique_id INTEGER,\n"
			"	failed INTEGER,\n"
			"	PRIMARY KEY(public_key, unique_id)\n"
			");\n";
	query = db.exec(create_command_messages);
	const QString create_command_text_messages = 
			"CREATE TABLE IF NOT EXISTS TextMessages\n"
			"(\n"
			"	reference_id INTEGER PRIMARY KEY,\n"
			"	message STRING\n"
			");\n"
			"";
	query = db.exec(create_command_text_messages);
	const QString create_command_file_messages = 
			"CREATE TABLE IF NOT EXISTS FileMessages\n"
			"(\n"
			"	reference_id INTEGER PRIMARY KEY,\n"
			"	file_path STRING,\n"
			"	size INTEGER\n"
			");";
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

void ChatDataBase::insertMessage(const ToxVariantMessage &variantMessage, QDateTime dt, const ToxPk &public_key, bool self, quint64 unique_id, bool failed)
{
	int type = variantMessage["type"].toInt();
	QSqlQuery msg_query(db);

	QString table;
	switch (type) {
		case ToxVariantMessageType::TOXMSG_TEXT: 
			msg_query.prepare("INSERT INTO TextMessages (message) " 
							  "VALUES (:message)");
			msg_query.bindValue(":message", variantMessage["message"]);
			table = "TextMessages";
			break;
	}
	msg_query.exec();

	QSqlQuery last_msg_query = db.exec(QString("SELECT reference_id FROM %1 ORDER BY reference_id DESC LIMIT 1").arg(table));
	last_msg_query.next();
	
	QSqlQuery query(db);
	query.prepare("INSERT INTO Messages (public_key, type, reference_id, self, received, datetime, unique_id) "
				  "VALUES (:public_key, :type, :reference_id, :self, :received, :datetime, :unique_id)");
	query.bindValue(":public_key", public_key);
	query.bindValue(":type", type);
	query.bindValue(":reference_id", last_msg_query.value(0).toInt());
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
				  "SELECT type,reference_id,unique_id,datetime,self,received,failed FROM Messages WHERE public_key = :public_key AND unique_id %1 :start ORDER BY unique_id %2 LIMIT :limit"
				  ") ORDER BY unique_id ASC").arg(reverse ? "<" : ">", from ? "DESC" : "ASC"));
	query.bindValue(":public_key", public_key);
	query.bindValue(":start", start);
	query.bindValue(":limit", limit);
	query.exec();
	while (query.next()) {
		QSqlQuery msg_query(db);
		int type = query.value(0).toInt();
		quint32 reference_id = query.value(1).toUInt();
		switch (type) {
			case ToxVariantMessageType::TOXMSG_TEXT: 
				msg_query.prepare("SELECT message FROM TextMessages WHERE reference_id = :reference_id");
				break;
		}
		msg_query.bindValue(":reference_id", reference_id);
		msg_query.exec();
		ToxVariantMessage variantMessage;
		variantMessage.insert("type", type);
		msg_query.next();
		switch (type) {
			case ToxVariantMessageType::TOXMSG_TEXT:
				variantMessage.insert("message", msg_query.value(0).toString());
				break;
		}
		messages.push_back(ToxMessage(variantMessage,
									  query.value(2).toULongLong(),
									  QDateTime::fromSecsSinceEpoch(query.value(3).toULongLong()),
									  query.value(4).toBool(),
									  query.value(5).toBool()));
	}
	return messages;
}

void ChatDataBase::clearFriendChatHistory(const ToxPk &public_key)
{
	db.exec("DROP TABLE IF EXISTS MessagesToDelete");
	db.exec("CREATE TEMPORARY TABLE MessagesToDelete (\n"
			"	reference_id INTEGER PRIMARY KEY\n"
			");");
	QSqlQuery pre_query(db);
	pre_query.prepare("INSERT INTO MessagesToDelete (reference_id) "
					  "SELECT reference_id FROM Messages WHERE public_key = :public_key");
	pre_query.bindValue(":public_key", public_key);
	pre_query.exec();
	db.exec("DELETE FROM TextMessages WHERE reference_id IN MessagesToDelete");
	db.exec("DELETE FROM FileMessages WHERE reference_id IN MessagesToDelete");
	db.exec("DELETE FROM Messages WHERE reference_id IN MessagesToDelete");
	db.exec("DROP TABLE MessagesToDelete");
}

void ChatDataBase::updatePassword(const QString &password)
{
	if (password.isEmpty()) {
		db.close();
		db.setConnectOptions("QSQLITE_REMOVE_KEY");
		db.open();
	} else {
		db.close();
		if (checkEncrypted()) {
			db.setConnectOptions("QSQLITE_UPDATE_KEY=" + password);
		} else {
			db.setPassword(password);
			db.setConnectOptions("QSQLITE_CREATE_KEY");
		}
		db.open();
	}
}

bool ChatDataBase::checkEncrypted()
{
	QFile f(db.databaseName());
	if (!f.open(QFile::ReadOnly)) {
		return false;
	}
	QByteArray data = f.read(15);
	f.close();
	if (QString::fromLatin1(data) == "SQLite format 3") {
		return false;
	}
	return true;
}

ChatDataBase::~ChatDataBase()
{
	db.close();
	db.removeDatabase(QSqlDatabase::defaultConnection);
}
