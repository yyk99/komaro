#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "komaro/core/ConnectionManager.h"

int main(int argc, char *argv[])
{
    QQuickStyle::setStyle("Material");

    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    auto *connectionManager = new komaro::core::ConnectionManager(&app);
    engine.rootContext()->setContextProperty("connectionManager", connectionManager);

    engine.loadFromModule("KomaroMobile", "Main");

    return app.exec();
}
