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
import android.util.Log;

// java
import java.lang.String;
import java.util.HashMap;

import org.protox.R;
import org.protox.activity.QtActivityEx;

class QtAndroidNotifications {

    public static void show(String title, String caption, int id, int type, HashMap <String, Object> parameters) {
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

        switch (type) {
            case 0: {
                String packageName = context.getApplicationContext().getPackageName();
                Intent resultIntent = context.getPackageManager().getLaunchIntentForPackage(packageName);
                resultIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
                Bundle bundle = new Bundle();
                bundle.putInt("notificationId", id);
                resultIntent.putExtras(bundle);
                PendingIntent resultPendingIntent = PendingIntent.getActivity(context, 0,
                        resultIntent, PendingIntent.FLAG_UPDATE_CURRENT);
                builder.setContentIntent(resultPendingIntent);
                notificationManager.notify(getTagByType(type), id, builder.build());
                break;
            }
            case 1: {
                int file_number = (int)parameters.get("fileNumber");
                // accept button
                Intent intentActionAccept = new Intent(context, QtActivityEx.class);
                intentActionAccept.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
                intentActionAccept.putExtra("transferAccepted",true);
                intentActionAccept.putExtra("friendNumber", id);
                intentActionAccept.putExtra("fileNumber", file_number);
                // cancel button
                Intent intentActionCancel = new Intent(context, QtActivityEx.class);
                intentActionCancel.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
                intentActionCancel.putExtra("transferAccepted",false);
                intentActionCancel.putExtra("friendNumber", id);
                intentActionCancel.putExtra("fileNumber", file_number);
                PendingIntent pendingIntentAccept = PendingIntent.getActivity(context, 0,
                        intentActionAccept, PendingIntent.FLAG_UPDATE_CURRENT);
                PendingIntent pendingIntentCancel = PendingIntent.getActivity(context, 1,
                        intentActionCancel, PendingIntent.FLAG_UPDATE_CURRENT);
                builder.addAction(0, (String)parameters.get("acceptButtonText"), pendingIntentAccept);
                builder.addAction(0, (String)parameters.get("cancelButtonText"), pendingIntentCancel);
                notificationManager.notify(getTagByType(type) + "_" + id, file_number, builder.build());
                break;
            }
        }
    }

    public static void cancel(int type, int id, HashMap <String, Object> parameters) {
        switch (type) {
            case 0: getManager().cancel(getTagByType(type), id); break;
            case 1: getManager().cancel(getTagByType(type) + "_" + id, (int)parameters.get("fileNumber"));
        }

    }

    public static void cancelAll() {
        getManager().cancelAll();
    }

    private static String getTagByType(int type) {
        switch (type) {
            case 0: return "Text";
            case 1: return "FileRequest";
        }
        return "";
    }

    private static NotificationManager getManager() {
        Context context = QtNative.activity();
        return (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
    }
}
