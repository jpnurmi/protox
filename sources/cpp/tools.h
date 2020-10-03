#ifndef TOOLS_H
#define TOOLS_H

#include "common.h"

namespace Tools {
	void debug(const QString &msg);
	const QString getProgDir();
	const QString getAvatarsDir();
	const QString replaceFileExtension(const QString &file, const QString &with);
	const QStringList qstringSplitUnicode(const QString &str, int limit_bytes);
	const QString getFilenameFromPath(const QString &path);
	const QString getDefaultDownloadsDirectory();
	const QString checkFileImage(const QString &path);
	bool checkFileExists(const QString &path);
	quint64 getFileSize(const QString &path);
	const QSize getImageSize(const QString &path);
	const QString getUniqueFilepath(const QString &path);
	const QString getCurrentCommitSha1();
}


#endif // TOOLS_H
