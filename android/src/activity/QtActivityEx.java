package org.protox.activity;

// Qt
import org.qtproject.qt5.android.bindings.QtActivity;

// android
import android.content.Intent;
import android.content.Context;
import android.os.Bundle;
import android.util.Log;

public class QtActivityEx extends QtActivity
{
    @Override
    public void onCreate(Bundle savedInstanceState) {
        processIntent(getIntent());
        super.onCreate(savedInstanceState);
    }

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

    public int getNotificationId() { return notificationId; }
    private int notificationId = -1;
}
