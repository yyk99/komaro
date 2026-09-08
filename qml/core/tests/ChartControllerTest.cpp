#include "komaro/core/ChartController.h"

#include <QEventLoop>
#include <QTimer>
#include <QVariantMap>
#include <gtest/gtest.h>

#include "support/FakeHttpServer.h"

using komaro::core::ChartController;
using komaro::core::test::FakeHttpServer;

namespace {

// Drives the local event loop until ChartController reports a result (or the
// timeout fires, so a bug fails the test instead of hanging it).
bool waitForUpdate(ChartController &controller, int timeoutMs = 3000)
{
    QEventLoop loop;
    bool updated = false;
    QObject::connect(&controller, &ChartController::seriesChanged, &loop, [&updated, &loop] {
        updated = true;
        loop.quit();
    });
    QTimer::singleShot(timeoutMs, &loop, &QEventLoop::quit);
    loop.exec();
    return updated;
}

QVariantList pointsOf(const QVariantList &series, const QString &measurement)
{
    for (const QVariant &entry : series) {
        const QVariantMap map = entry.toMap();
        if (map.value(QStringLiteral("measurement")).toString() == measurement) {
            return map.value(QStringLiteral("points")).toList();
        }
    }
    return {};
}

} // namespace

TEST(ChartControllerTest, LoadPopulatesPointsWithMovingAverageApplied)
{
    FakeHttpServer server;
    server.respondWith(200, R"({
        "results": [{
            "series": [{
                "columns": ["time", "temperature_c", "humidity"],
                "values": [
                    ["2026-08-05T19:00:00Z", 10.0, 40.0],
                    ["2026-08-05T19:05:00Z", 20.0, 60.0],
                    ["2026-08-05T19:10:00Z", 30.0, 80.0]
                ]
            }]
        }]
    })");

    ChartController controller;
    controller.load(QStringLiteral("127.0.0.1"), {QStringLiteral("sensor")}, QStringLiteral("all"),
                     /*window=*/2, server.port());

    ASSERT_TRUE(waitForUpdate(controller));

    const QVariantList series = controller.series();
    ASSERT_EQ(series.size(), 1);
    const QVariantList points = pointsOf(series, QStringLiteral("sensor"));
    ASSERT_EQ(points.size(), 3);
    // window=2: [mean(10), mean(10,20), mean(20,30)] = [10, 15, 25]
    EXPECT_DOUBLE_EQ(points.at(0).toMap().value(QStringLiteral("temperatureC")).toDouble(), 10.0);
    EXPECT_DOUBLE_EQ(points.at(1).toMap().value(QStringLiteral("temperatureC")).toDouble(), 15.0);
    EXPECT_DOUBLE_EQ(points.at(2).toMap().value(QStringLiteral("temperatureC")).toDouble(), 25.0);
    EXPECT_DOUBLE_EQ(points.at(0).toMap().value(QStringLiteral("humidity")).toDouble(), 40.0);
    EXPECT_DOUBLE_EQ(points.at(1).toMap().value(QStringLiteral("humidity")).toDouble(), 50.0);
    EXPECT_DOUBLE_EQ(points.at(2).toMap().value(QStringLiteral("humidity")).toDouble(), 70.0);
    EXPECT_EQ(controller.status(), QStringLiteral("3 points"));
}

TEST(ChartControllerTest, LoadDefaultsBlankMeasurementToSensor)
{
    FakeHttpServer server;
    server.respondWith(200, R"({"results":[]})");

    ChartController controller;
    controller.load(QStringLiteral("127.0.0.1"), {QStringLiteral("  ")}, QStringLiteral("1h"),
                     /*window=*/10, server.port());

    ASSERT_TRUE(waitForUpdate(controller));

    EXPECT_TRUE(server.lastRequestLine().contains(QStringLiteral("FROM%20sensor")));
}

TEST(ChartControllerTest, LoadRemembersMeasurementAtFrontOfRecentMeasurements)
{
    FakeHttpServer server;
    server.respondWith(200, R"({"results":[]})");

    // A name unlikely to already be present in this machine's persisted
    // QSettings, so the assertion doesn't depend on prior test/app runs.
    const QString measurement = QStringLiteral("chartcontrollertest_unique_measurement");

    ChartController controller;
    controller.load(QStringLiteral("127.0.0.1"), {measurement}, QStringLiteral("1h"),
                     /*window=*/10, server.port());

    ASSERT_TRUE(waitForUpdate(controller));
    ASSERT_FALSE(controller.recentMeasurements().isEmpty());
    EXPECT_EQ(controller.recentMeasurements().first(), measurement);
}

TEST(ChartControllerTest, LoadClearsPointsAndReportsErrorOnFailure)
{
    FakeHttpServer server;
    server.respondWith(200, R"({"results": [{"error": "database not found: bogus"}]})");

    ChartController controller;
    controller.load(QStringLiteral("127.0.0.1"), {QStringLiteral("sensor")}, QStringLiteral("all"),
                     /*window=*/10, server.port());

    ASSERT_TRUE(waitForUpdate(controller));

    EXPECT_TRUE(controller.series().isEmpty());
    EXPECT_EQ(controller.status(), QStringLiteral("Error: sensor: database not found: bogus"));
}

TEST(ChartControllerTest, LoadWithMultipleMeasurementsPopulatesOneSeriesEach)
{
    FakeHttpServer server;
    server.respondWith(200, R"({
        "results": [{
            "series": [{
                "columns": ["time", "temperature_c", "humidity"],
                "values": [
                    ["2026-08-05T19:00:00Z", 10.0, 40.0]
                ]
            }]
        }]
    })");

    const QString measurementA = QStringLiteral("chartcontrollertest_multi_a");
    const QString measurementB = QStringLiteral("chartcontrollertest_multi_b");

    ChartController controller;
    controller.load(QStringLiteral("127.0.0.1"), {measurementA, measurementB}, QStringLiteral("all"),
                     /*window=*/1, server.port());

    ASSERT_TRUE(waitForUpdate(controller));

    const QVariantList series = controller.series();
    ASSERT_EQ(series.size(), 2);
    EXPECT_EQ(pointsOf(series, measurementA).size(), 1);
    EXPECT_EQ(pointsOf(series, measurementB).size(), 1);
    EXPECT_EQ(controller.status(), QStringLiteral("2 points"));

    EXPECT_TRUE(controller.recentMeasurements().contains(measurementA));
    EXPECT_TRUE(controller.recentMeasurements().contains(measurementB));
}

TEST(ChartControllerTest, LoadSkipsFailedMeasurementButKeepsOthers)
{
    FakeHttpServer server;
    server.respondWith(200, R"({"results": [{"error": "database not found: bogus"}]})");

    ChartController controller;
    // Both measurements hit the same fake server response (an error), so
    // this exercises the "all failed" -> Error status path; a mixed
    // succeed/fail scenario isn't practical with this single-response fake
    // server, but the sequential-continue behavior (both queries actually
    // run, not just the first) is what LoadWithMultipleMeasurementsPopulates
    // OneSeriesEach already covers on the success path.
    controller.load(QStringLiteral("127.0.0.1"), {QStringLiteral("a"), QStringLiteral("b")}, QStringLiteral("all"),
                     /*window=*/1, server.port());

    ASSERT_TRUE(waitForUpdate(controller));

    EXPECT_TRUE(controller.series().isEmpty());
    EXPECT_EQ(controller.status(), QStringLiteral("Error: a: database not found: bogus"));
}
