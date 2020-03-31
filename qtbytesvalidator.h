#ifndef QTBYTESVALIDATOR_H
#define QTBYTESVALIDATOR_H

#include <QValidator>
#include <QQmlComponent>

class QBytesValidator : public QValidator {
	Q_OBJECT
	Q_PROPERTY(int length READ getLength WRITE setLength)
	Q_PROPERTY(QString prefix READ getPrefix WRITE setPrefix)
	Q_PROPERTY(bool less READ getLess WRITE setLess)
public:
	 explicit QBytesValidator(QObject *parent = nullptr) : QValidator(parent) {
		m_length = 0;
		m_prefix = "";
		m_less = true;
	}
	~QBytesValidator() {}
	QValidator::State validate(QString &input, int &) const
	{
		int prefix_length = 0;
		if (!m_prefix.isEmpty() && input.left(m_prefix.length()) == m_prefix) {
			prefix_length = m_prefix.toUtf8().length();
		}
		QByteArray bytes = input.toUtf8();
		if (bytes.length() - prefix_length > m_length) {
			parent()->setProperty("acceptableInput", false);
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
	static void declareQML() { qmlRegisterType<QBytesValidator>("QtBytesValidator", 1, 0, "BytesValidator"); }

	int getLength() { return m_length; }
	void setLength(int length) { m_length = length; }
	QString getPrefix() { return m_prefix; }
	void setPrefix(const QString &prefix) { m_prefix = prefix; }
	bool getLess() { return m_less; }
	void setLess(bool less) { m_less = less; }
private:
	Q_DISABLE_COPY(QBytesValidator)

	int m_length;
	QString m_prefix;
	bool m_less;
};

#endif // QTBYTESVALIDATOR_H
