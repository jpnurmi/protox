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
import android.os.Build;
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

    private static Notification createServiceNotification(Context context, String contentTitle, String contentText, Boolean connected) {
        Notification.Builder builder = new Notification.Builder(context)
            .setSmallIcon(connected ? org.protox.R.drawable.icon : org.protox.R.drawable.icon_disconnected)
            .setColor(connected 
                                ? Color.parseColor("#673AB7") /* Material.DeepPurple */ 
                                : Color.parseColor("#9E9E9E") /* Material.Grey */)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setAutoCancel(true);
        NotificationManager notificationManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel chan = new NotificationChannel("Service", "Service", NotificationManager.IMPORTANCE_DEFAULT);
            notificationManager.createNotificationChannel(chan);
            builder.setChannelId("Service");
        }
        return builder.build();
    }

    public static void updateServiceNotification(Context context, String contentTitle, String contentText, Boolean connected) {
        NotificationManager notificationManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
        Notification notification = createServiceNotification(context, contentTitle, contentText, connected);
        notificationManager.notify(1, notification);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        super.onStartCommand(intent, flags, startId);

        Bundle bundle = intent.getExtras();
        Notification notification = createServiceNotification(this, bundle.getString("contentTitle"), 
                                                                    bundle.getString("contentText"), 
                                                                    false);
        startForeground(1, notification);

        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
