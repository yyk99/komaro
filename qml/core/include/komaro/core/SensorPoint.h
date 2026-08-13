#pragma once

#include <QDateTime>

namespace komaro::core {

struct SensorPoint
{
    QDateTime time;
    double temperatureC = 0.0;
    double humidity = 0.0;
};

} // namespace komaro::core
