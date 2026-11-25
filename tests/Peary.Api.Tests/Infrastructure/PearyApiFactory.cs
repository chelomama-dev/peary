using System.Net.Http.Headers;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Peary.Infrastructure;
using Testcontainers.MsSql;

namespace Peary.Api.Tests.Infrastructure;

/// <summary>
/// Boots the real API in memory (same Program.cs, DI and middleware) against a throwaway SQL Server container, with
/// Entra configured for a made-up tenant whose tokens the tests sign themselves.
/// </summary>
public sealed class PearyApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private static readonly Guid TenantId = Guid.NewGuid();

    public static readonly string Authority = $"https://{TenantId}.ciamlogin.com/{TenantId}/v2.0";
    public static readonly string Audience = Guid.NewGuid().ToString();

    private readonly MsSqlContainer _container = new MsSqlBuilder("mcr.microsoft.com/mssql/server:2022-latest").Build();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // Replaces the connection string the AppHost injects when running under Aspire.
        // The environment stays Development, so Program.cs applies the real migrations on startup.
        builder.UseSetting($"ConnectionStrings:{DependencyInjection.DatabaseName}", _container.GetConnectionString());

        // The real Entra validation, not the development sign-in
        builder.UseSetting("Entra:Authority", Authority);
        builder.UseSetting("Entra:Audience", Audience);

        // Trust the tests' signing key instead of downloading the tenant's keys (no network, no real users).
        // Only the keys change: issuer, audience, lifetime and scope are checked with the real configuration.
        builder.ConfigureTestServices(services =>
        {
            services.PostConfigure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, options =>
            {
                var configuration = new OpenIdConnectConfiguration { Issuer = options.Authority };
                configuration.SigningKeys.Add(TestTokens.SigningKey);
                options.ConfigurationManager = new StaticConfigurationManager<OpenIdConnectConfiguration>(configuration);
            });
        });
    }

    /// <summary>A valid token for the configured tenant and API, ready to tweak with <c>with</c>.</summary>
    public static TokenSettings ValidToken() => new(Authority, Audience);

    /// <summary>A client signed in as a brand-new user.</summary>
    public HttpClient CreateAuthenticatedClient() => CreateClient(TestTokens.Create(ValidToken()));

    public HttpClient CreateClient(string accessToken)
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        return client;
    }

    public Task InitializeAsync() => _container.StartAsync();

    public new async Task DisposeAsync()
    {
        await base.DisposeAsync();
        await _container.DisposeAsync();
    }
}

/// <summary>
/// Shares one API + container across every test class in the collection: starting SQL Server takes seconds.
/// </summary>
[CollectionDefinition(Name)]
public sealed class ApiCollection : ICollectionFixture<PearyApiFactory>
{
    public const string Name = "Api";
}
