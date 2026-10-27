#include <QGuiApplication>
#include <QIcon>
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

    // Window icon: the app-id (Wayland) / WM_CLASS must match the installed
    // komaro-desktop.desktop for the shell to pick up its Icon= entry; Qt
    // otherwise defaults it to the executable name (komaro_qml_desktop).
    // The theme lookup covers an installed icon; the bundled SVG covers
    // running from a build tree (needs the Qt SVG image plugin).
    QGuiApplication::setDesktopFileName(QStringLiteral("komaro-desktop"));
#ifdef KOMARO_HAVE_QT_SVG
    QGuiApplication::setWindowIcon(QIcon::fromTheme(
        QStringLiteral("komaro-desktop"),
        QIcon(QStringLiteral(":/icons/komaro-desktop.svg"))));
#else
    QGuiApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("komaro-desktop")));
#endif

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    auto *connectionManager = new komaro::core::ConnectionManager(&app);
    engine.rootContext()->setContextProperty("connectionManager", connectionManager);

    auto *chartController = new komaro::core::ChartController(&app);
    engine.rootContext()->setContextProperty("chartController", chartController);

    // __DATE__/__TIME__ reflect when this translation unit was last compiled,
    // not necessarily the whole app - fine for an About-dialog build stamp,
    // just don't expect it to update unless main.cpp itself gets recompiled.
    engine.rootContext()->setContextProperty("appBuildTimestamp", QStringLiteral(__DATE__ " " __TIME__));

    engine.loadFromModule("KomaroDesktop", "Main");

    return app.exec();
}
