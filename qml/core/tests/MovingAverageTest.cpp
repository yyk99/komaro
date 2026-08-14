#include "komaro/core/MovingAverage.h"

#include <gtest/gtest.h>

using komaro::core::MovingAverage;

TEST(MovingAverageTest, ReturnsInputUnchangedWhenWindowBelowTwo)
{
    const std::vector<double> data = {1.0, 2.0, 3.0};

    EXPECT_EQ(MovingAverage::smooth(data, 1), data);
}

TEST(MovingAverageTest, ReturnsInputUnchangedWhenFewerSamplesThanWindow)
{
    const std::vector<double> data = {1.0, 2.0};

    EXPECT_EQ(MovingAverage::smooth(data, 5), data);
}

TEST(MovingAverageTest, RampsUpToFullWindowThenSlides)
{
    const std::vector<double> data = {1.0, 2.0, 3.0, 4.0, 5.0};

    const std::vector<double> result = MovingAverage::smooth(data, 3);

    ASSERT_EQ(result.size(), 5u);
    EXPECT_DOUBLE_EQ(result[0], 1.0); // mean(1)
    EXPECT_DOUBLE_EQ(result[1], 1.5); // mean(1,2)
    EXPECT_DOUBLE_EQ(result[2], 2.0); // mean(1,2,3)
    EXPECT_DOUBLE_EQ(result[3], 3.0); // mean(2,3,4)
    EXPECT_DOUBLE_EQ(result[4], 4.0); // mean(3,4,5)
}
