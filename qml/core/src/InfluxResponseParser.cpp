#include "komaro/core/InfluxResponseParser.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <stdexcept>

namespace komaro::core {

std::vector<SensorPoint> InfluxResponseParser::parse(const QByteArray &json)
{
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        throw std::runtime_error("Invalid JSON: " + parseError.errorString().toStdString());
    }

    const QJsonArray results = doc.object().value("results").toArray();
    if (results.isEmpty()) {
        return {};
    }

    const QJsonObject result = results.first().toObject();
    if (result.contains("error")) {
        throw std::runtime_error(result.value("error").toString().toStdString());
    }

    const QJsonArray series = result.value("series").toArray();
    if (series.isEmpty()) {
        return {};
    }

    const QJsonObject firstSeries = series.first().toObject();
    const QJsonArray columns = firstSeries.value("columns").toArray();

    int timeIndex = -1;
    int temperatureIndex = -1;
    int humidityIndex = -1;
    for (int i = 0; i < columns.size(); ++i) {
        const QString name = columns.at(i).toString();
        if (name == QStringLiteral("time")) {
            timeIndex = i;
        } else if (name == QStringLiteral("temperature_c")) {
            temperatureIndex = i;
        } else if (name == QStringLiteral("humidity")) {
            humidityIndex = i;
        }
    }

    if (timeIndex < 0) {
        throw std::runtime_error("InfluxDB response missing 'time' column");
    }

    const QJsonArray values = firstSeries.value("values").toArray();

    std::vector<SensorPoint> points;
    points.reserve(static_cast<size_t>(values.size()));

    for (const QJsonValue &rowValue : values) {
        const QJsonArray row = rowValue.toArray();

        SensorPoint point;
        point.time = QDateTime::fromString(row.at(timeIndex).toString(), Qt::ISODateWithMs);
        if (temperatureIndex >= 0) {
            point.temperatureC = row.at(temperatureIndex).toDouble();
        }
        if (humidityIndex >= 0) {
            point.humidity = row.at(humidityIndex).toDouble();
        }
        points.push_back(point);
    }

    return points;
}

} // namespace komaro::core
