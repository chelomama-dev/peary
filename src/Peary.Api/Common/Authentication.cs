using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;

namespace Peary.Api.Common;

/// <summary>The "Entra" configuration section: identifiers of the External ID tenant and this API (not secrets).</summary>
internal sealed class EntraOptions
{
    public const string SectionName = "Entra";

    /// <summary>Token issuer, e.g. https://{tenant id}.ciamlogin.com/{tenant id}/v2.0.</summary>
    [Required, Url]
    public string? Authority { get; init; }

    /// <summary>The API's application (client) id: the <c>aud</c> of v2 access tokens.</summary>
    [Required]
    public string? Audience { get; init; }

    /// <summary>Delegated scope the app must request to call the API.</summary>
    public string Scope { get; init; } = "access_as_user";
}

internal static class Authentication
{
    /// <summary>
    /// Requires a user on every endpoint unless it opts out with <c>AllowAnonymous</c> (health probes, OpenAPI).
    /// <list type="bullet">
    /// <item>With the "Entra" section: Entra External ID access tokens for this API, with its scope (ADR 0001).</item>
    /// <item>Without it, only in Development: <see cref="DevelopmentAuthenticationHandler"/>, so the API and the
    /// app can run locally with several made-up users and no tenant. Anywhere else the API refuses to start.</item>
    /// </list>
    /// </summary>
    public static WebApplicationBuilder AddPearyAuthentication(this WebApplicationBuilder builder)
    {
        var section = builder.Configuration.GetSection(EntraOptions.SectionName);
        string scheme;
        string scope;

        if (section.Exists())
        {
            var entra = section.Get<EntraOptions>()!;
            Validator.ValidateObject(entra, new ValidationContext(entra), validateAllProperties: true);
            scheme = JwtBearerDefaults.AuthenticationScheme;
            scope = entra.Scope;

            builder.Services.AddAuthentication(scheme)
                .AddJwtBearer(options =>
                {
                    // Signing keys come from {Authority}/.well-known/openid-configuration and are cached and rotated
                    options.Authority = entra.Authority;
                    options.TokenValidationParameters.ValidIssuer = entra.Authority;
                    options.TokenValidationParameters.ValidAudience = entra.Audience;

                    // Keep the token's claim names (oid, scp, email) instead of the long WS-Federation URIs
                    options.MapInboundClaims = false;
                    options.TokenValidationParameters.NameClaimType = "name";

                    // Why a token was rejected goes in WWW-Authenticate only while developing: in production it
                    // would help an attacker tune a forged token. The logs always have it
                    options.IncludeErrorDetails = builder.Environment.IsDevelopment();
                });
        }
        else
        {
            if (!builder.Environment.IsDevelopment())
            {
                throw new InvalidOperationException(
                    $"The '{EntraOptions.SectionName}' configuration section is required outside Development.");
            }

            scheme = DevelopmentAuthenticationHandler.SchemeName;
            scope = DevelopmentAuthenticationHandler.Scope;
            builder.Services.AddAuthentication(scheme)
                .AddScheme<AuthenticationSchemeOptions, DevelopmentAuthenticationHandler>(scheme, null);
        }

        var requireApiScope = new AuthorizationPolicyBuilder(scheme)
            .RequireAuthenticatedUser()
            .RequireClaim("oid")
            .RequireAssertion(context => HasScope(context.User, scope))
            .Build();

        builder.Services.AddAuthorizationBuilder()
            // RequireAuthorization() without a policy
            .SetDefaultPolicy(requireApiScope)
            // Endpoints with no authorization metadata at all: secure by default
            .SetFallbackPolicy(requireApiScope);

        builder.Services.AddHttpContextAccessor();
        builder.Services.AddScoped<Application.Abstractions.ICurrentUser, HttpCurrentUser>();

        return builder;
    }

    // scp is a space-separated list, e.g. "openid access_as_user"
    private static bool HasScope(ClaimsPrincipal user, string scope) =>
        user.FindFirst("scp")?.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries).Contains(scope) ?? false;
}

/// <summary>
/// Local development only (never registered outside Development): every request is signed in as the user its
/// <c>X-Dev-User-*</c> headers describe, or as a default one. Lets the app and <c>Peary.Api.http</c> act as different
/// family members without an Entra tenant.
/// </summary>
internal sealed class DevelopmentAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "Development";
    public const string Scope = "access_as_user";

    public const string UserIdHeader = "X-Dev-User-Id";
    public const string EmailHeader = "X-Dev-User-Email";
    public const string NameHeader = "X-Dev-User-Name";

    public static readonly Guid DefaultUserId = new("00000000-0000-0000-0000-000000000001");

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var headers = Request.Headers;
        var userId = DefaultUserId;
        if (headers.TryGetValue(UserIdHeader, out var rawId) && !Guid.TryParse(rawId, out userId))
        {
            return Task.FromResult(AuthenticateResult.Fail($"{UserIdHeader} must be a GUID."));
        }

        var email = headers.TryGetValue(EmailHeader, out var rawEmail) ? rawEmail.ToString() : "dev@example.com";
        var name = headers.TryGetValue(NameHeader, out var rawName) ? rawName.ToString() : "Dev";

        Claim[] claims =
        [
            new("oid", userId.ToString()),
            new("email", email),
            new("name", name),
            new("scp", Scope),
        ];
        var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, SchemeName, "name", null));
        return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(principal, SchemeName)));
    }
}

/// <summary>The signed-in user from the request's claims. Only used behind the authorization policy, so oid exists.</summary>
internal sealed class HttpCurrentUser(IHttpContextAccessor accessor) : Application.Abstractions.ICurrentUser
{
    private ClaimsPrincipal User =>
        accessor.HttpContext?.User ?? throw new InvalidOperationException("There is no current request.");

    public Guid ObjectId => Guid.Parse(User.FindFirst("oid")!.Value);

    public string? Name => User.FindFirst("name")?.Value;

    public string? Email => User.FindFirst("email")?.Value;
}
