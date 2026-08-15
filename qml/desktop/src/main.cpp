#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "komaro/core/ChartController.h"
#include "komaro/core/ConnectionManager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    auto *connectionManager = new komaro::core::ConnectionManager(&app);
    engine.rootContext()->setContextProperty("connectionManager", connectionManager);

    auto *chartController = new komaro::core::ChartController(&app);
    engine.rootContext()->setContextProperty("chartController", chartController);

    engine.loadFromModule("KomaroDesktop", "Main");

    return app.exec();
}
