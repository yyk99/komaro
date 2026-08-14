#include "komaro/core/MovingAverage.h"

#include <algorithm>

namespace komaro::core {

std::vector<double> MovingAverage::smooth(const std::vector<double> &data, int window)
{
    if (window < 2 || static_cast<int>(data.size()) < window) {
        return data;
    }

    std::vector<double> out;
    out.reserve(data.size());

    double sum = 0.0;
    for (size_t i = 0; i < data.size(); ++i) {
        sum += data[i];
        if (static_cast<int>(i) >= window) {
            sum -= data[i - static_cast<size_t>(window)];
        }
        const int count = std::min(static_cast<int>(i) + 1, window);
        out.push_back(sum / count);
    }

    return out;
}

} // namespace komaro::core
