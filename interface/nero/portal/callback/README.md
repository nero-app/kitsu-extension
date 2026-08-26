The `callback` interface provides a means of being reached from outside the
host application: an address the host sets aside for the caller, and the
delivery of a single URI directed at it.

Nothing here causes a URI to be sent. Arranging that is the caller's
business — handing the address to a service that is to return to it, or to
a person who will follow a link.

A host may have no way of being reached from outside itself. That is not
exceptional, and callers are expected to carry on without.