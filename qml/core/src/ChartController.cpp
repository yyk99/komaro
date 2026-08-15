#include "komaro/core/ChartController.h"

#include <QVariantMap>

#include "komaro/core/MovingAverage.h"

namespace komaro::core {

ChartController::ChartController(QObject *parent)
    : QObject(parent)
{
}

QVariantList ChartController::points() const
{
    return m_points;
}

QString ChartController::status() const
{
    return m_status;
}

void ChartController::load(const QString &host, const QString &measurement, const QString &timeRange, int window,
                            quint16 port)
{
    const QString trimmedHost = host.trimmed();
    if (trimmedHost.isEmpty()) {
        return;
    }
    const QString trimmedMeasurement =
        measurement.trimmed().isEmpty() ? QStringLiteral("sensor") : measurement.trimmed();

    setStatus(tr("Loading %1 from %2...").arg(trimmedMeasurement, trimmedHost));

    delete m_client;
    m_client = new InfluxDbClient(trimmedHost, port, QStringLiteral("komaro"), this);

    connect(m_client, &InfluxDbClient::succeeded, this, [this, window](const std::vector<SensorPoint> &points) {
        if (points.empty()) {
            setStatus(tr("No data found."));
            setPoints({});
            return;
        }

        std::vector<double> temperatures;
        std::vector<double> humidities;
        temperatures.reserve(points.size());
        humidities.reserve(points.size());
        for (const SensorPoint &point : points) {
            temperatures.push_back(point.temperatureC);
            humidities.push_back(point.humidity);
        }

        const std::vector<double> smoothedTemperatures = MovingAverage::smooth(temperatures, window);
        const std::vector<double> smoothedHumidities = MovingAverage::smooth(humidities, window);

        std::vector<SensorPoint> smoothedPoints;
        smoothedPoints.reserve(points.size());
        for (size_t i = 0; i < points.size(); ++i) {
            SensorPoint smoothedPoint;
            smoothedPoint.time = points[i].time;
            smoothedPoint.temperatureC = smoothedTemperatures[i];
            smoothedPoint.humidity = smoothedHumidities[i];
            smoothedPoints.push_back(smoothedPoint);
        }

        setStatus(tr("%1 points").arg(smoothedPoints.size()));
        setPoints(smoothedPoints);
    });
    connect(m_client, &InfluxDbClient::failed, this, [this](const QString &errorMessage) {
        setStatus(tr("Error: %1").arg(errorMessage));
        setPoints({});
    });

    m_client->query(InfluxDbClient::buildSelectQuery(trimmedMeasurement, timeRange));
}

void ChartController::setStatus(const QString &status)
{
    if (m_status == status) {
        return;
    }
    m_status = status;
    emit statusChanged();
}

void ChartController::setPoints(const std::vector<SensorPoint> &points)
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
    m_points = list;
    emit pointsChanged();
}

} // namespace komaro::core
