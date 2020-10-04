#include "main.h"

#include "tools.h"
#include "db.h"

#include "QtNotification.h"
#include "QtStatusBar.h"
#include "QZXing.h"
#include "native.h"
#include "qtutf8bytelimitvalidator.h"

QmlCBridge *qmlbridge = nullptr;
ChatDataBase *chat_db = nullptr;
QSettings *settings = nullptr;
QtNotification *notification = nullptr;

/*
 * QML <-> C++ object
*/

QmlCBridge::QmlCBridge()
{
	component = nullptr;
	tox = nullptr;
	tox_pass_key = nullptr;
	tox_opts = nullptr;
	toxcore_timer = nullptr;
	app_inactive = true;
	current_profile = "";
	current_friend_number = 0;
	profile_password = "";
	abort_bootstrapping = false;

	settings->beginGroup("Client");
	int reconnection_interval = settings->value("reconnection_interval", 60000).toInt();
	settings->endGroup();
	reconnection_timer = new QTimer;
	reconnection_timer->setInterval(reconnection_interval);
	reconnection_timer->setSingleShot(false);
	QObject::connect(reconnection_timer, &QTimer::timeout, [=]() {
		if (Toxcore::get_connection_status(tox) > 0) {
			reconnection_timer->stop();
			Tools::debug("Reconnection timer aborted: successfully connected!");
			return;
		}
		Tools::debug("Bootstrapping...");
		QMetaObject::invokeMethod(component, "resetConnectionStatus");
		Toxcore::bootstrap_DHT(tox);
	});
}

void QmlCBridge::test()
{
	// for testing
}

void QmlCBridge::setComponent(QObject *_component)
{
	component = _component;
}

void QmlCBridge::insertMessage(const ToxVariantMessage &message, quint32 friend_number, const QDateTime &dt, bool self, quint64 unique_id, bool history, bool failed, bool preload)
{
	QMetaObject::invokeMethod(component, "insertMessage", 
							  Q_ARG(QVariant, message), 
							  Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, self),
							  Q_ARG(QVariant, dt.toString("d MMMM hh:mm:ss")),
							  Q_ARG(QVariant, unique_id),
							  Q_ARG(QVariant, failed),
							  Q_ARG(QVariant, history),
							  Q_ARG(QVariant, preload));
}

void QmlCBridge::insertFriend(qint32 friend_number, const QString &nickName, bool request, const QString &request_message, const ToxPk &friendToxId)
{
	QMetaObject::invokeMethod(component, "insertFriend",
							  Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, nickName), 
							  Q_ARG(QVariant, request),
							  Q_ARG(QVariant, request_message),
							  Q_ARG(QVariant, ToxConverter::toString(friendToxId)));
}

void QmlCBridge::setMessageReceived(quint32 friend_number, quint64 unique_id)
{
	QMetaObject::invokeMethod(component, "setMessageReceived",
							  Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, unique_id));
}

void QmlCBridge::setCurrentFriendConnStatus(quint32 friend_number, int conn_status)
{
	QMetaObject::invokeMethod(component, "setCurrentFriendConnStatus", 
							  Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, conn_status));
}

void QmlCBridge::sendMessage(quint32 friend_number, const QString &message, bool reply)
{
	ToxPk friend_pk = Toxcore::get_friend_public_key(tox, friend_number);
	settings->beginGroup("Privacy");
	bool keep_chat_history = settings->value("keep_chat_history", true).toBool();
	settings->endGroup();
	QDateTime dt = QDateTime::currentDateTime();
	const QStringList splitMessage = Tools::qstringSplitUnicode(message, Toxcore::get_message_max_length());
	for (const auto &msg : splitMessage) {
		bool failed;
		ToxVariantMessage variantMessage;
		variantMessage.insert("type", ToxVariantMessageType::TOXMSG_TEXT);
		if (message.left(4).toLower() == "/me ") {
			variantMessage.insert("message", QString(msg).remove(0, 4));
			variantMessage.insert("action", true);
		} else {
			variantMessage.insert("message", msg);
			variantMessage.insert("action", false);
		}
		quint32 message_id = Toxcore::send_message(tox, friend_number, msg, variantMessage["action"].toBool(), failed);
		quint64 new_unique_id = chat_db->insertMessage(variantMessage, dt, friend_pk, !keep_chat_history, true);
		insertMessage(variantMessage, friend_number, dt, true, new_unique_id, false, failed);
		pending_messages.push_back(ToxPendingMessage(message_id, new_unique_id, friend_number, failed, reply));
	}
}

quint32 QmlCBridge::getCurrentFriendNumber()
{
	return current_friend_number;
}

int QmlCBridge::getFriendConnStatus(quint32 friend_number)
{
	return Toxcore::get_friend_connection_status(tox, friend_number);
}

const QString QmlCBridge::getFriendNickname(quint32 friend_number, bool publicKey)
{
	QString nickname;
	settings->beginGroup("Client_" + current_profile);
	nickname = settings->value("name_" + ToxConverter::toString(Toxcore::get_friend_public_key(tox, friend_number)), "").toString();
	settings->endGroup();
	if (!nickname.isEmpty()) {
		return nickname;
	}
	return Toxcore::get_friend_name(tox, friend_number, publicKey);
}

bool QmlCBridge::checkFriendCustomNickname(quint32 friend_number)
{
	QString nickname;
	settings->beginGroup("Client_" + current_profile);
	nickname = settings->value("name_" + ToxConverter::toString(Toxcore::get_friend_public_key(tox, friend_number)), "").toString();
	settings->endGroup();
	return !nickname.isEmpty();
}

void QmlCBridge::setCurrentFriend(quint32 newFriend)
{
	current_friend_number = newFriend;
}

const QString QmlCBridge::getFriendStatusMessage(quint32 friend_number)
{
	return Toxcore::get_friend_status_message(tox, friend_number);
}

int QmlCBridge::getFriendStatus(quint32 friend_number)
{
	return Toxcore::get_friend_status(tox, friend_number);
}

bool QmlCBridge::checkRemainingMessages(quint32 start)
{
	settings->beginGroup("Client");
	quint32 limit = settings->value("load_messages_limit", 64).toUInt();
	settings->endGroup();
	quint64 count = chat_db->getFriendMessagesCount(Toxcore::get_friend_public_key(tox, current_friend_number), limit, start, true);
	return count > 0;
}

void QmlCBridge::retrieveChatLog(quint32 start, bool preload)
{
	settings->beginGroup("Client");
	quint32 limit = preload ? settings->value("load_messages_limit", 64).toUInt() 
							: settings->value("last_messages_limit", 128).toUInt();
	settings->endGroup();
	ToxMessages messages = chat_db->getFriendMessages(Toxcore::get_friend_public_key(tox, current_friend_number), 
													  limit, start, preload);
	if (!preload) {
		QMetaObject::invokeMethod(component, "clearChatContent");
	}
	if (messages.isEmpty()) {
		return;
	}
	for (auto &msg : messages) {
		if (msg.variantMessage["type"].toUInt() == TOXMSG_FILE) {
			quint32 file_number = 0;
			bool transfer_exists = false;
			for (const auto transfer : transfers) {
				if (file_messages[transfer] == msg.unique_id) {
					file_number = transfer->file_number;
					transfer_exists = true;
					break;
				}
			}
			msg.variantMessage.insert("file_number", file_number);
			msg.variantMessage.insert("name", Tools::getFilenameFromPath(msg.variantMessage["file_path"].toString()));
			if (!transfer_exists && msg.variantMessage["state"].toInt() <= TOX_FILE_PAUSED) {
				msg.variantMessage["state"] = TOX_FILE_CANCELED;
				msg.received = true;
			} else if (msg.variantMessage["state"].toInt() > TOX_FILE_PAUSED) {
				msg.received = true;
			}
		}
		insertMessage(msg.variantMessage, current_friend_number, msg.dt, msg.self, msg.unique_id, true, false, preload);
		if (!msg.self || msg.received)
			setMessageReceived(current_friend_number, msg.unique_id);
	}
}

void QmlCBridge::copyTextToClipboard(QString text)
{
	QClipboard *clipboard = QGuiApplication::clipboard(); 
	clipboard->setText(text);
}

void QmlCBridge::makeFriendRequest(const QString &toxId, const QString &friendMessage)
{
	int error = Toxcore::make_friend_request(tox, ToxConverter::toToxId(toxId), friendMessage);
	QMetaObject::invokeMethod(component, "sendFriendRequestStatus", Q_ARG(QVariant, error));
}

void QmlCBridge::deleteFriend(quint32 friend_number)
{
	Toxcore::cancel_all_file_transfers_for_friend(friend_number);
	Toxcore::iterate(tox);
	Toxcore::delete_friend(tox, friend_number);
}

void QmlCBridge::clearFriendChatHistory(quint32 friend_number, const QString &friendPkHex, bool keep_active_file_transfers)
{
	ToxPk pk = friendPkHex.isEmpty() 
			? Toxcore::get_friend_public_key(tox, friend_number) 
			: ToxConverter::toToxId(friendPkHex);
	chat_db->clearFriendChatHistory(pk, keep_active_file_transfers);
}

void QmlCBridge::updateFriendNickName(quint32 friend_number, const QString &nickname)
{
	QMetaObject::invokeMethod(component, "updateFriendNickName", 
							  Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, nickname));
}

void QmlCBridge::setFriendTyping(quint32 friend_number, bool typing)
{
	QMetaObject::invokeMethod(component, "setFriendTyping", 
							  Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, typing));
}

void QmlCBridge::setTypingFriend(quint32 friend_number, bool typing)
{
	Toxcore::set_typing_friend(tox, friend_number, typing);
}

void QmlCBridge::setFriendStatusMessage(quint32 friend_number, const QString &message)
{
	QMetaObject::invokeMethod(component, "setFriendStatusMessage", 
							  Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, message));
}

void QmlCBridge::setFriendStatus(quint32 friend_number, quint32 status)
{
	QMetaObject::invokeMethod(component, "setFriendStatus", 
							  Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, status));
}

const QString QmlCBridge::getNickname(bool toxId)
{
	return Toxcore::get_nickname(tox, toxId);
}

void QmlCBridge::setNickname(const QString &nickname)
{
	Toxcore::set_nickname(tox, nickname);
}

const QString QmlCBridge::getStatusMessage()
{
	return Toxcore::get_status_message(tox);
}

void QmlCBridge::setStatusMessage(const QString &statusMessage)
{
	Toxcore::set_status_message(tox, statusMessage);
}

int QmlCBridge::getStatus()
{
	return Toxcore::get_status(tox);
}

void QmlCBridge::setStatus(quint32 status)
{
	Toxcore::set_status(tox, status);
}

QString QmlCBridge::getToxId()
{
	return ToxConverter::toString(Toxcore::get_address(tox));
}

long QmlCBridge::getFriendsCount()
{
	return Toxcore::get_friends_count(tox);
}

void QmlCBridge::setConnStatus(int conn_status)
{
	QMetaObject::invokeMethod(component, "setConnStatus", Q_ARG(QVariant, conn_status));
}

int QmlCBridge::getConnStatus()
{
	return Toxcore::get_connection_status(tox);
}

int QmlCBridge::addFriend(const QString &friendToxIdHex)
{
	int error;
	quint32 friend_number = Toxcore::add_friend(tox, ToxConverter::toToxId(friendToxIdHex), &error);
	if (error > 0) {
		return error;
	}
	insertFriend(friend_number, Toxcore::get_friend_name(tox, friend_number));
	return 0;
}

QList<QVariant> QmlCBridge::getFriendsModelOrder()
{
	QVariant returnedValue;
	QMetaObject::invokeMethod(component, "getFriendsModelOrder",
		Q_RETURN_ARG(QVariant, returnedValue));
	return returnedValue.toList();
}

void QmlCBridge::setKeyboardHeight(int height)
{
	QMetaObject::invokeMethod(component, "setKeyboardHeight", Qt::UniqueConnection, Q_ARG(QVariant, height));
}

QVariant QmlCBridge::getSettingsValue(const QString &group, const QString &key, int type, const QVariant &default_value)
{
	QVariant result;
	settings->beginGroup(group);
	result = settings->value(key, default_value);
	settings->endGroup();
	switch (type) {
	case QVariant::Bool: return result.toBool(); break;
	case QVariant::String: return result.toString(); break;
	default: return result; break;
	}
}

void QmlCBridge::setSettingsValue(const QString &group, const QString &key, const QVariant &value)
{
	settings->beginGroup(group);
	if (value.type() == QVariant::String && value.toString().isEmpty()) {
		settings->remove(key);
	} else {
		settings->setValue(key, value);
	}
	settings->endGroup();
}

void QmlCBridge::setKeyboardAdjustMode(bool adjustNothing)
{
	Native::setKeyboardAdjustMode(adjustNothing);
}

bool QmlCBridge::checkProfileEncrypted(const QString &profile)
{
	return Toxcore::check_profile_encrypted(profile);
}

QString QmlCBridge::getNospamValue()
{
	quint32 nospam = Toxcore::get_nospam(tox);
	ToxId nospam_bytes;
	nospam_bytes.append((nospam >> 24) & 0xFF);
	nospam_bytes.append((nospam >> 16) & 0xFF);
	nospam_bytes.append((nospam >> 8) & 0xFF);
	nospam_bytes.append(nospam & 0xFF);
	return ToxConverter::toString(nospam_bytes);
}

void QmlCBridge::setNospamValue(const QString &nospam)
{
	ToxId bytes = ToxConverter::toToxId(nospam);
	Toxcore::set_nospam(tox, (quint8)bytes[0] << 24 | (quint8)bytes[1] << 16 | (quint8)bytes[2] << 8 | (quint8)bytes[3]);
}

void QmlCBridge::setToxPassword(const QString &password)
{
	profile_password = password;
}

void QmlCBridge::saveProfile()
{
	updateToxPasswordKey();
	Toxcore::save_data(tox, tox_pass_key, Tools::getProgDir() + current_profile);
}

void QmlCBridge::updateToxPasswordKey()
{
	Toxcore::reset_pass_key(&tox_pass_key);
	tox_pass_key = Toxcore::generate_pass_key(profile_password);
}

bool QmlCBridge::checkFriendHistoryExists(quint32 friend_number)
{
	return chat_db->getMessagesCountFriend(Toxcore::get_friend_public_key(tox, friend_number)) > 0;
}

void QmlCBridge::updateDataBasePassword(const QString &password)
{
	chat_db->updatePassword(password);
}

const QString QmlCBridge::getToxcoreVersion()
{
	return Toxcore::get_version_string();
}

void QmlCBridge::tryReconnect()
{
	reconnection_timer->start();
}

int QmlCBridge::signInProfile(const QString &profile, bool create_new, const QString &password, bool autoLogin)
{
	current_profile = profile;
	setToxPassword(password);
	updateToxPasswordKey();
	ToxProfileLoadingError error;
	tox_opts = Toxcore::create_opts();
	tox = Toxcore::create_tox(error, create_new, password, current_profile, tox_pass_key, tox_opts);
	if (!tox) {
		current_profile.clear();
		return error;
	}
	settings->beginGroup("Profile");
	if (autoLogin) {
		settings->setValue("auto_login_profile", profile);
	} else {
		settings->setValue("auto_login_profile", "");
	}
	settings->endGroup();
	//Tools::debug("My address: " + ToxConverter::toString(Toxcore::get_address(tox)));
	chat_db = new ChatDataBase("chat_" + Tools::replaceFileExtension(current_profile, ".db"), password);

	// load config
	settings->beginGroup("Client_" + current_profile);
	ToxPk friendPk = settings->value("last_friend", Toxcore::get_friend_public_key(tox, 0)).toByteArray();
	QList <QVariant> friend_list = settings->value("friend_list", QList <QVariant>()).toList();
	settings->endGroup();
	ToxFriends friends = Toxcore::get_friends(tox);

	for (auto _friend : friends) {
		if (friend_list.lastIndexOf(_friend) < 0) {
			friend_list.append(_friend);
		}
	}
	for (auto _friend : friend_list) {
		if (friends.lastIndexOf(_friend.toUInt()) < 0) {
			friend_list.removeOne(_friend);
		}
	}

	if (!friendPk.isEmpty()) {
		for (auto _friend : friend_list) {
			if (Toxcore::get_friend_public_key(tox, _friend.toUInt()) == friendPk) {
				current_friend_number = _friend.toUInt();
				break;
			}
		}
	}

	for (auto _friend : friend_list) {
		insertFriend(_friend.toUInt(), getFriendNickname(_friend.toUInt()));
	}

	Tools::debug("Bootstrapping...");
	Toxcore::bootstrap_DHT(tox);
	reconnection_timer->start();
	toxcore_timer = Toxcore::create_qtimer(tox);
	toxcore_timer->start();
	return error;
}

QmlCBridge::~QmlCBridge()
{
	if (current_profile.isEmpty()) {
		return;
	}
	signOutProfile();
	delete reconnection_timer;
}

QVariant QmlCBridge::getProfileList()
{
	QDir directory(Tools::getProgDir());
	return directory.entryList(QStringList() << "*.tox", QDir::Files);
}

void QmlCBridge::signOutProfile(bool remove)
{
	Tools::debug("Logout.");
	settings->beginGroup("Client_" + current_profile);
	if (remove) {
		settings->remove("");
	} else {
		settings->setValue("last_friend", Toxcore::get_friend_public_key(tox, current_friend_number));
		settings->setValue("friend_list", getFriendsModelOrder());
	}
	settings->endGroup();
	if (remove) {
		settings->beginGroup("Profile");
		QString autoLoginProfile = settings->value("auto_login_profile").toString();
		if (autoLoginProfile == current_profile) {
			settings->setValue("auto_login_profile", "");
		}
		settings->endGroup();
	}
	settings->sync();

	Toxcore::cancel_all_file_transfers();
	Toxcore::iterate(tox);

	reconnection_timer->stop();
	toxcore_timer->stop();
	delete toxcore_timer;
	if (!remove) {
		Toxcore::save_data(tox, tox_pass_key, Tools::getProgDir() + current_profile);
	}
	if (bootstrapping_thread.isRunning()) {
		abort_bootstrapping = true;
		bootstrapping_thread.waitForFinished();
	}
	Toxcore::destroy_tox(tox);
	Toxcore::reset_pass_key(&tox_pass_key);
	Toxcore::destroy_opts(tox_opts);

	delete chat_db;
	profile_password.clear();

	if (remove) {
		QFile::remove(Tools::getProgDir() + current_profile);
		QFile::remove(Tools::getProgDir() + "chat_" + Tools::replaceFileExtension(current_profile, ".db"));
	}
	current_profile.clear();
	pending_messages.clear();
	transfers.clear();
	file_messages.clear();
	self_canceled_transfers.clear();
}

quint32 QmlCBridge::getToxNodesCount()
{
	return Toxcore::get_available_nodes();
}

quint32 QmlCBridge::getFriendRequestMessageMaxLength()
{
	return Toxcore::get_friend_request_message_max_length();
}

quint32 QmlCBridge::getNicknameMaxLength()
{
	return Toxcore::get_nickname_max_length();
}

quint32 QmlCBridge::getStatusMessageMaxLength()
{
	return Toxcore::get_status_message_max_length();
}

quint32 QmlCBridge::getToxAddressSizeHex()
{
	return Toxcore::get_tox_address_size() * 2;
}

quint32 QmlCBridge::getToxPublicKeySizeHex()
{
	return Toxcore::get_tox_public_key_size() * 2;
}

quint32 QmlCBridge::getHostnameMaxLength()
{
	return Toxcore::get_tox_max_hostname_length();
}

QString QmlCBridge::getSystemLocale()
{
	return QLocale::system().name();
}

void QmlCBridge::hideSplashScreen()
{
	Native::hideSplashScreen();
}

void QmlCBridge::sendPendingMessages(quint32 friend_number)
{
	for (int i = 0; i < pending_messages.count(); i++) {
		if (friend_number != pending_messages[i].friend_number && !pending_messages[i].failed) {
			continue;
		}
		if (pending_messages[i].resent) {
			continue;
		}
		const ToxTextMessage msg = chat_db->getTextMessage(pending_messages[i].unique_id, 
											  Toxcore::get_friend_public_key(tox, pending_messages[i].friend_number));
		bool failed;
		quint32 message_id = Toxcore::send_message(tox, pending_messages[i].friend_number, msg.message, msg.action, failed);
		pending_messages[i].message_id = message_id;
		pending_messages[i].failed = failed;
		pending_messages[i].resent = !pending_messages[i].failed;
	}
}

bool QmlCBridge::checkMessageInPendingList(quint32 friend_number, quint64 unique_id)
{
	for (int i = 0; i < pending_messages.count(); i++) {
		if (friend_number != pending_messages[i].friend_number) {
			continue;
		}
		if (unique_id == pending_messages[i].unique_id) {
			return true;
		}
	}
	return false;
}

void QmlCBridge::resendMessage(quint32 friend_number, quint64 unique_id)
{
	bool failed;
	const ToxTextMessage msg = chat_db->getTextMessage(unique_id, 
										  Toxcore::get_friend_public_key(tox, friend_number));
	quint32 message_id = Toxcore::send_message(tox, friend_number, msg.message, msg.action, failed);
	pending_messages.push_back(ToxPendingMessage(message_id, unique_id, friend_number, failed, false));
}

void QmlCBridge::removeMessageFromPendingList(quint32 friend_number, quint64 unique_id)
{
	for (int i = 0; i < pending_messages.count(); i++) {
		if (pending_messages[i].friend_number == friend_number && pending_messages[i].unique_id == unique_id) {
			pending_messages.removeAt(i);
			return;
		}
	}
}

void QmlCBridge::removeNonFailedPendingMessages(quint32 friend_number)
{
	ToxPendingMessages toRemove;
	for (int i = 0; i < pending_messages.count(); i++) {
		if (pending_messages[i].friend_number == friend_number && !pending_messages[i].failed) {
			toRemove.push_back(pending_messages[i]);
		}
	}
	for (const auto &pendingMessage : toRemove) {
		pending_messages.removeOne(pendingMessage);
	}
}

void QmlCBridge::removeMessageFromDB(quint32 friend_number, quint64 unique_id)
{
	chat_db->removeMessage(unique_id, Toxcore::get_friend_public_key(tox, friend_number));
}

QString QmlCBridge::uriToRealPath(const QString &uriString)
{
	return Native::uriToRealPath(uriString);
}

quint32 QmlCBridge::sendFile(quint32 friend_number, const QString &filepath)
{
	quint64 filesize;
	ToxFileId file_id;
	quint32 error;
	ToxFileTransfer *transfer = nullptr;
	quint32 file_number = Toxcore::send_file(tox, friend_number, filepath, &transfer, filesize, file_id, error);
	if (error > 0) {
		return error;
	}
	QDateTime dt = QDateTime::currentDateTime();
	ToxVariantMessage variantMessage;
	variantMessage.insert("type", ToxVariantMessageType::TOXMSG_FILE);
	variantMessage.insert("size", filesize);
	variantMessage.insert("state", ToxFileState::TOX_FILE_REQUEST);
	variantMessage.insert("file_id", file_id);
	variantMessage.insert("file_path", filepath);
	variantMessage.insert("file_number", file_number);
	// ui only
	variantMessage.insert("name", Tools::getFilenameFromPath(filepath));
	settings->beginGroup("Privacy");
	bool keep_chat_history = settings->value("keep_chat_history", true).toBool();
	settings->endGroup();
	quint64 unique_id = chat_db->insertMessage(variantMessage, dt, Toxcore::get_friend_public_key(tox, friend_number), !keep_chat_history, true);
	file_messages[transfer] = unique_id;
	insertMessage(variantMessage, friend_number, dt, true, unique_id);
	return 0;
}

void QmlCBridge::fileControlUpdateMessage(quint32 friend_number, quint64 unique_id, quint32 control, bool remote)
{
	QMetaObject::invokeMethod(component, "fileControlUpdateMessage",
							  Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, unique_id),
							  Q_ARG(QVariant, control),
							  Q_ARG(QVariant, remote));
}

bool QmlCBridge::controlFile(quint32 friend_number, quint32 file_number, quint32 control)
{
	quint64 unique_id = 0;
	bool success = Toxcore::file_control(tox, friend_number, file_number, control, unique_id);
	if (success) {
		fileControlUpdateMessage(friend_number, unique_id, control, false);
	}
	return success;
}

void QmlCBridge::changeFileProgress(quint32 friend_number, quint32 file_number, quint32 bytesTransfered, bool finished)
{
	QMetaObject::invokeMethod(component, "changeFileProgress", 
							  Q_ARG(QVariant, friend_number), 
							  Q_ARG(QVariant, file_number), 
							  Q_ARG(QVariant, bytesTransfered),
							  Q_ARG(QVariant, finished));
}

QString QmlCBridge::getDefaultDownloadsDirectory()
{
	return Tools::getDefaultDownloadsDirectory();
}

QString QmlCBridge::checkFileImage(const QString &path)
{
	return Tools::checkFileImage(path);
}

void QmlCBridge::viewFile(const QString &path, const QString &type)
{
	Native::viewFile(path, type);
}

quint32 QmlCBridge::acceptFile(quint32 friend_number, quint32 file_number)
{
	quint64 unique_id = 0;
	quint32 control = Toxcore::acceptFile(friend_number, file_number, unique_id);
	fileControlUpdateMessage(friend_number, unique_id, control, false);
	cancelFileNotification(friend_number, file_number);
	createFileProgressNotification(friend_number, file_number);
	return control;
}

bool QmlCBridge::checkFileExists(const QString &path)
{
	return Tools::checkFileExists(path);
}

void QmlCBridge::cancelFileNotification(quint32 friend_number, quint32 file_number)
{
	QVariantMap parameters;
	parameters["fileNumber"] = file_number;
	QVariantMap notificationParameters;
	notificationParameters["type"] = QtNotification::FileRequest;
	notificationParameters["id"] = friend_number;
	notificationParameters["parameters"] = parameters;
	notification->cancel(notificationParameters);
}

void QmlCBridge::cancelTextNotification(quint32 friend_number)
{
	QVariantMap notificationParameters;
	notificationParameters["type"] = QtNotification::Text;
	notificationParameters["id"] = friend_number;
	notification->cancel(notificationParameters);
}

const QString QmlCBridge::formatBytes(quint64 bytes)
{
	QVariant formattedBytes;
	QMetaObject::invokeMethod(component, "formatBytes", Qt::DirectConnection, Q_RETURN_ARG(QVariant, formattedBytes), 
							  Q_ARG(QVariant, bytes), Q_ARG(QVariant, 2));
	return formattedBytes.toString();
}

void QmlCBridge::createFileProgressNotification(quint32 friend_number, quint32 file_number)
{
	for (const auto transfer : transfers) {
		if (transfer->friend_number == friend_number && transfer->file_number == file_number) {
			QVariantMap parameters;
			parameters["fileNumber"] = file_number;
			const QString file_path = transfer->manager->getFile()->fileName();
			const QString friend_name = getFriendNickname(friend_number);
			quint64 file_size = chat_db->getFileSize(file_messages[transfer], 
													 Toxcore::get_friend_public_key(tox, friend_number));
			parameters["filePath"] = file_path;
			parameters["fileSize"] = file_size;
			parameters["speedPrefix"] = tr("/s");
			parameters["transferFinishedText"] = QString(tr("Transfer from %1 is finished")).arg(friend_name);
			parameters["transferCanceledText"] = QString(tr("Transfer from %1 is canceled")).arg(friend_name);
			QVariantMap notificationParameters;
			notificationParameters["type"] = QtNotification::FileProgress;
			notificationParameters["id"] = friend_number;
			notificationParameters["parameters"] = parameters;
			notificationParameters["caption"] = Tools::getFilenameFromPath(file_path) +
					" (" + formatBytes(file_size) + ")";
			notificationParameters["title"] = QString(tr("Transfering file from %1")).arg(friend_name);
			notification->show(notificationParameters);
			break;
		}
	}
}

QString QmlCBridge::getFriendPublicKeyHex(quint32 friend_number)
{
	return ToxConverter::toString(Toxcore::get_friend_public_key(tox, friend_number));
}

const QString QmlCBridge::getFriendAvatarPath(quint32 friend_number)
{
	return Tools::getAvatarsDir() + ToxConverter::toString(Toxcore::get_friend_public_key(tox, friend_number));
}

const QString QmlCBridge::getSelfAvatarPath()
{
	QString publicKey = ToxConverter::toString(Toxcore::get_address(tox));
	publicKey.truncate(Toxcore::get_tox_public_key_size() * 2);
	return Tools::getAvatarsDir() + publicKey;
}

void QmlCBridge::updateFriendAvatar(quint32 friend_number)
{
	QMetaObject::invokeMethod(component, "updateFriendAvatar", Q_ARG(QVariant, friend_number));
}

void QmlCBridge::changeSelfAvatar(const QString &path)
{
	const int scaled_avatar_size = 128;
	QString avatarPath = getSelfAvatarPath();;
	if (path.isEmpty()) {
		QFile::remove(avatarPath);
		avatarPath.clear();
	} else {
		QImage avatar(path);
		QImage scaledAvatar = avatar.scaled(QSize(scaled_avatar_size, scaled_avatar_size), 
											Qt::IgnoreAspectRatio, 
											Qt::SmoothTransformation);
		scaledAvatar.save(avatarPath, "PNG");
	}
	Toxcore::send_avatar_to_all_friends(tox, avatarPath);
}

const QSize QmlCBridge::getImageSize(const QString &path)
{
	return Tools::getImageSize(path);
}

const QString QmlCBridge::getCurrentCommitSha1()
{
	return Tools::getCurrentCommitSha1();
}

/*
 * Translation object 
*/

QmlTranslator::QmlTranslator(QObject *parent) : QObject(parent) {}

void QmlTranslator::setTranslation(const QString &translation)
{
	if (!translator.load(":protox_" + translation, ".")) {
		Tools::debug("Translation loading failed: " + translation);
		return;
	}
	qApp->installTranslator(&translator);
	emit languageChanged();
}

/*
 * QML warnings handler
*/

static const QtMessageHandler QT_DEFAULT_MESSAGE_HANDLER = qInstallMessageHandler(0);

void customMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString & msg)
{
	const QStringList skipWarningsList = { "QML Connections: Implicitly defined onFoo properties in Connections are deprecated. Use this syntax instead: function onFoo(<arguments>) { ... }", 
										   "QML Loader: Possible anchor loop detected on fill." };
	switch (type) {
	case QtWarningMsg: {
		for (const auto &warnMsg : skipWarningsList) {
			if (msg.contains(warnMsg)) {
				return;
			}
		}
		(*QT_DEFAULT_MESSAGE_HANDLER)(type, context, msg);
	}
	break;
	default:
		(*QT_DEFAULT_MESSAGE_HANDLER)(type, context, msg);
		break;
	}
}

/*
 * main function
*/

int main(int argc, char *argv[])
{
	if (!Native::requestApplicationPermissions()) {
		return 1;
	}
	ChatDataBase::registerSQLDriver();
	settings = new QSettings(Tools::getProgDir() + "settings.ini", QSettings::IniFormat);
	notification = new QtNotification;

	Tools::debug("App started.");
	QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

	QGuiApplication app(argc, argv);
	// eleminate QML warnings
	app.setOrganizationName("protox");
	app.setOrganizationDomain("org");

	qInstallMessageHandler(customMessageHandler);

	QQmlApplicationEngine engine;
	const QUrl url(QStringLiteral(QML_MAIN));
	QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
					 &app, [url](QObject *obj, const QUrl &objUrl) {
		if (!obj && url == objUrl)
			QCoreApplication::exit(-1);
	}, Qt::QueuedConnection);

	QmlTranslator qmltranslator;
	qmlbridge = new QmlCBridge;
	QQmlContext *root = engine.rootContext();
	root->setContextProperty("bridge", qmlbridge);
	root->setContextProperty("translator", &qmltranslator);
	QtNotification::declareQML();
	QtStatusBar::declareQML();
	QtToast::declareQML();
	QtPhotoDialog::declareQML();
	QtFolderDialog::declareQML();
	QtQRCodeScanner::declareQML();
	QUtf8ByteLimitValidator::declareQML();
	QZXing::registerQMLTypes();
	QZXing::registerQMLImageProvider(engine);
	qmltranslator.setTranslation(qmlbridge->getSystemLocale());
	engine.load(url);
	QObject *component = engine.rootObjects().first();
	qmlbridge->setComponent(component);

	int result = app.exec();
	delete qmlbridge;
	delete settings;
	delete notification;
	Tools::debug("Program exited successfully.");

	return result;
}
