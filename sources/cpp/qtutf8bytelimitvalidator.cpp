
#include "qtutf8bytelimitvalidator.h"

QUtf8ByteLimitValidator::QUtf8ByteLimitValidator(QObject *_parent) : QValidator(_parent)
{
	m_length = INT_MAX;
	m_prefix = "";
	m_less = true;
	m_typemore = false;
}

QValidator::State QUtf8ByteLimitValidator::validate(QString &input, int &) const
{
	int prefix_length = 0;
	if (!m_prefix.isEmpty() && input.left(m_prefix.length()).toUpper() == m_prefix.toUpper()) {
		prefix_length = m_prefix.toUtf8().length();
	}

	QByteArray bytes = input.toUtf8();
	if (bytes.length() - prefix_length > m_length) {
		parent()->setProperty("acceptableInput", false);

		if (m_typemore) {
			return QValidator::Intermediate;
		}

		return QValidator::Invalid;
	}

	if (!m_less && bytes.length() - prefix_length < m_length) {
		parent()->setProperty("acceptableInput", false);
		return QValidator::Intermediate;
	}

	parent()->setProperty("acceptableInput", true);
	return QValidator::Acceptable;
}

void QUtf8ByteLimitValidator::declareQML()
{
	qmlRegisterType<QUtf8ByteLimitValidator>("QtUtf8ByteLimitValidator", 1, 0, "Utf8ByteLimitValidator");
}
