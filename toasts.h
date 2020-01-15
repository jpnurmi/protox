#ifndef ANDROID_H
#define ANDROID_H

#include "common.h"

class QtToast : public QObject{
	Q_OBJECT

public:
	QtToast() {}
	Q_INVOKABLE bool show(const QVariant &toastParameters);

	static void declareQML();
};

#endif // ANDROID_H
