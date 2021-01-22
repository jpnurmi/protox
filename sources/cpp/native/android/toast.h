#ifndef ANDROID_H
#define ANDROID_H

#include "sources/cpp/common.h"

class QtToast : public QObject
{
	Q_OBJECT

public:
	QtToast() {}
	Q_INVOKABLE bool show(const QVariant &toastParameters);

	enum Duration {
		Short = 0,
		Long = 1
	};
	Q_ENUM(Duration)

	static void declareQML();
};

#endif // ANDROID_H
