#ifndef TOOLS_H
#define TOOLS_H

#include "common.h"
#include "tox.h"

namespace Tools {
	void debug(const QString &msg);
	const QString getProgDir(bool create = true);
}


#endif // TOOLS_H
