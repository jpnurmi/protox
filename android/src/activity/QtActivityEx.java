package org.protox.activity;

// Qt
import org.qtproject.qt5.android.bindings.QtActivity;
import org.qtproject.qt5.android.QtNative;

// android
import android.content.Intent;
import android.content.Context;
import android.os.Bundle;
import android.util.Log;
import android.view.ViewTreeObserver.OnGlobalLayoutListener;
import android.view.View;
import android.view.WindowManager;
import android.view.Window;
import android.graphics.Rect;

import KeyboardProvider.KeyboardProvider;

public class QtActivityEx extends QtActivity
{
    @Override
    public void onCreate(Bundle savedInstanceState) {
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
}
