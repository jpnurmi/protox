package org.protox;

import android.content.Context;
import android.content.Intent;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.NotificationChannel;
import android.util.Log;
import android.app.Service;
import android.os.IBinder;

import java.lang.Thread;

import org.protox.R;

public class ProtoxService extends Service
{
    private static native void serviceLoop();
    private static final String TAG = "QtAndroidService";

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

        Notification.Builder builder = new Notification.Builder(this)
            .setSmallIcon(org.protox.R.drawable.icon)
            .setContentTitle("Protox")
            .setContentText("Service is running")
            .setAutoCancel(true);
        Notification notification = builder.build();
        startForeground(1, notification);

        new Thread(new Runnable(){
            public void run() {
                serviceLoop();
            }
        }).start();

        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}