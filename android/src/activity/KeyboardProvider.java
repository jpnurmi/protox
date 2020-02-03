package KeyboardProvider;

import android.app.Activity;
import android.view.View;
import android.view.ViewTreeObserver.OnGlobalLayoutListener;
import android.view.ViewGroup.LayoutParams;
import android.view.Gravity;
import android.view.WindowManager;
import android.graphics.Rect;
import android.graphics.drawable.ColorDrawable;
import android.widget.PopupWindow;

public class KeyboardProvider extends PopupWindow implements OnGlobalLayoutListener {
    private Activity mActivity;
    private View rootView;
    private KeyboardListener listener;
    private int heightMax; // Record the maximum height of the pop content area

    public KeyboardProvider(Activity activity) {
        super(activity);
        this.mActivity = activity;

        // Basic configuration
        rootView = new View(activity);
        setContentView(rootView);

        // Monitor global Layout changes
        rootView.getViewTreeObserver().addOnGlobalLayoutListener(this);
        setBackgroundDrawable(new ColorDrawable(0));

        // Set width to 0 and height to full screen
        setWidth(0);
        setHeight(LayoutParams.MATCH_PARENT);

        // Set keyboard pop-up mode
        setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        setInputMethodMode(PopupWindow.INPUT_METHOD_NEEDED);
    }

    public KeyboardProvider init() {
        if (!isShowing()) {
            final View view = mActivity.getWindow().getDecorView();
            // Delay loading popupwindow, if not, error will be reported
            view.post(new Runnable() {
                @Override
                public void run() {
                    showAtLocation(view, Gravity.NO_GRAVITY, 0, 0);
                }
            });
        }
        return this;
    }

    public KeyboardProvider setListener(KeyboardListener listener) {
        this.listener = listener;
        return this;
    }

    @Override
    public void onGlobalLayout() {
        Rect rect = new Rect();
        rootView.getWindowVisibleDisplayFrame(rect);
        if (rect.bottom > heightMax) {
            heightMax = rect.bottom;
        }

        // The difference between the two is the height of the keyboard
        int keyboardHeight = heightMax - rect.bottom;
        if (listener != null) {
            listener.onHeightChanged(keyboardHeight);
        }
    }

    public interface KeyboardListener {
        void onHeightChanged(int height);
    }
}
