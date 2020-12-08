#include "tox.h"
#include "main.h"
#include "tools.h"
#include "db.h"
#include "settings.h"

extern QmlCBridge *qmlbridge;
extern QSettingsExt *settings;

/*
 * Toxcore callbacks
*/

namespace Toxcore {

quint32 available_nodes = 0;
ToxLocalFileManager local_manager;

void cb_log(Tox *m, TOX_LOG_LEVEL level, const char *file, uint32_t line, const char *func,
                        const char *message, void *userdata)
{
	Q_UNUSED(m)
	Q_UNUSED(userdata)

	QString _level;
	switch (level) {
	case TOX_LOG_LEVEL_INFO: _level = "INFO"; break;
	case TOX_LOG_LEVEL_ERROR: _level = "ERROR"; break;
	case TOX_LOG_LEVEL_DEBUG: _level = "DEBUG"; break;
	case TOX_LOG_LEVEL_WARNING: _level = "WARNING"; break;
	case TOX_LOG_LEVEL_TRACE: _level = "TRACE"; break;
	}

	Tools::debug("Toxcore: " + QString(file) + " (line " + QString::number(line) + ") " + _level + ": " + func + " " + message);
}

static void cb_self_connection_change(Tox *m, TOX_CONNECTION connection_status, void *userdata)
{
	Q_UNUSED(m);
	Q_UNUSED(userdata);

	switch (connection_status) {
		case TOX_CONNECTION_NONE:
			qmlbridge->tryReconnect();
			Tools::debug("Connection to Tox network has been lost.");
			break;

		case TOX_CONNECTION_TCP:
			Tools::debug("Connection to Tox network is weak (using TCP).");
			break;

		case TOX_CONNECTION_UDP:
			Tools::debug("Connection to Tox network is strong (using UDP).");
			break;
	}

	qmlbridge->setConnectionStatus(connection_status);
}

static void cb_friend_request(Tox *m, const uint8_t *public_key, const uint8_t *data, size_t length, void *userdata)
{
	Q_UNUSED(m)
	Q_UNUSED(userdata);

	ToxPk pk((char*)public_key);
	// hint: friend_number is fake here
	qmlbridge->insertFriend(0, pk.toToxString(), 
							true, QString::fromUtf8((char*)data, length), pk);
}

void cb_friend_read_receipt(Tox *m, uint32_t friend_number, uint32_t message_id, void *userdata)
{
	Q_UNUSED(m);
	Q_UNUSED(userdata);

	for (int i = 0; i < qmlbridge->pending_messages.count(); i++) {
		const ToxPendingMessage &pending_message = qmlbridge->pending_messages[i];

		if (pending_message.message_id == message_id && pending_message.friend_number == friend_number) {
			qmlbridge->getChatDB()->setMessageReceived(pending_message.unique_id, getFriendPublicKey(m, friend_number));
			qmlbridge->setMessageReceived(friend_number, pending_message.unique_id);

			if (pending_message.reply) {
				qmlbridge->cancelTextNotification(friend_number);
			}

			qmlbridge->pending_messages.removeAt(i);
			break;
		}
	}
}

static void cb_friend_message(Tox *m, uint32_t friend_number, TOX_MESSAGE_TYPE type, const uint8_t *string, size_t length, void *userdata)
{
	Q_UNUSED(userdata);

	QString message = QString::fromUtf8((char*)string, length);
	ToxPk friend_pk = getFriendPublicKey(m, friend_number);
	ToxVariantMessage variantMessage = {
		{ "type", ToxVariantMessageType::TOXMSG_TEXT },
		{ "message", message },
		{ "action", type != TOX_MESSAGE_TYPE_NORMAL }
	};
	QDateTime dt = QDateTime::currentDateTime();

	settings->beginGroup("Privacy");
	bool keep_chat_history = settings->valued("keep_chat_history").toBool();
	settings->endGroup();

	qmlbridge->getChatDB()->insertMessage(variantMessage, dt, friend_pk, !keep_chat_history, false);
	qmlbridge->insertMessage(variantMessage, friend_number, dt);
}

static void cb_friend_name(Tox *m, uint32_t friend_number, const uint8_t *name, size_t length, void *user_data)
{
	Q_UNUSED(user_data)
	if (!qmlbridge->checkFriendCustomNickname(friend_number)) {
		// I replace newlines with spaces to not make a mess in UI
		QString nickName = QString::fromUtf8((char*)name, length).replace("\n", " ");
		if (nickName.isEmpty()) {
			nickName = getFriendPublicKey(m, friend_number).toToxString();
		}

		qmlbridge->updateFriendNickName(friend_number, nickName);
	}
}

static void cb_friend_connection_change(Tox *m, uint32_t friend_number, TOX_CONNECTION connection_status, void *userdata)
{
	Q_UNUSED(userdata)

	if (!tox_self_get_friend_list_size(m)) {
		return;
	}

	qmlbridge->setCurrentFriendConnStatus(friend_number, connection_status);

	if (connection_status > 0) {
		qmlbridge->sendPendingMessages(friend_number);

		const QString avatar_path = qmlbridge->getSelfAvatarPath();
		if (QFile::exists(avatar_path)) {
			sendFile(m, friend_number, avatar_path, true);
		} else {
			sendFile(m, friend_number, "", true);
		}
	} else {
		qmlbridge->removeNonFailedPendingMessages(friend_number);
		cancelAllFileTransfersForFriend(friend_number);
	}
}

static void cb_friend_typing(Tox *m, uint32_t friend_number, bool is_typing, void *user_data)
{
	Q_UNUSED(m)
	Q_UNUSED(user_data)

	qmlbridge->setFriendTyping(friend_number, is_typing);
}

static void cb_friend_status_message(Tox *m, uint32_t friend_number, const uint8_t *message, size_t length, void *user_data)
{
	Q_UNUSED(m)
	Q_UNUSED(user_data)

	// I replace newlines with spaces to not make a mess in UI
	qmlbridge->setFriendStatusMessage(friend_number, QString::fromUtf8((char*)message, length).replace("\n", " "));
}

static void cb_friend_status(Tox *m, uint32_t friend_number, TOX_USER_STATUS status, void *user_data)
{
	Q_UNUSED(m)
	Q_UNUSED(user_data)

	qmlbridge->setFriendStatus(friend_number, status);
}

static void cb_file_chunk_request(Tox *m, uint32_t friend_number, uint32_t file_number, uint64_t position,
                                       size_t length, void *user_data)
{
	Q_UNUSED(m)
	Q_UNUSED(user_data)

	for (const auto transfer : qmlbridge->transfers) {
		if (transfer->friend_number == friend_number && transfer->file_number == file_number) {
			QMetaObject::invokeMethod(transfer->manager, "onChunkReadRequest", 
									  Q_ARG(qulonglong, (quint64)position), 
									  Q_ARG(uint, length));
		}
	}
}

static void cb_file_recv_control_cb(Tox *m, uint32_t friend_number, uint32_t file_number, TOX_FILE_CONTROL control,
                                      void *user_data)
{
	Q_UNUSED(m)
	Q_UNUSED(user_data)

	for (const auto transfer : qmlbridge->transfers) {
		if (transfer->friend_number == friend_number && transfer->file_number == file_number && !transfer->avatar) {
			qmlbridge->fileControlUpdateMessage(friend_number, qmlbridge->file_messages[transfer], control, true);

			switch (control) {
				case TOX_FILE_CONTROL_RESUME: {
					return;
				}
				case TOX_FILE_CONTROL_CANCEL: {
					qmlbridge->getChatDB()->updateFileMessageState(qmlbridge->file_messages[transfer], 
													getFriendPublicKey(m, friend_number), 
													ToxFileState::TOX_FILE_CANCELED);
					delete transfer;
					qmlbridge->file_messages.remove(transfer);
					qmlbridge->transfers.removeOne(transfer);
					return;
				}
				case TOX_FILE_CONTROL_PAUSE: {
					return;
				}
			}
		}
	}
}

static void fileTransferEnd(Tox *m, quint32 friend_number, quint32 file_number);
static void cb_file_recv(Tox *m, uint32_t friend_number, uint32_t file_number, uint32_t kind, uint64_t file_size,
                              const uint8_t *filename, size_t filename_length, void *user_data)
{
	Q_UNUSED(user_data)

	switch (kind) {
		case TOX_FILE_KIND_AVATAR: {
			const QString file_path = Tools::getAvatarsDir() + 
					getFriendPublicKey(m, friend_number).toToxString();

			auto file = make_unique<QFile>(file_path);
			if (file->exists()) {
				if (!file->open(QIODevice::ReadOnly)) {
					Tools::debug("Couldn't open avatar file for reading: " + file->fileName());
					break;
				}
				QByteArray data = file->readAll();
				
				QByteArray hash_local;
				hash_local.resize(tox_hash_length());
				tox_hash((uint8_t*)hash_local.data(), (uint8_t*)data.data(), data.length());

				QByteArray hash;
				hash.resize(tox_file_id_length());

				TOX_ERR_FILE_GET err;
				TOX_ERR_FILE_CONTROL err2;
				tox_file_get_file_id(m, friend_number, file_number, (uint8_t*)hash.data(), &err);

				if (err > 0) {
					Tools::debug("Couldn't get file id for friend: " + QString::number(friend_number) + ".");
					tox_file_control(m, friend_number, file_number, TOX_FILE_CONTROL_CANCEL, &err2);
					break;
				}

				if (hash == hash_local) {
					Tools::debug("Avatar transfer canceled for friend: " + QString::number(friend_number) + ". Avatar already exists.");
					tox_file_control(m, friend_number, file_number, TOX_FILE_CONTROL_CANCEL, &err2);
					break;
				}

				file->close();
			}

			Tools::AsyncFileManager *manager = new Tools::AsyncFileManager(file.release());
			QObject::connect(manager, &Tools::AsyncFileManager::fileTransferEnded, 
							 &local_manager, &ToxLocalFileManager::onFileTransferEnded);
			ToxFileTransfer *transfer = new ToxFileTransfer(m, friend_number, file_number, true, manager);
			qmlbridge->transfers.push_back(transfer);

			bool result;
			QMetaObject::invokeMethod(transfer->manager, "onFileTransferStarted", Qt::BlockingQueuedConnection, 
									  Q_RETURN_ARG(bool, result));

			TOX_ERR_FILE_CONTROL err;
			if (!result) {
				Tools::debug("Couldn't open file " + file_path + " for saving avatar.");
				tox_file_control(m, friend_number, file_number, TOX_FILE_CONTROL_CANCEL, &err);
				delete transfer;
				qmlbridge->transfers.removeOne(transfer);
				break;
			}

			tox_file_control(m, friend_number, file_number, TOX_FILE_CONTROL_RESUME, &err);
			if (err > 0) {
				Tools::debug("Avatar transfer resuming error, error code (tox_file_control): " + QString::number(err));
				tox_file_control(m, friend_number, file_number, TOX_FILE_CONTROL_CANCEL, &err);
				delete transfer;
				qmlbridge->transfers.removeOne(transfer);
				break;
			}

			break;
		}
		case TOX_FILE_KIND_DATA: {
			QString fileName = QString::fromUtf8((char*)filename, filename_length);

			settings->beginGroup("Client");
			const QString downloadsFolder = settings->valued("downloads_folder").toString();
			bool auto_accept_files = settings->valued("auto_accept_files").toBool();
			quint64 auto_accept_file_size = settings->valued("auto_accept_file_size").toULongLong();
			settings->endGroup();

			const QString file_path = downloadsFolder + QDir::separator() + fileName;
			const QString new_path = Tools::getUniqueFilepath(file_path);

			Tools::AsyncFileManager *manager = new Tools::AsyncFileManager(new QFile(new_path));
			QObject::connect(manager, &Tools::AsyncFileManager::fileTransferEnded, 
							 &local_manager, &ToxLocalFileManager::onFileTransferEnded);
			ToxFileTransfer *transfer = new ToxFileTransfer(m, friend_number, file_number, false, manager);
			qmlbridge->transfers.push_back(transfer);

			QDateTime dt = QDateTime::currentDateTime();
			ToxVariantMessage variantMessage = {
				{ "type", ToxVariantMessageType::TOXMSG_FILE },
				{ "size", (quint64)file_size},
				{ "state", ToxFileState::TOX_FILE_REQUEST },
				{ "file_path", new_path },
				{ "file_number", file_number },
				{ "name", Tools::getFilenameFromPath(new_path) } // ui only
			};

			settings->beginGroup("Privacy");
			bool keep_chat_history = settings->valued("keep_chat_history").toBool();
			settings->endGroup();

			quint64 unique_id = qmlbridge->getChatDB()->insertMessage(variantMessage, dt, Toxcore::getFriendPublicKey(m, friend_number), !keep_chat_history, false);
			qmlbridge->file_messages[transfer] = unique_id;
			qmlbridge->insertMessage(variantMessage, friend_number, dt, false, unique_id);

			if (auto_accept_files && (auto_accept_file_size == 0 || (quint64)file_size <= auto_accept_file_size * 1024 * 1024)) {
				qmlbridge->acceptFile(friend_number, file_number);

			}

			break;
		}
	}
}

void cb_file_recv_chunk(Tox *m, uint32_t friend_number, uint32_t file_number, uint64_t position,
                                    const uint8_t *data, size_t length, void *user_data)
{
	Q_UNUSED(m)
	Q_UNUSED(user_data)

	for (const auto transfer : qmlbridge->transfers) {
		if (transfer->friend_number == friend_number && transfer->file_number == file_number) {
			QMetaObject::invokeMethod(transfer->manager, "onChunkWriteRequest", 
									  Q_ARG(qulonglong, (quint64)position), 
									  Q_ARG(QByteArray, QByteArray((char*)data, length)));
	
			transfer->bytesTransfered += length;

			if (!transfer->avatar && !transfer->progress_update_timer->isActive()) {
				qmlbridge->changeFileProgress(transfer->friend_number, transfer->file_number, 
											  transfer->bytesTransfered, false);
				transfer->progress_update_timer->start();
			}
		}
	}
}

/*
 * Toxcore functions
 * 
*/

quint32 getFriendsCount(Tox *m)
{
	return tox_self_get_friend_list_size(m);
}

ToxFriends getFriends(Tox *m)
{
	ToxFriends friends_list(getFriendsCount(m));
	tox_self_get_friend_list(m, &friends_list[0]);

	return friends_list;
}

ToxPk getFriendPublicKey(Tox *m, quint32 friend_number)
{
	ToxPk public_key;

	if(tox_friend_get_public_key(m, friend_number, (uint8_t*)public_key.data(), nullptr))
		return public_key;

	return ToxPk();
}

const QString getFriendStatusMessage(Tox *m, quint32 friend_number)
{
	TOX_ERR_FRIEND_QUERY query_error;
	size_t length = tox_friend_get_status_message_size(m, friend_number, &query_error);

	if (!length || query_error > 0)
		return QString();

	QByteArray message;
	message.resize(length);
	tox_friend_get_status_message(m, friend_number, (uint8_t*)message.data(), nullptr);

	// I replace newlines with spaces to not make a mess in UI
	return QString::fromUtf8(message).replace("\n", " ");
}

const QString getFriendName(Tox *m, quint32 friend_number, bool publicKey)
{
	size_t length = tox_friend_get_name_size(m, friend_number, nullptr);

	if (!length) {
		if (publicKey) {
			return getFriendPublicKey(m, friend_number).toToxString();
		} else {
			return QString();
		}
	}

	QByteArray name;
	name.resize(length);

	if (tox_friend_get_name(m, friend_number, (uint8_t*)name.data(), nullptr)) {
		// I replace newlines with spaces to not make a mess in UI
		return QString::fromUtf8(name).replace("\n", " ");
	} else {
		return QString();
	}
}

quint32 getStatus(Tox *m)
{
	return tox_self_get_status(m);
}

void setStatus(Tox *m, quint32 status)
{
	tox_self_set_status(m, (TOX_USER_STATUS)status);
}

pair<quint32, bool> sendMessage(Tox *m, quint32 friend_number, const QString &message, bool action)
{
	TOX_ERR_FRIEND_SEND_MESSAGE err;
	QByteArray encodedMessage = message.toUtf8();
	quint32 message_id = tox_friend_send_message(m, friend_number, 
												 action ? TOX_MESSAGE_TYPE_ACTION : TOX_MESSAGE_TYPE_NORMAL, 
												 (uint8_t*)encodedMessage.data(), encodedMessage.size(), &err);

	if (err > 0) {
		Tools::debug("tox_friend_send_message failed with error number: " + QString::number(err));
		return { message_id, true };
	} else {
		return { message_id, false };
	}
}

quint32 makeFriendRequest(Tox *m, const ToxIdData &id, const QString &friendMessage)
{
	TOX_ERR_FRIEND_ADD error;
	QByteArray msgData(friendMessage.toUtf8());
	quint32 friend_number = tox_friend_add(m, (uint8_t*)id.data(), (uint8_t*)msgData.data(), msgData.length(), &error);

	if (!error) {
		qmlbridge->insertFriend(friend_number, getFriendPublicKey(m, friend_number).toToxString());
	}

	return error;
}

pair<quint32, quint32> addFriend(Tox *m, const ToxPk &friendPk)
{
	TOX_ERR_FRIEND_ADD error;
	quint32 friend_number = tox_friend_add_norequest(m, (uint8_t*)friendPk.data(), &error);
	return { friend_number, error };
}

void deleteFriend(Tox *m, quint32 friend_number)
{
	tox_friend_delete(m, friend_number, nullptr);
}

void setFriendTyping(Tox *m, quint32 friend_number, bool typing)
{
	tox_self_set_typing(m, friend_number, typing, nullptr);
}

const QString getNickname(Tox *m, bool toxPk)
{
	size_t length = tox_self_get_name_size(m);

	if (!length && toxPk) {
		return ToxPk(getAddress(m)).toToxString();
	}

	QByteArray name;
	name.resize(length);
	tox_self_get_name(m, (uint8_t*)name.data());

	return QString::fromUtf8(name);
}

void setNickname(Tox *m, const QString &nickname)
{
	QByteArray encodedNickname = nickname.toUtf8();
	tox_self_set_name(m, (uint8_t*)encodedNickname.data(), encodedNickname.length(), nullptr);
}

int getFriendStatus(Tox *m, quint32 friend_number)
{
	TOX_ERR_FRIEND_QUERY error;
	int result = tox_friend_get_status(m, friend_number, &error);

	if (!error) {
		return result;
	}

	return -1;
}

quint32 getFriendConnectionStatus(Tox *m, quint32 friend_number)
{
	TOX_ERR_FRIEND_QUERY err;
	return tox_friend_get_connection_status(m, friend_number, &err);
}

const QString getStatusMessage(Tox *m)
{
	size_t length = tox_self_get_status_message_size(m);

	if (!length)
		return QString();

	QByteArray name;
	name.resize(length);
	tox_self_get_status_message(m, (uint8_t*)name.data());

	return QString::fromUtf8(name);
}

void setStatusMessage(Tox *m, const QString &statusMessage)
{
	QByteArray encodedMessage = statusMessage.toUtf8();
	tox_self_set_status_message(m, (uint8_t*)encodedMessage.data(), encodedMessage.length(), nullptr);
}

/*
 * Basic Functions 
*/

int getConnectionStatus(Tox *m)
{
	return tox_self_get_connection_status(m);
}

bool saveData(Tox *m, const Tox_Pass_Key *pass_key, const QString &path)
{
	if (path.isEmpty()) {
		Tools::debug("Warning: save_data failed: path is empty.");
		return false;
	}

	QFile file(path);
	if (!file.open(QIODevice::WriteOnly))
		return false;

	QByteArray data;
	data.resize(tox_get_savedata_size(m));
	tox_get_savedata(m, (uint8_t*)data.data());

	QByteArray encryptedData;

	if (pass_key) {
		encryptedData.resize(data.length() + TOX_PASS_ENCRYPTION_EXTRA_LENGTH);
		if(!tox_pass_key_encrypt(pass_key, (uint8_t*)data.data(), data.length(),
								 (uint8_t*)encryptedData.data(), nullptr)) {
			return false;
		}
	}

	int result;
	if (pass_key) {
		result = file.write(encryptedData);
	} else {
		result = file.write(data);
	}

	if (result == -1) {
		Tools::debug("Warning: save_data failed: write failed.");
		return false;
	}

	if (!file.flush()) {
		Tools::debug("Warning: save_data failed: flush failed.");
		return false;
	}

	return true;
}

static pair<Tox*, ToxProfileLoadingError> loadTox(struct Tox_Options *options, const QString &path, const QString &password)
{
	QFile file(path);
	Tox *m = nullptr;

	if (!file.open(QIODevice::ReadOnly)) {
		TOX_ERR_NEW err;
		m = tox_new(options, &err);

		bool reset_proxy = false;
		if (err == TOX_ERR_NEW_PROXY_BAD_HOST) {
			Tools::debug("Connection to proxy has failed. Ignoring proxy.");
			tox_options_set_proxy_type(options, TOX_PROXY_TYPE_NONE);
			m = tox_new(options, &err);
			reset_proxy = true;
		}

		if (err != TOX_ERR_NEW_OK) {
			Tools::debug("tox_new failed with error number: " + QString::number(err));
			return { nullptr, TOX_ERR_LOADING_NULL };
		}

		return { m, reset_proxy ? TOX_ERR_LOADING_OK_BUT_INVALID_PROXY : TOX_ERR_LOADING_OK };
	}

	if (!file.size()) {
		return { nullptr, TOX_ERR_LOADING_NULL };
	}

	QByteArray data = file.readAll();
	if (data.isEmpty()) {
		return { nullptr, TOX_ERR_LOADING_NULL };
	}

	QByteArray decrypted_data;
	bool encrypted = tox_is_data_encrypted((uint8_t*)data.data());

	if (encrypted) {
		if (!password.isEmpty()) {
			QByteArray encodedPassword = password.toUtf8();
			decrypted_data.resize(data.length() - TOX_PASS_ENCRYPTION_EXTRA_LENGTH);

			if (!tox_pass_decrypt((uint8_t*)data.data(), data.length(), 
								  (uint8_t*)encodedPassword.data(), encodedPassword.length(), 
								  (uint8_t*)decrypted_data.data(), nullptr)) {
				return { nullptr, TOX_ERR_LOADING_WRONG_PASSWORD };
			}
		} else {
			return { nullptr, TOX_ERR_LOADING_EMPTY_PASSWORD };
		}
	}

	TOX_ERR_NEW err;
	options->savedata_type = TOX_SAVEDATA_TYPE_TOX_SAVE;
	if (encrypted) {
		options->savedata_data = (uint8_t*)decrypted_data.data();
		options->savedata_length = decrypted_data.length();
	} else {
		options->savedata_data = (uint8_t*)data.data();
		options->savedata_length = data.length();
	}

	m = tox_new(options, &err);

	bool reset_proxy = false;
	if (err == TOX_ERR_NEW_PROXY_BAD_HOST) {
		Tools::debug("Connection to proxy has failed. Ignoring proxy.");
		tox_options_set_proxy_type(options, TOX_PROXY_TYPE_NONE);
		m = tox_new(options, &err);
		reset_proxy = true;
	}

	if (err != TOX_ERR_NEW_OK) {
		Tools::debug("tox_new failed with error number: " + QString::number(err));
		return { nullptr, TOX_ERR_LOADING_NULL };
	}

	return { m, reset_proxy ? TOX_ERR_LOADING_OK_BUT_INVALID_PROXY : TOX_ERR_LOADING_OK };
}

quint32 getNospam(Tox *m) 
{
	return tox_self_get_nospam(m);
}

void setNospam(Tox *m, quint32 nospam)
{
	tox_self_set_nospam(m, nospam);
}

const QString default_nodes_json = "{\"last_scan\":1581207188,\"last_refresh\":1581207129,\"nodes\":[{\"ipv4\":\"85.172.30.117\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"8E7D0B859922EF569298B4D261A8CCB5FEA14FB91ED412A7603A585A25698832\",\"maintainer\":\"ray65536\",\"location\":\"RU\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"Ray's Tox Node. TOX ID:3C3D6DB24D24754393679E59F198EF45EE26835AEF7EA3E3ECEA40E204F2B828BE86DF012ABF\",\"last_ping\":1581207190},{\"ipv4\":\"85.143.221.42\",\"ipv6\":\"2a04:ac00:1:9f00:5054:ff:fe01:becd\",\"port\":33445,\"tcp_ports\":[33445,3389],\"public_key\":\"DA4E4ED4B697F2E9B000EEFE3A34B554ACD3F45F5C96EAEA2516DD7FF9AF7B43\",\"maintainer\":\"MAH69K\",\"location\":\"RU\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002009\",\"motd\":\"Saluton! Mia Tox ID: B229B7BD68FC66C2716EAB8671A461906321C764782D7B3EDBB650A315F6C458EF744CE89F07. Scribu! ;)\",\"last_ping\":1581207188},{\"ipv4\":\"tox.verdict.gg\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"1C5293AEF2114717547B39DA8EA6F1E331E5E358B35F9B6B5F19317911C5F976\",\"maintainer\":\"Deliran\",\"location\":\"DE\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002008\",\"motd\":\"Praise The Sun!\",\"last_ping\":1581207188},{\"ipv4\":\"78.46.73.141\",\"ipv6\":\"2a01:4f8:120:4091::3\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"02807CF4F8BB8FB390CC3794BDF1E8449E9A8392C5D3F2200019DA9F1E812E46\",\"maintainer\":\"Sorunome\",\"location\":\"DE\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002008\",\"motd\":\"Keep calm and pony on!\",\"last_ping\":1581207188},{\"ipv4\":\"46.229.52.198\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"813C8F4187833EF0655B10F7752141A352248462A567529A38B6BBF73E979307\",\"maintainer\":\"Stranger\",\"location\":\"UA\",\"status_udp\":true,\"status_tcp\":false,\"version\":\"1000002008\",\"motd\":\"Freedom to parrots!\",\"last_ping\":1581207188},{\"ipv4\":\"144.217.167.73\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445,3389],\"public_key\":\"7E5668E0EE09E19F320AD47902419331FFEE147BB3606769CFBE921A2A2FD34C\",\"maintainer\":\"velusip\",\"location\":\"CA\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"Jera\",\"last_ping\":1581207188},{\"ipv4\":\"tox.abilinski.com\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"10C00EB250C3233E343E2AEBA07115A5C28920E9C8D29492F6D00B29049EDC7E\",\"maintainer\":\"AnthonyBilinski\",\"location\":\"CA\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"Running https://github.com/toktok/c-toxcore v0.2.10. qTox best Tox! Contact: AC18841E56CCDEE16E93E10E6AB2765BE54277D67F1372921B5B418A6B330D3D3FAFA60B0931\",\"last_ping\":1581207188},{\"ipv4\":\"37.48.122.22\",\"ipv6\":\"2001:1af8:4700:a115:6::b\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"1B5A8AB25FFFB66620A531C4646B47F0F32B74C547B30AF8BD8266CA50A3AB59\",\"maintainer\":\"Pokemon\",\"location\":\"NL\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002009\",\"motd\":\"Those who would give up essential Liberty, to purchase a little temporary Safety, deserve neither Liberty nor Safety\",\"last_ping\":1581207188},{\"ipv4\":\"tox.novg.net\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"D527E5847F8330D628DAB1814F0A422F6DC9D0A300E6C357634EE2DA88C35463\",\"maintainer\":\"blind_oracle\",\"location\":\"NL\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1581207190},{\"ipv4\":\"95.31.18.227\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"257744DBF57BE3E117FE05D145B5F806089428D4DCE4E3D0D50616AA16D9417E\",\"maintainer\":\"ky0uraku\",\"location\":\"RU\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002008\",\"motd\":\"Vive le TOX\",\"last_ping\":1581207190},{\"ipv4\":\"198.199.98.108\",\"ipv6\":\"2604:a880:1:20::32f:1001\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"BEF0CFB37AF874BD17B9A8F9FE64C75521DB95A37D33C5BDB00E9CF58659C04F\",\"maintainer\":\"Cody\",\"location\":\"US\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002008\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1581207188},{\"ipv4\":\"tox.kurnevsky.net\",\"ipv6\":\"tox.kurnevsky.net\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"82EF82BA33445A1F91A7DB27189ECFC0C013E06E3DA71F588ED692BED625EC23\",\"maintainer\":\"kurnevsky\",\"location\":\"NL\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"3000000008\",\"motd\":\"Hi from tox-rs! I'm up 01 days 16 hours 19 minutes.\",\"last_ping\":1581207190},{\"ipv4\":\"87.118.126.207\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"0D303B1778CA102035DA01334E7B1855A45C3EFBC9A83B9D916FFDEBC6DD3B2E\",\"maintainer\":\"quux\",\"location\":\"DE\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"Make Orwell Fiction Again\",\"last_ping\":1581207188},{\"ipv4\":\"81.169.136.229\",\"ipv6\":\"2a01:238:4254:2a00:7aca:fe8c:68e0:27ec\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"E0DB78116AC6500398DDBA2AEEF3220BB116384CAB714C5D1FCD61EA2B69D75E\",\"maintainer\":\"9ofSpades\",\"location\":\"DE\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"🂩 wishes happy toxing. 📡\",\"last_ping\":1581207190},{\"ipv4\":\"205.185.115.131\",\"ipv6\":\"-\",\"port\":53,\"tcp_ports\":[53,3389,443,33445],\"public_key\":\"3091C6BEB2A993F1C6300C16549FABA67098FF3D62C6D253828B531470B53D68\",\"maintainer\":\"GDR!\",\"location\":\"US\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"https://gdr.name/tuntox/\",\"last_ping\":1581207188},{\"ipv4\":\"tox2.abilinski.com\",\"ipv6\":\"tox2.abilinski.com\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"7A6098B590BDC73F9723FC59F82B3F9085A64D1B213AAF8E610FD351930D052D\",\"maintainer\":\"AnthonyBilinski\",\"location\":\"US\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"Running https://github.com/toktok/c-toxcore v0.2.10. qTox best Tox! Contact: AC18841E56CCDEE16E93E10E6AB2765BE54277D67F1372921B5B418A6B330D3D3FAFA60B0931\",\"last_ping\":1581207188},{\"ipv4\":\"floki.blog\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"6C6AF2236F478F8305969CCFC7A7B67C6383558FF87716D38D55906E08E72667\",\"maintainer\":\"Floki\",\"location\":\"GB\",\"status_udp\":true,\"status_tcp\":false,\"version\":\"1000002010\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1581207188},{\"ipv4\":\"51.158.146.76\",\"ipv6\":\"2001:bc8:6010:213:208:a2ff:fe0c:7fee\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"E940D8FA9B07C1D13EA4ECF9F06B66F565F1CF61F094F60C67FDC8ADD3F4BA59\",\"maintainer\":\"CyberSquirrel\",\"location\":\"NL\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002009\",\"motd\":\"CyberSquirrel TOX node. Contacts - toxnode@cock.li\",\"last_ping\":1581207190},{\"ipv4\":\"194.36.190.71\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"B62F1878BD08EDD34E4D7B0D66F9E74CC7BDE4BEA2C95E130DAADCFF9BCB4F6D\",\"maintainer\":\"Shilov\",\"location\":\"NL\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1581207188},{\"ipv4\":\"94.45.70.19\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"CE049A748EB31F0377F94427E8E3D219FC96509D4F9D16E181E956BC5B1C4564\",\"maintainer\":\"Shilov\",\"location\":\"UA\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"3000000008\",\"motd\":\"{{Welcome to Ukraine!}} 10 days 04 hours 56 minutes Tcp: incoming 49.9M, outgoing 39.7M, Udp: incoming 116.9M, outgoing 123.5M\",\"last_ping\":1581207188},{\"ipv4\":\"185.66.13.169\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"A44A024DA1299A85B91E3A64B9D19C7F331D0073DD2FAAF1361C127B5D909E3D\",\"maintainer\":\"Shilov\",\"location\":\"RU\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"3000000008\",\"motd\":\"{Elektrostal{start_date}} 10 days 06 hours 06 minutes Tcp: incoming 24.7M, outgoing 19.9M, Udp: incoming 175.7M, outgoing 177.7M\",\"last_ping\":1581207188},{\"ipv4\":\"46.101.197.175\",\"ipv6\":\"2a03:b0c0:3:d0::ac:5001\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"CD133B521159541FB1D326DE9850F5E56A6C724B5B8E5EB5CD8D950408E95707\",\"maintainer\":\"kotelnik\",\"location\":\"DE\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1581207188},{\"ipv4\":\"tox.initramfs.io\",\"ipv6\":\"tox.initramfs.io\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"3F0A45A268367C1BEA652F258C85F4A66DA76BCAA667A49E770BCC4917AB6A25\",\"maintainer\":\"initramfs\",\"location\":\"TW\",\"status_udp\":false,\"status_tcp\":false,\"version\":\"1000002010\",\"motd\":\"initramfs' Tox DHT Node\",\"last_ping\":1581194588},{\"ipv4\":\"tox.neuland.technology\",\"ipv6\":\"tox.neuland.technology\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"15E9C309CFCB79FDDF0EBA057DABB49FE15F3803B1BFF06536AE2E5BA5E4690E\",\"maintainer\":\"Nolz\",\"location\":\"DE\",\"status_udp\":false,\"status_tcp\":false,\"version\":\"1000002008\",\"motd\":\"Unlike Others\",\"last_ping\":1580033828},{\"ipv4\":\"185.14.30.213\",\"ipv6\":\"2a00:1ca8:a7::e8b\",\"port\":443,\"tcp_ports\":[],\"public_key\":\"2555763C8C460495B14157D234DD56B86300A2395554BCAE4621AC345B8C1B1B\",\"maintainer\":\"dvor\",\"location\":\"NL\",\"status_udp\":false,\"status_tcp\":false,\"version\":\"1000002008\",\"motd\":\"Just another tox node.\",\"last_ping\":1579652108},{\"ipv4\":\"109.111.178.181\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"25890C0139ECF9F217C72058D9E43E8873F6755D24374525623944915C98A903\",\"maintainer\":\"LivingstoneI2P\",\"location\":\"RU\",\"status_udp\":false,\"status_tcp\":false,\"version\":\"\",\"motd\":\"\",\"last_ping\":1580906888},{\"ipv4\":\"218.28.170.22\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"DBACB7D3F53693498398E6B46EF0C063A4656EB02FEFA11D72A60BAFA8DF7B59\",\"maintainer\":\"OnionBulb\",\"location\":\"CN\",\"status_udp\":false,\"status_tcp\":false,\"version\":\"1000002010\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1579642990}]}";

#define tox_bootstrap_abort_checkpoint() do { if (qmlbridge->abort_bootstrapping) { return; } } while(0)

void bootstrapDHT(Tox *m)
{
	settings->beginGroup("Toxcore");
	QString json_file = settings->valued("nodes_json_file").toString();
	bool use_ipv6 = settings->valued("ipv6_enabled").toBool();
	settings->endGroup();

	QByteArray json_data;
	if (!json_file.isEmpty()) {
		QFile file(Tools::getProgDir() + json_file);

		if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
			json_data = file.readAll();
		}
	}

	QJsonDocument doc = QJsonDocument::fromJson(json_data.isEmpty() ? default_nodes_json.toUtf8() : json_data);
	QJsonArray array = doc.object()["nodes"].toArray();
	available_nodes = array.count();

	qmlbridge->bootstrapping_thread = QtConcurrent::run([m, use_ipv6, array]() {
		for (const auto &node : array) {
			QJsonObject item = node.toObject();
			QString ipv4 = item["ipv4"].toString();
			QString ipv6 = item["ipv6"].toString();
			int port = item["port"].toInt();
			QString public_key = item["public_key"].toString();
			QJsonArray tcp_ports = item["tcp_ports"].toArray();

			TOX_ERR_BOOTSTRAP err, err2;
			tox_bootstrap_abort_checkpoint();
			tox_bootstrap(m, ipv4.toUtf8().data(), (uint16_t)port, (uint8_t*)ToxIdData::fromToxString(public_key).data(), &err);

			if (use_ipv6 && ipv6 != "-") {
				tox_bootstrap_abort_checkpoint();
				tox_bootstrap(m, ipv6.toUtf8().data(), (uint16_t)port, (uint8_t*)ToxIdData::fromToxString(public_key).data(), &err2);
			}

			if (!tcp_ports.isEmpty()) {
				for (const auto tcp_port : tcp_ports) {
					TOX_ERR_BOOTSTRAP err3, err4;
					tox_bootstrap_abort_checkpoint();
					tox_add_tcp_relay(m, ipv4.toUtf8().data(), (uint16_t)tcp_port.toInt(), (uint8_t*)ToxIdData::fromToxString(public_key).data(), &err3);

					if (use_ipv6 && ipv6 != "-") {
						tox_bootstrap_abort_checkpoint();
						tox_add_tcp_relay(m, ipv6.toUtf8().data(), (uint16_t)tcp_port.toInt(), (uint8_t*)ToxIdData::fromToxString(public_key).data(), &err4);
					}
				}
			}
		}
	});
}

struct Tox_Options *createOptions()
{
	TOX_ERR_OPTIONS_NEW err;
	struct Tox_Options *opts = tox_options_new(&err);

	if (err > 0) {
		Tools::debug("tox_options_new failed with error number: " + QString::number(err));
		return nullptr;
	}

	tox_options_default(opts);
	tox_options_set_log_callback(opts, cb_log);

	settings->beginGroup("Toxcore");
	tox_options_set_udp_enabled(opts, settings->valued("udp_enabled").toBool());
	tox_options_set_ipv6_enabled(opts, settings->valued("ipv6_enabled").toBool());
	tox_options_set_local_discovery_enabled(opts, settings->valued("local_discovery_enabled").toBool());
	tox_options_set_proxy_host(opts, settings->valued("proxy_host").toString().toUtf8().data());
	tox_options_set_proxy_port(opts, (uint16_t)settings->valued("proxy_port").toUInt());
	tox_options_set_proxy_type(opts, (TOX_PROXY_TYPE)settings->valued("proxy_type").toUInt());
	settings->endGroup();

	return opts;
}

void destroyOptions(struct Tox_Options *opts)
{
	tox_options_free(opts);
}

pair<Tox*, ToxProfileLoadingError> createTox(bool create_new, const QString &password, const QString &profile, const Tox_Pass_Key *pass_key, struct Tox_Options *opts)
{
	QFile file(Tools::getProgDir() + profile);

	if (!create_new && !file.exists()) {
		return { nullptr, TOX_ERR_LOADING_NOT_EXISTS };
	}

	if (create_new && file.exists()) {
		return { nullptr, TOX_ERR_LOADING_ALREADY_EXISTS };
	}

	auto [m, error] = loadTox(opts, Tools::getProgDir() + profile, password);

	if (m) {
		tox_callback_self_connection_status(m, cb_self_connection_change);
		tox_callback_friend_connection_status(m, cb_friend_connection_change);
		tox_callback_friend_request(m, cb_friend_request);
		tox_callback_friend_message(m, cb_friend_message);
		tox_callback_friend_name(m, cb_friend_name);
		tox_callback_friend_read_receipt(m, cb_friend_read_receipt);
		tox_callback_friend_typing(m, cb_friend_typing);
		tox_callback_friend_status_message(m, cb_friend_status_message);
		tox_callback_friend_status(m, cb_friend_status);
		tox_callback_file_chunk_request(m, cb_file_chunk_request);
		tox_callback_file_recv_control(m, cb_file_recv_control_cb);
		tox_callback_file_recv(m, cb_file_recv);
		tox_callback_file_recv_chunk(m, cb_file_recv_chunk);

		if (!tox_self_get_status_message_size(m) && !file.exists()) {
			const char *statusmsg = "Protox is here!";
			tox_self_set_status_message(m, (uint8_t*)statusmsg, strlen(statusmsg), nullptr);
		}

		if (!tox_self_get_name_size(m) && !file.exists()) {
			const char *username = "Protox";
			tox_self_set_name(m, (uint8_t*)username, strlen(username), nullptr);
		}

		if (!file.exists()) {
			saveData(m, pass_key, Tools::getProgDir() + profile);
		}
	}

	return { m, error };
}

bool checkProfileEncrypted(const QString &profile)
{
	QFile file(Tools::getProgDir() + profile);

	if (!file.open(QIODevice::ReadOnly)) {
		return false;
	}

	return tox_is_data_encrypted((uint8_t*)file.readAll().data());
}

static void resendAllFileChunks(Tox *m);
QTimer *createQTimer(Tox *m)
{
	QTimer *timer = new QTimer;

	QObject::connect(timer, &QTimer::timeout, [=]() { 
		tox_iterate(m, nullptr);
		resendAllFileChunks(m);
		timer->start(tox_iteration_interval(m));
	});
	timer->setSingleShot(true);

	return timer;
}

ToxIdData getAddress(Tox *m)
{
	ToxIdData address(getToxAddressSize());
	tox_self_get_address(m, (uint8_t*)address.data());
	return address;
}

void destroyTox(Tox *m)
{
	tox_kill(m);
}

void resetPasswordKey(Tox_Pass_Key **key)
{
	tox_pass_key_free(*key);
	*key = nullptr;
}

Tox_Pass_Key *generatePassKey(const QString &password)
{
	if (password.isEmpty()) {
		return nullptr;
	}

	QByteArray encodedPassword = password.toUtf8();
	return tox_pass_key_derive((uint8_t*)encodedPassword.data(), encodedPassword.length(), nullptr);
}

const QString getVersionString()
{
	return QString::number(tox_version_major()) + "." + QString::number(tox_version_minor()) + "." + QString::number(tox_version_patch());
}

quint32 getAvailableNodes()
{
	return available_nodes;
}

quint32 getMessageMaxLength()
{
	return tox_max_message_length();
}

quint32 getFriendRequestMaxLength()
{
	return tox_max_friend_request_length();
}

quint32 getNicknameMaxLength() 
{
	return tox_max_name_length();
}

quint32 getStatusMessageMaxLength()
{
	return tox_max_status_message_length();
}

quint32 getToxAddressSize()
{
	return tox_address_size();
}

quint32 getToxPublicKeySize()
{
	return tox_public_key_size();
}

quint32 getToxMaxHostnameLength()
{
	return tox_max_hostname_length();
}

static bool sendFileChunk(Tox *m, quint32 friend_number, quint32 file_number
							, quint64 position, const QByteArray &bytesRead, bool resend = false)
{
	TOX_ERR_FILE_SEND_CHUNK err;
	tox_file_send_chunk(m, friend_number, file_number, position, (uint8_t*)bytesRead.data(), bytesRead.length(), &err);

	bool save_to_buffer = false;
	if (err == TOX_ERR_FILE_SEND_CHUNK_SENDQ) {
		if (resend) {
			return false;
		}

		save_to_buffer = true;
	}

	for (const auto transfer : qmlbridge->transfers) {
		if (transfer->friend_number == friend_number && transfer->file_number == file_number) {
			if (save_to_buffer) {
				transfer->chunks_buffer.enqueue(ToxFileChunk(position, bytesRead));
				return true;
			}

			transfer->bytesTransfered += bytesRead.length();

			if (!transfer->avatar && !transfer->progress_update_timer->isActive()) {
				qmlbridge->changeFileProgress(friend_number, file_number, transfer->bytesTransfered, false);
				transfer->progress_update_timer->start();
			}

			break;
		}
	}
	return true;
}

static void resendAllFileChunks(Tox *m)
{
	for (const auto transfer : qmlbridge->transfers) {
		while (!transfer->chunks_buffer.isEmpty()) {
			const ToxFileChunk &chunk = transfer->chunks_buffer.first();

			if (sendFileChunk(m, transfer->friend_number, transfer->file_number, 
								 chunk.position, chunk.data, true)) {
				transfer->chunks_buffer.removeFirst();
			} else {
				break;
			}
		}
	}
}

static void fileTransferEnd(Tox *m, quint32 friend_number, quint32 file_number)
{
	for (const auto transfer : qmlbridge->transfers) {
		if (transfer->friend_number == friend_number && transfer->file_number == file_number) {
			if (!transfer->avatar) {
				qmlbridge->getChatDB()->updateFileMessageState(qmlbridge->file_messages[transfer], 
												getFriendPublicKey(m, friend_number), 
												ToxFileState::TOX_FILE_FINISHED);
				qmlbridge->changeFileProgress(friend_number, file_number, transfer->bytesTransfered, true);
				qmlbridge->file_messages.remove(transfer);
			}

			if (transfer->avatar) {
				qmlbridge->updateFriendAvatar(friend_number);
			}

			delete transfer;
			qmlbridge->transfers.removeOne(transfer);

			break;
		}
	}
}

pair<ToxSentFile, ToxFileSendingError> sendFile(Tox *m, quint32 friend_number, const QString &path, bool avatar)
{
	ToxSentFile sent_file;
	unique_ptr<QFile> file;

	if (!(avatar && path.isEmpty())) {
		file = make_unique<QFile>(path);
	}

	if (file && !file->open(QIODevice::ReadOnly)) {
		return { sent_file, TOX_ERR_SENDING_OPEN_FAILED };
	}

	if (file) {
		sent_file.file_size = file->size();
	} else {
		sent_file.file_size = 0;
	}

	if (file && avatar && sent_file.file_size > TOX_AVATAR_MAX_CLIENT_SIZE) {
		Tools::debug("Can't send avatar. File is too large: " + QString::number(sent_file.file_size) + " > " + QString::number(TOX_AVATAR_MAX_CLIENT_SIZE));
		return { sent_file, TOX_ERR_SENDING_OTHER };
	}

	QByteArray encodedFilename;
	if (!path.isEmpty()) {
		encodedFilename = Tools::getFilenameFromPath(path).toUtf8();
	}

	sent_file.file_id.resize(tox_file_id_length());

	TOX_ERR_FILE_SEND err;
	sent_file.file_number = tox_file_send(m, friend_number, avatar ? TOX_FILE_KIND_AVATAR : TOX_FILE_KIND_DATA, 
										sent_file.file_size, (uint8_t*)sent_file.file_id.data(), 
										(uint8_t*)encodedFilename.data(), encodedFilename.length(), &err);

	if (err > 0) {
		Tools::debug("tox_file_send file failed with error number: " + QString::number(err));
	}

	switch (err) {
		case TOX_ERR_FILE_SEND_OK: break;
		case TOX_ERR_FILE_SEND_FRIEND_NOT_CONNECTED: return { sent_file, TOX_ERR_SENDING_FRIEND_OFFLINE };
		case TOX_ERR_FILE_SEND_TOO_MANY: return { sent_file, TOX_ERR_SENDING_TOO_MANY_REQUESTS };
		default: return { sent_file, TOX_ERR_SENDING_OTHER };
	}

	if (file) {
		Tools::AsyncFileManager *manager = new Tools::AsyncFileManager(file.release());
		QObject::connect(manager, &Tools::AsyncFileManager::fileChunkReady, 
						 &local_manager, &ToxLocalFileManager::onFileChunkReady);
		QObject::connect(manager, &Tools::AsyncFileManager::fileTransferEnded, 
						 &local_manager, &ToxLocalFileManager::onFileTransferEnded);

		sent_file.transfer = new ToxFileTransfer(m, friend_number, sent_file.file_number, avatar, manager);
		qmlbridge->transfers.push_back(sent_file.transfer);
	} 

	if (avatar && path.isEmpty()) {
		Tools::debug("Removing avatar for friend: " + QString::number(friend_number) + ".");
	}

	return { sent_file, TOX_ERR_SENDING_OK };
}

void cancelAllFileTransfersForFriend(quint32 friend_number)
{
	for (const auto transfer : qmlbridge->transfers) {
		if (transfer->friend_number != friend_number) {
			continue;
		}

		TOX_ERR_FILE_CONTROL err; // we don't care about errors here
		tox_file_control(transfer->tox, transfer->friend_number, transfer->file_number, TOX_FILE_CONTROL_CANCEL, &err);

		if (!transfer->avatar) {
			qmlbridge->getChatDB()->updateFileMessageState(qmlbridge->file_messages[transfer], 
											getFriendPublicKey(transfer->tox, transfer->friend_number), 
											ToxFileState::TOX_FILE_CANCELED);
			qmlbridge->file_messages.remove(transfer);
		}

		delete transfer;
		qmlbridge->transfers.removeOne(transfer);
	}
}

void cancelAllFileTransfers()
{
	while (!qmlbridge->transfers.isEmpty()) {
		ToxFileTransfer *transfer = qmlbridge->transfers.last();

		TOX_ERR_FILE_CONTROL err; // we don't care about errors here
		tox_file_control(transfer->tox, transfer->friend_number, transfer->file_number, TOX_FILE_CONTROL_CANCEL, &err);

		if (!transfer->avatar) {
			qmlbridge->getChatDB()->updateFileMessageState(qmlbridge->file_messages[transfer], 
											getFriendPublicKey(transfer->tox, transfer->friend_number), 
											ToxFileState::TOX_FILE_CANCELED);
			qmlbridge->file_messages.remove(transfer);
		}

		qmlbridge->transfers.removeLast();
		delete transfer;
	}
}

optional<quint64> fileControl(Tox *m, quint32 friend_number, quint32 file_number, quint32 control)
{
	TOX_ERR_FILE_CONTROL err;
	tox_file_control(m, friend_number, file_number, (TOX_FILE_CONTROL)control, &err);

	if (err > 0) {
		Tools::debug("tox_file_control failed with error number: " + QString::number(err));
	} else {
		for (const auto transfer : qmlbridge->transfers) {
			if (transfer->friend_number == friend_number && transfer->file_number == file_number && !transfer->avatar) {
				quint64 unique_id = qmlbridge->file_messages[transfer];

				switch (control) {
					case TOX_FILE_CONTROL_CANCEL: {
						qmlbridge->getChatDB()->updateFileMessageState(unique_id, 
														getFriendPublicKey(m, friend_number), 
														ToxFileState::TOX_FILE_CANCELED);

						qmlbridge->self_canceled_transfers.push_back(ToxSelfCanceledTransfer(friend_number, file_number));

						delete transfer;
						qmlbridge->file_messages.remove(transfer);
						qmlbridge->transfers.removeOne(transfer);

						qmlbridge->cancelFileNotification(friend_number, file_number);
						return unique_id;
					}
					case TOX_FILE_CONTROL_PAUSE: {
						qmlbridge->getChatDB()->updateFileMessageState(unique_id, 
														getFriendPublicKey(m, friend_number), 
														ToxFileState::TOX_FILE_PAUSED);
						return unique_id;
					}
					case TOX_FILE_CONTROL_RESUME: {
						qmlbridge->getChatDB()->updateFileMessageState(unique_id, 
														getFriendPublicKey(m, friend_number), 
														ToxFileState::TOX_FILE_INPROGRESS);
						return unique_id;
					}
				}
			}
		}
	}

	return nullopt;
}

void iterate(Tox *m)
{
	tox_iterate(m, nullptr);
}

AcceptFileResult acceptFile(quint32 friend_number, quint32 file_number)
{
	for (const auto transfer : qmlbridge->transfers) {
		if (transfer->friend_number == friend_number && transfer->file_number == file_number) {
			bool success;
			QMetaObject::invokeMethod(transfer->manager, "onFileTransferStarted", Qt::BlockingQueuedConnection, 
									  Q_RETURN_ARG(bool, success));

			if (success) {
				auto result = fileControl(transfer->tox, transfer->friend_number, transfer->file_number, 
									  TOX_FILE_CONTROL_RESUME);

				if (result) {
					return AcceptFileResult({ TOX_FILE_CONTROL_RESUME, result.value() });
				} else {
					return nullopt;
				}
			} else {
				quint64 unique_id = qmlbridge->file_messages[transfer];

				TOX_ERR_FILE_CONTROL err;
				tox_file_control(transfer->tox, transfer->friend_number, transfer->file_number, 
								 TOX_FILE_CONTROL_CANCEL, &err);

				qmlbridge->getChatDB()->updateFileMessageState(unique_id, 
												getFriendPublicKey(transfer->tox, friend_number), 
												ToxFileState::TOX_FILE_CANCELED);

				delete transfer;
				qmlbridge->file_messages.remove(transfer);
				qmlbridge->transfers.removeOne(transfer);

				return AcceptFileResult({ TOX_FILE_CONTROL_CANCEL, unique_id });
			}
		}
	}

	return nullopt;
}

void sendAvatarToAllFriends(Tox *m, const QString &path)
{
	ToxFriends friends = getFriends(m);
	for (auto &_friend : friends) {
		if (getFriendConnectionStatus(m, _friend) == TOX_CONNECTION_NONE) {
			continue;
		}

		sendFile(m, _friend, path, true);
	}
}

bool checkToxFile(const QString &path)
{
	QFile file(path);

	if (!file.open(QFile::ReadOnly))
		return false;

	QByteArray data = file.read(8);

	const quint8 tox_profile_header[] = { 0x0, 0x0, 0x0, 0x0, 0x1f, 0x1b, 0xed, 0x15 };
	const quint8 tox_profile_header_encrypted[] = { 't', 'o', 'x', 'E', 's', 'a', 'v', 'e' };

	bool test1 = data == QByteArray((char*)tox_profile_header, sizeof(tox_profile_header));
	if (test1) {
		return true;
	}

	bool test2 = data == QByteArray((char*)tox_profile_header_encrypted, sizeof(tox_profile_header_encrypted));
	if (test2) {
		return true;
	}

	return false;
}

}

/*
 * Classes & Structures
*/

void ToxLocalFileManager::onFileChunkReady(void *parent, const QByteArray &data, quint64 position)
{
	ToxFileTransfer *parent_transfer = (ToxFileTransfer*)parent;

	if (qmlbridge->transfers.contains(parent_transfer)) {
		if (parent_transfer->chunks_buffer.empty()) {
			Toxcore::sendFileChunk(parent_transfer->tox, parent_transfer->friend_number, parent_transfer->file_number,
							position, data);
		} else {
			parent_transfer->chunks_buffer.enqueue(ToxFileChunk(position, data));
		}
	}
}

void ToxLocalFileManager::onFileTransferEnded(void *parent)
{
	ToxFileTransfer *parent_transfer = (ToxFileTransfer*)parent;
	Toxcore::fileTransferEnd(parent_transfer->tox, parent_transfer->friend_number, parent_transfer->file_number);
}

ToxIdData::ToxIdData(int size) : QByteArray()
{
	resize(size);
}

QString ToxIdData::toToxString() const
{
	return toHex().toUpper();
}

ToxIdData ToxIdData::fromToxString(const QString &str)
{
	return fromHex(str.toLatin1().toUpper());
}

ToxPk::ToxPk() : ToxIdData(tox_public_key_size()) {}

ToxPk::ToxPk(const ToxIdData &data) : ToxIdData(data) 
{
	if (data.length() > (int)tox_public_key_size()) {
		truncate(tox_public_key_size());
	}
}

ToxPk::ToxPk(const QByteArray &data) : ToxIdData(data) 
{
	if (data.length() > (int)tox_public_key_size()) {
		truncate(tox_public_key_size());
	}
}
