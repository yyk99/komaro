#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>

#include "komaro/core/InfluxDbClient.h"

namespace komaro::core {

// Exposed to QML via QQmlContext::setContextProperty (registered as
// "chartController" in each app's main.cpp), following the same
// context-property pattern as ConnectionManager and for the same reason —
// see ../../README.md.
//
// Fetches a measurement's temperature/humidity time series from InfluxDB and
// applies the same moving-average smoothing as nano/plot_sensor.py before
// exposing it as `points`, ready for SensorChart.qml to draw. Also tracks a
// most-recently-used list of measurement names (persisted via QSettings,
// mirroring ConnectionManager's recentServers), updated on every load() call.
class ChartController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList points READ points NOTIFY pointsChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QStringList recentMeasurements READ recentMeasurements NOTIFY recentMeasurementsChanged)

public:
    explicit ChartController(QObject *parent = nullptr);

    QVariantList points() const;
    QString status() const;
    QStringList recentMeasurements() const;

    // timeRange: InfluxDB duration literal (e.g. "1h", "7d") or "all".
    // window: moving-average window size in samples; < 2 disables smoothing.
    // port defaults to InfluxDB's standard port; overridable so tests can
    // point this at a local fake server instead.
    Q_INVOKABLE void load(const QString &host, const QString &measurement, const QString &timeRange, int window,
                           quint16 port = 8086);

signals:
    void pointsChanged();
    void statusChanged();
    void recentMeasurementsChanged();

private:
    void setStatus(const QString &status);
    void setPoints(const std::vector<SensorPoint> &points);
    void rememberMeasurement(const QString &measurement);
    void loadRecentMeasurements();
    void saveRecentMeasurements();

    InfluxDbClient *m_client = nullptr;
    QVariantList m_points;
    QString m_status;
    QStringList m_recentMeasurements;
};

} // namespace komaro::core
