#include "folderdialog.h"

QtFolderDialog::QtFolderDialog()
{
	m_activityResultReceiver = new QtFolderDialogActivityResultReceiver(this);
}

QtFolderDialog::~QtFolderDialog()
{
	delete m_activityResultReceiver;
}

bool QtFolderDialog::open()
{
	QtAndroid::runOnAndroidThread([=]() {
		QAndroidJniObject intent = QAndroidJniObject::callStaticObjectMethod(
		"org/protox/activity/QtActivityEx",
		"createChooseFolderIntent",
		"()Landroid/content/Intent;");
		QtAndroid::startActivity(intent, 12051978, m_activityResultReceiver);
	});

	return true;
}

QtFolderDialogActivityResultReceiver::QtFolderDialogActivityResultReceiver(QtFolderDialog *folderPickerDialog)
{
	m_folderDialog = folderPickerDialog;
}

void QtFolderDialogActivityResultReceiver::handleActivityResult(int requestCode, int resultCode, const QAndroidJniObject &data)
{
		Q_UNUSED(requestCode)

		if (resultCode == -1) {
			QAndroidJniObject folderUri = data.callObjectMethod(
						"getData",
						"()Landroid/net/Uri;");
			m_folderDialog->setFolderUrl(folderUri.toString());
			emit m_folderDialog->accepted();
		}
}

void QtFolderDialog::declareQML()
{
	qmlRegisterType<QtFolderDialog>("QtFolderDialog", 1, 0, "FolderDialog");
}
