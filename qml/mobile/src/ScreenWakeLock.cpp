#include "ScreenWakeLock.h"

#if defined(Q_OS_ANDROID)
#include <QJniObject>
#include <QtCore/qcoreapplication_platform.h>
#endif

namespace komaro::mobile {

ScreenWakeLock::ScreenWakeLock(QObject *parent) : QObject(parent)
{
}

bool ScreenWakeLock::keepScreenOn() const
{
    return m_keepScreenOn;
}

void ScreenWakeLock::setKeepScreenOn(bool enabled)
{
    if (m_keepScreenOn == enabled)
        return;

    m_keepScreenOn = enabled;

#if defined(Q_OS_ANDROID)
    // android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON - no Qt-side
    // API for this, so it's set directly on the Activity's Window via JNI.
    constexpr int FLAG_KEEP_SCREEN_ON = 0x00000080;
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (activity.isValid()) {
        QJniObject window = activity.callObjectMethod("getWindow", "()Landroid/view/Window;");
        if (window.isValid()) {
            if (enabled)
                window.callMethod<void>("addFlags", "(I)V", FLAG_KEEP_SCREEN_ON);
            else
                window.callMethod<void>("clearFlags", "(I)V", FLAG_KEEP_SCREEN_ON);
        }
    }
#endif

    emit keepScreenOnChanged();
}

} // namespace komaro::mobile
