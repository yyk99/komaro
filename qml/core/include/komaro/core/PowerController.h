#pragma once

#include <QByteArray>
#include <QNetworkAccessManager>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>

namespace komaro::core {

// Backs the "Power" page: INA219 readings, mirroring ina219_plot.py (in the
// Arduino sketches repo). Unlike the environment pipeline (one measurement
// per sensor in database "komaro"), INA219 data is one measurement "ina219"
// in database "ina219", with the sensor chosen by a `sensor` tag.
//
// Exposed to QML as the "powerController" context property (same pattern as
// ChartController). `panels` is a list of
//   {"key", "title", "unit", "series": [{"field", "points": [{"time", "value"}]}]}
// one entry per requested value (voltage/current/power/shunt), ready to be
// drawn as stacked panels by PowerPage.qml.
class PowerController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList panels READ panels NOTIFY panelsChanged)
    Q_PROPERTY(QStringList sensors READ sensors NOTIFY sensorsChanged)
    Q_PROPERTY(QStringList valueKeys READ valueKeys CONSTANT)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit PowerController(QObject *parent = nullptr);

    QVariantList panels() const { return m_panels; }
    QStringList sensors() const { return m_sensors; }
    QString status() const { return m_status; }
    // "voltage", "current", "power", "shunt" - what load() accepts in `values`.
    QStringList valueKeys() const;

    // Fills `sensors` from SHOW TAG VALUES; failures are reported via status.
    Q_INVOKABLE void loadSensors(const QString &host, quint16 port = 8086);
    // values: subset of valueKeys() (unknown/duplicate entries dropped).
    // timeRange: InfluxDB duration literal or "all". window < 2: no smoothing.
    Q_INVOKABLE void load(const QString &host, const QString &sensor, const QStringList &values,
                           const QString &timeRange, int window, quint16 port = 8086);

    // Pure helpers, public for tests.
    static QString buildQuery(const QString &sensor, const QStringList &fields, const QString &timeRange);
    // Parses a /query response with a multi-column series into `panels`
    // format for the given (already validated) value keys. Throws
    // std::runtime_error on invalid JSON or an InfluxDB error.
    static QVariantList parsePanels(const QByteArray &json, const QStringList &values, int window);
    static QStringList parseTagValues(const QByteArray &json);

signals:
    void panelsChanged();
    void sensorsChanged();
    void statusChanged();

private:
    void setStatus(const QString &status);
    QNetworkReply *get(const QString &host, quint16 port, const QString &influxQl);

    QNetworkAccessManager m_manager;
    QVariantList m_panels;
    QStringList m_sensors;
    QString m_status;
    int m_loadId = 0;
};

} // namespace komaro::core
