#ifndef TOOLS_H
#define TOOLS_H

#include "common.h"
#include "tox.h"

void Debug(const QString msg);
char *String_To_ToxPk(const char *hex_string);
const QString ToxId_To_QString(ToxId user_id);
const QString GetProgDir(bool create = true);

#endif // TOOLS_H
