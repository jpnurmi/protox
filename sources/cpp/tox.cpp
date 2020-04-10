#include "tox.h"
#include "main.h"
#include "tools.h"
#include "db.h"

extern QmlCBridge *qmlbridge;
extern ChatDataBase *chat_db;
extern QSettings *settings;

/*
 * Toxcore callbacks
*/

namespace Toxcore {

int current_connection_status = -1;
struct Tox_Options *opts = nullptr;
quint32 available_nodes = 0;

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
			current_connection_status = 0;
			qmlbridge->tryReconnect();
			Tools::debug("Connection to Tox network has been lost.");
			break;

		case TOX_CONNECTION_TCP:
			current_connection_status = 1;
			Tools::debug("Connection to Tox network is weak (using TCP).");
			break;

		case TOX_CONNECTION_UDP:
			current_connection_status = 2;
			Tools::debug("Connection to Tox network is strong (using UDP).");
			break;
	}
	qmlbridge->setConnStatus(current_connection_status);
}

static void cb_friend_request(Tox *m, const quint8 *public_key, const quint8 *data, size_t length, void *userdata)
{
	Q_UNUSED(m)
	Q_UNUSED(userdata);

	ToxPk pk((char*)public_key, TOX_PUBLIC_KEY_SIZE);
	// hint: friend_number is fake here
	qmlbridge->insertFriend(0, ToxConverter::toString(pk), 
							true, QString::fromUtf8((char*)data, length), pk);
}

void cb_friend_read_receipt(Tox *m, quint32 friend_number, quint32 message_id, void *userdata)
{
	Q_UNUSED(m);
	Q_UNUSED(userdata);

	for (int i = 0; i < qmlbridge->pending_messages.count(); i++) {
		if (qmlbridge->pending_messages[i].message_id == message_id && qmlbridge->pending_messages[i].friend_number == friend_number) {
			chat_db->setMessageReceived(qmlbridge->pending_messages[i].unique_id, get_friend_public_key(m, friend_number));
			qmlbridge->pending_messages.removeAt(i);
			break;
		}
	}

	qmlbridge->setMessageReceived(friend_number, message_id);
}

static void cb_friend_message(Tox *m, quint32 friend_number, TOX_MESSAGE_TYPE type, const quint8 *string, size_t length, void *userdata)
{
	Q_UNUSED(userdata);
	if (type != TOX_MESSAGE_TYPE_NORMAL) {
		return;
	}
	char public_key[TOX_PUBLIC_KEY_SIZE];
	TOX_ERR_FRIEND_GET_PUBLIC_KEY err;
	if (!tox_friend_get_public_key(m, friend_number, (quint8 *)public_key, &err)) {
		Tools::debug("tox_friend_get_public_key failed with error number: " + QString::number(err));
		return;
	}
	QString message(QByteArray((char*)string, length));
	ToxPk friend_pk = get_friend_public_key(m, friend_number);
	quint64 new_unique_id = chat_db->getMessagesCountFriend(friend_pk) + 1;
	settings->beginGroup("Privacy");
	bool keep_chat_history = settings->value("keep_chat_history", true).toBool();
	settings->endGroup();
	ToxVariantMessage variantMessage;
	variantMessage.insert("type", ToxVariantMessageType::TOXMSG_TEXT);
	variantMessage.insert("message", message);
	QDateTime dt = QDateTime::currentDateTime();
	if (keep_chat_history) {
		chat_db->insertMessage(variantMessage, dt, friend_pk, false, new_unique_id);
	}
	qmlbridge->insertMessage(variantMessage, friend_number, dt);
}

static void cb_friend_name(Tox *m, quint32 friend_number, const quint8 *name, size_t length, void *user_data)
{
	Q_UNUSED(user_data)
	QString nickName = QString::fromUtf8((char*)name, length);;
	if (nickName.isEmpty()) {
		nickName = ToxConverter::toString(get_friend_public_key(m, friend_number));
	}
	qmlbridge->updateFriendNickName(friend_number, nickName);
}

static void cb_friend_connection_change(Tox *m, quint32 friend_number, TOX_CONNECTION connection_status, void *userdata)
{
	Q_UNUSED(userdata)
	size_t size = tox_self_get_friend_list_size(m);

	if (!size) {
		return;
	}

	qmlbridge->setCurrentFriendConnStatus(friend_number, connection_status);
	qmlbridge->friends_conn_status[friend_number] = connection_status;
}

static void cb_friend_typing(Tox *m, quint32 friend_number, bool is_typing, void *user_data)
{
	Q_UNUSED(m)
	Q_UNUSED(user_data)

	qmlbridge->setFriendTyping(friend_number, is_typing);
}

static void cb_friend_status_message(Tox *m, quint32 friend_number, const quint8 *message, size_t length, void *user_data)
{
	Q_UNUSED(m)
	Q_UNUSED(user_data)

	qmlbridge->setFriendStatusMessage(friend_number, QString::fromUtf8((char*)message, length));
}

static void cb_friend_status(Tox *m, uint32_t friend_number, TOX_USER_STATUS status, void *user_data)
{
	Q_UNUSED(m)
	Q_UNUSED(user_data)

	qmlbridge->setFriendStatus(friend_number, status);
}

/*
 * Toxcore functions
 * 
*/

size_t get_friends_count(Tox *m)
{
	return tox_self_get_friend_list_size(m);
}

ToxFriends get_friends(Tox *m)
{
	ToxFriends friends_list;
	size_t count = get_friends_count(m);
	quint32 friends[count];
	tox_self_get_friend_list(m, friends);
	for (size_t i = 0; i < count; i++) {
		friends_list.push_front(friends[i]);
	}
	return friends_list;
}

ToxPk get_friend_public_key(Tox *m, quint32 friend_number)
{
	char public_key[TOX_PUBLIC_KEY_SIZE];
	if(tox_friend_get_public_key(m, friend_number, (quint8*)public_key, nullptr))
		return ToxPk(public_key, TOX_PUBLIC_KEY_SIZE);

	return ToxPk();
}

const QString get_friend_status_message(Tox *m, quint32 friend_number)
{
	TOX_ERR_FRIEND_QUERY query_error;
	size_t length = tox_friend_get_status_message_size(m, friend_number, &query_error);
	if (!length || query_error > 0)
		return QString();

	char message[length];
	tox_friend_get_status_message(m, friend_number, (quint8*)message, nullptr);
	return QString::fromUtf8(message, length);
}

const QString get_friend_name(Tox *m, quint32 friend_number)
{
	size_t length = tox_friend_get_name_size(m, friend_number, nullptr);
	if (!length)
		return ToxConverter::toString(get_friend_public_key(m, friend_number));
	char name[length];
	if (tox_friend_get_name(m, friend_number, (quint8*)name, nullptr)) {
		return QString::fromUtf8(name, length);
	} else {
		return QString();
	}
}

quint32 get_status(Tox *m)
{
	return tox_self_get_status(m);
}

void set_status(Tox *m, quint32 status)
{
	tox_self_set_status(m, (TOX_USER_STATUS)status);
}

quint32 send_message(Tox *m, quint32 friend_number, const QString &message, bool &failed)
{
	TOX_ERR_FRIEND_SEND_MESSAGE err;
	QByteArray encodedMessage = message.toUtf8();
	quint32 message_id = tox_friend_send_message(m, friend_number, TOX_MESSAGE_TYPE_NORMAL, (quint8*)encodedMessage.data(), encodedMessage.size(), &err);
	if (err > 0) {
		failed = true;
		Tools::debug("tox_friend_send_message failed with error number: " + QString::number(err));
	} else {
		failed = false;
	}
	return message_id;
}

int make_friend_request(Tox *m, ToxId id, const QString &friendMessage)
{
	TOX_ERR_FRIEND_ADD error;
	QByteArray msgData(friendMessage.toUtf8());
	quint32 friend_number = tox_friend_add(m, (quint8*)id.data(), (quint8*)msgData.data(), msgData.length(), &error);
	if (!error) {
		qmlbridge->insertFriend(friend_number, ToxConverter::toString(get_friend_public_key(m, friend_number)));
	}
	return error;
}

quint32 add_friend(Tox *m, const ToxPk &friendPk, int *error)
{
	quint32 friend_number = tox_friend_add_norequest(m, (quint8*)friendPk.data(), (TOX_ERR_FRIEND_ADD*)error);
	return friend_number;
}

void delete_friend(Tox *m, quint32 friend_number)
{
	tox_friend_delete(m, friend_number, nullptr);
}

void set_typing_friend(Tox *m, quint32 friend_number, bool typing)
{
	tox_self_set_typing(m, friend_number, typing, nullptr);
}

const QString get_nickname(Tox *m, bool toxId)
{
	size_t length = tox_self_get_name_size(m);
	if (!length) {
		return toxId ? ToxConverter::toString(get_address(m)) : QString();
	}
	char name[length];
	tox_self_get_name(m, (quint8*)name);
	QString nickname = QString::fromUtf8(name, length);

	return nickname;
}

void set_nickname(Tox *m, const QString &nickname)
{
	QByteArray encodedNickname = nickname.toUtf8();
	tox_self_set_name(m, (quint8*)encodedNickname.data(), encodedNickname.length(), nullptr);
}

int get_friend_status(Tox *m, quint32 friend_number)
{
	TOX_ERR_FRIEND_QUERY error;
	int result = tox_friend_get_status(m, friend_number, &error);
	if (!error) {
		return result;
	}
	return -1;
}

const QString get_status_message(Tox *m)
{
	size_t length = tox_self_get_status_message_size(m);
	if (!length)
		return QString();
	char name[length];
	tox_self_get_status_message(m, (quint8*)name);
	return QString::fromUtf8(name, length);
}

void set_status_message(Tox *m, const QString &statusMessage)
{
	QByteArray encodedMessage = statusMessage.toUtf8();
	tox_self_set_status_message(m, (quint8*)encodedMessage.data(), encodedMessage.length(), nullptr);
}

/*
 * Basic Functions 
*/

int get_connection_status()
{
	return current_connection_status;
}

bool save_data(Tox *m, const QString &path)
{
	qmlbridge->updateToxPasswordKey();
	if (path.isEmpty()) {
		Tools::debug("Warning: save_data failed: path is empty.");
		return false;
	}

	QFile file(path);
	if (!file.open(QIODevice::WriteOnly))
		return false;

	size_t data_len = tox_get_savedata_size(m);
	quint8 data[data_len];
	tox_get_savedata(m, data);

	quint8 encryptedData[data_len + TOX_PASS_ENCRYPTION_EXTRA_LENGTH];
	const Tox_Pass_Key *pass_key = qmlbridge->getToxPasswordKey();
	if (pass_key) {
		if(!tox_pass_key_encrypt(pass_key, data, data_len,
								 encryptedData, nullptr)) {
			return false;
		}
	}

	int result;
	if (pass_key) {
		result = file.write((char*)encryptedData, data_len + TOX_PASS_ENCRYPTION_EXTRA_LENGTH);
	} else {
		result = file.write((char*)data, data_len);
	}

	if (result == -1) {
		file.close();
		Tools::debug("Warning: save_data failed: write failed.");
		return false;
	}

	file.close();
	return true;
}

static Tox *load_tox(struct Tox_Options *options, const QString &path, ToxProfileLoadingError &error)
{
	QFile file(path);
	Tox *m = nullptr;

	if (!file.open(QIODevice::ReadOnly)) {
		TOX_ERR_NEW err;
		m = tox_new(options, &err);

		if (err != TOX_ERR_NEW_OK) {
			Tools::debug("tox_new failed with error number: " + QString::number(err));
			error = TOX_ERR_LOADING_NULL;
			return nullptr;
		}

		save_data(m, path);
		error = TOX_ERR_LOADING_OK;
		return m;
	}

	quint64 data_len = file.size();

	if (data_len == 0) {
		file.close();
		error = TOX_ERR_LOADING_NULL;
		return nullptr;
	}

	char data[data_len];
	if (file.read(data, data_len) == -1) {
		file.close();
		error = TOX_ERR_LOADING_NULL;
		return nullptr;
	}
	file.close();

	quint8 decrypted_data[data_len - TOX_PASS_ENCRYPTION_EXTRA_LENGTH];
	QByteArray encodedPassword = qmlbridge->getProfilePassword().toUtf8();
	bool encrypted = tox_is_data_encrypted((quint8*)data);
	if (encrypted) {
		if (!qmlbridge->getProfilePassword().isEmpty()) {
			if (!tox_pass_decrypt((quint8*)data, data_len, 
								  (quint8*)encodedPassword.data(), encodedPassword.length(), 
								  decrypted_data, nullptr)) {
				error = TOX_ERR_LOADING_WRONG_PASSWORD;
				return nullptr;
			}
		} else {
			error = TOX_ERR_LOADING_EMPTY_PASSWORD;
			return nullptr;
		}
	}

	TOX_ERR_NEW err;
	options->savedata_type = TOX_SAVEDATA_TYPE_TOX_SAVE;
	if (encrypted) {
		options->savedata_data = decrypted_data;
		options->savedata_length = data_len - TOX_PASS_ENCRYPTION_EXTRA_LENGTH;
	} else {
		options->savedata_data = (quint8*)data;
		options->savedata_length = data_len;
	}

	m = tox_new(options, &err);

	if (err != TOX_ERR_NEW_OK) {
		Tools::debug("tox_new failed with error number: " + QString::number(err));
		error = TOX_ERR_LOADING_NULL;
		return nullptr;
	}

	error = TOX_ERR_LOADING_OK;
	return m;
}

quint32 get_nospam(Tox *m) 
{
	return tox_self_get_nospam(m);
}

void set_nospam(Tox *m, quint32 nospam)
{
	tox_self_set_nospam(m, nospam);
}

const QString default_nodes_json = "{\"last_scan\":1581207188,\"last_refresh\":1581207129,\"nodes\":[{\"ipv4\":\"85.172.30.117\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"8E7D0B859922EF569298B4D261A8CCB5FEA14FB91ED412A7603A585A25698832\",\"maintainer\":\"ray65536\",\"location\":\"RU\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"Ray's Tox Node. TOX ID:3C3D6DB24D24754393679E59F198EF45EE26835AEF7EA3E3ECEA40E204F2B828BE86DF012ABF\",\"last_ping\":1581207190},{\"ipv4\":\"85.143.221.42\",\"ipv6\":\"2a04:ac00:1:9f00:5054:ff:fe01:becd\",\"port\":33445,\"tcp_ports\":[33445,3389],\"public_key\":\"DA4E4ED4B697F2E9B000EEFE3A34B554ACD3F45F5C96EAEA2516DD7FF9AF7B43\",\"maintainer\":\"MAH69K\",\"location\":\"RU\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002009\",\"motd\":\"Saluton! Mia Tox ID: B229B7BD68FC66C2716EAB8671A461906321C764782D7B3EDBB650A315F6C458EF744CE89F07. Scribu! ;)\",\"last_ping\":1581207188},{\"ipv4\":\"tox.verdict.gg\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"1C5293AEF2114717547B39DA8EA6F1E331E5E358B35F9B6B5F19317911C5F976\",\"maintainer\":\"Deliran\",\"location\":\"DE\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002008\",\"motd\":\"Praise The Sun!\",\"last_ping\":1581207188},{\"ipv4\":\"78.46.73.141\",\"ipv6\":\"2a01:4f8:120:4091::3\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"02807CF4F8BB8FB390CC3794BDF1E8449E9A8392C5D3F2200019DA9F1E812E46\",\"maintainer\":\"Sorunome\",\"location\":\"DE\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002008\",\"motd\":\"Keep calm and pony on!\",\"last_ping\":1581207188},{\"ipv4\":\"46.229.52.198\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"813C8F4187833EF0655B10F7752141A352248462A567529A38B6BBF73E979307\",\"maintainer\":\"Stranger\",\"location\":\"UA\",\"status_udp\":true,\"status_tcp\":false,\"version\":\"1000002008\",\"motd\":\"Freedom to parrots!\",\"last_ping\":1581207188},{\"ipv4\":\"144.217.167.73\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445,3389],\"public_key\":\"7E5668E0EE09E19F320AD47902419331FFEE147BB3606769CFBE921A2A2FD34C\",\"maintainer\":\"velusip\",\"location\":\"CA\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"Jera\",\"last_ping\":1581207188},{\"ipv4\":\"tox.abilinski.com\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"10C00EB250C3233E343E2AEBA07115A5C28920E9C8D29492F6D00B29049EDC7E\",\"maintainer\":\"AnthonyBilinski\",\"location\":\"CA\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"Running https://github.com/toktok/c-toxcore v0.2.10. qTox best Tox! Contact: AC18841E56CCDEE16E93E10E6AB2765BE54277D67F1372921B5B418A6B330D3D3FAFA60B0931\",\"last_ping\":1581207188},{\"ipv4\":\"37.48.122.22\",\"ipv6\":\"2001:1af8:4700:a115:6::b\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"1B5A8AB25FFFB66620A531C4646B47F0F32B74C547B30AF8BD8266CA50A3AB59\",\"maintainer\":\"Pokemon\",\"location\":\"NL\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002009\",\"motd\":\"Those who would give up essential Liberty, to purchase a little temporary Safety, deserve neither Liberty nor Safety\",\"last_ping\":1581207188},{\"ipv4\":\"tox.novg.net\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"D527E5847F8330D628DAB1814F0A422F6DC9D0A300E6C357634EE2DA88C35463\",\"maintainer\":\"blind_oracle\",\"location\":\"NL\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1581207190},{\"ipv4\":\"95.31.18.227\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"257744DBF57BE3E117FE05D145B5F806089428D4DCE4E3D0D50616AA16D9417E\",\"maintainer\":\"ky0uraku\",\"location\":\"RU\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002008\",\"motd\":\"Vive le TOX\",\"last_ping\":1581207190},{\"ipv4\":\"198.199.98.108\",\"ipv6\":\"2604:a880:1:20::32f:1001\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"BEF0CFB37AF874BD17B9A8F9FE64C75521DB95A37D33C5BDB00E9CF58659C04F\",\"maintainer\":\"Cody\",\"location\":\"US\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002008\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1581207188},{\"ipv4\":\"tox.kurnevsky.net\",\"ipv6\":\"tox.kurnevsky.net\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"82EF82BA33445A1F91A7DB27189ECFC0C013E06E3DA71F588ED692BED625EC23\",\"maintainer\":\"kurnevsky\",\"location\":\"NL\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"3000000008\",\"motd\":\"Hi from tox-rs! I'm up 01 days 16 hours 19 minutes.\",\"last_ping\":1581207190},{\"ipv4\":\"87.118.126.207\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"0D303B1778CA102035DA01334E7B1855A45C3EFBC9A83B9D916FFDEBC6DD3B2E\",\"maintainer\":\"quux\",\"location\":\"DE\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"Make Orwell Fiction Again\",\"last_ping\":1581207188},{\"ipv4\":\"81.169.136.229\",\"ipv6\":\"2a01:238:4254:2a00:7aca:fe8c:68e0:27ec\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"E0DB78116AC6500398DDBA2AEEF3220BB116384CAB714C5D1FCD61EA2B69D75E\",\"maintainer\":\"9ofSpades\",\"location\":\"DE\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"🂩 wishes happy toxing. 📡\",\"last_ping\":1581207190},{\"ipv4\":\"205.185.115.131\",\"ipv6\":\"-\",\"port\":53,\"tcp_ports\":[53,3389,443,33445],\"public_key\":\"3091C6BEB2A993F1C6300C16549FABA67098FF3D62C6D253828B531470B53D68\",\"maintainer\":\"GDR!\",\"location\":\"US\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"https://gdr.name/tuntox/\",\"last_ping\":1581207188},{\"ipv4\":\"tox2.abilinski.com\",\"ipv6\":\"tox2.abilinski.com\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"7A6098B590BDC73F9723FC59F82B3F9085A64D1B213AAF8E610FD351930D052D\",\"maintainer\":\"AnthonyBilinski\",\"location\":\"US\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"Running https://github.com/toktok/c-toxcore v0.2.10. qTox best Tox! Contact: AC18841E56CCDEE16E93E10E6AB2765BE54277D67F1372921B5B418A6B330D3D3FAFA60B0931\",\"last_ping\":1581207188},{\"ipv4\":\"floki.blog\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"6C6AF2236F478F8305969CCFC7A7B67C6383558FF87716D38D55906E08E72667\",\"maintainer\":\"Floki\",\"location\":\"GB\",\"status_udp\":true,\"status_tcp\":false,\"version\":\"1000002010\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1581207188},{\"ipv4\":\"51.158.146.76\",\"ipv6\":\"2001:bc8:6010:213:208:a2ff:fe0c:7fee\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"E940D8FA9B07C1D13EA4ECF9F06B66F565F1CF61F094F60C67FDC8ADD3F4BA59\",\"maintainer\":\"CyberSquirrel\",\"location\":\"NL\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002009\",\"motd\":\"CyberSquirrel TOX node. Contacts - toxnode@cock.li\",\"last_ping\":1581207190},{\"ipv4\":\"194.36.190.71\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"B62F1878BD08EDD34E4D7B0D66F9E74CC7BDE4BEA2C95E130DAADCFF9BCB4F6D\",\"maintainer\":\"Shilov\",\"location\":\"NL\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1581207188},{\"ipv4\":\"94.45.70.19\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"CE049A748EB31F0377F94427E8E3D219FC96509D4F9D16E181E956BC5B1C4564\",\"maintainer\":\"Shilov\",\"location\":\"UA\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"3000000008\",\"motd\":\"{{Welcome to Ukraine!}} 10 days 04 hours 56 minutes Tcp: incoming 49.9M, outgoing 39.7M, Udp: incoming 116.9M, outgoing 123.5M\",\"last_ping\":1581207188},{\"ipv4\":\"185.66.13.169\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[33445],\"public_key\":\"A44A024DA1299A85B91E3A64B9D19C7F331D0073DD2FAAF1361C127B5D909E3D\",\"maintainer\":\"Shilov\",\"location\":\"RU\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"3000000008\",\"motd\":\"{Elektrostal{start_date}} 10 days 06 hours 06 minutes Tcp: incoming 24.7M, outgoing 19.9M, Udp: incoming 175.7M, outgoing 177.7M\",\"last_ping\":1581207188},{\"ipv4\":\"46.101.197.175\",\"ipv6\":\"2a03:b0c0:3:d0::ac:5001\",\"port\":33445,\"tcp_ports\":[3389,33445],\"public_key\":\"CD133B521159541FB1D326DE9850F5E56A6C724B5B8E5EB5CD8D950408E95707\",\"maintainer\":\"kotelnik\",\"location\":\"DE\",\"status_udp\":true,\"status_tcp\":true,\"version\":\"1000002010\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1581207188},{\"ipv4\":\"tox.initramfs.io\",\"ipv6\":\"tox.initramfs.io\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"3F0A45A268367C1BEA652F258C85F4A66DA76BCAA667A49E770BCC4917AB6A25\",\"maintainer\":\"initramfs\",\"location\":\"TW\",\"status_udp\":false,\"status_tcp\":false,\"version\":\"1000002010\",\"motd\":\"initramfs' Tox DHT Node\",\"last_ping\":1581194588},{\"ipv4\":\"tox.neuland.technology\",\"ipv6\":\"tox.neuland.technology\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"15E9C309CFCB79FDDF0EBA057DABB49FE15F3803B1BFF06536AE2E5BA5E4690E\",\"maintainer\":\"Nolz\",\"location\":\"DE\",\"status_udp\":false,\"status_tcp\":false,\"version\":\"1000002008\",\"motd\":\"Unlike Others\",\"last_ping\":1580033828},{\"ipv4\":\"185.14.30.213\",\"ipv6\":\"2a00:1ca8:a7::e8b\",\"port\":443,\"tcp_ports\":[],\"public_key\":\"2555763C8C460495B14157D234DD56B86300A2395554BCAE4621AC345B8C1B1B\",\"maintainer\":\"dvor\",\"location\":\"NL\",\"status_udp\":false,\"status_tcp\":false,\"version\":\"1000002008\",\"motd\":\"Just another tox node.\",\"last_ping\":1579652108},{\"ipv4\":\"109.111.178.181\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"25890C0139ECF9F217C72058D9E43E8873F6755D24374525623944915C98A903\",\"maintainer\":\"LivingstoneI2P\",\"location\":\"RU\",\"status_udp\":false,\"status_tcp\":false,\"version\":\"\",\"motd\":\"\",\"last_ping\":1580906888},{\"ipv4\":\"218.28.170.22\",\"ipv6\":\"-\",\"port\":33445,\"tcp_ports\":[],\"public_key\":\"DBACB7D3F53693498398E6B46EF0C063A4656EB02FEFA11D72A60BAFA8DF7B59\",\"maintainer\":\"OnionBulb\",\"location\":\"CN\",\"status_udp\":false,\"status_tcp\":false,\"version\":\"1000002010\",\"motd\":\"tox-bootstrapd\",\"last_ping\":1579642990}]}";

void bootstrap_DHT(Tox *m)
{
	settings->beginGroup("Toxcore");
	QString json_file = settings->value("nodes_json_file", "").toString();
	bool use_ipv6 = settings->value("ipv6_enabled", true).toBool();
	uint32_t max_bootstrap_nodes = settings->value("max_bootstrap_nodes", 6).toUInt();
	settings->endGroup();
	QByteArray json_data;
	if (!json_file.isEmpty()) {
		QFile file(Tools::getProgDir() + json_file);
		if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
			json_data = file.readAll();
			file.close();
		}
	}
	QJsonDocument doc = QJsonDocument::fromJson(json_data.isEmpty() ? default_nodes_json.toUtf8() : json_data);
	QJsonArray array = doc.object()["nodes"].toArray();
	available_nodes = array.count();

	uint32_t succeed = 0;
	for (auto node : array) {
		QJsonObject item = node.toObject();
		QString ipv4 = item["ipv4"].toString();
		QString ipv6 = item["ipv6"].toString();
		int port = item["port"].toInt();
		QString public_key = item["public_key"].toString();

		TOX_ERR_BOOTSTRAP err, err2;
		tox_bootstrap(m, ipv4.toStdString().c_str(), (quint16)port, (quint8*)public_key.toStdString().c_str(), &err);
		if (use_ipv6 && ipv6 != "-") {
			tox_bootstrap(m, ipv6.toStdString().c_str(), (quint16)port, (quint8*)public_key.toStdString().c_str(), &err2);
		}

		if (err == TOX_ERR_BOOTSTRAP_OK || err2 == TOX_ERR_BOOTSTRAP_OK) {
			succeed++;
		}
		if (succeed == max_bootstrap_nodes) {
			return;
		}
	}
}

struct Tox_Options *get_opts()
{
	TOX_ERR_OPTIONS_NEW err;
	struct Tox_Options *opts = tox_options_new(&err);
	if (err > 0) {
		Tools::debug("tox_options_new failed with error number: " + QString::number(err));
		return nullptr;
	}
	memset(opts, 0, sizeof(struct Tox_Options));
	tox_options_default(opts);
	opts->log_callback = cb_log;
	settings->beginGroup("Toxcore");
	opts->udp_enabled = settings->value("udp_enabled", true).toBool();
	opts->ipv6_enabled = settings->value("ipv6_enabled", true).toBool();
	opts->local_discovery_enabled = settings->value("local_discovery_enabled", false).toBool();
	settings->endGroup();
	return opts;
}

Tox *create(ToxProfileLoadingError &error, bool create_new)
{
	QFile f(Tools::getProgDir() + qmlbridge->getCurrentProfile());
	bool clean = !f.exists();
	if (!create_new && clean) {
		error = TOX_ERR_LOADING_NOT_EXISTS;
		return nullptr;
	}
	if (create_new && !clean) {
		error = TOX_ERR_LOADING_ALREADY_EXISTS;
		return nullptr;
	}

	opts = get_opts();
	Tox *m = load_tox(opts, Tools::getProgDir() + qmlbridge->getCurrentProfile(), error);

	if (!m) {
		// error is set inside load_tox
		return nullptr;
	}

	tox_callback_self_connection_status(m, cb_self_connection_change);
	tox_callback_friend_connection_status(m, cb_friend_connection_change);
	tox_callback_friend_request(m, cb_friend_request);
	tox_callback_friend_message(m, cb_friend_message);
	tox_callback_friend_name(m, cb_friend_name);
	tox_callback_friend_read_receipt(m, cb_friend_read_receipt);
	tox_callback_friend_typing(m, cb_friend_typing);
	tox_callback_friend_status_message(m, cb_friend_status_message);
	tox_callback_friend_status(m, cb_friend_status);

	size_t s_len = tox_self_get_status_message_size(m);

	if (!s_len && clean) {
		const char *statusmsg = "Protox is here!";
		tox_self_set_status_message(m, (quint8*)statusmsg, strlen(statusmsg), NULL);
	}

	size_t n_len = tox_self_get_name_size(m);

	const char *username = "Protox";
	if (!n_len && clean) {
		tox_self_set_name(m, (quint8*)username, strlen(username), NULL);
	}

	save_data(m, Tools::getProgDir() + qmlbridge->getCurrentProfile());
	error = TOX_ERR_LOADING_OK;
	return m;
}

bool check_profile_encrypted(const QString &profile)
{
	QFile f(Tools::getProgDir() + profile);
	if (!f.open(QIODevice::ReadOnly)) {
		return false;
	}
	bool encrypted = tox_is_data_encrypted((quint8*)f.readAll().data());
	f.close();
	return encrypted;
}

QTimer *create_qtimer(Tox *m)
{
	QTimer *timer = new QTimer;
	QObject::connect(timer, &QTimer::timeout, [=]() { tox_iterate(m, nullptr); });
	timer->setSingleShot(false);
	timer->setInterval(tox_iteration_interval(m));
	return timer;
}

ToxId get_address(Tox *m)
{
	char address[get_tox_address_size()];
	tox_self_get_address(m, (quint8*)address);
	return ToxId(address, get_tox_address_size());
}

void destroy(Tox *m)
{
	save_data(m, Tools::getProgDir() + qmlbridge->getCurrentProfile());
	tox_kill(m);
	tox_options_free(opts);
}

void reset_pass_key(Tox_Pass_Key *key)
{
	tox_pass_key_free(key);
}

Tox_Pass_Key *generate_pass_key(const QString &password)
{
	if (password.isEmpty()) {
		return nullptr;
	}
	QByteArray encodedPassword = password.toUtf8();
	return tox_pass_key_derive((quint8*)encodedPassword.data(), encodedPassword.length(), nullptr);
}

const QString get_version_string()
{
	return QString::number(tox_version_major()) + "." + QString::number(tox_version_minor()) + "." + QString::number(tox_version_patch());
}

quint32 get_available_nodes()
{
	return available_nodes;
}

quint32 get_message_max_length()
{
	return tox_max_message_length();
}

quint32 get_friend_request_message_max_length()
{
	return tox_max_friend_request_length();
}

quint32 get_nickname_max_length() 
{
	return tox_max_name_length();
}

quint32 get_status_message_max_length()
{
	return tox_max_status_message_length();
}

quint32 get_tox_address_size()
{
	return tox_address_size();
}

}

/*
 * String <-> ToxId converter
*/

namespace ToxConverter {
	const ToxId toToxId(const QString &str)
	{
		return ToxId::fromHex(str.toLatin1().toUpper());
	}
	const QString toString(const ToxId &user_id)
	{
		return QString(user_id.toHex().toUpper());
	}
}