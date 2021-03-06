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
import android.app.RemoteInput;
import android.os.Bundle;
import android.os.Build;
import android.util.Log;
import android.text.format.Formatter;
import android.net.Uri;
import android.graphics.Color;
import android.R.drawable;

// java
import java.lang.String;
import java.util.HashMap;
import java.util.Map.Entry;
import java.util.concurrent.atomic.AtomicInteger;
import java.io.File;

import org.protox.R;
import org.protox.activity.QtActivityEx;

class NotificationModel
{
    public int type; 
    public int id;
    public HashMap <String, Object> parameters;
};

class QtAndroidNotifications {

    public static void show(final String title, final String caption, final int id, final int type, final HashMap <String, Object> parameters) {
        final Context context = QtNative.activity();
        final NotificationManager notificationManager = getManager();
        final Notification.Builder builder =
                new Notification.Builder(context)
                .setSmallIcon(org.protox.R.drawable.icon)
                .setColor(Color.parseColor("#673AB7")) // Material.DeepPurple
                .setContentTitle(title)
                .setContentText(caption)
                .setDefaults(Notification.DEFAULT_ALL)
                .setPriority(Notification.PRIORITY_HIGH)
                .setAutoCancel(true);

        final int notification_id = getUniqueNotificationID();
        switch (type) {
            case 0: {
                String packageName = context.getApplicationContext().getPackageName();
                Intent resultIntent = context.getPackageManager().getLaunchIntentForPackage(packageName);
                resultIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
                Bundle bundle = new Bundle();
                bundle.putInt("notificationId", id);
                resultIntent.putExtras(bundle);
                PendingIntent resultPendingIntent = PendingIntent.getActivity(context, getUniquePendingIntentID(),
                        resultIntent, PendingIntent.FLAG_UPDATE_CURRENT);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && id >= 0) {
                    RemoteInput remoteInput = new RemoteInput.Builder("key_text_reply")
                            .setLabel((String)parameters.get("replyPlaceholderText"))
                            .build();
                    Intent intentActionReply = new Intent("notificationAction");
                    intentActionReply.putExtra("friendNumber", id);
                    intentActionReply.putExtra("quoteText", caption);
                    PendingIntent pendingIntentReply = PendingIntent.getBroadcast(context, getUniquePendingIntentID(), intentActionReply, 
                                    PendingIntent.FLAG_UPDATE_CURRENT);
                    Notification.Action replyAction = new Notification.Action.Builder(android.R.drawable.ic_dialog_info,
                                    (String)parameters.get("replyButtonText"), pendingIntentReply)
                                    .addRemoteInput(remoteInput)
                                    .build();
                    builder.addAction(replyAction);
                    builder.setStyle(new Notification.BigTextStyle().bigText(caption));
                }
                builder.setContentIntent(resultPendingIntent);
                release("Text", id, type, parameters, notification_id, builder);
                break;
            }
            case 1: {
                int file_number = (int)parameters.get("fileNumber");
                // accept button
                Intent intentActionAccept = new Intent("notificationAction");
                intentActionAccept.putExtra("transferAccepted", true);
                intentActionAccept.putExtra("friendNumber", id);
                intentActionAccept.putExtra("fileNumber", file_number);
                // cancel button
                Intent intentActionCancel = new Intent("notificationAction");
                intentActionCancel.putExtra("transferAccepted", false);
                intentActionCancel.putExtra("friendNumber", id);
                intentActionCancel.putExtra("fileNumber", file_number);
                PendingIntent pendingIntentAccept = PendingIntent.getBroadcast(context, getUniquePendingIntentID(), intentActionAccept, 
                                    PendingIntent.FLAG_UPDATE_CURRENT);
                PendingIntent pendingIntentCancel = PendingIntent.getBroadcast(context, getUniquePendingIntentID(), intentActionCancel, 
                                    PendingIntent.FLAG_UPDATE_CURRENT);
                builder.addAction(0, (String)parameters.get("acceptButtonText"), pendingIntentAccept);
                builder.addAction(0, (String)parameters.get("cancelButtonText"), pendingIntentCancel);
                release("FileRequest", id, type, parameters, notification_id, builder);
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
                            builder.setDefaults(Notification.DEFAULT_LIGHTS);
                            release("FileProgress", id, type, parameters, notification_id, builder);
                            if (file_size == bytesTransfered) {
                                break;
                            }
                            try {
                                Thread.sleep(1000);
                            } catch (InterruptedException e) {
                                Log.d("Notifications", "Sleep failure!");
                            }
                        }
                        try {
                            Thread.sleep(1000);
                        } catch (InterruptedException e) {
                            Log.d("Notifications", "Sleep failure!");
                        }
                        boolean self_canceled = QtActivityEx.checkFileTransferSelfCanceled(id, file_number);
                        if (self_canceled) {
                            getManager().cancel(notification_id);
                            return;
                        }
                        builder.setProgress(0, 0, false);
                        builder.setOngoing(false);
                        builder.setContentText(caption);
                        boolean transfer_succeded = new File((String)parameters.get("filePath")).length() == file_size;
                        if (transfer_succeded) {
                            builder.setContentTitle((String)parameters.get("transferFinishedText"));
                        } else {
                            builder.setContentTitle((String)parameters.get("transferCanceledText"));
                        }
                        if (QtActivityEx.getCurrentFriendNumber() == id) {
                            builder.setPriority(Notification.PRIORITY_MIN);
                            builder.setDefaults(Notification.DEFAULT_LIGHTS);
                        } else {
                            builder.setDefaults(Notification.DEFAULT_ALL);
                        }
                        if (transfer_succeded) {
                            Intent intentActionViewFile = new Intent("notificationAction");
                            intentActionViewFile.putExtra("viewFilePath", (String)parameters.get("filePath"));
                            PendingIntent pendingIntentViewFile = PendingIntent.getBroadcast(context, getUniquePendingIntentID(), intentActionViewFile, 
                                                PendingIntent.FLAG_UPDATE_CURRENT);
                            builder.setContentIntent(pendingIntentViewFile);
                        }
                        if (transfer_succeded || (!transfer_succeded && !self_canceled)) {
                            release("FileProgress", id, type, parameters, notification_id, builder);
                        }
                    }
                }).start();
                break;
        }
    }

    public static void cancel(int type, int id, HashMap <String, Object> parameters) {
        for (Entry <Integer, NotificationModel> entry : notifications.entrySet()) {
            final int current_notification_id = entry.getKey();
            final NotificationModel current_model = entry.getValue();
            if (current_model.type == type && current_model.id == id) {
                if (type == 1 && (int)current_model.parameters.get("fileNumber") != (int)parameters.get("fileNumber")) {
                    continue;
                }
                getManager().cancel(current_notification_id);
                notifications.remove(current_notification_id);
                break;
            }
        }
    }

    private static void release(String channel, int id, int type, HashMap <String, Object> parameters, int notification_id, Notification.Builder builder) {
        final NotificationManager notificationManager = getManager();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel chan = new NotificationChannel(channel,
                                                                  "Application",
                                                                  NotificationManager.IMPORTANCE_DEFAULT);
            notificationManager.createNotificationChannel(chan);
            builder.setChannelId(channel);
        }
        if (type < 2) {
            for (Entry <Integer, NotificationModel> entry : notifications.entrySet()) {
                final int current_notification_id = entry.getKey();
                final NotificationModel current_model = entry.getValue();
                if (current_model.type == type && current_model.id == id) {
                    if (type == 1 && (int)current_model.parameters.get("fileNumber") != (int)parameters.get("fileNumber")) {
                        continue;
                    }
                    getManager().cancel(current_notification_id);
                    notifications.remove(current_notification_id);
                    break;
                }
            }
            NotificationModel model = new NotificationModel();
            model.type = type;
            model.id = id;
            if (type == 1) {
                model.parameters = new HashMap <String, Object>();
                model.parameters.put("fileNumber", parameters.get("fileNumber"));
            }
            notifications.put(notification_id, model);
        }
        notificationManager.notify(notification_id, builder.build());
    }

    public static void cancelAll() {
        getManager().cancelAll();
    }

    private static NotificationManager getManager() {
        Context context = QtNative.activity();
        return (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
    }

    private final static AtomicInteger unique_notification_id = new AtomicInteger(1); // 1 is reserved in PersistentNotification.java
    private final static AtomicInteger unique_pending_intent_id = new AtomicInteger(1); // 1 is reserved in PersistentNotification.java
    private static int getUniqueNotificationID() {
        return unique_notification_id.incrementAndGet();
    }
    private static int getUniquePendingIntentID() {
        return unique_pending_intent_id.incrementAndGet();
    }

    private static HashMap <Integer, NotificationModel> notifications = new HashMap <Integer, NotificationModel>();
}
