#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "komaro/core/ChartController.h"
#include "komaro/core/ConnectionManager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    // Matches ConnectionManager's QSettings(..., "Komaro", "QmlApp") org/app
    // scope, so Main.qml's QtCore Settings (UI-preference persistence) lands
    // in the same ~/.config/Komaro/ directory rather than a default-named
    // one. Not literally the same file: QtCore's Settings uses NativeFormat
    // (QmlApp.conf) while ConnectionManager forces IniFormat (QmlApp.ini).
    QCoreApplication::setOrganizationName(QStringLiteral("Komaro"));
    QCoreApplication::setApplicationName(QStringLiteral("QmlApp"));

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
