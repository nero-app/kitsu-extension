The `tracker` interface stores viewing state for series.

Entries are grouped into a fixed set of states rather than custom lists. An
entry wraps a `series` with the viewing progress and other
tracking information associated with it.

Series identifiers are in the identifier space of the implementation. They
are opaque to callers and must be passed back unchanged. The implementation
is responsible for resolving an identifier to the corresponding series.