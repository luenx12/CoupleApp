using System.Text;
using CoupleApp.Backend.Data;
using CoupleApp.Backend.Hubs;
using CoupleApp.Backend.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// ════════════════════════════════════════════════════════════════════
//  1. DATABASE — PostgreSQL via EF Core
// ════════════════════════════════════════════════════════════════════
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// ════════════════════════════════════════════════════════════════════
//  2. AUTHENTICATION — JWT Bearer
// ════════════════════════════════════════════════════════════════════
var jwtSecret = builder.Configuration["Jwt:Secret"]!;

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer           = true,
            ValidateAudience         = true,
            ValidateLifetime         = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer              = builder.Configuration["Jwt:Issuer"],
            ValidAudience            = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey         = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret))
        };

        // Allow JWT via query-string for SignalR WebSocket connections
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"].ToString();
                var path  = ctx.HttpContext.Request.Path;
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
    options.KeepAliveInterval    = TimeSpan.FromSeconds(15);
    options.ClientTimeoutInterval= TimeSpan.FromSeconds(30);
});

// ════════════════════════════════════════════════════════════════════
//  4. DI — Application Services
// ════════════════════════════════════════════════════════════════════
builder.Services.AddSingleton<IConnectionManager, ConnectionManager>(); // Singleton: shared state

// ════════════════════════════════════════════════════════════════════
//  5. CONTROLLERS + SWAGGER
// ════════════════════════════════════════════════════════════════════
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title       = "CoupleApp API",
        Version     = "v1",
        Description = "Zero-Leak E2EE Couple Application Backend"
    });

    // Enable JWT auth in Swagger UI
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name         = "Authorization",
        Type         = SecuritySchemeType.Http,
        Scheme       = "bearer",
        BearerFormat = "JWT",
        In           = ParameterLocation.Header,
        Description  = "Enter your JWT token (without 'Bearer' prefix)"
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
    p.WithOrigins("http://localhost:3000", "http://localhost:5173")
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
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "CoupleApp API v1");
        c.RoutePrefix = "swagger";
    });
}

app.UseCors("DevPolicy");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// ── SignalR Hub route ────────────────────────────────────────────
app.MapHub<CoupleHub>("/hubs/couple");

app.Run();
