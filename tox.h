#ifndef TOX_H
#define TOX_H

#include "common.h"

typedef QList <quint32> ToxFriends; 
typedef QByteArray ToxPk;
typedef QByteArray ToxId;

typedef QMap <quint32, TOX_CONNECTION> ToxFriendsConnStatus;
typedef QMap <quint32, QDateTime> ToxMessagesDateTime;
typedef QMap <quint32, quint64> ToxMessagesIdUid;
typedef QMap <quint32, bool> ToxFriendsOnce;

typedef QMap<QString, QVariant> ToxVariantMessage;
enum ToxVariantMessageType {
	TOXMSG_TEXT,
	TOXMSG_FILE
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

Tox *toxcore_create(const QString &profile);
void toxcore_destroy(Tox *m);
QTimer *toxcore_create_qtimer(Tox *m);
void toxcore_bootstrap_DHT(Tox *m);
ToxId toxcore_get_address(Tox *m);
quint32 toxcore_send_message(Tox *m, quint32 friend_number, const QString &message, bool &failed);
ToxPk toxcore_get_friend_public_key(Tox *m, quint32 friend_number);
const QString toxcore_get_friend_name(Tox *m, quint32 friend_number);
size_t toxcore_get_friends_count(Tox *m);
ToxFriends toxcore_get_friends(Tox *m);
int toxcore_make_friend_request(Tox *m, ToxId id, const QString &friendMessage);
int toxcore_get_friend_status(Tox *m, quint32 friend_number);
quint32 toxcore_add_friend(Tox *m, const ToxPk &friendPk);
void toxcore_delete_friend(Tox *m, quint32 friend_number);
void toxcore_set_typing_friend(Tox *m, quint32 friend_number, bool typing);
const QString toxcore_get_friend_status_message(Tox *m, quint32 friend_number);
const QString toxcore_get_nickname(Tox* m, bool toxId = false);
void toxcore_set_nickname(Tox *m, const QString &nickname);
const QString toxcore_get_status_message(Tox *m);
void toxcore_set_status_message(Tox *m, const QString &statusMessage);
quint32 toxcore_get_status(Tox *m);
void toxcore_set_status(Tox *m, quint32 status);
int toxcore_get_connection_status();
quint32 toxcore_get_nospam(Tox *m);
void toxcore_set_nospam(Tox *m, quint32 nospam);


bool toxcore_save_data(Tox *m, const QString &path);

#endif // TOX_H
