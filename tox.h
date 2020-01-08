#ifndef TOX_H
#define TOX_H

#include "common.h"

typedef QList <quint32> ToxFriends; 
typedef const QByteArray ToxPk;
typedef const QByteArray ToxId;

typedef QMap <quint32, TOX_CONNECTION> ToxFriendsConnStatus;
typedef QMap <quint32, QDateTime> ToxMessagesDateTime;
typedef QMap <quint32, quint64> ToxMessagesIdUid;
typedef QMap <quint32, bool> ToxFriendsOnce;

struct ToxMessage {
	QString message;
	QDateTime dt;
	bool self;
	bool received;
	quint64 unique_id;
	ToxMessage (QString _message, QDateTime _dt, bool _self, bool _received, quint64 _unique_id) {
		message = _message;
		dt = _dt;
		self = _self;
		received = _received;
		unique_id = _unique_id;
	}
};
typedef QList <ToxMessage> ToxMessages;

Tox *toxcore_create(void);
void toxcore_destroy(Tox *m);
QTimer *toxcore_create_qtimer(Tox *m);
void toxcore_bootstrap_DHT(Tox *m);
ToxId toxcore_get_self_address(Tox *m);
quint32 toxcore_send_message(Tox *m, quint32 friend_number, const QString message, bool &failed);
ToxPk toxcore_get_friend_public_key(Tox *m, quint32 friend_number);
const QString toxcore_get_friend_name(Tox *m, quint32 friend_number);
ToxFriends toxcore_get_friends(Tox *m);

bool toxcore_save_data(Tox *m, const QString path);

#endif // TOX_H
