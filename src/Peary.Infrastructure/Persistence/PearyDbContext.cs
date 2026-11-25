using Microsoft.EntityFrameworkCore;

namespace Peary.Infrastructure.Persistence;

public sealed class PearyDbContext(DbContextOptions<PearyDbContext> options) : DbContext(options)
{
    protected override void OnModelCreating(ModelBuilder modelBuilder) =>
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(PearyDbContext).Assembly);
}
