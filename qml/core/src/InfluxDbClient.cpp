#include "komaro/core/InfluxDbClient.h"

#include <QNetworkReply>
#include <QUrl>
#include <QUrlQuery>
#include <utility>

#include "komaro/core/InfluxResponseParser.h"

namespace komaro::core {

InfluxDbClient::InfluxDbClient(QString host, quint16 port, QString database, QObject *parent)
    : QObject(parent)
    , m_host(std::move(host))
    , m_port(port)
    , m_database(std::move(database))
{
}

QString InfluxDbClient::buildSelectQuery(const QString &measurement, const QString &timeRange)
{
    QString query = QStringLiteral("SELECT temperature_c, humidity FROM %1").arg(measurement);
    if (timeRange != QStringLiteral("all")) {
        query += QStringLiteral(" WHERE time > now() - %1").arg(timeRange);
    }
    return query;
}

void InfluxDbClient::query(const QString &influxQl)
{
    QUrl url;
    url.setScheme(QStringLiteral("http"));
    url.setHost(m_host);
    url.setPort(m_port);
    url.setPath(QStringLiteral("/query"));

    QUrlQuery urlQuery;
    urlQuery.addQueryItem(QStringLiteral("db"), m_database);
    urlQuery.addQueryItem(QStringLiteral("q"), influxQl);
    url.setQuery(urlQuery);

    QNetworkReply *reply = m_manager.get(QNetworkRequest(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply] { onReplyFinished(reply); });
}

void InfluxDbClient::onReplyFinished(QNetworkReply *reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        emit failed(reply->errorString());
        return;
    }

    try {
        emit succeeded(InfluxResponseParser::parse(reply->readAll()));
    } catch (const std::exception &e) {
        emit failed(QString::fromStdString(e.what()));
    }
}

} // namespace komaro::core
