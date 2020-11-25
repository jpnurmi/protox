package org.protox.persistent_notification;

// android
import android.content.Context;
import android.content.Intent;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.NotificationChannel;
import android.util.Log;
import android.os.Bundle;
import android.os.Build;
import android.graphics.Color;

import org.protox.R;

public class PersistentNotification
{
    private static Notification createPersistentNotification(Context context, String contentTitle, String contentText, Boolean connected) {
        Notification.Builder builder = new Notification.Builder(context)
            .setSmallIcon(connected ? org.protox.R.drawable.icon : org.protox.R.drawable.icon_disconnected)
            .setColor(connected 
                                ? Color.parseColor("#673AB7") /* Material.DeepPurple */ 
                                : Color.parseColor("#9E9E9E") /* Material.Grey */)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setOngoing(true)
            .setAutoCancel(true);
        NotificationManager notificationManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel chan = new NotificationChannel("Status", "Status", NotificationManager.IMPORTANCE_DEFAULT);
            notificationManager.createNotificationChannel(chan);
            builder.setChannelId("Status");
        }
        return builder.build();
    }

    public static void updatePersistentNotification(Context context, String contentTitle, String contentText, Boolean connected) {
        NotificationManager notificationManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
        Notification notification = createPersistentNotification(context, contentTitle, contentText, connected);
        notificationManager.notify(1, notification);
    }

    public static void clearPersistentNotification(Context context) {
        NotificationManager notificationManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.cancel(1);
    }
}
