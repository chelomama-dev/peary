using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Peary.Infrastructure.Persistence;

namespace Peary.Infrastructure;

public static class DependencyInjection
{
    public const string DatabaseName = "pearydb";

    public static IHostApplicationBuilder AddInfrastructure(this IHostApplicationBuilder builder)
    {
        // A plain (not pooled) registration, so the context can take scoped services later, like the current
        // group. Aspire then adds retries, the health check and telemetry on top
        var connectionString = builder.Configuration.GetConnectionString(DatabaseName)
            ?? throw new InvalidOperationException($"Missing the '{DatabaseName}' connection string.");
        builder.Services.AddDbContext<PearyDbContext>(options => options.UseSqlServer(connectionString));
        builder.EnrichSqlServerDbContext<PearyDbContext>();

        return builder;
    }
}
