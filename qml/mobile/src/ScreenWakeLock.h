#pragma once

#include <QObject>

namespace komaro::mobile {

// Exposed to QML as the "screenWakeLock" context property so the Settings
// dialog's "Keep screen on" switch can toggle it. Android only - there's no
// portable Qt API for suppressing screen-off, so setKeepScreenOn() is a
// no-op on desktop builds.
class ScreenWakeLock : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool keepScreenOn READ keepScreenOn WRITE setKeepScreenOn NOTIFY keepScreenOnChanged)

public:
    explicit ScreenWakeLock(QObject *parent = nullptr);

    bool keepScreenOn() const;
    void setKeepScreenOn(bool enabled);

signals:
    void keepScreenOnChanged();

private:
    bool m_keepScreenOn = false;
};

} // namespace komaro::mobile
