using CoupleApp.Core.Interfaces.Repositories;
using CoupleApp.Infrastructure.Persistence;
using CoupleApp.Infrastructure.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CoupleApp.Infrastructure;

/// <summary>
/// Extension method to register Infrastructure layer services with the DI container.
/// </summary>
public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // ── EF Core — PostgreSQL ──────────────────────────────────────
        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("DefaultConnection"),
                b => b.MigrationsAssembly("CoupleApp.Backend")));

        // ── Repositories ──────────────────────────────────────────────
        services.AddScoped<IMessageRepository, MessageRepository>();
        services.AddScoped<IUserRepository,    UserRepository>();
        services.AddScoped<IGalleryRepository, GalleryRepository>();

        return services;
    }
}
