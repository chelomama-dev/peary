using System.Net;
using Microsoft.AspNetCore.Hosting;
using Peary.Api.Tests.Infrastructure;

namespace Peary.Api.Tests;

/// <summary>
/// Every endpoint requires a valid Entra access token for this API with the access_as_user scope (fallback
/// policy). Until the first endpoint exists, a path with no endpoint is enough: authorization runs before routing
/// gives up, so a rejected token is 401/403 and an accepted one gets as far as the 404.
/// </summary>
[Collection(ApiCollection.Name)]
public class AuthenticationTests(PearyApiFactory factory)
{
    private const string ProtectedPath = "/api/nothing-here-yet";

    [Fact]
    public async Task Request_WithValidToken_IsLetThrough()
    {
        var response = await factory.CreateAuthenticatedClient().GetAsync(ProtectedPath);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Request_WithoutToken_Returns401()
    {
        var response = await factory.CreateClient().GetAsync(ProtectedPath);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Request_WithDevelopmentHeaders_Returns401WhenEntraIsConfigured()
    {
        // The development sign-in only exists without the Entra section: its headers must mean nothing here
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Dev-User-Id", Guid.NewGuid().ToString());

        var response = await client.GetAsync(ProtectedPath);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Request_WithExpiredToken_Returns401()
    {
        // Beyond the default 5 minutes of clock skew
        var token = PearyApiFactory.ValidToken() with { Expires = DateTime.UtcNow.AddMinutes(-10) };

        var response = await SendWith(token);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Request_WithTokenForAnotherApi_Returns401()
    {
        // A token the same tenant issued for a different application must not open this API
        var token = PearyApiFactory.ValidToken() with { Audience = Guid.NewGuid().ToString() };

        var response = await SendWith(token);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Request_WithTokenFromAnotherTenant_Returns401()
    {
        var otherTenant = Guid.NewGuid();
        var token = PearyApiFactory.ValidToken() with
        {
            Issuer = $"https://{otherTenant}.ciamlogin.com/{otherTenant}/v2.0",
        };

        var response = await SendWith(token);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Request_WithTokenSignedByUntrustedKey_Returns401()
    {
        // Same claims as a valid token: only the signature gives it away
        var token = PearyApiFactory.ValidToken() with { Key = TestTokens.UntrustedKey };

        var response = await SendWith(token);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("User.Read")]
    public async Task Request_WithoutAccessAsUserScope_Returns403(string? scope)
    {
        // Authenticated (valid token) but not authorized: the app didn't ask for permission to call this API
        var token = PearyApiFactory.ValidToken() with { Scope = scope };

        var response = await SendWith(token);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Request_WithScopeAmongOthers_IsLetThrough()
    {
        // scp is a space-separated list
        var token = PearyApiFactory.ValidToken() with { Scope = "openid access_as_user offline_access" };

        var response = await SendWith(token);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task RejectedToken_InProduction_DoesNotExplainWhy()
    {
        // The reason ("issuer invalid", "signature invalid"...) helps an attacker tune a forged token
        var client = factory.WithWebHostBuilder(builder => builder.UseEnvironment("Production")).CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new("Bearer", TestTokens.Create(PearyApiFactory.ValidToken() with { Audience = Guid.NewGuid().ToString() }));

        var response = await client.GetAsync(ProtectedPath);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        var challenge = Assert.Single(response.Headers.WwwAuthenticate);
        Assert.Equal("Bearer", challenge.Scheme);
        Assert.Null(challenge.Parameter);
    }

    private Task<HttpResponseMessage> SendWith(TokenSettings token) =>
        factory.CreateClient(TestTokens.Create(token)).GetAsync(ProtectedPath);
}
