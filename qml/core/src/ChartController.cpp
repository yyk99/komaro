#include "komaro/core/ChartController.h"

#include <QSettings>
#include <QVariantMap>

#include "komaro/core/MovingAverage.h"
#include "komaro/core/RecentServers.h"

namespace komaro::core {

namespace {
constexpr auto kRecentMeasurementsKey = "recentMeasurements";

QVariantList toVariantList(const std::vector<SensorPoint> &points)
{
    QVariantList list;
    list.reserve(static_cast<int>(points.size()));
    for (const SensorPoint &point : points) {
        QVariantMap map;
        map.insert(QStringLiteral("time"), point.time.toMSecsSinceEpoch());
        map.insert(QStringLiteral("temperatureC"), point.temperatureC);
        map.insert(QStringLiteral("humidity"), point.humidity);
        list.append(map);
    }
    return list;
}
} // namespace

ChartController::ChartController(QObject *parent)
    : QObject(parent)
{
    loadRecentMeasurements();
}

QVariantList ChartController::series() const
{
    return m_series;
}

QString ChartController::status() const
{
    return m_status;
}

QStringList ChartController::recentMeasurements() const
{
    return m_recentMeasurements;
}

void ChartController::load(const QString &host, const QStringList &measurements, const QString &timeRange,
                            int window, quint16 port)
{
    const QString trimmedHost = host.trimmed();
    if (trimmedHost.isEmpty()) {
        return;
    }

    QStringList trimmedMeasurements;
    for (const QString &measurement : measurements) {
        const QString trimmed = measurement.trimmed();
        if (!trimmed.isEmpty() && !trimmedMeasurements.contains(trimmed, Qt::CaseInsensitive)) {
            trimmedMeasurements.append(trimmed);
        }
    }
    if (trimmedMeasurements.isEmpty()) {
        trimmedMeasurements.append(QStringLiteral("sensor"));
    }

    for (const QString &measurement : trimmedMeasurements) {
        rememberMeasurement(measurement);
    }

    m_host = trimmedHost;
    m_timeRange = timeRange;
    m_window = window;
    m_port = port;
    m_pendingMeasurements = trimmedMeasurements;
    m_series = {};
    m_totalPoints = 0;
    m_firstError.clear();

    setStatus(tr("Loading %1 from %2...").arg(trimmedMeasurements.join(QStringLiteral(", ")), trimmedHost));

    startNextQuery();
}

void ChartController::startNextQuery()
{
    if (m_pendingMeasurements.isEmpty()) {
        if (!m_series.isEmpty()) {
            setStatus(tr("%1 points").arg(m_totalPoints));
        } else if (!m_firstError.isEmpty()) {
            setStatus(tr("Error: %1").arg(m_firstError));
        } else {
            setStatus(tr("No data found."));
        }
        emit seriesChanged();
        return;
    }

    const QString measurement = m_pendingMeasurements.takeFirst();

    delete m_client;
    m_client = new InfluxDbClient(m_host, m_port, QStringLiteral("komaro"), this);

    connect(m_client, &InfluxDbClient::succeeded, this,
            [this, measurement](const std::vector<SensorPoint> &points) {
                if (!points.empty()) {
                    std::vector<double> temperatures;
                    std::vector<double> humidities;
                    temperatures.reserve(points.size());
                    humidities.reserve(points.size());
                    for (const SensorPoint &point : points) {
                        temperatures.push_back(point.temperatureC);
                        humidities.push_back(point.humidity);
                    }

                    const std::vector<double> smoothedTemperatures = MovingAverage::smooth(temperatures, m_window);
                    const std::vector<double> smoothedHumidities = MovingAverage::smooth(humidities, m_window);

                    std::vector<SensorPoint> smoothedPoints;
                    smoothedPoints.reserve(points.size());
                    for (size_t i = 0; i < points.size(); ++i) {
                        SensorPoint smoothedPoint;
                        smoothedPoint.time = points[i].time;
                        smoothedPoint.temperatureC = smoothedTemperatures[i];
                        smoothedPoint.humidity = smoothedHumidities[i];
                        smoothedPoints.push_back(smoothedPoint);
                    }

                    QVariantMap seriesEntry;
                    seriesEntry.insert(QStringLiteral("measurement"), measurement);
                    seriesEntry.insert(QStringLiteral("points"), toVariantList(smoothedPoints));
                    m_series.append(seriesEntry);
                    m_totalPoints += static_cast<int>(smoothedPoints.size());
                }
                startNextQuery();
            });
    connect(m_client, &InfluxDbClient::failed, this, [this, measurement](const QString &errorMessage) {
        if (m_firstError.isEmpty()) {
            m_firstError = tr("%1: %2").arg(measurement, errorMessage);
        }
        startNextQuery();
    });

    m_client->query(InfluxDbClient::buildSelectQuery(measurement, m_timeRange));
}

void ChartController::setStatus(const QString &status)
{
    if (m_status == status) {
        return;
    }
    m_status = status;
    emit statusChanged();
}

void ChartController::rememberMeasurement(const QString &measurement)
{
    const QStringList updated = RecentServers::withServerAddedToFront(m_recentMeasurements, measurement);
    if (updated == m_recentMeasurements) {
        return;
    }
    m_recentMeasurements = updated;
    saveRecentMeasurements();
    emit recentMeasurementsChanged();
}

void ChartController::loadRecentMeasurements()
{
    QSettings settings(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("Komaro"),
                        QStringLiteral("QmlApp"));
    m_recentMeasurements = settings.value(QLatin1String(kRecentMeasurementsKey)).toStringList();
}

void ChartController::saveRecentMeasurements()
{
    QSettings settings(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("Komaro"),
                        QStringLiteral("QmlApp"));
    settings.setValue(QLatin1String(kRecentMeasurementsKey), m_recentMeasurements);
}

} // namespace komaro::core
