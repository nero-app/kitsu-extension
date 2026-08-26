The `interaction` interface provides a set of functions to request values
from, and present information to, the person operating the host
application.

Nothing here describes how a request is presented. Callers must not assume
any particular presentation.

A function that requests a value waits until the host supplies an answer or
determines that none will be supplied. The latter is reported as `none`
rather than as an error and may mean, for example, that the person dismissed
the request, that the host could not present it, or that the host declined to
do so. Callers must treat an unanswered request as an ordinary outcome.