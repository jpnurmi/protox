package notifications;

// Qt
import org.qtproject.qt5.android.QtNative;

// android
import android.content.Intent;
import android.content.Context;
import android.app.PendingIntent;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.NotificationChannel;
import android.os.Bundle;
import android.os.Build;

// java
import java.lang.String;

import org.protox.R;

class QtAndroidNotifications {

    public static void show(String title, String caption, int id) {
        Context context = QtNative.activity();
        NotificationManager notificationManager = getManager();
        Notification.Builder builder =
                new Notification.Builder(context)
                .setSmallIcon(org.protox.R.drawable.icon)
                .setContentTitle(title)
                .setContentText(caption)
                .setDefaults(Notification.DEFAULT_ALL)
                .setPriority(Notification.PRIORITY_HIGH)
                .setAutoCancel(true);

        String packageName = context.getApplicationContext().getPackageName();
        Intent resultIntent = context.getPackageManager().getLaunchIntentForPackage(packageName);
        resultIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        Bundle bundle = new Bundle();
        bundle.putInt("notificationId", id);
        resultIntent.putExtras(bundle);

        PendingIntent resultPendingIntent = PendingIntent.getActivity(context, 0,
            resultIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        builder.setContentIntent(resultPendingIntent);
        notificationManager.notify(id, builder.build());
    }

    public static void cancel(int id) {
        Context context = QtNative.activity();
        NotificationManager notificationManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.cancel(id);
    }

    private static NotificationManager getManager() {
        Context context = QtNative.activity();
        return (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    }
}
