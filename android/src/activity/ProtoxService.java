package org.protox;

import android.content.Context;
import android.content.Intent;
import android.util.Log;
import android.os.IBinder;
import org.qtproject.qt5.android.bindings.QtService;

public class ProtoxService extends QtService
{
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
        int ret = super.onStartCommand(intent, flags, startId);

        // Do some work

        return ret;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    public static void startBackgroundService(Context context) {
        Log.i(TAG, "Starting Service");
        context.startService(new Intent(context, ProtoxService.class));
    }
}