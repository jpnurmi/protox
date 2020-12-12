#ifndef TOX_H
#define TOX_H

#include "common.h"
#include "tools.h"
#include "asyncfilemanager.h"

// Toxcore
#include "deps/tox/tox.h"
#include "deps/tox/toxencryptsave.h"

typedef quint32 ToxResult;
typedef QVector <quint32> ToxFriends; 

class ToxIdData : public QByteArray
{
public:
	ToxIdData(int size);

	QString toToxString() const;
	static ToxIdData fromToxString(const QString &str);

protected:
	ToxIdData(const QByteArray &data) : QByteArray(data) {}
	ToxIdData(const char *data, int size) : QByteArray(data, size) {}
};

class ToxPk : public ToxIdData
{
public:
	ToxPk();
	ToxPk(const ToxIdData &data);
	ToxPk(const QByteArray &data);
	ToxPk(const char *data) : ToxIdData(data, tox_public_key_size()) {}
};

#define TOX_AVATAR_MAX_CLIENT_SIZE 65536

struct ToxPendingMessage {
	quint32 message_id;
	quint32 unique_id;
	quint32 friend_number;
	bool failed;
	bool reply;
	bool resent;

	ToxPendingMessage(quint32 _message_id, quint32 _unique_id, quint32 _friend_number, bool _failed, bool _reply) {
		message_id = _message_id;
		unique_id = _unique_id;
		friend_number = _friend_number;
		failed = _failed;
		reply = _reply;
		resent = false;
	}

	friend bool operator==(const ToxPendingMessage &a, const ToxPendingMessage &b) {
		return a.message_id == b.message_id && 
				a.unique_id == b.unique_id && 
				a.friend_number == b.friend_number &&
				a.failed == b.failed &&
				a.reply == b.reply &&
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
	TOX_ERR_LOADING_OK_BUT_INVALID_PROXY = -1,
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

class ToxLocalFileManager : public QObject
{
	Q_OBJECT
public:
	explicit ToxLocalFileManager() {}
public slots:
	void onFileChunkReady(void *parent, const QByteArray &data, quint64 position);
	void onFileTransferEnded(void *parent);
};

struct ToxFileChunk {
	quint64 position;
	QByteArray data;

	ToxFileChunk(quint64 _position, const QByteArray &_data) {
		position = _position;
		data = _data;
	}
};

struct ToxFileTransfer {
	Tox *tox;
	quint32 friend_number;
	quint32 file_number;
	Tools::AsyncFileManager *manager;
	quint32 bytesTransfered;
	bool avatar;
	QTimer *progress_update_timer; // ui only
	QQueue <ToxFileChunk> chunks_buffer;
	ToxFileTransfer (Tox *_tox, quint32 _friend_number, quint32 _file_number,  bool _avatar, Tools::AsyncFileManager *_manager) {
		tox = _tox;
		friend_number = _friend_number;
		file_number = _file_number;
		avatar = _avatar;
		manager = _manager;
		manager->setObjectParent(this);
		bytesTransfered = 0;

		if (_avatar) {
			progress_update_timer = nullptr;
		} else {
			progress_update_timer = new QTimer;
			progress_update_timer->setSingleShot(true);
			progress_update_timer->setInterval(32);
		}
	}
	~ToxFileTransfer() {
		delete manager;
		delete progress_update_timer;
	}
};
typedef QVector <ToxFileTransfer*> ToxFileTransfers;
typedef QMap <ToxFileTransfer*, quint64> ToxFileMessages;

struct ToxTextMessage {
	QString message;
	bool action;

	ToxTextMessage() {}
	ToxTextMessage(const QString &_message, bool _action) {
		message = _message;
		action = _action;
	}
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
typedef QVector <ToxMessage> ToxMessages;

struct ToxSelfCanceledTransfer
{
	quint32 friend_number;
	quint32 file_number;

	ToxSelfCanceledTransfer(quint32 _friend_number, quint32 _file_number) {
		friend_number = _friend_number;
		file_number = _file_number;
	}

	friend bool operator==(const ToxSelfCanceledTransfer &a, const ToxSelfCanceledTransfer &b) {
		return a.friend_number == b.friend_number && a.file_number == b.file_number;
	}
};
typedef QVector <ToxSelfCanceledTransfer> ToxSelfCanceledTransfers;
typedef QFuture <void> ToxBootstrapingThread;

struct ToxSentFile
{
	quint32 file_number;
	ToxFileTransfer *transfer;
	quint64 file_size;
	QByteArray file_id; 
};

namespace Toxcore {
	struct Tox_Options *createOptions();
	void destroyOptions(struct Tox_Options *opts);
	pair<Tox*, ToxProfileLoadingError> createTox(bool create_new, const QString &password, const QString &profile, const Tox_Pass_Key *pass_key, Tox_Options *opts);
	void destroyTox(Tox *m);
	QTimer *createQTimer(Tox *m);
	void bootstrapDHT(Tox *m);
	ToxIdData getAddress(Tox *m);
	pair<quint32, bool> sendMessage(Tox *m, quint32 friend_number, const QString &message, bool action);
	ToxPk getFriendPublicKey(Tox *m, quint32 friend_number);
	const QString getFriendName(Tox *m, quint32 friend_number, bool publicKey = true);
	quint32 getFriendsCount(Tox *m);
	ToxFriends getFriends(Tox *m);
	ToxResult makeFriendRequest(Tox *m, const ToxIdData &id, const QString &friendMessage);
	int getFriendStatus(Tox *m, quint32 friend_number);
	quint32 getFriendConnectionStatus(Tox *m, quint32 friend_number);
	pair<quint32, ToxResult> addFriend(Tox *m, const ToxPk &friendPk);
	void deleteFriend(Tox *m, quint32 friend_number);
	void setFriendTyping(Tox *m, quint32 friend_number, bool typing);
	const QString getFriendStatusMessage(Tox *m, quint32 friend_number);
	const QString getNickname(Tox* m, bool toxPk = false);
	void setNickname(Tox *m, const QString &nickname);
	const QString getStatusMessage(Tox *m);
	void setStatusMessage(Tox *m, const QString &statusMessage);
	quint32 getStatus(Tox *m);
	void setStatus(Tox *m, quint32 status);
	int getConnectionStatus(Tox *m);
	quint32 getNospam(Tox *m);
	void setNospam(Tox *m, quint32 nospam);
	bool checkProfileEncrypted(const QString &profile);
	bool saveData(Tox *m, const Tox_Pass_Key *pass_key, const QString &path);
	Tox_Pass_Key *generatePassKey(const QString &password);
	void resetPasswordKey(Tox_Pass_Key **key);
	const QString getVersionString();
	quint32 getAvailableNodes();
	quint32 getMessageMaxLength();
	quint32 getFriendRequestMaxLength();
	quint32 getNicknameMaxLength();
	quint32 getStatusMessageMaxLength();
	quint32 getToxAddressSize();
	quint32 getToxPublicKeySize();
	quint32 getToxMaxHostnameLength();
	pair<ToxSentFile, ToxFileSendingError> sendFile(Tox *m, quint32 friend_number, const QString &path, bool avatar = false);
	optional<quint64> fileControl(Tox *m, quint32 friend_number, quint32 file_number, quint32 control);
	void cancelAllFileTransfers();
	void cancelAllFileTransfersForFriend(quint32 friend_number);
	void iterate(Tox *m);
	typedef optional<pair<quint32, quint64>> AcceptFileResult;
	AcceptFileResult acceptFile(quint32 friend_number, quint32 file_number);
	void sendAvatarToAllFriends(Tox *m, const QString &path);
	bool checkToxFile(const QString &path);
}

#endif // TOX_H
