#include "db.h"
#include "tools.h"

#include "deps/sqlitecipher/sqlitecipher_p.h"

#define DATABASE_VERSION 5
#define APPLICATION_ID ('P' << 24) + ('T' << 16) + ('O' << 8) + 'X'

ChatDataBase::ChatDataBase(const QString &fileName, const QString &password)
{
	db = QSqlDatabase::addDatabase("SQLITECIPHER");
	db.setDatabaseName(Tools::getProgDir() + fileName);

	if (!password.isEmpty()) {
		db.setPassword(password);
		if (!checkEncrypted()) {
			db.setConnectOptions("QSQLITE_CREATE_KEY");
		}
	}

	db.open();

	upgradeFromV4toV5();

	QSqlQuery query(db);
	query = execQuery(QString("PRAGMA application_id=%1").arg(APPLICATION_ID));
	query = execQuery(QString("PRAGMA user_version=%1").arg(DATABASE_VERSION));
	const QString create_command_messages =
			"CREATE TABLE IF NOT EXISTS Messages\n"
			"(\n"
			"	public_key BLOB,\n"
			"	type INTEGER,\n"
			"	reference_id INTEGER,\n"
			"	self INTEGER,\n"
			"	received INTEGER,\n"
			"	datetime INTEGER,\n"
			"	temporary INTEGER,\n"
			"	unique_id INTEGER,\n"
			"	PRIMARY KEY(public_key, unique_id)\n"
			");\n";
	query = execQuery(create_command_messages);
	const QString create_command_text_messages = 
			"CREATE TABLE IF NOT EXISTS TextMessages\n"
			"(\n"
			"	reference_id INTEGER PRIMARY KEY,\n"
			"	message STRING,\n"
			"	action INTEGER\n"
			");\n"
			"";
	query = execQuery(create_command_text_messages);
	const QString create_command_file_messages = 
			"CREATE TABLE IF NOT EXISTS FileMessages\n"
			"(\n"
			"	reference_id INTEGER PRIMARY KEY,\n"
			"	file_path STRING,\n"
			"	size INTEGER,\n"
			"	state INTEGER,\n"
			"	file_id BLOB\n"
			");\n";
	query = execQuery(create_command_file_messages);
	db.commit();
}

void ChatDataBase::upgradeFromV4toV5()
{
	QSqlQuery check = execQuery("PRAGMA user_version");
	check.next();
	quint64 user_version = check.value(0).toULongLong();
	check.finish();
	if (user_version == 4) {
		Tools::debug("Detected v4 .db. Upgrading...");
		QFile::copy(db.databaseName(), db.databaseName() + ".v4bak");
		execQuery("ALTER TABLE TextMessages ADD COLUMN action INTEGER");
		execQuery("UPDATE TextMessages SET action = 0");
	}
}

quint64 ChatDataBase::getMessagesCountFriend(const ToxPk &public_key)
{
	QSqlQuery query(db);
	query.prepare("SELECT COUNT(*) FROM Messages WHERE (public_key = :public_key)");
	query.bindValue(":public_key", public_key);
	execQuery(query);
	query.first();
	return query.value(0).toULongLong();
}

quint64 ChatDataBase::insertMessage(const ToxVariantMessage &variantMessage, const QDateTime &dt, const ToxPk &public_key, bool temporary, bool self)
{
	int type = variantMessage["type"].toInt();
	QSqlQuery msg_query(db);

	QString table;
	switch (type) {
		case ToxVariantMessageType::TOXMSG_TEXT: 
			msg_query.prepare("INSERT INTO TextMessages (message, action) " 
							  "VALUES (:message, :action)");
			msg_query.bindValue(":message", variantMessage["message"]);
			msg_query.bindValue(":action", variantMessage["action"]);
			table = "TextMessages";
			break;
		case ToxVariantMessageType::TOXMSG_FILE:
			msg_query.prepare("INSERT INTO FileMessages (file_path, size, state, file_id) " 
							  "VALUES (:file_path, :size, :state, :file_id)");
			msg_query.bindValue(":file_path", variantMessage["file_path"]);
			msg_query.bindValue(":size", variantMessage["size"]);
			msg_query.bindValue(":state", variantMessage["state"]);
			msg_query.bindValue(":file_id", variantMessage["file_id"]);
			table = "FileMessages";
			break;
	}
	execQuery(msg_query);

	QSqlQuery last_msg_query = execQuery(QString("SELECT reference_id FROM %1 ORDER BY reference_id DESC LIMIT 1").arg(table));
	last_msg_query.next();

	QSqlQuery new_unique_id_query(db);
	new_unique_id_query.prepare("SELECT MAX(unique_id) + 1 FROM Messages WHERE public_key = :public_key");
	new_unique_id_query.bindValue(":public_key", public_key);
	execQuery(new_unique_id_query);
	new_unique_id_query.next();
	quint64 new_unique_id = new_unique_id_query.value(0).toULongLong();

	QSqlQuery query(db);
	query.prepare("INSERT INTO Messages (public_key, type, reference_id, self, received, datetime, temporary, unique_id) "
				  "VALUES (:public_key, :type, :reference_id, :self, :received, :datetime, :temporary, :unique_id)");
	query.bindValue(":public_key", public_key);
	query.bindValue(":type", type);
	query.bindValue(":reference_id", last_msg_query.value(0).toInt());
	query.bindValue(":self", self);
	query.bindValue(":received", false);
	query.bindValue(":datetime", dt.toSecsSinceEpoch());
	query.bindValue(":temporary", temporary);
	query.bindValue(":unique_id", new_unique_id);
	execQuery(query);

	db.commit();
	return new_unique_id;
}

void ChatDataBase::setMessageReceived(quint64 unique_id, const ToxPk &public_key)
{
	QSqlQuery query(db);
	query.prepare("UPDATE Messages SET received = 1 WHERE unique_id = :unique_id AND public_key = :public_key");
	query.bindValue(":unique_id", unique_id);
	query.bindValue(":public_key", public_key);
	execQuery(query);
	db.commit();
}

quint64 ChatDataBase::getFriendMessagesCount(const ToxPk &public_key, quint32 limit, quint32 start, bool preload)
{
	QSqlQuery query(db);
	query.prepare(QString("SELECT COUNT(*) FROM ("
				  "SELECT type,reference_id,unique_id,datetime,self,received FROM Messages WHERE public_key = :public_key AND unique_id %1 :start ORDER BY unique_id DESC LIMIT :limit"
				  ") ORDER BY unique_id %2").arg(preload ? "<" : ">=", preload ? "DESC" : "ASC"));
	query.bindValue(":public_key", public_key);
	query.bindValue(":start", start);
	query.bindValue(":limit", limit);
	execQuery(query);
	query.next();
	return query.value(0).toULongLong();
}

const ToxMessages ChatDataBase::getFriendMessages(const ToxPk &public_key, quint32 limit, quint32 start, bool preload)
{
	ToxMessages messages;
	QSqlQuery query(db);
	query.prepare(QString("SELECT * FROM ("
				  "SELECT type,reference_id,unique_id,datetime,self,received FROM Messages WHERE public_key = :public_key AND unique_id %1 :start ORDER BY unique_id DESC LIMIT :limit"
				  ") ORDER BY unique_id %2").arg(preload ? "<" : ">=", preload ? "DESC" : "ASC"));
	query.bindValue(":public_key", public_key);
	query.bindValue(":start", start);
	query.bindValue(":limit", limit);
	execQuery(query);
	while (query.next()) {
		QSqlQuery msg_query(db);
		int type = query.value(0).toInt();
		quint32 reference_id = query.value(1).toUInt();
		switch (type) {
			case ToxVariantMessageType::TOXMSG_TEXT: 
				msg_query.prepare("SELECT message,action FROM TextMessages WHERE reference_id = :reference_id");
				break;
			case ToxVariantMessageType::TOXMSG_FILE:
				msg_query.prepare("SELECT file_path,size,state,file_id FROM FileMessages WHERE reference_id = :reference_id");
				break;
		}
		msg_query.bindValue(":reference_id", reference_id);
		execQuery(msg_query);
		ToxVariantMessage variantMessage;
		variantMessage.insert("type", type);
		msg_query.next();
		switch (type) {
			case ToxVariantMessageType::TOXMSG_TEXT:
				variantMessage.insert("message", msg_query.value(0).toString());
				variantMessage.insert("action", msg_query.value(1).toBool());
				break;
			case ToxVariantMessageType::TOXMSG_FILE:
				QString file_path = msg_query.value(0).toString();
				variantMessage.insert("file_path", file_path);
				variantMessage.insert("size", msg_query.value(1).toUInt());
				variantMessage.insert("state", msg_query.value(2).toUInt());
				variantMessage.insert("file_id", msg_query.value(3).toByteArray());
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

quint64 ChatDataBase::getFileSize(quint64 unique_id, const ToxPk &public_key)
{
	QSqlQuery query(db);
	query.prepare("SELECT type,reference_id FROM Messages WHERE unique_id = :unique_id AND public_key = :public_key");
	query.bindValue(":unique_id", unique_id);
	query.bindValue(":public_key", public_key);
	execQuery(query);
	query.next();
	if (query.value(0).toInt() == ToxVariantMessageType::TOXMSG_FILE) {
		QSqlQuery msg_query(db);
		msg_query.prepare("SELECT size FROM FileMessages WHERE reference_id = :reference_id");
		msg_query.bindValue(":reference_id", query.value(1).toUInt());
		execQuery(msg_query);
		msg_query.next();
		return msg_query.value(0).toULongLong();
	} else {
		return 0;
	}
}

const ToxTextMessage ChatDataBase::getTextMessage(quint64 unique_id, const ToxPk &public_key)
{
	QSqlQuery query(db);
	query.prepare("SELECT type,reference_id FROM Messages WHERE unique_id = :unique_id AND public_key = :public_key");
	query.bindValue(":unique_id", unique_id);
	query.bindValue(":public_key", public_key);
	execQuery(query);
	query.next();
	if (query.value(0).toInt() == ToxVariantMessageType::TOXMSG_TEXT) {
		QSqlQuery msg_query(db);
		msg_query.prepare("SELECT message,action FROM TextMessages WHERE reference_id = :reference_id");
		msg_query.bindValue(":reference_id", query.value(1).toUInt());
		execQuery(msg_query);
		msg_query.next();
		return ToxTextMessage(msg_query.value(0).toString(), msg_query.value(1).toBool());
	} else {
		return ToxTextMessage();
	}
}

bool ChatDataBase::updateFileMessageState(quint64 unique_id, const ToxPk &public_key, ToxFileState state)
{
	QSqlQuery query(db);
	query.prepare("SELECT type,reference_id FROM Messages WHERE unique_id = :unique_id AND public_key = :public_key");
	query.bindValue(":unique_id", unique_id);
	query.bindValue(":public_key", public_key);
	execQuery(query);
	query.next();
	if (query.value(0).toInt() == ToxVariantMessageType::TOXMSG_FILE) {
		QSqlQuery msg_query(db);
		msg_query.prepare("UPDATE FileMessages SET state = :state WHERE reference_id = :reference_id");
		msg_query.bindValue(":reference_id", query.value(1).toUInt());
		msg_query.bindValue(":state", state);
		execQuery(msg_query);
		return true;
	} else {
		return false;
	}
}

void ChatDataBase::removeMessage(quint64 unique_id, const ToxPk &public_key)
{
	QSqlQuery query(db);
	query.prepare("SELECT type,reference_id FROM Messages WHERE unique_id = :unique_id AND public_key = :public_key");
	query.bindValue(":unique_id", unique_id);
	query.bindValue(":public_key", public_key);
	execQuery(query);
	query.next();
	QString type;
	switch (query.value(0).toInt()) {
		case ToxVariantMessageType::TOXMSG_TEXT: type = "Text"; break;
		case ToxVariantMessageType::TOXMSG_FILE: type = "File"; break;
	}
	quint32 reference_id = query.value(1).toUInt();
	QSqlQuery remove_query(db);
	remove_query.prepare(QString("DELETE FROM %1Messages WHERE reference_id = :reference_id").arg(type));
	remove_query.bindValue(":reference_id", reference_id);
	execQuery(remove_query);
	remove_query.prepare("DELETE FROM Messages WHERE unique_id = :unique_id AND public_key = :public_key");
	remove_query.bindValue(":unique_id", unique_id);
	remove_query.bindValue(":public_key", public_key);
	execQuery(remove_query);
	db.commit();
}

void ChatDataBase::clearFriendChatHistory(const ToxPk &public_key, bool keep_active_file_transfers)
{
	execQuery("DROP TABLE IF EXISTS MessagesToDelete");
	execQuery("CREATE TEMPORARY TABLE MessagesToDelete (\n"
			"	reference_id INTEGER PRIMARY KEY\n"
			");");
	QSqlQuery pre_query(db);
	if (keep_active_file_transfers) {
		pre_query.prepare("INSERT INTO MessagesToDelete (reference_id) "
						  "SELECT reference_id FROM Messages WHERE public_key=:public_key AND type != :type");
		pre_query.bindValue(":public_key", public_key);
		pre_query.bindValue(":type", ToxVariantMessageType::TOXMSG_FILE);
		execQuery(pre_query);
		pre_query.prepare("INSERT INTO MessagesToDelete (reference_id) "
						  "SELECT m.reference_id FROM Messages m "
						  "INNER JOIN FileMessages fm "
						  "ON type = :type "
						  "AND public_key = :public_key "
						  "AND m.reference_id = fm.reference_id "
						  "AND fm.state > :state;");
		pre_query.bindValue(":public_key", public_key);
		pre_query.bindValue(":type", ToxVariantMessageType::TOXMSG_FILE);
		pre_query.bindValue(":state", ToxFileState::TOX_FILE_PAUSED);
		execQuery(pre_query);
	} else {
		pre_query.prepare("INSERT INTO MessagesToDelete (reference_id) "
						  "SELECT reference_id FROM Messages WHERE public_key = :public_key");
		pre_query.bindValue(":public_key", public_key);
		execQuery(pre_query);
	}
	execQuery("DELETE FROM TextMessages WHERE reference_id IN MessagesToDelete");
	execQuery("DELETE FROM FileMessages WHERE reference_id IN MessagesToDelete");
	execQuery("DELETE FROM Messages WHERE reference_id IN MessagesToDelete");
	execQuery("DROP TABLE MessagesToDelete");
	db.commit();
}

void ChatDataBase::removeAllTemporaryMessages()
{
	execQuery("DROP TABLE IF EXISTS MessagesToDelete");
	execQuery("CREATE TEMPORARY TABLE MessagesToDelete (\n"
			"	reference_id INTEGER PRIMARY KEY\n"
			");");
	execQuery("INSERT INTO MessagesToDelete (reference_id) "
					  "SELECT reference_id FROM Messages WHERE temporary = 1");
	execQuery("DELETE FROM TextMessages WHERE reference_id IN MessagesToDelete");
	execQuery("DELETE FROM FileMessages WHERE reference_id IN MessagesToDelete");
	execQuery("DELETE FROM Messages WHERE reference_id IN MessagesToDelete");
	execQuery("DROP TABLE MessagesToDelete");
	db.commit();
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

void ChatDataBase::registerSQLDriver()
{
	QSqlDatabase::registerSqlDriver("SQLITECIPHER", new QSqlDriverCreator<SQLiteCipherDriver>);
}

void ChatDataBase::execQuery(QSqlQuery &query)
{
	query.exec();
#ifdef SQLDEBUG
	Tools::debug("SQL: " + query.lastQuery());
#endif
	const QString error = query.lastError().text();
	if (!error.isEmpty()) {
		Tools::debug("SQL error: " + query.lastError().text());
	}
}

const QSqlQuery ChatDataBase::execQuery(const QString &query_string)
{
	QSqlQuery query = db.exec(query_string);
#ifdef SQLDEBUG
	Tools::debug("SQL: " + query.lastQuery());
#endif
	const QString error = query.lastError().text();
	if (!error.isEmpty()) {
		Tools::debug("SQL error: " + query.lastError().text());
	}
	return query;
}

ChatDataBase::~ChatDataBase()
{
	removeAllTemporaryMessages();
	db.close();
	QSqlDatabase::removeDatabase(db.connectionName());
}
