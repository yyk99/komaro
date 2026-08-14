#pragma once

#include <vector>

namespace komaro::core {

// Cumulative windowed mean, matching nano/plot_sensor.py's moving_average():
// returns one output value per input sample (never shrinks the series),
// where each output is the mean of up to `window` preceding samples
// (including itself). Returns `data` unchanged if window < 2 or data has
// fewer than `window` samples.
class MovingAverage
{
public:
    static std::vector<double> smooth(const std::vector<double> &data, int window);
};

} // namespace komaro::core
