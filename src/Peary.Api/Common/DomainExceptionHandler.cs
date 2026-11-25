using Microsoft.AspNetCore.Diagnostics;
using Peary.Domain.Common;

namespace Peary.Api.Common;

/// <summary>A broken business rule is a 409 whose <c>detail</c> the app shows as is (docs/api.md, Errors).</summary>
internal sealed class DomainExceptionHandler(IProblemDetailsService problemDetails) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is not DomainException)
        {
            return false;
        }

        httpContext.Response.StatusCode = StatusCodes.Status409Conflict;
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            Exception = exception,
            ProblemDetails = { Status = StatusCodes.Status409Conflict, Detail = exception.Message },
        });
    }
}
