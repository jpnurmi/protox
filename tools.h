#ifndef TOOLS_H
#define TOOLS_H

#include "common.h"
#include "tox.h"

void Debug(const QString &msg);
const QString ToxId_To_QString(const ToxId &user_id);
const QString GetProgDir(bool create = true);
const ToxId QString_To_ToxId(const QString &str);

#endif // TOOLS_H
