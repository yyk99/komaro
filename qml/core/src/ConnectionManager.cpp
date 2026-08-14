#include "komaro/core/ConnectionManager.h"

#include <QSettings>

#include "komaro/core/RecentServers.h"

namespace komaro::core {

namespace {
constexpr auto kRecentServersKey = "recentServers";
}

ConnectionManager::ConnectionManager(QObject *parent)
    : QObject(parent)
{
    loadRecentServers();
}

QStringList ConnectionManager::recentServers() const
{
    return m_recentServers;
}

QString ConnectionManager::status() const
{
    return m_status;
}

void ConnectionManager::connectToServer(const QString &host)
{
    const QString trimmed = host.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }

    m_recentServers = RecentServers::withServerAddedToFront(m_recentServers, trimmed);
    saveRecentServers();
    emit recentServersChanged();

    setStatus(tr("Connecting to %1...").arg(trimmed));

    delete m_client;
    m_client = new InfluxDbClient(trimmed, 8086, QStringLiteral("komaro"), this);

    connect(m_client, &InfluxDbClient::succeeded, this,
            [this, trimmed](const std::vector<SensorPoint> &points) {
                setStatus(tr("Connected to %1 (%2 points)").arg(trimmed).arg(points.size()));
            });
    connect(m_client, &InfluxDbClient::failed, this, [this](const QString &errorMessage) {
        setStatus(tr("Error: %1").arg(errorMessage));
    });

    m_client->query(InfluxDbClient::buildSelectQuery(QStringLiteral("sensor"), QStringLiteral("1h")));
}

void ConnectionManager::setStatus(const QString &status)
{
    if (m_status == status) {
        return;
    }
    m_status = status;
    emit statusChanged();
}

void ConnectionManager::loadRecentServers()
{
    QSettings settings(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("Komaro"),
                        QStringLiteral("QmlApp"));
    m_recentServers = settings.value(QLatin1String(kRecentServersKey)).toStringList();
}

void ConnectionManager::saveRecentServers()
{
    QSettings settings(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("Komaro"),
                        QStringLiteral("QmlApp"));
    settings.setValue(QLatin1String(kRecentServersKey), m_recentServers);
}

} // namespace komaro::core
