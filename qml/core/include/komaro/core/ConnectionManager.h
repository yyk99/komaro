#pragma once

#include <QObject>
#include <QStringList>

#include "komaro/core/InfluxDbClient.h"

namespace komaro::core {

// Exposed to QML via QQmlContext::setContextProperty (not QML_ELEMENT: it's
// a single C++-owned instance per app, not something QML instantiates
// itself). Owns the recent-server history (persisted via QSettings) and the
// InfluxDbClient used to test connectivity on Connect.
class ConnectionManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList recentServers READ recentServers NOTIFY recentServersChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit ConnectionManager(QObject *parent = nullptr);

    QStringList recentServers() const;
    QString status() const;

    Q_INVOKABLE void connectToServer(const QString &host);

signals:
    void recentServersChanged();
    void statusChanged();

private:
    void setStatus(const QString &status);
    void loadRecentServers();
    void saveRecentServers();

    QStringList m_recentServers;
    QString m_status;
    InfluxDbClient *m_client = nullptr;
};

} // namespace komaro::core
