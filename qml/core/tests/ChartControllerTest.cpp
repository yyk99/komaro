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
    QObject::connect(&controller, &ChartController::pointsChanged, &loop, [&updated, &loop] {
        updated = true;
        loop.quit();
    });
    QTimer::singleShot(timeoutMs, &loop, &QEventLoop::quit);
    loop.exec();
    return updated;
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
    controller.load(QStringLiteral("127.0.0.1"), QStringLiteral("sensor"), QStringLiteral("all"),
                     /*window=*/2, server.port());

    ASSERT_TRUE(waitForUpdate(controller));

    const QVariantList points = controller.points();
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
    controller.load(QStringLiteral("127.0.0.1"), QStringLiteral("  "), QStringLiteral("1h"),
                     /*window=*/10, server.port());

    ASSERT_TRUE(waitForUpdate(controller));

    EXPECT_TRUE(server.lastRequestLine().contains(QStringLiteral("FROM%20sensor")));
}

TEST(ChartControllerTest, LoadClearsPointsAndReportsErrorOnFailure)
{
    FakeHttpServer server;
    server.respondWith(200, R"({"results": [{"error": "database not found: bogus"}]})");

    ChartController controller;
    controller.load(QStringLiteral("127.0.0.1"), QStringLiteral("sensor"), QStringLiteral("all"),
                     /*window=*/10, server.port());

    ASSERT_TRUE(waitForUpdate(controller));

    EXPECT_TRUE(controller.points().isEmpty());
    EXPECT_EQ(controller.status(), QStringLiteral("Error: database not found: bogus"));
}
