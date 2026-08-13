#pragma once

#include <QByteArray>
#include <vector>

#include "komaro/core/SensorPoint.h"

namespace komaro::core {

// Parses an InfluxDB /query JSON response of the form
//   {"results":[{"series":[{"columns":[...],"values":[[...]]}]}]}
// into SensorPoint values, matching columns by name ("time",
// "temperature_c", "humidity"). Throws std::runtime_error if the
// response is not valid JSON or InfluxDB reported an error.
class InfluxResponseParser
{
public:
    static std::vector<SensorPoint> parse(const QByteArray &json);
};

} // namespace komaro::core
