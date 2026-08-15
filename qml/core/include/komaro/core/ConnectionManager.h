#pragma once

#include <QObject>
#include <QStringList>

namespace komaro::core {

// Exposed to QML via QQmlContext::setContextProperty (not QML_ELEMENT: it's
// a single C++-owned instance per app, not something QML instantiates
// itself). Owns the recent-server history (persisted via QSettings) and
// tracks which host is currently selected; actual querying is
// ChartController's job (see ../../README.md for why the two are split).
class ConnectionManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList recentServers READ recentServers NOTIFY recentServersChanged)
    Q_PROPERTY(QString currentHost READ currentHost NOTIFY currentHostChanged)

public:
    explicit ConnectionManager(QObject *parent = nullptr);

    QStringList recentServers() const;
    QString currentHost() const;

    Q_INVOKABLE void connectToServer(const QString &host);

signals:
    void recentServersChanged();
    void currentHostChanged();

private:
    void loadRecentServers();
    void saveRecentServers();

    QStringList m_recentServers;
    QString m_currentHost;
};

} // namespace komaro::core
