#ifndef QTUTF8BYTELIMITVALIDATOR_H
#define QTUTF8BYTELIMITVALIDATOR_H

#include <QValidator>
#include <QQmlComponent>

class QUtf8ByteLimitValidator : public QValidator {
	Q_OBJECT
	Q_PROPERTY(int length READ getLength WRITE setLength)
	Q_PROPERTY(QString prefix READ getPrefix WRITE setPrefix)
	Q_PROPERTY(bool less READ getLess WRITE setLess)
	Q_PROPERTY(bool typemore READ getTypeMore WRITE setTypeMore)
public:
	 explicit QUtf8ByteLimitValidator(QObject *parent = nullptr) : QValidator(parent) {
		m_length = UINT_MAX;
		m_prefix = "";
		m_less = true;
		m_typemore = false;
	}
	~QUtf8ByteLimitValidator() {}
	QValidator::State validate(QString &input, int &) const
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
	void fixup(QString &) const {}
	static void declareQML() { qmlRegisterType<QUtf8ByteLimitValidator>("QtUtf8ByteLimitValidator", 1, 0, "Utf8ByteLimitValidator"); }

	int getLength() { return m_length; }
	void setLength(int length) { m_length = length; }
	QString getPrefix() { return m_prefix; }
	void setPrefix(const QString &prefix) { m_prefix = prefix; }
	bool getLess() { return m_less; }
	void setLess(bool less) { m_less = less; }
	bool getTypeMore() { return m_typemore; }
	void setTypeMore(bool typemore) { m_typemore = typemore; }
private:
	Q_DISABLE_COPY(QUtf8ByteLimitValidator)

	int m_length;
	QString m_prefix;
	bool m_less;
	bool m_typemore;
};

#endif // QTUTF8BYTELIMITVALIDATOR_H
