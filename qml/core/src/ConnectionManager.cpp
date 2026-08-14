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

QString ConnectionManager::currentHost() const
{
    return m_currentHost;
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

    if (m_currentHost != trimmed) {
        m_currentHost = trimmed;
        emit currentHostChanged();
    }
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
