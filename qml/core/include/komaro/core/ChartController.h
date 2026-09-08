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
// Fetches one or more measurements' temperature/humidity time series from
// InfluxDB (one query per measurement, issued sequentially - InfluxDbClient's
// succeeded/failed signals aren't tagged with which query they answer, so
// concurrent in-flight queries on one client would be ambiguous) and applies
// the same moving-average smoothing as nano/plot_sensor.py before exposing
// them as `series`, ready for SensorChart.qml to draw one temperature/
// humidity line pair per measurement. Also tracks a most-recently-used list
// of measurement names (persisted via QSettings, mirroring
// ConnectionManager's recentServers), updated on every load() call.
class ChartController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList series READ series NOTIFY seriesChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QStringList recentMeasurements READ recentMeasurements NOTIFY recentMeasurementsChanged)

public:
    explicit ChartController(QObject *parent = nullptr);

    // Each entry is {"measurement": QString, "points": QVariantList}, one per
    // successfully-loaded measurement from the most recent load() call.
    QVariantList series() const;
    QString status() const;
    QStringList recentMeasurements() const;

    // timeRange: InfluxDB duration literal (e.g. "1h", "7d") or "all".
    // window: moving-average window size in samples; < 2 disables smoothing.
    // port defaults to InfluxDB's standard port; overridable so tests can
    // point this at a local fake server instead. Blank/duplicate entries in
    // `measurements` are dropped; an empty list defaults to ["sensor"].
    Q_INVOKABLE void load(const QString &host, const QStringList &measurements, const QString &timeRange, int window,
                           quint16 port = 8086);

signals:
    void seriesChanged();
    void statusChanged();
    void recentMeasurementsChanged();

private:
    void setStatus(const QString &status);
    void startNextQuery();
    void rememberMeasurement(const QString &measurement);
    void loadRecentMeasurements();
    void saveRecentMeasurements();

    InfluxDbClient *m_client = nullptr;
    QString m_host;
    QString m_timeRange;
    int m_window = 1;
    quint16 m_port = 8086;
    QStringList m_pendingMeasurements;
    QVariantList m_series;
    int m_totalPoints = 0;
    QString m_firstError;
    QString m_status;
    QStringList m_recentMeasurements;
};

} // namespace komaro::core
