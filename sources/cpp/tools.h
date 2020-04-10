#ifndef TOOLS_H
#define TOOLS_H

#include "common.h"
#include "tox.h"

namespace Tools {
	void debug(const QString &msg);
	const QString getProgDir(bool create = true);
	const QStringList qstringSplitUnicode(const QString &str, int limit_bytes);
}


#endif // TOOLS_H
