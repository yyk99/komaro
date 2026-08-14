#include "komaro/core/RecentServers.h"

namespace komaro::core {

QStringList RecentServers::withServerAddedToFront(const QStringList &existing, const QString &server,
                                                    int maxCount)
{
    const QString trimmed = server.trimmed();
    if (trimmed.isEmpty()) {
        return existing;
    }

    QStringList result;
    result.reserve(existing.size() + 1);
    result.append(trimmed);

    for (const QString &entry : existing) {
        if (entry.compare(trimmed, Qt::CaseInsensitive) != 0) {
            result.append(entry);
        }
    }

    if (result.size() > maxCount) {
        result = result.mid(0, maxCount);
    }

    return result;
}

} // namespace komaro::core
