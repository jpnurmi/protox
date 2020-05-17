package org.protox.activity;

// Qt
import org.qtproject.qt5.android.bindings.QtActivity;
import org.qtproject.qt5.android.QtNative;

// android
import android.content.Intent;
import android.content.Context;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.os.Bundle;
import android.os.Build;
import android.os.Environment;
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


import KeyboardProvider.KeyboardProvider;

public class QtActivityEx extends QtActivity
{
    @Override
    public void onCreate(Bundle savedInstanceState) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            Window window = getWindow();
            window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
            window.setStatusBarColor(Color.parseColor("#3F51B5"));
        }
        super.onCreate(savedInstanceState);
        processIntent(getIntent());
        new KeyboardProvider(this).init().setListener(new KeyboardProvider.KeyboardListener() {
            @Override
            public void onHeightChanged(int height) {
                keyboardHeightChanged(height);
            }
        });
    }

    private static native void keyboardHeightChanged(int height);

    @Override
    protected void onNewIntent(Intent intent) {
        Bundle bundle = intent.getExtras();
        if (bundle != null && bundle.containsKey("notificationId")) {
            notificationId = bundle.getInt("notificationId");
        }
        super.onNewIntent(intent);
    };

    private void processIntent(Intent intent){
        Bundle bundle = intent.getExtras();
        if (bundle != null && bundle.containsKey("notificationId")) {
            notificationId = bundle.getInt("notificationId");
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

    public static Intent createChoosePhotoIntent(String title) {
        Intent intent = new Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
        intent.setType("image/*");
        return Intent.createChooser(intent, title);
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
                if (split[0].equals("primary")) {
                    return Environment.getExternalStorageDirectory() + "/" + split[1];
                } else {
                    return "/storage/" + split[0] + "/" + split[1];
                }
            } else if (isDownloadsDocument(uri)) {
                final String id = DocumentsContract.getDocumentId(uri);
                uri = ContentUris.withAppendedId(Uri.parse("content://downloads/public_downloads"), Long.valueOf(id));
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
}
