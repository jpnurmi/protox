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
		"(Ljava/lang/String;Z)Landroid/content/Intent;", 
		javaString.object(), jboolean(m_selectMultiple));
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
			if (m_photoDialog->getSelectMultiple()) {
				QAndroidJniObject clipData = data.callObjectMethod("getClipData", "()Landroid/content/ClipData;");

				if (!clipData.object()) {
					QAndroidJniObject imageUri = data.callObjectMethod(
								"getData",
								"()Landroid/net/Uri;");
					m_photoDialog->setImageUrls(QStringList() << imageUri.toString());
				} else {
					jint count = clipData.callMethod<jint>("getItemCount", "()I");
					QStringList imageUrls;

					// callObjectMethod is not working
					for (jint i = 0; i < count; i++) {
						QAndroidJniObject imageUri = QAndroidJniObject::callStaticObjectMethod(
						"org/protox/activity/QtActivityEx",
						"getUriFromClipData",
						"(Landroid/content/ClipData;I)Landroid/net/Uri;", 
						clipData.object(), i);
						imageUrls.push_back(imageUri.toString());
					}
					m_photoDialog->setImageUrls(imageUrls);
				}

				emit m_photoDialog->accepted();
				return;
			}
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
