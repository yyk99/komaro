#pragma once

#include <QByteArray>
#include <QHostAddress>
#include <QObject>
#include <QString>
#include <QTcpServer>
#include <QTcpSocket>

namespace komaro::core::test {

// Minimal HTTP/1.1 server test double: accepts a single request and replies
// with a canned status/body, so InfluxDbClient's real QNetworkAccessManager
// round-trip can be exercised without a live InfluxDB instance.
class FakeHttpServer
{
public:
    FakeHttpServer()
    {
        m_server.listen(QHostAddress::LocalHost);
        QObject::connect(&m_server, &QTcpServer::newConnection, [this] {
            QTcpSocket *socket = m_server.nextPendingConnection();
            QObject::connect(socket, &QTcpSocket::readyRead, [this, socket] { handleReadyRead(socket); });
            QObject::connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
        });
    }

    quint16 port() const { return m_server.serverPort(); }

    void respondWith(int statusCode, const QByteArray &body)
    {
        m_statusCode = statusCode;
        m_body = body;
    }

    QString lastRequestLine() const { return m_lastRequestLine; }

private:
    void handleReadyRead(QTcpSocket *socket)
    {
        m_buffer.append(socket->readAll());
        if (!m_buffer.contains("\r\n\r\n")) {
            return;
        }
        m_lastRequestLine = QString::fromUtf8(m_buffer.left(m_buffer.indexOf("\r\n")));

        const QByteArray response = "HTTP/1.1 " + QByteArray::number(m_statusCode) + " OK\r\n"
            "Content-Type: application/json\r\n"
            "Content-Length: " + QByteArray::number(m_body.size()) + "\r\n"
            "Connection: close\r\n\r\n" + m_body;
        socket->write(response);
        socket->disconnectFromHost();
    }

    QTcpServer m_server;
    int m_statusCode = 200;
    QByteArray m_body;
    QByteArray m_buffer;
    QString m_lastRequestLine;
};

} // namespace komaro::core::test
