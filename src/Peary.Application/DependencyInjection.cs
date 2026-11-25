using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Peary.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        // Real clock in production; tests pass a fixed one. TryAdd lets the host register its own first
        services.TryAddSingleton(TimeProvider.System);

        return services;
    }
}
