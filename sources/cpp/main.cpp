#include "main.h"

#include "tools.h"

#include "QZXing.h"
#include "native.h"
#include "qtutf8bytelimitvalidator.h"
#include "settings.h"

#include "components/QtMobileNotification/QtNotification.h"
#include "components/QtStatusBar/QtStatusBar.h"

QmlCBridge *qmlbridge = nullptr;
QSettingsExt *settings = nullptr;
QtNotification *notification = nullptr;

/*
 * QML <-> C++ object
*/

QmlCBridge::QmlCBridge()
{
	component = nullptr;
	chat_db = nullptr;
	tox = nullptr;
	tox_pass_key = nullptr;
	tox_opts = nullptr;
	toxcore_timer = nullptr;
	app_inactive = true;
	current_profile = "";
	current_friend_number = 0;
	profile_password = "";
	abort_bootstrapping = false;

	translator = new QTranslator;
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
							  Q_ARG(QVariant, friendToxId.toToxString()));
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
	ToxPk friend_pk = Toxcore::getFriendPublicKey(tox, friend_number);

	settings->beginGroup("Privacy");
	bool keep_chat_history = settings->valued("keep_chat_history").toBool();
	settings->endGroup();

	QDateTime dt = QDateTime::currentDateTime();
	bool action = message.left(4).toLower() == "/me ";
	const QStringList splitMessage = Tools::qstringSplitUnicode(action ? QString(message).remove(0, 4) : message, 
																Toxcore::getMessageMaxLength());

	for (const auto &msg : splitMessage) {
		ToxVariantMessage variantMessage = {
			{ "type", ToxVariantMessageType::TOXMSG_TEXT },
			{ "message", msg },
			{ "action", action }
		};

		auto [message_id, failed] = Toxcore::sendMessage(tox, friend_number, msg, action);
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
	return Toxcore::getFriendConnectionStatus(tox, friend_number);
}

const QString QmlCBridge::getFriendNickname(quint32 friend_number, bool publicKey)
{
	QString nickname;

	settings->beginGroup("Client_" + current_profile);
	nickname = settings->value("name_" + Toxcore::getFriendPublicKey(tox, friend_number).toToxString(), "").toString();
	settings->endGroup();

	if (!nickname.isEmpty()) {
		return nickname;
	}

	return Toxcore::getFriendName(tox, friend_number, publicKey);
}

bool QmlCBridge::checkFriendCustomNickname(quint32 friend_number)
{
	QString nickname;

	settings->beginGroup("Client_" + current_profile);
	nickname = settings->value("name_" + Toxcore::getFriendPublicKey(tox, friend_number).toToxString(), "").toString();
	settings->endGroup();

	return !nickname.isEmpty();
}

void QmlCBridge::setCurrentFriend(quint32 newFriend)
{
	current_friend_number = newFriend;
}

const QString QmlCBridge::getFriendStatusMessage(quint32 friend_number)
{
	return Toxcore::getFriendStatusMessage(tox, friend_number);
}

int QmlCBridge::getFriendStatus(quint32 friend_number)
{
	return Toxcore::getFriendStatus(tox, friend_number);
}

bool QmlCBridge::checkRemainingMessages(quint32 start)
{
	settings->beginGroup("Client");
	quint32 limit = settings->valued("load_messages_limit").toUInt();
	settings->endGroup();

	quint64 count = chat_db->getFriendMessagesCount(Toxcore::getFriendPublicKey(tox, current_friend_number), limit, start, true);
	return count > 0;
}

void QmlCBridge::retrieveChatLog(quint32 start, bool preload)
{
	settings->beginGroup("Client");
	quint32 limit = preload ? settings->valued("load_messages_limit").toUInt() 
							: settings->valued("last_messages_limit").toUInt();
	settings->endGroup();

	ToxMessages messages = chat_db->getFriendMessages(Toxcore::getFriendPublicKey(tox, current_friend_number), 
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
	QClipboard *clipboard = qApp->clipboard();
	clipboard->setText(text);
}

void QmlCBridge::makeFriendRequest(const QString &toxId, const QString &friendMessage)
{
	quint32 error = Toxcore::makeFriendRequest(tox, ToxIdData::fromToxString(toxId), friendMessage);
	QMetaObject::invokeMethod(component, "sendFriendRequestStatus", Q_ARG(QVariant, error));
}

void QmlCBridge::deleteFriend(quint32 friend_number)
{
	Toxcore::cancelAllFileTransfersForFriend(friend_number);
	Toxcore::iterate(tox);
	Toxcore::deleteFriend(tox, friend_number);
}

void QmlCBridge::clearFriendChatHistory(quint32 friend_number, bool keep_active_file_transfers)
{
	chat_db->clearFriendChatHistory(Toxcore::getFriendPublicKey(tox, friend_number), keep_active_file_transfers);
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
	Toxcore::setFriendTyping(tox, friend_number, typing);
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

const QString QmlCBridge::getNickname(bool toxPk)
{
	return Toxcore::getNickname(tox, toxPk);
}

void QmlCBridge::setNickname(const QString &nickname)
{
	Toxcore::setNickname(tox, nickname);
}

const QString QmlCBridge::getStatusMessage()
{
	return Toxcore::getStatusMessage(tox);
}

void QmlCBridge::setStatusMessage(const QString &statusMessage)
{
	Toxcore::setStatusMessage(tox, statusMessage);
}

int QmlCBridge::getStatus()
{
	return Toxcore::getStatus(tox);
}

void QmlCBridge::setStatus(quint32 status)
{
	Toxcore::setStatus(tox, status);
}

QString QmlCBridge::getToxId()
{
	return Toxcore::getAddress(tox).toToxString();
}

long QmlCBridge::getFriendsCount()
{
	return Toxcore::getFriendsCount(tox);
}

void QmlCBridge::setConnectionStatus(int conn_status)
{
	QMetaObject::invokeMethod(component, "setConnectionStatus", Q_ARG(QVariant, conn_status));

	QString statusText;
	switch (conn_status) {
	case TOX_CONNECTION_NONE: statusText = tr("Connection lost."); break;
	case TOX_CONNECTION_TCP: statusText = tr("Connected (TCP)."); break;
	case TOX_CONNECTION_UDP: statusText = tr("Connected (UDP)."); break;
	}

	Native::updatePersistentNotification(tr("Application is running"), statusText, conn_status > TOX_CONNECTION_NONE);
}

int QmlCBridge::getConnectionStatus()
{
	return Toxcore::getConnectionStatus(tox);
}

quint32 QmlCBridge::addFriend(const QString &friendToxIdHex)
{
	auto [friend_number, error] = Toxcore::addFriend(tox, ToxIdData::fromToxString(friendToxIdHex));

	if (error > 0) {
		return error;
	}

	insertFriend(friend_number, Toxcore::getFriendName(tox, friend_number));
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

QVariant QmlCBridge::getSettingsValueDefault(const QString &group, const QString &key, int type)
{
	QVariant result;
	settings->beginGroup(group);
	result = settings->valued(key);
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
	return Toxcore::checkProfileEncrypted(profile);
}

QString QmlCBridge::getNospamValue()
{
	quint32 nospam = Toxcore::getNospam(tox);
	ToxIdData nospam_bytes(sizeof(quint32));
	nospam_bytes[0] = (nospam >> 24) & 0xFF;
	nospam_bytes[1] = (nospam >> 16) & 0xFF;
	nospam_bytes[2] = (nospam >> 8) & 0xFF;
	nospam_bytes[3] = nospam & 0xFF;
	return nospam_bytes.toToxString();
}

void QmlCBridge::setNospamValue(const QString &nospam)
{
	ToxIdData bytes = ToxIdData::fromToxString(nospam);
	Toxcore::setNospam(tox, (quint8)bytes[0] << 24 | (quint8)bytes[1] << 16 | (quint8)bytes[2] << 8 | (quint8)bytes[3]);
}

void QmlCBridge::setToxPassword(const QString &password)
{
	profile_password = password;
}

void QmlCBridge::saveProfile()
{
	updateToxPasswordKey();
	Toxcore::saveData(tox, tox_pass_key, Tools::getProgDir() + current_profile);
}

void QmlCBridge::updateToxPasswordKey()
{
	Toxcore::resetPasswordKey(&tox_pass_key);
	tox_pass_key = Toxcore::generatePassKey(profile_password);
}

bool QmlCBridge::checkFriendHistoryExists(quint32 friend_number)
{
	return chat_db->getMessagesCountFriend(Toxcore::getFriendPublicKey(tox, friend_number)) > 0;
}

void QmlCBridge::updateDataBasePassword(const QString &password)
{
	chat_db->updatePassword(password);
}

const QString QmlCBridge::getToxcoreVersion()
{
	return Toxcore::getVersionString();
}

void QmlCBridge::tryReconnect()
{
	reconnection_timer->start();
}

void QmlCBridge::createTimers()
{
	toxcore_timer = Toxcore::createQTimer(tox);
	toxcore_timer->start();

	settings->beginGroup("Client");
	int reconnection_interval = settings->valued("reconnection_interval").toInt();
	settings->endGroup();

	reconnection_timer = new QTimer;
	reconnection_timer->setInterval(reconnection_interval);
	reconnection_timer->setSingleShot(false);
	QObject::connect(reconnection_timer, &QTimer::timeout, [=]() {
		if (Toxcore::getConnectionStatus(tox) > 0) {
			reconnection_timer->stop();
			Tools::debug("Reconnection timer aborted: successfully connected!");
			return;
		}

		Tools::debug("Bootstrapping...");

		QMetaObject::invokeMethod(component, "setConnectionStatus", Q_ARG(QVariant, -1));

		Native::updatePersistentNotification(tr("Application is running"), tr("Bootstrapping..."), false);
		Toxcore::bootstrapDHT(tox);
	});
	reconnection_timer->start();
}

int QmlCBridge::signInProfile(const QString &profile, bool create_new, const QString &password, bool autoLogin)
{
	current_profile = profile;

	setToxPassword(password);
	updateToxPasswordKey();

	tox_opts = Toxcore::createOptions();
	ToxProfileLoadingError error;
	tie(tox, error) = Toxcore::createTox(create_new, password, current_profile, tox_pass_key, tox_opts);

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

	//ToxIdData address = Toxcore::get_address(tox);
	//Tools::debug("My address: " + address.toToxString());
	//Tools::debug("My public key: " + ToxPk(address).toToxString());

	chat_db = new ChatDataBase("chat_" + Tools::replaceFileExtension(current_profile, ".db"), profile_password);

	// load config
	settings->beginGroup("Client_" + current_profile);
	ToxPk friendPk = settings->value("last_friend", Toxcore::getFriendPublicKey(tox, 0)).toByteArray();
	QList <QVariant> friend_list = settings->value("friend_list", QList <QVariant>()).toList();
	settings->endGroup();

	ToxFriends friends = Toxcore::getFriends(tox);
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
			if (Toxcore::getFriendPublicKey(tox, _friend.toUInt()) == friendPk) {
				current_friend_number = _friend.toUInt();
				break;
			}
		}
	}

	for (auto _friend : friend_list) {
		insertFriend(_friend.toUInt(), getFriendNickname(_friend.toUInt()));
	}

	Native::updatePersistentNotification(tr("Application is running"), tr("Bootstrapping..."), false);

	Tools::debug("Bootstrapping...");
	Toxcore::bootstrapDHT(tox);
	createTimers();

	return error;
}

QmlCBridge::~QmlCBridge()
{
	if (!current_profile.isEmpty()) {
		signOutProfile();
	}

	qApp->removeTranslator(translator);
	delete translator;
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
		settings->setValue("last_friend", Toxcore::getFriendPublicKey(tox, current_friend_number));
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

	Toxcore::cancelAllFileTransfers();
	Toxcore::iterate(tox);

	delete toxcore_timer;
	delete reconnection_timer;

	if (!remove) {
		Toxcore::saveData(tox, tox_pass_key, Tools::getProgDir() + current_profile);
	}

	if (bootstrapping_thread.isRunning()) {
		abort_bootstrapping = true;
		bootstrapping_thread.waitForFinished();
	}

	Toxcore::destroyTox(tox);
	Toxcore::resetPasswordKey(&tox_pass_key);
	Toxcore::destroyOptions(tox_opts);

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

	Native::clearPersistentNotification();
}

quint32 QmlCBridge::getToxNodesCount()
{
	return Toxcore::getAvailableNodes();
}

quint32 QmlCBridge::getFriendRequestMessageMaxLength()
{
	return Toxcore::getFriendRequestMaxLength();
}

quint32 QmlCBridge::getNicknameMaxLength()
{
	return Toxcore::getNicknameMaxLength();
}

quint32 QmlCBridge::getStatusMessageMaxLength()
{
	return Toxcore::getStatusMessageMaxLength();
}

quint32 QmlCBridge::getToxAddressSizeHex()
{
	return Toxcore::getToxAddressSize() * 2;
}

quint32 QmlCBridge::getToxPublicKeySizeHex()
{
	return Toxcore::getToxPublicKeySize() * 2;
}

quint32 QmlCBridge::getHostnameMaxLength()
{
	return Toxcore::getToxMaxHostnameLength();
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
											  Toxcore::getFriendPublicKey(tox, pending_messages[i].friend_number));

		auto [message_id, failed] = Toxcore::sendMessage(tox, pending_messages[i].friend_number, msg.message, msg.action);

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
	const ToxTextMessage msg = chat_db->getTextMessage(unique_id, 
										  Toxcore::getFriendPublicKey(tox, friend_number));
	auto [message_id, failed] = Toxcore::sendMessage(tox, friend_number, msg.message, msg.action);
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
	chat_db->removeMessage(unique_id, Toxcore::getFriendPublicKey(tox, friend_number));
}

QString QmlCBridge::uriToRealPath(const QString &uriString)
{
	return Native::uriToRealPath(uriString);
}

quint32 QmlCBridge::sendFile(quint32 friend_number, const QString &file_path)
{
	auto [file_sent, error] = Toxcore::sendFile(tox, friend_number, file_path);

	if (error > 0) {
		return error;
	}

	QDateTime dt = QDateTime::currentDateTime();
	ToxVariantMessage variantMessage = {
		{ "type", ToxVariantMessageType::TOXMSG_FILE },
		{ "state", ToxFileState::TOX_FILE_REQUEST },
		{ "file_number", file_sent.file_number },
		{ "size", file_sent.file_size },
		{ "file_id", file_sent.file_id },
		{ "file_path", file_path },
		{ "name", Tools::getFilenameFromPath(file_path) } // ui only
	};

	settings->beginGroup("Privacy");
	bool keep_chat_history = settings->valued("keep_chat_history").toBool();
	settings->endGroup();

	quint64 unique_id = chat_db->insertMessage(variantMessage, dt, Toxcore::getFriendPublicKey(tox, friend_number), !keep_chat_history, true);
	file_messages[file_sent.transfer] = unique_id;
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
	auto result = Toxcore::fileControl(tox, friend_number, file_number, control);

	if (result) {
		fileControlUpdateMessage(friend_number, result.value(), control, false);
	}

	return result.has_value();
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

bool QmlCBridge::viewFile(const QString &path, const QString &type)
{
	return Native::viewFile(path, type);
}

int QmlCBridge::acceptFile(quint32 friend_number, quint32 file_number)
{
	auto result = Toxcore::acceptFile(friend_number, file_number);
	
	if (result) {
		const auto &[control, unique_id] = result.value();

		fileControlUpdateMessage(friend_number, unique_id, control, false);

		cancelFileNotification(friend_number, file_number);
		createFileProgressNotification(friend_number, file_number);

		return control;
	}

	return -1;
}

bool QmlCBridge::checkFileExists(const QString &path)
{
	return Tools::checkFileExists(path);
}

void QmlCBridge::cancelFileNotification(quint32 friend_number, quint32 file_number)
{
	QVariantMap parameters = {
		{ "fileNumber", file_number }
	};
	QVariantMap notificationParameters = {
		{ "type", QtNotification::FileRequest },
		{ "id", friend_number },
		{ "parameters", parameters }
	};
	notification->cancel(notificationParameters);
}

void QmlCBridge::cancelTextNotification(quint32 friend_number)
{
	QVariantMap notificationParameters = {
		{ "type", QtNotification::Text },
		{ "id", friend_number }
	};
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
			const QString file_path = transfer->manager->getFile()->fileName();
			const QString friend_name = getFriendNickname(friend_number);
			quint64 file_size = chat_db->getFileSize(file_messages[transfer], 
													 Toxcore::getFriendPublicKey(tox, friend_number));

			QVariantMap parameters = {
				{ "fileNumber", file_number },
				{ "filePath", file_path },
				{ "fileSize", file_size },
				{ "speedPrefix", tr("/s") },
				{ "transferFinishedText", QString(tr("Transfer from %1 is finished")).arg(friend_name) },
				{ "transferCanceledText", QString(tr("Transfer from %1 is canceled")).arg(friend_name) }
			};
			QVariantMap notificationParameters = {
				{ "type", QtNotification::FileProgress },
				{ "id", friend_number },
				{ "parameters", parameters },
				{ "caption", Tools::getFilenameFromPath(file_path) + " (" + formatBytes(file_size) + ")" },
				{ "title", QString(tr("Transfering file from %1")).arg(friend_name) }
			};

			notification->show(notificationParameters);
			break;
		}
	}
}

QString QmlCBridge::getFriendPublicKeyHex(quint32 friend_number)
{
	return Toxcore::getFriendPublicKey(tox, friend_number).toToxString();
}

const QString QmlCBridge::getFriendAvatarPath(quint32 friend_number)
{
	return Tools::getAvatarsDir() + Toxcore::getFriendPublicKey(tox, friend_number).toToxString();
}

const QString QmlCBridge::getSelfAvatarPath()
{
	QString publicKey = ToxPk(Toxcore::getAddress(tox)).toToxString();
	return Tools::getAvatarsDir() + publicKey;
}

void QmlCBridge::updateFriendAvatar(quint32 friend_number)
{
	QMetaObject::invokeMethod(component, "updateFriendAvatar", Q_ARG(QVariant, friend_number));
}

void QmlCBridge::changeSelfAvatar(const QString &path)
{
	const int scaled_avatar_size = 128;
	QString avatarPath = getSelfAvatarPath();

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

	Toxcore::sendAvatarToAllFriends(tox, avatarPath);
}

const QSize QmlCBridge::getImageSize(const QString &path)
{
	return Tools::getImageSize(path);
}

const QString QmlCBridge::getCurrentCommitSha1()
{
	return Tools::getCurrentCommitSha1();
}

void QmlCBridge::setTranslation(const QString &translation)
{
	// default language
	if (translation == "en_US") {
		return;
	}

	if (!translator->load(":protox_" + translation, ".")) {
		Tools::debug("Translation loading failed: " + translation);
		return;
	}

	qApp->installTranslator(translator);
}

void QmlCBridge::scrollToEnd()
{
	QMetaObject::invokeMethod(component, "scrollToEnd");
}

QString QmlCBridge::importProfile(const QString &path)
{
	if (!Toxcore::checkToxFile(path)) {
		return QString();
	}

	QFileInfo info(path);
	if (!info.exists() || info.suffix() != "tox") {
		return QString();
	}

	return QFile::copy(path, Tools::getProgDir() + info.fileName()) ? info.fileName() : QString();
}

/*
 * QML warnings handler
*/

static const QtMessageHandler QT_DEFAULT_MESSAGE_HANDLER = qInstallMessageHandler(0);

void customMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString & msg)
{
	const QStringList skipWarningsList = { "QML Connections: Implicitly defined onFoo properties in Connections are deprecated. Use this syntax instead: function onFoo(<arguments>) { ... }", 
										   "QML Loader: Possible anchor loop detected on fill.",
										   // Qt 5.15.1
										   "QML TableViewColumn: Accessible must be attached to an Item",
										   "QML ToolBar (parent or ancestor of Material): Binding loop detected for property \"foreground\""};
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
	qInstallMessageHandler(customMessageHandler);

	if (!Native::requestApplicationPermissions()) {
		return 1;
	}

	ChatDataBase::registerSQLDriver();

	settings = new QSettingsExt(Tools::getProgDir() + "settings.ini");
	notification = new QtNotification;
	qmlbridge = new QmlCBridge;

	Tools::debug("App started.");

	QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

	// fixme: added workaround for qt bug https://bugreports.qt.io/browse/QTBUG-85577
#ifdef Q_OS_ANDROID
	QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::Round);
#endif

	QGuiApplication app(argc, argv);
	// eleminate QML warnings
	app.setOrganizationName("protox");
	app.setOrganizationDomain("org");

	QQmlApplicationEngine engine;
	const QUrl url(QStringLiteral(QML_MAIN));
	QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
					 &app, [url](QObject *obj, const QUrl &objUrl) {
		if (!obj && url == objUrl)
			QCoreApplication::exit(-1);
	}, Qt::QueuedConnection);

	QQmlContext *root = engine.rootContext();
	root->setContextProperty("bridge", qmlbridge);

	QtNotification::declareQML();
	QtStatusBar::declareQML();
	QtToast::declareQML();
	QtPhotoDialog::declareQML();
	QtFolderDialog::declareQML();
	QtQRCodeScanner::declareQML();
	QUtf8ByteLimitValidator::declareQML();
	QZXing::registerQMLTypes();
	QZXing::registerQMLImageProvider(engine);

	qmlbridge->setTranslation(qmlbridge->getSystemLocale());
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
