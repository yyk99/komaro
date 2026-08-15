#pragma once

#include <QStringList>

namespace komaro::core {

// Pure list-management logic for a most-recently-used server address list,
// kept separate from QSettings I/O so it can be unit-tested directly.
class RecentServers
{
public:
    // Returns `existing` with `server` moved (or inserted) at the front,
    // trimmed, deduplicated case-insensitively, and capped to `maxCount`
    // entries. A blank `server` (after trimming) returns `existing` unchanged.
    static QStringList withServerAddedToFront(const QStringList &existing, const QString &server,
                                               int maxCount = 10);
};

} // namespace komaro::core
