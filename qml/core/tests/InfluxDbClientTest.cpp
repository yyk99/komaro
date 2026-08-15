#include "komaro/core/InfluxDbClient.h"

#include <QEventLoop>
#include <QHostAddress>
#include <QTcpServer>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <gtest/gtest.h>

#include "support/FakeHttpServer.h"

using komaro::core::InfluxDbClient;
using komaro::core::SensorPoint;
using komaro::core::test::FakeHttpServer;

namespace {

struct QueryResult
{
    bool succeeded = false;
    bool timedOut = false;
    std::vector<SensorPoint> points;
    QString errorMessage;
};

// Drives the local event loop until InfluxDbClient reports a result (or the
// timeout fires, so a transport bug fails the test instead of hanging it).
QueryResult runQuery(InfluxDbClient &client, const QString &influxQl, int timeoutMs = 3000)
{
    QueryResult result;
    QEventLoop loop;

    QObject::connect(&client, &InfluxDbClient::succeeded, &loop,
                      [&result, &loop](const std::vector<SensorPoint> &points) {
                          result.succeeded = true;
                          result.points = points;
                          loop.quit();
                      });
    QObject::connect(&client, &InfluxDbClient::failed, &loop, [&result, &loop](const QString &message) {
        result.errorMessage = message;
        loop.quit();
    });
    QTimer::singleShot(timeoutMs, &loop, [&result, &loop] {
        result.timedOut = true;
        loop.quit();
    });

    client.query(influxQl);
    loop.exec();
    return result;
}

} // namespace

TEST(InfluxDbClientTest, BuildSelectQueryAddsTimeRangeClause)
{
    EXPECT_EQ(InfluxDbClient::buildSelectQuery(QStringLiteral("sensor"), QStringLiteral("1h")),
              QStringLiteral("SELECT temperature_c, humidity FROM sensor WHERE time > now() - 1h"));
}

TEST(InfluxDbClientTest, BuildSelectQueryOmitsClauseForAll)
{
    EXPECT_EQ(InfluxDbClient::buildSelectQuery(QStringLiteral("sensor"), QStringLiteral("all")),
              QStringLiteral("SELECT temperature_c, humidity FROM sensor"));
}

TEST(InfluxDbClientTest, QueryEmitsSucceededWithParsedPoints)
{
    FakeHttpServer server;
    server.respondWith(200, R"({
        "results": [{
            "series": [{
                "columns": ["time", "temperature_c", "humidity"],
                "values": [["2026-08-05T19:05:03.476179Z", 21.5, 48.2]]
            }]
        }]
    })");

    InfluxDbClient client(QStringLiteral("127.0.0.1"), server.port());
    const QueryResult result =
        runQuery(client, InfluxDbClient::buildSelectQuery(QStringLiteral("sensor"), QStringLiteral("all")));

    ASSERT_FALSE(result.timedOut);
    ASSERT_TRUE(result.succeeded);
    ASSERT_EQ(result.points.size(), 1u);
    EXPECT_DOUBLE_EQ(result.points[0].temperatureC, 21.5);
    EXPECT_DOUBLE_EQ(result.points[0].humidity, 48.2);
}

TEST(InfluxDbClientTest, QueryEmitsFailedOnInfluxError)
{
    FakeHttpServer server;
    server.respondWith(200, R"({"results": [{"error": "database not found: bogus"}]})");

    InfluxDbClient client(QStringLiteral("127.0.0.1"), server.port());
    const QueryResult result =
        runQuery(client, InfluxDbClient::buildSelectQuery(QStringLiteral("sensor"), QStringLiteral("all")));

    ASSERT_FALSE(result.timedOut);
    EXPECT_FALSE(result.succeeded);
    EXPECT_EQ(result.errorMessage, QStringLiteral("database not found: bogus"));
}

TEST(InfluxDbClientTest, QueryEmitsFailedOnConnectionRefused)
{
    QTcpServer probe;
    ASSERT_TRUE(probe.listen(QHostAddress::LocalHost));
    const quint16 refusedPort = probe.serverPort();
    probe.close();

    // Windows' loopback stack can take a few seconds to report ECONNREFUSED
    // (observed ~4s), well past the 3s default used by the other tests here.
    InfluxDbClient client(QStringLiteral("127.0.0.1"), refusedPort);
    const QueryResult result = runQuery(
        client, InfluxDbClient::buildSelectQuery(QStringLiteral("sensor"), QStringLiteral("all")), 8000);

    ASSERT_FALSE(result.timedOut);
    EXPECT_FALSE(result.succeeded);
    EXPECT_FALSE(result.errorMessage.isEmpty());
}

TEST(InfluxDbClientTest, QuerySendsDatabaseAndQueryAsUrlParameters)
{
    FakeHttpServer server;
    server.respondWith(200, R"({"results":[]})");

    InfluxDbClient client(QStringLiteral("127.0.0.1"), server.port(), QStringLiteral("testdb"));
    const QString influxQl = InfluxDbClient::buildSelectQuery(QStringLiteral("sensor"), QStringLiteral("1h"));
    const QueryResult result = runQuery(client, influxQl);

    ASSERT_FALSE(result.timedOut);
    ASSERT_TRUE(result.succeeded);

    const QStringList requestParts = server.lastRequestLine().split(' ');
    ASSERT_EQ(requestParts.size(), 3);
    const QUrlQuery requestQuery(QUrl(QStringLiteral("http://127.0.0.1") + requestParts.at(1)));
    EXPECT_EQ(requestQuery.queryItemValue(QStringLiteral("db"), QUrl::FullyDecoded), QStringLiteral("testdb"));
    EXPECT_EQ(requestQuery.queryItemValue(QStringLiteral("q"), QUrl::FullyDecoded), influxQl);
}
