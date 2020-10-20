#ifndef SETTINGS_H
#define SETTINGS_H

#include "common.h"

class QSettingsExt : public QSettings
{
	Q_OBJECT
public:
	QSettingsExt(const QString &fileName);
	QVariant valued(const QString &key);
private:
	QVariantMap default_values;
};

#endif // SETTINGS_H
