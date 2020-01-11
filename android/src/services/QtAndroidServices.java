package org.protox.services;

import android.content.Context;
import android.content.Intent;

import org.qtproject.qt5.android.bindings.QtService;
import android.util.Log;

import android.app.ActivityManager;
import android.app.ActivityManager.RunningServiceInfo;

import java.lang.String;


public class QtAndroidServices extends QtService
{
    public static void _startService(Context ctx) {
        Log.i("Service", "Service requested!");
        ctx.startService(new Intent(ctx, QtAndroidServices.class));
    }
    @Override
    public void onCreate() {
        Log.i("Service", "Service created!");
        super.onCreate();
    }

}
