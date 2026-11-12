#include "komaro/core/PowerController.h"

#include <gtest/gtest.h>

using komaro::core::PowerController;

TEST(PowerControllerTest, BuildQueryQuotesAndBoundsTime)
{
    const QString q = PowerController::buildQuery(QStringLiteral("it's"), {"bus_v", "load_v"}, QStringLiteral("6h"));
    EXPECT_EQ(q, QStringLiteral("SELECT \"bus_v\", \"load_v\" FROM \"ina219\" WHERE \"sensor\" = 'it\\'s' "
                                "AND time > now() - 6h"));
}

TEST(PowerControllerTest, BuildQueryAllOmitsTimeClause)
{
    const QString q = PowerController::buildQuery(QStringLiteral("desk"), {"power_mw"}, QStringLiteral("all"));
    EXPECT_FALSE(q.contains(QStringLiteral("time >")));
}

TEST(PowerControllerTest, ParsePanelsSkipsNullsAndGroupsFields)
{
    const QByteArray json = R"({"results":[{"series":[{"name":"ina219",
        "columns":["time","bus_v","load_v","current_ma"],
        "values":[["2026-01-01T00:00:00Z",5.0,5.1,100.0],
                  ["2026-01-01T00:00:10Z",null,null,110.0],
                  ["2026-01-01T00:00:20Z",5.2,5.3,120.0]]}]}]})";
    const QVariantList panels = PowerController::parsePanels(json, {"voltage", "current", "bogus"}, 1);
    ASSERT_EQ(panels.size(), 2);

    const QVariantMap voltage = panels[0].toMap();
    EXPECT_EQ(voltage["key"].toString(), QStringLiteral("voltage"));
    EXPECT_EQ(voltage["unit"].toString(), QStringLiteral("V"));
    const QVariantList vSeries = voltage["series"].toList();
    ASSERT_EQ(vSeries.size(), 2);
    EXPECT_EQ(vSeries[0].toMap()["points"].toList().size(), 2); // null row skipped

    const QVariantList cSeries = panels[1].toMap()["series"].toList();
    ASSERT_EQ(cSeries.size(), 1);
    EXPECT_EQ(cSeries[0].toMap()["points"].toList().size(), 3);
}

TEST(PowerControllerTest, ParsePanelsEmptyResponse)
{
    EXPECT_TRUE(PowerController::parsePanels(R"({"results":[{}]})", {"voltage"}, 1).isEmpty());
}

TEST(PowerControllerTest, ParsePanelsThrowsOnInfluxError)
{
    EXPECT_THROW(PowerController::parsePanels(R"({"results":[{"error":"boom"}]})", {"voltage"}, 1),
                 std::runtime_error);
}

TEST(PowerControllerTest, ParseTagValuesSorted)
{
    const QByteArray json = R"({"results":[{"series":[{"name":"ina219","columns":["key","value"],
        "values":[["sensor","b"],["sensor","a"]]}]}]})";
    EXPECT_EQ(PowerController::parseTagValues(json), (QStringList{"a", "b"}));
}
