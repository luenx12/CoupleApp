using CoupleApp.Application.Handlers;
using CoupleApp.Application.Services;
using CoupleApp.Core.Interfaces.Services;
using Microsoft.Extensions.DependencyInjection;

namespace CoupleApp.Application;

/// <summary>
/// Extension method to register Application layer services with the DI container.
/// </summary>
public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        // MediatR — scans this assembly for all IRequestHandler<,> implementations
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(DependencyInjection).Assembly));

        // Application services
        services.AddScoped<IMessageService, MessageService>();

        return services;
    }
}
