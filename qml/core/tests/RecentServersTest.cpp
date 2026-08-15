#include "komaro/core/RecentServers.h"

#include <gtest/gtest.h>

using komaro::core::RecentServers;

TEST(RecentServersTest, InsertsNewServerAtFront)
{
    const QStringList result = RecentServers::withServerAddedToFront({"b.home", "c.home"}, "a.home");

    EXPECT_EQ(result, QStringList({"a.home", "b.home", "c.home"}));
}

TEST(RecentServersTest, MovesExistingServerToFrontWithoutDuplicating)
{
    const QStringList result =
        RecentServers::withServerAddedToFront({"a.home", "b.home", "c.home"}, "b.home");

    EXPECT_EQ(result, QStringList({"b.home", "a.home", "c.home"}));
}

TEST(RecentServersTest, DedupeIsCaseInsensitive)
{
    const QStringList result = RecentServers::withServerAddedToFront({"Silvana.home"}, "silvana.home");

    EXPECT_EQ(result, QStringList({"silvana.home"}));
}

TEST(RecentServersTest, TrimsWhitespace)
{
    const QStringList result = RecentServers::withServerAddedToFront({}, "  silvana.home  ");

    EXPECT_EQ(result, QStringList({"silvana.home"}));
}

TEST(RecentServersTest, IgnoresBlankServer)
{
    const QStringList result = RecentServers::withServerAddedToFront({"a.home"}, "   ");

    EXPECT_EQ(result, QStringList({"a.home"}));
}

TEST(RecentServersTest, CapsToMaxCount)
{
    const QStringList result =
        RecentServers::withServerAddedToFront({"a", "b", "c"}, "d", /*maxCount=*/3);

    EXPECT_EQ(result, QStringList({"d", "a", "b"}));
}
