#ifndef QTUTF8BYTELIMITVALIDATOR_H
#define QTUTF8BYTELIMITVALIDATOR_H

#include <QValidator>
#include <QQmlComponent>

class QUtf8ByteLimitValidator : public QValidator 
{
	Q_OBJECT
	Q_PROPERTY(int length READ getLength WRITE setLength)
	Q_PROPERTY(QString prefix READ getPrefix WRITE setPrefix)
	Q_PROPERTY(bool less READ getLess WRITE setLess)
	Q_PROPERTY(bool typemore READ getTypeMore WRITE setTypeMore)
public:
	 explicit QUtf8ByteLimitValidator(QObject *_parent = nullptr);
	~QUtf8ByteLimitValidator() {}
	State validate(QString &input, int &) const;

	void fixup(QString &) const {}
	static void declareQML();

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
