#include "photodialog.h"

QtPhotoDialog::QtPhotoDialog()
{
	m_activityResultReceiver = new QtPhotoDialogActivityResultReceiver(this);
}

QtPhotoDialog::~QtPhotoDialog()
{
	delete m_activityResultReceiver;
}

bool QtPhotoDialog::open()
{
	QtAndroid::runOnAndroidThread([=]() {
		QAndroidJniObject javaString = QAndroidJniObject::fromString(m_title);
		QAndroidJniObject intent = QAndroidJniObject::callStaticObjectMethod(
		"org/protox/activity/QtActivityEx",
		"createChoosePhotoIntent",
		"(Ljava/lang/String;)Landroid/content/Intent;", 
		javaString.object());
		QtAndroid::startActivity(intent, 12051978, m_activityResultReceiver);
	});

	return true;
}

QtPhotoDialogActivityResultReceiver::QtPhotoDialogActivityResultReceiver(QtPhotoDialog *photoPickerDialog)
{
	m_photoDialog = photoPickerDialog;
}

void QtPhotoDialogActivityResultReceiver::handleActivityResult(int requestCode, int resultCode, const QAndroidJniObject &data)
{
		Q_UNUSED(requestCode)
		if (resultCode == -1) {
			QAndroidJniObject imageUri = data.callObjectMethod(
						"getData",
						"()Landroid/net/Uri;");
			m_photoDialog->setImageUrl(imageUri.toString());
			emit m_photoDialog->accepted();
		}
}

void QtPhotoDialog::declareQML()
{
	qmlRegisterType<QtPhotoDialog>("QtPhotoDialog", 1, 0, "PhotoDialog");
}
