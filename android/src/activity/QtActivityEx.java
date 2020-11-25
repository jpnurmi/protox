package org.protox.activity;

// Qt
import org.qtproject.qt5.android.bindings.QtActivity;
import org.qtproject.qt5.android.QtNative;

// android
import android.content.ClipData;
import android.content.Intent;
import android.content.Context;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.BroadcastReceiver;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Build;
import android.os.Environment;
import android.os.StrictMode;
import android.util.Log;
import android.view.ViewTreeObserver.OnGlobalLayoutListener;
import android.view.View;
import android.view.WindowManager;
import android.view.Window;
import android.graphics.Rect;
import android.graphics.Color;
import android.provider.MediaStore;
import android.provider.DocumentsContract;
import android.database.Cursor;
import android.net.Uri;
import android.webkit.MimeTypeMap;
import android.app.RemoteInput;

// project
import KeyboardProvider.KeyboardProvider;
import org.protox.service.ProtoxService;

// java
import java.lang.String;

public class QtActivityEx extends QtActivity
{
    @Override
    public void onCreate(Bundle savedInstanceState) {
        // I need this to fix crashes in viewFile
        StrictMode.VmPolicy.Builder builder = new StrictMode.VmPolicy.Builder();
        StrictMode.setVmPolicy(builder.build());
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            Window window = getWindow();
            window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
            window.setStatusBarColor(Color.parseColor("#3F51B5")); // Material.Indigo
        }
        super.onCreate(savedInstanceState);
        processIntent(getIntent());
        new KeyboardProvider(this).init().setListener(new KeyboardProvider.KeyboardListener() {
            @Override
            public void onHeightChanged(int height) {
                keyboardHeightChanged(height);
            }
        });
        BroadcastReceiver receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                Bundle bundle = intent.getExtras();
                if (bundle != null) {
                    if (bundle.containsKey("transferAccepted")) {
                        if (bundle.getBoolean("transferAccepted")) {
                            transferAccepted(bundle.getInt("friendNumber"), bundle.getInt("fileNumber"));
                        } else {
                            transferCanceled(bundle.getInt("friendNumber"), bundle.getInt("fileNumber"));
                        }
                    }
                    Bundle remoteInput = RemoteInput.getResultsFromIntent(intent);
                    if (remoteInput != null) {
                        String replyText = remoteInput.getCharSequence("key_text_reply").toString();
                        messageReplied(bundle.getInt("friendNumber"), bundle.getString("quoteText"), replyText);
                    }
                }
            }
        };
        registerReceiver(receiver, new IntentFilter("notificationAction"));
    }

    private static native void keyboardHeightChanged(int height);
    private static native void transferAccepted(int friend_number, int file_number);
    private static native void transferCanceled(int friend_number, int file_number);
    private static native void messageReplied(int friend_number, String quote_text, String reply_text);
    public static native long getBytesTransfered(int friend_number, int file_number);
    public static native boolean checkFileTransferInProgress(int friend_number, int file_number);
    public static native boolean checkFileTransferSelfCanceled(int friend_number, int file_number);
    public static native int getCurrentFriendNumber();

    @Override
    protected void onNewIntent(Intent intent) {
        processIntent(intent);
        super.onNewIntent(intent);
    };

    private void processIntent(Intent intent) {
        Bundle bundle = intent.getExtras();
        if (bundle != null) {
            if (bundle.containsKey("notificationId")) {
                notificationId = bundle.getInt("notificationId");
            }
        }
    }

    public int getNotificationId(boolean cancel) {
        int result = notificationId;
        if (cancel) {
            notificationId = -1;
        }
        return result; 
    }
    private int notificationId = -1;

    public void setKeyboardAdjustMode(boolean adjustNothing) {
        // for some reason it doesn't work without QtNative.activity(). Why?
        QtNative.activity().getWindow().setSoftInputMode(adjustNothing ? WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING :
                                                                         WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN);
    }

    public static Uri getUriFromClipData(ClipData data, int index) {
        return data.getItemAt(index).getUri();
    }

    public static Intent createChoosePhotoIntent(String title, boolean selectMultiple) {
        Intent intent = new Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
        if (selectMultiple) {
            intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        }
        intent.setType("image/*");
        return Intent.createChooser(intent, title);
    }

    public static Intent createScanQRCodeIntent() {
        PackageManager packageManager = QtNative.activity().getPackageManager();
        Intent intent = new Intent("com.google.zxing.client.android.SCAN");
        intent.putExtra("SCAN_MODE", "QR_CODE_MODE");
        if (intent.resolveActivity(packageManager) != null) {
            return intent;
        } else {
            return null;
        }
    }

    public void browseForQRCodeScanner() {
        Uri marketUri = Uri.parse("market://details?id=com.google.zxing.client.android");
        Intent marketIntent = new Intent(Intent.ACTION_VIEW, marketUri);
        startActivity(marketIntent);
    }

    public static Intent createChooseFolderIntent() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        return Intent.createChooser(intent, "");
    }

    private static String getDataColumn(Context context, Uri uri, String selection, String[] selectionArgs) {
        Cursor cursor = null;
        final String column = "_data";
        final String[] projection = {
                column
        };
        try {
            cursor = context.getContentResolver().query(uri, projection, selection, selectionArgs,
                    null);
            if (cursor != null && cursor.moveToFirst()) {
                final int index = cursor.getColumnIndexOrThrow(column);
                return cursor.getString(index);
            }
        } finally {
            if (cursor != null)
                cursor.close();
        }
        return null;
    }

    public static String convertMediaUriToPath(String uriString) {
        Uri uri = Uri.parse(uriString);
        Context context = (Context)QtNative.activity();
        String selection = null;
        String[] selectionArgs = null;
        if (DocumentsContract.isDocumentUri(context.getApplicationContext(), uri)) {
            if (isExternalStorageDocument(uri)) {
                final String docId = DocumentsContract.getDocumentId(uri);
                final String[] split = docId.split(":");
                if (split[0].equalsIgnoreCase("primary")) {
                    return Environment.getExternalStorageDirectory() + "/" + split[1];
                } else {
                    return "/storage/" + split[0] + "/" + split[1];
                }
            } else if (isDownloadsDocument(uri)) {
                String id = DocumentsContract.getDocumentId(uri);
                if (id.startsWith("raw:")) {
                    return id.replaceFirst("raw:", "");
                }
                if (id.startsWith("msf:")) {
                    id = id.replaceFirst("msf:", "");
                }
                String[] contentUriPrefixesToTry = new String[]{
                        "content://downloads/public_downloads",
                        "content://downloads/my_downloads"
                };
                for (String contentUriPrefix : contentUriPrefixesToTry) {
                    Uri contentUri = ContentUris.withAppendedId(Uri.parse(contentUriPrefix), Long.valueOf(id));
                    try {
                        String path = getDataColumn(context, contentUri, null, null);
                        if (path != null) {
                            return path;
                        }
                    } catch (Exception e) {}
                }
            } else if (isMediaDocument(uri)) {
                final String docId = DocumentsContract.getDocumentId(uri);
                final String[] split = docId.split(":");
                final String type = split[0];
                if ("image".equals(type)) {
                    uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
                } else if ("video".equals(type)) {
                    uri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
                } else if ("audio".equals(type)) {
                    uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;
                }
                selection = "_id=?";
                selectionArgs = new String[]{
                        split[1]
                };
            }
        } else if (DocumentsContract.isTreeUri(uri)) {
            if (isExternalStorageDocument(uri)) {
                final String docId = DocumentsContract.getTreeDocumentId(uri);
                final String[] split = docId.split(":");
                String path;
                if (split[0].equalsIgnoreCase("primary")) {
                    path = Environment.getExternalStorageDirectory().getAbsolutePath();
                } else {
                    path = "/storage/" + split[0];
                }
                if (split.length > 1) {
                    path += "/" + split[1];
                }
                return path;
            }
        }
        if ("content".equalsIgnoreCase(uri.getScheme())) {
          if (isGooglePhotosUri(uri)) {
              return uri.getLastPathSegment();
           }
            String[] projection = {
                    MediaStore.Images.Media.DATA
            };
            Cursor cursor = null;
            try {
                cursor = context.getContentResolver().query(uri, projection, selection, selectionArgs, null);
                int column_index = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA);
                if (cursor.moveToFirst()) {
                    return cursor.getString(column_index);
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        } else if ("file".equalsIgnoreCase(uri.getScheme())) {
            return uri.getPath();
        }
        return null;
    }

    public static boolean isExternalStorageDocument(Uri uri) {
        return "com.android.externalstorage.documents".equals(uri.getAuthority());
    }

    public static boolean isDownloadsDocument(Uri uri) {
        return "com.android.providers.downloads.documents".equals(uri.getAuthority());
    }

    public static boolean isMediaDocument(Uri uri) {
        return "com.android.providers.media.documents".equals(uri.getAuthority());
    }

    public static boolean isGooglePhotosUri(Uri uri) {
        return "com.google.android.apps.photos.content".equals(uri.getAuthority());
    }

    private static String getMimeType(String url) {
        String type = null;
        String extension = MimeTypeMap.getFileExtensionFromUrl(url);
        if (extension != null) {
            type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
        }
        return type;
    }

    public void viewFile(String path, String type) {
        if (type.equals("*")) {
            type = getMimeType(path);
        }
        Intent intent = new Intent();
        intent.setAction(Intent.ACTION_VIEW);
        intent.setDataAndType(Uri.parse("file://" + path), type);
        startActivity(intent);
    }

    public void startProtoxService(String contentTitle, String contentText) {
        Intent serviceIntent = new Intent(this, ProtoxService.class);
        serviceIntent.putExtra("contentTitle", contentTitle);
        serviceIntent.putExtra("contentText", contentText);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent);
        } else {
            startService(serviceIntent);
        }
    }

    public void stopProtoxService() {
        stopService(new Intent(this, ProtoxService.class));
    }
}
