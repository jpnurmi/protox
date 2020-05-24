#ifndef TOX_H
#define TOX_H

#include "common.h"
#include "tools.h"

// Toxcore
#include "deps/tox/tox.h"
#include "deps/tox/toxencryptsave.h"

typedef QVector <quint32> ToxFriends; 
typedef QByteArray ToxPk;
typedef QByteArray ToxId;
typedef QByteArray ToxFileId;

typedef QMap <quint32, TOX_CONNECTION> ToxFriendsConnStatus;
struct ToxPendingMessage {
	quint32 message_id;
	quint32 unique_id;
	quint32 friend_number;
	bool failed;
	bool resent;
	ToxPendingMessage(quint32 _message_id, quint32 _unique_id, quint32 _friend_number, bool _failed) {
		message_id = _message_id;
		unique_id = _unique_id;
		friend_number = _friend_number;
		failed = _failed;
		resent = false;
	}
	friend bool operator==(const ToxPendingMessage &a, const ToxPendingMessage &b) {
		return a.message_id == b.message_id && 
				a.unique_id == b.unique_id && 
				a.friend_number == b.friend_number &&
				a.failed == b.failed &&
				a.resent == b.resent;
	}
};
typedef QVector<ToxPendingMessage> ToxPendingMessages;

typedef QMap<QString, QVariant> ToxVariantMessage;
enum ToxVariantMessageType {
	TOXMSG_TEXT,
	TOXMSG_FILE
};
enum ToxProfileLoadingError {
	TOX_ERR_LOADING_OK,
	TOX_ERR_LOADING_NULL,
	TOX_ERR_LOADING_WRONG_PASSWORD,
	TOX_ERR_LOADING_NOT_EXISTS,
	TOX_ERR_LOADING_ALREADY_EXISTS,
	TOX_ERR_LOADING_EMPTY_PASSWORD
};
enum ToxFileSendingError {
	TOX_ERR_SENDING_OK,
	TOX_ERR_SENDING_OPEN_FAILED,
	TOX_ERR_SENDING_TOO_MANY_REQUESTS,
	TOX_ERR_SENDING_LONG_FILENAME,
	TOX_ERR_SENDING_FRIEND_OFFLINE,
	TOX_ERR_SENDING_OTHER
};
enum ToxFileState {
	TOX_FILE_REQUEST,
	TOX_FILE_INPROGRESS,
	TOX_FILE_PAUSED,
	TOX_FILE_CANCELED,
	TOX_FILE_FINISHED
};

struct ToxFileTransfer {
	Tox *tox;
	quint32 friend_number;
	quint32 file_number;
	Tools::AsyncFileManager *manager;
	quint32 bytesTransfered;
	ToxFileTransfer (Tox *_tox, quint32 _friend_number, quint32 _file_number, Tools::AsyncFileManager *_manager) {
		tox = _tox;
		friend_number = _friend_number;
		file_number = _file_number;
		manager = _manager;
		manager->setObjectParent(this);
		bytesTransfered = 0;
	}
	~ToxFileTransfer() {
		delete manager;
	}
};
typedef QVector <ToxFileTransfer*> ToxFileTransfers;
typedef QMap <ToxFileTransfer*, quint64> ToxFileMessages;

struct ToxMessage {
	ToxVariantMessage variantMessage;
	QDateTime dt;
	bool self;
	bool received;
	quint64 unique_id;
	ToxMessage (ToxVariantMessage _variantMessage, quint64 _unique_id, QDateTime _dt, bool _self, bool _received) {
		variantMessage = _variantMessage;
		dt = _dt;
		self = _self;
		received = _received;
		unique_id = _unique_id;
	}
};
typedef QVector <ToxMessage> ToxMessages;

namespace Toxcore {
	Tox *create(ToxProfileLoadingError &error, bool create_new, const QString &password, const QString &profile, const Tox_Pass_Key *pass_key);
	void destroy(Tox *m);
	QTimer *create_qtimer(Tox *m);
	void bootstrap_DHT(Tox *m);
	ToxId get_address(Tox *m);
	quint32 send_message(Tox *m, quint32 friend_number, const QString &message, bool &failed);
	ToxPk get_friend_public_key(Tox *m, quint32 friend_number);
	const QString get_friend_name(Tox *m, quint32 friend_number);
	size_t get_friends_count(Tox *m);
	ToxFriends get_friends(Tox *m);
	int make_friend_request(Tox *m, ToxId id, const QString &friendMessage);
	int get_friend_status(Tox *m, quint32 friend_number);
	quint32 add_friend(Tox *m, const ToxPk &friendPk, int *error);
	void delete_friend(Tox *m, quint32 friend_number);
	void set_typing_friend(Tox *m, quint32 friend_number, bool typing);
	const QString get_friend_status_message(Tox *m, quint32 friend_number);
	const QString get_nickname(Tox* m, bool toxId = false);
	void set_nickname(Tox *m, const QString &nickname);
	const QString get_status_message(Tox *m);
	void set_status_message(Tox *m, const QString &statusMessage);
	quint32 get_status(Tox *m);
	void set_status(Tox *m, quint32 status);
	int get_connection_status();
	quint32 get_nospam(Tox *m);
	void set_nospam(Tox *m, quint32 nospam);
	bool check_profile_encrypted(const QString &profile);
	bool save_data(Tox *m, const Tox_Pass_Key *pass_key, const QString &path);
	Tox_Pass_Key *generate_pass_key(const QString &password);
	void reset_pass_key(Tox_Pass_Key *key);
	const QString get_version_string();
	quint32 get_available_nodes();
	quint32 get_message_max_length();
	quint32 get_friend_request_message_max_length();
	quint32 get_nickname_max_length();
	quint32 get_status_message_max_length();
	quint32 get_tox_address_size();
	quint32 send_file(Tox *m, quint32 friend_number, const QString &path, ToxFileTransfer **transfer, quint64 &filesize, ToxFileId &file_id, quint32 &error);
	bool file_control(Tox *m, quint32 friend_number, quint32 file_number, quint32 control, quint64 &unique_id);
	void cancel_all_file_transfers();
	void cancel_all_file_transfers_for_friend(quint32 friend_number);
	void iterate(Tox *m);
	bool acceptFile(quint32 friend_number, quint32 file_number, quint64 &unique_id);
}

namespace ToxConverter {
	const ToxId toToxId(const QString &str);
	const QString toString(const ToxId &user_id);
}

#endif // TOX_H
