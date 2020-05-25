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
import android.text.format.Formatter;
import android.net.Uri;

// java
import java.lang.String;
import java.util.HashMap;
import java.io.File;

import org.protox.R;
import org.protox.activity.QtActivityEx;

class QtAndroidNotifications {

    public static void show(final String title, final String caption, final int id, final int type, final HashMap <String, Object> parameters) {
        final Context context = QtNative.activity();
        final NotificationManager notificationManager = getManager();
        final Notification.Builder builder =
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
            case 2:
                final int file_number = (int)parameters.get("fileNumber");
                final long file_size = (long)parameters.get("fileSize");
                new Thread(new Runnable() {
                    @Override
                    public void run() {
                        long lastBytesTransfered = 0;
                        while (QtActivityEx.checkFileTransferInProgress(id, file_number)) {
                            long bytesTransfered = QtActivityEx.getBytesTransfered(id, file_number);
                            long speedInBytes = bytesTransfered - lastBytesTransfered;
                            lastBytesTransfered = bytesTransfered;
                            builder.setContentText(caption + " " + Formatter.formatFileSize(context, speedInBytes) + (String)parameters.get("speedPrefix"));
                            int current = (int)((float)bytesTransfered / file_size * Short.MAX_VALUE);
                            builder.setProgress(Short.MAX_VALUE, current, false);
                            builder.setOngoing(true);
                            notificationManager.notify(getTagByType(type) + "_" + id, file_number, builder.build());
                            if (file_size == bytesTransfered) {
                                break;
                            }
                            try {
                                Thread.sleep(1000);
                            } catch (InterruptedException e) {
                                Log.d("Notifications", "Sleep failure!");
                            }
                        }
                        builder.setProgress(0, 0, false);
                        builder.setOngoing(false);
                        builder.setContentText(caption);
                        if (new File(Uri.parse((String)parameters.get("filePath")).getPath()).length() == file_size) {
                            builder.setContentTitle((String)parameters.get("transferFinishedText"));
                        } else {
                            builder.setContentTitle((String)parameters.get("transferCanceledText"));
                        }
                        notificationManager.notify(getTagByType(type) + "_" + id, file_number, builder.build());
                    }
                }).start();
                break;
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
            case 2: return "FileProgress";
        }
        return "";
    }

    private static NotificationManager getManager() {
        Context context = QtNative.activity();
        return (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
    }
}
