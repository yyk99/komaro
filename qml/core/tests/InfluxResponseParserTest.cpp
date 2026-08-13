#include "komaro/core/InfluxResponseParser.h"

#include <gtest/gtest.h>

using komaro::core::InfluxResponseParser;
using komaro::core::SensorPoint;

TEST(InfluxResponseParserTest, ParsesPointsWithZSuffixedTimestamp)
{
    const QByteArray json = R"({
        "results": [{
            "series": [{
                "columns": ["time", "temperature_c", "humidity"],
                "values": [
                    ["2026-08-05T19:05:03.476179Z", 21.5, 48.2],
                    ["2026-08-05T19:10:03.476179Z", 21.7, 47.9]
                ]
            }]
        }]
    })";

    const std::vector<SensorPoint> points = InfluxResponseParser::parse(json);

    ASSERT_EQ(points.size(), 2u);
    EXPECT_TRUE(points[0].time.isValid());
    EXPECT_EQ(points[0].time.timeSpec(), Qt::UTC);
    EXPECT_DOUBLE_EQ(points[0].temperatureC, 21.5);
    EXPECT_DOUBLE_EQ(points[0].humidity, 48.2);
    EXPECT_DOUBLE_EQ(points[1].temperatureC, 21.7);
    EXPECT_DOUBLE_EQ(points[1].humidity, 47.9);
}

TEST(InfluxResponseParserTest, ReturnsEmptyForNoSeries)
{
    const QByteArray json = R"({"results": [{"statement_id": 0}]})";

    EXPECT_TRUE(InfluxResponseParser::parse(json).empty());
}

TEST(InfluxResponseParserTest, ThrowsOnInfluxError)
{
    const QByteArray json = R"({"results": [{"error": "database not found: bogus"}]})";

    EXPECT_THROW(InfluxResponseParser::parse(json), std::runtime_error);
}

TEST(InfluxResponseParserTest, ThrowsOnInvalidJson)
{
    const QByteArray json = "not json";

    EXPECT_THROW(InfluxResponseParser::parse(json), std::runtime_error);
}

TEST(InfluxResponseParserTest, ThrowsOnMissingTimeColumn)
{
    const QByteArray json = R"({
        "results": [{
            "series": [{
                "columns": ["temperature_c", "humidity"],
                "values": [[21.5, 48.2]]
            }]
        }]
    })";

    EXPECT_THROW(InfluxResponseParser::parse(json), std::runtime_error);
}
