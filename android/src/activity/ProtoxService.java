package org.protox.service;

// android
import android.content.Context;
import android.content.Intent;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.NotificationChannel;
import android.util.Log;
import android.app.Service;
import android.os.IBinder;
import android.os.Bundle;
import android.graphics.Color;

// java
import java.lang.Thread;

import org.protox.R;

public class ProtoxService extends Service
{
    private static final String TAG = "ProtoxService";

    @Override
    public void onCreate() {
        super.onCreate();
        Log.i(TAG, "Creating Service");
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.i(TAG, "Destroying Service");
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        super.onStartCommand(intent, flags, startId);

        Bundle bundle = intent.getExtras();
        Notification.Builder builder = new Notification.Builder(this)
            .setSmallIcon(org.protox.R.drawable.icon)
            .setColor(Color.parseColor("#673AB7")) // Material.DeepPurple
            .setContentTitle("Protox")
            .setContentText(bundle.getString("contentText"))
            .setAutoCancel(true);
        Notification notification = builder.build();
        startForeground(1, notification);

        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}