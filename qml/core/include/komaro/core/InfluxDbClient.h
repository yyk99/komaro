#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QString>
#include <vector>

#include "komaro/core/SensorPoint.h"

QT_BEGIN_NAMESPACE
class QNetworkReply;
QT_END_NAMESPACE

namespace komaro::core {

// Asynchronous client for InfluxDB 1.x's HTTP /query endpoint.
class InfluxDbClient : public QObject
{
    Q_OBJECT

public:
    explicit InfluxDbClient(QString host, quint16 port = 8086,
                             QString database = QStringLiteral("komaro"), QObject *parent = nullptr);

    // Builds "SELECT temperature_c, humidity FROM <measurement>", adding a
    // "WHERE time > now() - <timeRange>" clause unless timeRange == "all".
    static QString buildSelectQuery(const QString &measurement, const QString &timeRange);

    // Issues an InfluxQL query; result/error is reported via the signals below.
    void query(const QString &influxQl);

signals:
    void succeeded(const std::vector<SensorPoint> &points);
    void failed(const QString &errorMessage);

private:
    void onReplyFinished(QNetworkReply *reply);

    QNetworkAccessManager m_manager;
    QString m_host;
    quint16 m_port;
    QString m_database;
};

} // namespace komaro::core
