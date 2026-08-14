#include <QCoreApplication>
#include <gtest/gtest.h>

// A QCoreApplication instance is required so QNetworkAccessManager/QTcpServer
// (used by InfluxDbClientTest) have an event dispatcher to run against.
int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
