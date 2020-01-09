#include "tox.h"
#include "main.h"
#include "tools.h"
#include "db.h"

#define DEFAULT_PROFILE "profile.tox"

extern QPointer <QmlCBridge> qmlbridge;
extern QPointer <ChatDataBase> chat_db;

/*
 * Toxcore callbacks
*/

static void toxcore_cb_self_connection_change(Tox *m, TOX_CONNECTION connection_status, void *userdata)
{
	Q_UNUSED(m);
	Q_UNUSED(userdata);
	switch (connection_status) {
		case TOX_CONNECTION_NONE:
			Debug("Connection to Tox network has been lost.");
			break;

		case TOX_CONNECTION_TCP:
			Debug("Connection to Tox network is weak (using TCP).");
			break;

		case TOX_CONNECTION_UDP:
			Debug("Connection to Tox network is strong (using UDP).");
			break;
	}
}

static void toxcore_cb_friend_request(Tox *m, const uint8_t *public_key, const uint8_t *data, size_t length, void *userdata)
{
	Q_UNUSED(data);
	Q_UNUSED(length);
	Q_UNUSED(userdata);
	TOX_ERR_FRIEND_ADD err;
	quint32 friend_number = tox_friend_add_norequest(m, public_key, &err);

	if (err != TOX_ERR_FRIEND_ADD_OK) {
		Debug("tox_friend_add_norequest failed (error " + QString::number(err) + ")");
		return;
	}

	toxcore_save_data(m, GetProgDir() + DEFAULT_PROFILE);
	qmlbridge->insertFriend(friend_number, toxcore_get_friend_name(m, friend_number));
}

void toxcore_cb_friend_read_receipt(Tox *m, uint32_t friend_number, uint32_t message_id, void *userdata)
{
	Q_UNUSED(m);
	Q_UNUSED(userdata);
	// insert to db here
	if (qmlbridge->getCurrentFriendNumber() != friend_number)
		return;
	chat_db->setMessageReceived(qmlbridge->messages_id_uid[message_id], toxcore_get_friend_public_key(m, friend_number));
	qmlbridge->setMessageReceived(friend_number, message_id);
}

static void toxcore_cb_friend_message(Tox *m, quint32 friend_number, TOX_MESSAGE_TYPE type, const uint8_t *string, size_t length, void *userdata)
{
	Q_UNUSED(userdata);
	if (type != TOX_MESSAGE_TYPE_NORMAL) {
		return;
	}

	char public_key[TOX_PUBLIC_KEY_SIZE];

	if (!tox_friend_get_public_key(m, friend_number, (uint8_t *)public_key, NULL)) {
		return;
	}

	QString message(QByteArray((char*)string, length));
	chat_db->insertMessage(message, QDateTime::currentDateTime(), toxcore_get_friend_public_key(m, friend_number));
	qmlbridge->insertMessage(message, friend_number);
}

static void toxcore_cb_friend_name(Tox *m, uint32_t friend_number, const uint8_t *name, size_t length, void *user_data)
{
	Q_UNUSED(user_data)
	QString nickName = QString::fromUtf8((char*)name, length);;
	if (nickName.isEmpty()) {
		nickName = ToxId_To_QString(toxcore_get_friend_public_key(m, friend_number));
	}
	qmlbridge->updateFriendNickName(friend_number, nickName);
}

static void toxcore_cb_friend_connection_change(Tox *m, uint32_t friend_number, TOX_CONNECTION connection_status, void *userdata)
{
	Q_UNUSED(userdata)
	size_t size = tox_self_get_friend_list_size(m);

	if (!size) {
		return;
	}

	qmlbridge->setCurrentFriendConnStatus(friend_number, connection_status);
	qmlbridge->friends_conn_status[friend_number] = connection_status;
}

/*
 * Toxcore functions
 * 
*/

size_t toxcore_get_friends_count(Tox *m)
{
	return tox_self_get_friend_list_size(m);
}

ToxFriends toxcore_get_friends(Tox *m)
{
	ToxFriends friends_list;
	size_t count = toxcore_get_friends_count(m);
	quint32 friends[count];
	tox_self_get_friend_list(m, friends);
	for (size_t i = 0; i < count; i++) {
		friends_list.push_front(friends[i]);
	}
	return friends_list;
}

ToxPk toxcore_get_friend_public_key(Tox *m, quint32 friend_number)
{
	char public_key[TOX_PUBLIC_KEY_SIZE];
	if(tox_friend_get_public_key(m, friend_number, (uint8_t*)public_key, nullptr))
		return ToxPk(public_key, TOX_PUBLIC_KEY_SIZE);

	return ToxPk();
}

const QString toxcore_get_friend_name(Tox *m, quint32 friend_number)
{
	size_t length = tox_friend_get_name_size(m, friend_number, nullptr);
	if (!length)
		return QString();
	char name[length];
	if (tox_friend_get_name(m, friend_number, (uint8_t*)name, nullptr)) {
		return QString::fromUtf8(name, length);
	} else {
		return QString();
	}
}

quint32 toxcore_send_message(Tox *m, quint32 friend_number, const QString message, bool &failed)
{
	TOX_ERR_FRIEND_SEND_MESSAGE error;
	QByteArray encodedMessage = message.toUtf8();
	quint32 message_id = tox_friend_send_message(m, friend_number, TOX_MESSAGE_TYPE_NORMAL, (uint8_t*)encodedMessage.data(), encodedMessage.size(), &error);
	switch (error) {
	case TOX_ERR_FRIEND_SEND_MESSAGE_OK:
		failed = false;
		break;
	case TOX_ERR_FRIEND_SEND_MESSAGE_FRIEND_NOT_CONNECTED:
		failed = true;
		break;
	default:
		break;
	}
	return message_id;
}

int toxcore_make_friend_request(Tox *m, ToxId id, const QString friendMessage)
{
	TOX_ERR_FRIEND_ADD error;
	QByteArray msgData(friendMessage.toUtf8());
	quint32 friend_number = tox_friend_add(m, (uint8_t*)id.data(), (uint8_t*)msgData.data(), msgData.length(), &error);
	if (!error) {
		qmlbridge->insertFriend(friend_number, ToxId_To_QString(toxcore_get_friend_public_key(m, friend_number)));
	}
	return error;
}

void toxcore_delete_friend(Tox *m, quint32 friend_number)
{
	tox_friend_delete(m, friend_number, nullptr);
}

bool toxcore_save_data(Tox *m, const QString path)
{
	if (path.isEmpty()) {
		Debug("Warning: save_data failed: path is empty.");
		return false;
	}

	QFile file(path);
	if (!file.open(QFile::OpenModeFlag::WriteOnly))
		return false;

	size_t data_len = tox_get_savedata_size(m);
	char *data = (char*)malloc(data_len);
	tox_get_savedata(m, (uint8_t*)data);

	if (file.write(data, data_len) == -1) {
		free(data);
		file.close();
		Debug("Warning: save_data failed: write failed.");
		return false;
	}

	free(data);
	file.close();
	return true;
}

static Tox *toxcore_load_tox(struct Tox_Options *options, QString path)
{
	QFile file(path);
	Tox *m = NULL;

	if (!file.open(QFile::OpenModeFlag::ReadOnly)) {
		TOX_ERR_NEW err;
		m = tox_new(options, &err);

		if (err != TOX_ERR_NEW_OK) {
			Debug("tox_new failed with error number: " + QString::number(err));
			return nullptr;
		}

		toxcore_save_data(m, path);
		return m;
	}

	QFile test(path);
	size_t data_len = test.size();

	if (data_len == 0) {
		file.close();
		return nullptr;
	}

	char data[data_len];

	if (file.read(data, data_len) == -1) {
		file.close();
		return nullptr;
	}

	TOX_ERR_NEW err;
	options->savedata_type = TOX_SAVEDATA_TYPE_TOX_SAVE;
	options->savedata_data = (uint8_t*)data;
	options->savedata_length = data_len;

	m = tox_new(options, &err);

	if (err != TOX_ERR_NEW_OK) {
		Debug("tox_new failed with error number: " + QString::number(err));
		return nullptr;
	}

	file.close();
	return m;
}


/* TODO: hardcoding is bad stop being lazy */
static struct toxNodes {
	const char *ip;
	uint16_t	port;
	const char *key;
} nodes[] = {
	{ "45.59.119.218", 33445, "0FB96EEBFB1650DDB52E70CF773DDFCABE25A95CC3BB50FC251082E4B63EF82A"},
	{ "92.54.84.70", 33445, "5625A62618CB4FCA70E147A71B29695F38CC65FF0CBD68AD46254585BE564802"},
	{ "163.172.136.118", 33445, "2C289F9F37C20D09DA83565588BF496FAB3764853FA38141817A72E3F18ACA0B"},
	{ "136.243.141.187", 443,   "6EE1FADE9F55CC7938234CC07C864081FC606D8FE7B751EDA217F268F1078A39"},
	{ "37.48.122.22", 5228,  "1B5A8AB25FFFB66620A531C4646B47F0F32B74C547B30AF8BD8266CA50A3AB59"},
	{ "185.25.116.107", 33445, "DA4E4ED4B697F2E9B000EEFE3A34B554ACD3F45F5C96EAEA2516DD7FF9AF7B43"},
	{ "79.140.30.52", 33445, "FFAC871E85B1E1487F87AE7C76726AE0E60318A85F6A1669E04C47EB8DC7C72D"},
	{ "46.101.197.175", 443,   "CD133B521159541FB1D326DE9850F5E56A6C724B5B8E5EB5CD8D950408E95707"},
	{ NULL, 0, NULL },
};

void toxcore_bootstrap_DHT(Tox *m)
{
	int i;

	for (i = 0; nodes[i].ip; ++i) {
		char *key = String_To_ToxPk(nodes[i].key);

		TOX_ERR_BOOTSTRAP err;
		tox_bootstrap(m, nodes[i].ip, nodes[i].port, (uint8_t*)key, &err);
		free(key);

		if (err != TOX_ERR_BOOTSTRAP_OK) {
			Debug("Failed to bootstrap DHT via: " + QString(nodes[i].ip) + " " + QString::number(nodes[i].port) + " (error number: " + QString::number(err) + ")");
		}
	}
}

Tox *toxcore_create(void)
{
	struct Tox_Options tox_opts;
	memset(&tox_opts, 0, sizeof(struct Tox_Options));
	tox_options_default(&tox_opts);

	Tox *m = toxcore_load_tox(&tox_opts, GetProgDir() + DEFAULT_PROFILE);

	if (!m) {
		return NULL;
	}

	tox_callback_self_connection_status(m, toxcore_cb_self_connection_change);
	tox_callback_friend_connection_status(m, toxcore_cb_friend_connection_change);
	tox_callback_friend_request(m, toxcore_cb_friend_request);
	tox_callback_friend_message(m, toxcore_cb_friend_message);
	tox_callback_friend_name(m, toxcore_cb_friend_name);
	//tox_callback_conference_invite(m, cb_group_invite);
	//tox_callback_conference_title(m, cb_group_titlechange);
	tox_callback_friend_read_receipt(m, toxcore_cb_friend_read_receipt);

	size_t s_len = tox_self_get_status_message_size(m);

	if (!s_len) {
		const char *statusmsg = "Protox is here!";
		tox_self_set_status_message(m, (uint8_t *)statusmsg, strlen(statusmsg), NULL);
	}

	size_t n_len = tox_self_get_name_size(m);

	const char *username = "Protox";
	if (!n_len) {
		tox_self_set_name(m, (uint8_t *)username, strlen(username), NULL);
	}

	return m;
}

void toxcore_step(Tox *m)
{
	tox_iterate(m, NULL);
}

QTimer *toxcore_create_qtimer(Tox *m)
{
	QTimer *timer = new QTimer();
	QObject::connect(timer, &QTimer::timeout, [=]() { toxcore_step(m); });
	timer->setSingleShot(false);
	timer->setInterval(tox_iteration_interval(m));
	return timer;
}

ToxId toxcore_get_self_address(Tox *m)
{
	char address[TOX_ADDRESS_SIZE];
	tox_self_get_address(m, (uint8_t*)address);
	return ToxId(address, TOX_ADDRESS_SIZE);
}

void toxcore_destroy(Tox *m)
{
	toxcore_save_data(m, GetProgDir() + DEFAULT_PROFILE);
	tox_kill(m);
}
