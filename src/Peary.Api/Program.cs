using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using Peary.Api.Common;
using Peary.Application;
using Peary.Infrastructure;
using Peary.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.AddInfrastructure();
builder.Services.AddApplication();

builder.Services.AddProblemDetails();
// .NET 10: validates DataAnnotations on endpoint parameters and returns a 400 ValidationProblem
builder.Services.AddValidation();
builder.Services.AddExceptionHandler<DomainExceptionHandler>();

// Entra External ID tokens on every endpoint by default; a made-up user in local development (see Authentication)
builder.AddPearyAuthentication();

// In Azure, TLS terminates at the Container Apps ingress, which forwards plain HTTP plus X-Forwarded-* headers.
// Without this the app would think every request is HTTP and log the ingress IP instead of the client's.
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    // The ingress IPs are not known in advance
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

builder.Services.AddOpenApi();

var app = builder.Build();

// First, so everything after it sees the original scheme and client IP
app.UseForwardedHeaders();

app.UseExceptionHandler();
app.UseStatusCodePages();

app.UseAuthentication();
app.UseAuthorization();

app.MapDefaultEndpoints();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi().AllowAnonymous();

    // Dev only: in Azure, migrations run from the pipeline as a bundle
    await using var scope = app.Services.CreateAsyncScope();
    await scope.ServiceProvider.GetRequiredService<PearyDbContext>().Database.MigrateAsync();
}

await app.RunAsync();

/// <summary>Visible to the API tests' WebApplicationFactory.</summary>
public partial class Program;
