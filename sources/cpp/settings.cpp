
#include "settings.h"
#include "tools.h"
#include "tox.h"

QSettingsExt::QSettingsExt(const QString &fileName) : QSettings(fileName, QSettings::IniFormat)
{
	default_values = {
		// Toxcore
		{ "udp_enabled", true },
		{ "ipv6_enabled", true },
		{ "local_discovery_enabled", false },
		{ "nodes_json_file", QString() },
		{ "proxy_host", QString() },
		{ "proxy_port", 51552 },
		{ "proxy_type", TOX_PROXY_TYPE_NONE },
		// Client
		{ "reconnection_interval", 60000 },
		{ "absent_timer_interval", 10 },
		{ "load_messages_limit", 64 },
		{ "last_messages_limit", 128 },
		{ "downloads_folder", Tools::getDefaultDownloadsDirectory() },
		{ "auto_accept_files", false },
		{ "auto_accept_file_size", 20 },
		// Privacy
		{ "keep_chat_history", true }
	};
}

QVariant QSettingsExt::valued(const QString &key)
{
	if (!contains(key) && !default_values.contains(key)) {
		Tools::debug("QSettingsExt: default value for key \"" + key + "\" is missing.");
		return QVariant();
	}
	return value(key, default_values.value(key));
}
