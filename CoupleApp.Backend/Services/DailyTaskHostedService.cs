using CoupleApp.Core.Entities;
using CoupleApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CoupleApp.Backend.Services;

public class DailyTaskHostedService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<DailyTaskHostedService> _logger;

    public DailyTaskHostedService(IServiceProvider serviceProvider, ILogger<DailyTaskHostedService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("DailyTaskHostedService is starting.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await AssignDailyTasksAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred in DailyTaskHostedService.");
            }

            // Calculate time until next midnight UTC (or local, depending on requirements)
            var now = DateTime.UtcNow;
            var nextMidnight = now.Date.AddDays(1);
            var delay = nextMidnight - now;
            
            // For MVP and testing, we can use a shorter interval (e.g. 1 hour) instead.
            // Using precise midnight logic.
            _logger.LogInformation("DailyTaskHostedService waiting {DelayTotalHours} hours until next run.", delay.TotalHours);
            await Task.Delay(delay, stoppingToken);
        }
    }

    private async Task AssignDailyTasksAsync(CancellationToken ct)
    {
        using var scope = _serviceProvider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var today = DateTime.UtcNow.Date;

        var allPairs = await db.CouplePairs.ToListAsync(ct);
        int assignedCount = 0;

        // Fetch some tasks from an imaginary pool or array
        var mockTasks = new[]
        {
            "Bugün partnerine en sevdiği kahveyi ısmarlamaya ne dersin? ☕",
            "Bugün ona uzun zamandır söylemediğin güzel bir iltifat et. ✨",
            "Akşam yemeğinde hiç denemediğiniz bir tarif deneyin. 🍝",
            "Partnerine minik bir sürpriz hediye al. 🎁",
            "Birlikte yapmaktan keyif aldığınız bir aktivite planla. 🎲"
        };
        var random = new Random();

        foreach (var pair in allPairs)
        {
            // Check if already assigned today
            var existing = await db.DailyTasks
                .AnyAsync(t => t.PairId == pair.Id && t.AssignedAt >= today, ct);

            if (!existing)
            {
                var randTask = mockTasks[random.Next(mockTasks.Length)];
                db.DailyTasks.Add(new DailyTask
                {
                    PairId = pair.Id,
                    TaskText = randTask,
                    Points = 10,
                    Category = "Genel",
                    AssignedAt = DateTime.UtcNow
                });
                assignedCount++;
            }
        }

        if (assignedCount > 0)
        {
            await db.SaveChangesAsync(ct);
            _logger.LogInformation("Assigned {Count} daily tasks to couples.", assignedCount);
        }
    }
}
