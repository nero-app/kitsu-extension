The `opener` interface provides a function to hand a URI to the system
outside the host application, so that whatever is arranged to deal with its
scheme takes it from there.

A host may have nothing to hand URIs to. That is not exceptional, and
callers are expected to carry on without.