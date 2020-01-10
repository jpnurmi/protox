package services;

import android.content.Context;
import android.content.Intent;

import org.qtproject.qt5.android.bindings.QtService;
import android.util.Log;

public class QtAndroidServices extends QtService
{
    public static void startService(Context ctx) {
        Log.i("Service", "Service requested!");
        ctx.startService(new Intent(ctx, QtAndroidServices.class));
    }
}
