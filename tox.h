#ifndef TOX_H
#define TOX_H

#include "common.h"

typedef QList <quint32> ToxFriends; 
typedef QByteArray ToxPk;
typedef QByteArray ToxId;

typedef QMap <quint32, TOX_CONNECTION> ToxFriendsConnStatus;
typedef QMap <quint32, QDateTime> ToxMessagesDateTime;
typedef QMap <quint32, quint64> ToxMessagesIdUid;

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
typedef QList <ToxMessage> ToxMessages;

namespace Toxcore {
	Tox *create(ToxProfileLoadingError &error, bool create_new = false);
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
	quint32 add_friend(Tox *m, const ToxPk &friendPk, int &error);
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
	bool save_data(Tox *m, const QString &path);
	const Tox_Pass_Key *generate_pass_key(const QString &password);
	const QString get_version_string();
	void reset(Tox *m);
}



#endif // TOX_H
