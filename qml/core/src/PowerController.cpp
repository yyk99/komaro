#include "komaro/core/PowerController.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QUrl>
#include <QUrlQuery>
#include <QVariantMap>
#include <stdexcept>
#include <vector>

#include "komaro/core/MovingAverage.h"

namespace komaro::core {

namespace {

constexpr auto kDatabase = "ina219";
constexpr auto kMeasurement = "ina219";

struct PanelDef
{
    const char *key;
    const char *title;
    const char *unit;
    QStringList fields;
};

// Same panels as ina219_plot.py's PANELS.
const QList<PanelDef> &panelDefs()
{
    static const QList<PanelDef> defs = {
        {"voltage", "Voltage", "V", {"bus_v", "load_v"}},
        {"current", "Current", "mA", {"current_ma"}},
        {"power", "Power", "mW", {"power_mw"}},
        {"shunt", "Shunt voltage", "mV", {"shunt_mv"}},
    };
    return defs;
}

const PanelDef *findPanel(const QString &key)
{
    for (const PanelDef &def : panelDefs()) {
        if (key == QLatin1String(def.key)) {
            return &def;
        }
    }
    return nullptr;
}

QString quoteIdent(QString s)
{
    s.replace(QLatin1Char('\\'), QStringLiteral("\\\\"));
    s.replace(QLatin1Char('"'), QStringLiteral("\\\""));
    return QLatin1Char('"') + s + QLatin1Char('"');
}

QString quoteString(QString s)
{
    s.replace(QLatin1Char('\\'), QStringLiteral("\\\\"));
    s.replace(QLatin1Char('\''), QStringLiteral("\\'"));
    return QLatin1Char('\'') + s + QLatin1Char('\'');
}

QJsonObject firstSeries(const QByteArray &json)
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
    return series.isEmpty() ? QJsonObject() : series.first().toObject();
}

} // namespace

PowerController::PowerController(QObject *parent)
    : QObject(parent)
{
}

QStringList PowerController::valueKeys() const
{
    QStringList keys;
    for (const PanelDef &def : panelDefs()) {
        keys.append(QLatin1String(def.key));
    }
    return keys;
}

QString PowerController::buildQuery(const QString &sensor, const QStringList &fields, const QString &timeRange)
{
    QStringList quoted;
    for (const QString &field : fields) {
        quoted.append(quoteIdent(field));
    }
    QString query = QStringLiteral("SELECT %1 FROM %2 WHERE \"sensor\" = %3")
                        .arg(quoted.join(QStringLiteral(", ")), quoteIdent(QLatin1String(kMeasurement)),
                             quoteString(sensor));
    if (timeRange != QStringLiteral("all")) {
        query += QStringLiteral(" AND time > now() - %1").arg(timeRange);
    }
    return query;
}

QVariantList PowerController::parsePanels(const QByteArray &json, const QStringList &values, int window)
{
    const QJsonObject series = firstSeries(json);
    const QJsonArray columns = series.value("columns").toArray();
    const QJsonArray rows = series.value("values").toArray();

    QVariantList panels;
    if (columns.isEmpty()) {
        return panels;
    }

    auto columnIndex = [&columns](const QString &name) {
        for (int i = 0; i < columns.size(); ++i) {
            if (columns.at(i).toString() == name) {
                return i;
            }
        }
        return -1;
    };
    const int timeIndex = columnIndex(QStringLiteral("time"));
    if (timeIndex < 0) {
        throw std::runtime_error("InfluxDB response missing 'time' column");
    }

    for (const QString &key : values) {
        const PanelDef *def = findPanel(key);
        if (!def) {
            continue;
        }
        QVariantList panelSeries;
        for (const QString &field : def->fields) {
            const int col = columnIndex(field);
            if (col < 0) {
                continue;
            }
            // Null cells (field missing in that point) are skipped, not gaps.
            std::vector<qint64> times;
            std::vector<double> ys;
            for (const QJsonValue &rowValue : rows) {
                const QJsonArray row = rowValue.toArray();
                if (row.at(col).isNull() || row.at(col).isUndefined()) {
                    continue;
                }
                times.push_back(QDateTime::fromString(row.at(timeIndex).toString(), Qt::ISODateWithMs)
                                    .toMSecsSinceEpoch());
                ys.push_back(row.at(col).toDouble());
            }
            if (ys.empty()) {
                continue;
            }
            const std::vector<double> smoothed = MovingAverage::smooth(ys, window);
            QVariantList points;
            points.reserve(static_cast<int>(ys.size()));
            for (size_t i = 0; i < ys.size(); ++i) {
                QVariantMap point;
                point.insert(QStringLiteral("time"), times[i]);
                point.insert(QStringLiteral("value"), smoothed[i]);
                points.append(point);
            }
            QVariantMap entry;
            entry.insert(QStringLiteral("field"), field);
            entry.insert(QStringLiteral("points"), points);
            panelSeries.append(entry);
        }
        QVariantMap panel;
        panel.insert(QStringLiteral("key"), key);
        panel.insert(QStringLiteral("title"), tr(def->title));
        panel.insert(QStringLiteral("unit"), QLatin1String(def->unit));
        panel.insert(QStringLiteral("series"), panelSeries);
        panels.append(panel);
    }
    return panels;
}

QStringList PowerController::parseTagValues(const QByteArray &json)
{
    const QJsonObject series = firstSeries(json);
    QStringList out;
    for (const QJsonValue &rowValue : series.value("values").toArray()) {
        // SHOW TAG VALUES rows are ["sensor", "<value>"].
        const QJsonArray row = rowValue.toArray();
        if (row.size() >= 2) {
            out.append(row.at(1).toString());
        }
    }
    out.sort();
    return out;
}

QNetworkReply *PowerController::get(const QString &host, quint16 port, const QString &influxQl)
{
    QUrl url;
    url.setScheme(QStringLiteral("http"));
    url.setHost(host);
    url.setPort(port);
    url.setPath(QStringLiteral("/query"));
    QUrlQuery urlQuery;
    urlQuery.addQueryItem(QStringLiteral("db"), QLatin1String(kDatabase));
    urlQuery.addQueryItem(QStringLiteral("q"), influxQl);
    url.setQuery(urlQuery);
    return m_manager.get(QNetworkRequest(url));
}

void PowerController::loadSensors(const QString &host, quint16 port)
{
    const QString trimmedHost = host.trimmed();
    if (trimmedHost.isEmpty()) {
        return;
    }
    QNetworkReply *reply = get(trimmedHost, port,
                               QStringLiteral("SHOW TAG VALUES FROM %1 WITH KEY = \"sensor\"")
                                   .arg(quoteIdent(QLatin1String(kMeasurement))));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            setStatus(tr("Error: %1").arg(reply->errorString()));
            return;
        }
        try {
            const QStringList sensors = parseTagValues(reply->readAll());
            if (sensors != m_sensors) {
                m_sensors = sensors;
                emit sensorsChanged();
            }
        } catch (const std::exception &e) {
            setStatus(tr("Error: %1").arg(QString::fromStdString(e.what())));
        }
    });
}

void PowerController::load(const QString &host, const QString &sensor, const QStringList &values,
                            const QString &timeRange, int window, quint16 port)
{
    const QString trimmedHost = host.trimmed();
    const QString trimmedSensor = sensor.trimmed();
    if (trimmedHost.isEmpty() || trimmedSensor.isEmpty()) {
        return;
    }

    QStringList keys;
    QStringList fields;
    for (const QString &value : values) {
        const PanelDef *def = findPanel(value.trimmed().toLower());
        if (def && !keys.contains(QLatin1String(def->key))) {
            keys.append(QLatin1String(def->key));
            fields += def->fields;
        }
    }
    if (keys.isEmpty()) {
        return;
    }

    const int loadId = ++m_loadId; // a newer load() makes older replies stale
    setStatus(tr("Loading %1 from %2...").arg(trimmedSensor, trimmedHost));

    QNetworkReply *reply = get(trimmedHost, port, buildQuery(trimmedSensor, fields, timeRange));
    connect(reply, &QNetworkReply::finished, this, [this, reply, loadId, keys, window, trimmedSensor] {
        reply->deleteLater();
        if (loadId != m_loadId) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            setStatus(tr("Error: %1").arg(reply->errorString()));
            return;
        }
        try {
            m_panels = parsePanels(reply->readAll(), keys, window);
        } catch (const std::exception &e) {
            setStatus(tr("Error: %1").arg(QString::fromStdString(e.what())));
            return;
        }
        int total = 0;
        for (const QVariant &panel : std::as_const(m_panels)) {
            for (const QVariant &s : panel.toMap().value(QStringLiteral("series")).toList()) {
                total += s.toMap().value(QStringLiteral("points")).toList().size();
            }
        }
        setStatus(total > 0 ? tr("%1 points").arg(total) : tr("No data for sensor %1.").arg(trimmedSensor));
        emit panelsChanged();
    });
}

void PowerController::setStatus(const QString &status)
{
    if (m_status == status) {
        return;
    }
    m_status = status;
    emit statusChanged();
}

} // namespace komaro::core
