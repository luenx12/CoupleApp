using System.Text;
using CoupleApp.Application;
using CoupleApp.Infrastructure;
using CoupleApp.Infrastructure.Persistence;
using CoupleApp.Core.Entities;
using CoupleApp.Backend.Hubs;
using CoupleApp.Backend.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// ════════════════════════════════════════════════════════════════════
//  1. CLEAN ARCHITECTURE LAYERS
// ════════════════════════════════════════════════════════════════════
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

// ════════════════════════════════════════════════════════════════════
//  2. AUTHENTICATION — JWT Bearer
// ════════════════════════════════════════════════════════════════════
// JWT Secret: read from config (which in production is overridden by
// ASPNETCORE environment variables using Jwt__Secret naming convention,
// e.g. docker-compose env: JWT_SECRET should be mapped to Jwt__Secret)
var jwtSecret = builder.Configuration["Jwt:Secret"]
    ?? Environment.GetEnvironmentVariable("JWT_SECRET")
    ?? throw new InvalidOperationException(
        "JWT secret is not configured. Set 'Jwt:Secret' in appsettings or 'Jwt__Secret' environment variable.");

if (jwtSecret.Contains("CHANGE_ME") || jwtSecret.Contains("${"))
{
    // Running with default/placeholder key — use a stable derived key for dev
    // In PRODUCTION this must be overridden via environment variable!
    if (!builder.Environment.IsDevelopment())
        throw new InvalidOperationException("Production JWT secret must not use placeholder values!");
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret))
        };

        // Allow JWT via query-string for SignalR WebSocket connections
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"].ToString();
                var path = ctx.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(token) && path.StartsWithSegments("/hubs/couple"))
                    ctx.Token = token;
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();

// ════════════════════════════════════════════════════════════════════
//  3. SIGNALR
// ════════════════════════════════════════════════════════════════════
builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = builder.Environment.IsDevelopment();
    // Production-tuned values:
    // KeepAlive pings the client every 25s to keep WebSocket alive through Nginx
    options.KeepAliveInterval = TimeSpan.FromSeconds(25);
    // Client must respond within 60s — gives room for mobile sleep/background
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(60);
    // Handshake must complete within 15s (default 15s — explicit for clarity)
    options.HandshakeTimeout = TimeSpan.FromSeconds(15);
    // Allow larger payloads for encrypted media messages
    options.MaximumReceiveMessageSize = 512 * 1024; // 512 KB
});

// ════════════════════════════════════════════════════════════════════
//  4. SINGLETON SERVICES & HOSTED SERVICES
// ════════════════════════════════════════════════════════════════════
builder.Services.AddSingleton<IConnectionManager, ConnectionManager>();
builder.Services.AddSingleton<IFirebaseService, FirebaseService>();
builder.Services.AddHostedService<DailyTaskHostedService>();

// ════════════════════════════════════════════════════════════════════
//  5. CONTROLLERS + SWAGGER
// ════════════════════════════════════════════════════════════════════
builder.Services.AddControllers()
    .AddJsonOptions(o =>
    {
        // Ensure all API responses use camelCase so Flutter clients get:
        // "accessToken", "refreshToken", "id", "mediaId", "inviteCode" etc.
        o.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
        o.JsonSerializerOptions.DictionaryKeyPolicy  = System.Text.Json.JsonNamingPolicy.CamelCase;
        o.JsonSerializerOptions.DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull;
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "CoupleApp API",
        Version = "v1",
        Description = "Zero-Leak E2EE Couple Application Backend — Clean Architecture"
    });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Enter your JWT token (without 'Bearer' prefix)"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
            },
            Array.Empty<string>()
        }
    });
});

// ════════════════════════════════════════════════════════════════════
//  6. CORS — development only; tighten in production
// ════════════════════════════════════════════════════════════════════
builder.Services.AddCors(o => o.AddPolicy("DevPolicy", p =>
    p.WithOrigins(
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8080",
        "http://localhost:8081",
        "http://209.38.238.55",
        "https://209.38.238.55"
     )
     .AllowAnyHeader()
     .AllowAnyMethod()
     .AllowCredentials()));

// ════════════════════════════════════════════════════════════════════
//  BUILD
// ════════════════════════════════════════════════════════════════════
var app = builder.Build();

// ── Auto-migrate on startup (dev convenience) ────────────────────
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.Migrate();
}

// ── Middleware pipeline ──────────────────────────────────────────

app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "CoupleApp API v1");
    c.RoutePrefix = "swagger";
});


app.UseCors("DevPolicy");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// ── SignalR Hub route ────────────────────────────────────────────
app.MapHub<CoupleHub>("/hubs/couple");

app.Run();
