#include "QtStatusBar_p.h"

#include <UIKit/UIKit.h>
#include <QGuiApplication>

#include <QScreen>
#include <QTimer>

@interface QIOSViewController : UIViewController
@property (nonatomic, assign) BOOL prefersStatusBarHidden;
@property (nonatomic, assign) UIStatusBarAnimation preferredStatusBarUpdateAnimation;
@property (nonatomic, assign) UIStatusBarStyle preferredStatusBarStyle;
@end

bool QtStatusBarPrivate::isAvailable_sys()
{
    return true;
}

void QtStatusBarPrivate::setColor_sys(const QColor &color)
{
    Q_UNUSED(color);
}

static UIStatusBarStyle statusBarStyle(QtStatusBar::Theme theme)
{
    return theme == QtStatusBar::Light ? UIStatusBarStyleDefault : UIStatusBarStyleLightContent;
}

static void setPreferredStatusBarStyle(UIWindow *window, UIStatusBarStyle style)
{
    QIOSViewController *viewController = static_cast<QIOSViewController *>([window rootViewController]);
    if (!viewController || viewController.preferredStatusBarStyle == style)
        return;

    viewController.preferredStatusBarStyle = style;
    [viewController setNeedsStatusBarAppearanceUpdate];
}

void togglePreferredStatusBarStyle()
{
    UIStatusBarStyle style = statusBarStyle(QtStatusBar::Light);
    if(QtStatusBarPrivate::theme == QtStatusBar::Light) {
        style = statusBarStyle(QtStatusBar::Dark);
    }
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (keyWindow)
        setPreferredStatusBarStyle(keyWindow, style);
    QTimer::singleShot(200, []() {
        UIStatusBarStyle style = statusBarStyle(QtStatusBarPrivate::theme);
        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        if (keyWindow)
            setPreferredStatusBarStyle(keyWindow, style);
    });
}

static void updatePreferredStatusBarStyle()
{
    UIStatusBarStyle style = statusBarStyle(QtStatusBarPrivate::theme);
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (keyWindow)
        setPreferredStatusBarStyle(keyWindow, style);
}

void QtStatusBarPrivate::setTheme_sys(QtStatusBar::Theme)
{
    updatePreferredStatusBarStyle();

    QObject::connect(qApp, &QGuiApplication::applicationStateChanged, qApp, [](Qt::ApplicationState state) {
        if (state == Qt::ApplicationActive)
            updatePreferredStatusBarStyle();
    }, Qt::UniqueConnection);

    QScreen *screen = qApp->primaryScreen();
    screen->setOrientationUpdateMask(Qt::PortraitOrientation | Qt::LandscapeOrientation | Qt::InvertedPortraitOrientation | Qt::InvertedLandscapeOrientation);
    QObject::connect(screen, &QScreen::orientationChanged, qApp, [](Qt::ScreenOrientation) {
        togglePreferredStatusBarStyle();
    }, Qt::UniqueConnection);
}
