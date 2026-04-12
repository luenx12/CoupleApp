using CoupleApp.Core.Entities;
using Microsoft.EntityFrameworkCore;

namespace CoupleApp.Infrastructure.Persistence;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<Activity> Activities => Set<Activity>();
    public DbSet<GameTask> GameTasks => Set<GameTask>();
    public DbSet<GalleryItem> GalleryItems => Set<GalleryItem>();
    public DbSet<DrawWord> DrawWords => Set<DrawWord>();
    public DbSet<DrawSession> DrawSessions => Set<DrawSession>();

    // Mini-Games
    public DbSet<DailyQuestion> DailyQuestions => Set<DailyQuestion>();
    public DbSet<DailyTask> DailyTasks => Set<DailyTask>();
    public DbSet<UserStats> UserStats => Set<UserStats>();
    public DbSet<FlameLevel> FlameLevels => Set<FlameLevel>();

    // Pairing
    public DbSet<CoupleInvitation> CoupleInvitations => Set<CoupleInvitation>();
    public DbSet<CouplePair> CouplePairs => Set<CouplePair>();

    // Auth
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // ── User ──────────────────────────────────────────────────────────
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(u => u.Id);
            entity.HasIndex(u => u.Username).IsUnique();
            entity.Property(u => u.Username).IsRequired().HasMaxLength(50);
            entity.Property(u => u.PasswordHash).IsRequired().HasMaxLength(255);
        });

        // ── Message ───────────────────────────────────────────────────────
        modelBuilder.Entity<Message>(entity =>
        {
            entity.HasKey(m => m.Id);

            entity.HasOne(m => m.Sender)
                  .WithMany(u => u.SentMessages)
                  .HasForeignKey(m => m.SenderId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(m => m.Receiver)
                  .WithMany(u => u.ReceivedMessages)
                  .HasForeignKey(m => m.ReceiverId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.Property(m => m.EncryptedText).IsRequired();
            entity.HasIndex(m => new { m.SenderId, m.SentAt });
        });

        // ── Activity ──────────────────────────────────────────────────────
        modelBuilder.Entity<Activity>(entity =>
        {
            entity.HasKey(a => a.Id);

            entity.HasOne(a => a.CreatedBy)
                  .WithMany(u => u.Activities)
                  .HasForeignKey(a => a.CreatedByUserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // ── GameTask ──────────────────────────────────────────────────────
        modelBuilder.Entity<GameTask>(entity =>
        {
            entity.HasKey(g => g.Id);

            entity.HasOne(g => g.AssignedBy)
                  .WithMany()
                  .HasForeignKey(g => g.AssignedByUserId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(g => g.AssignedTo)
                  .WithMany(u => u.GameTasks)
                  .HasForeignKey(g => g.AssignedToUserId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // ── GalleryItem ───────────────────────────────────────────────────
        modelBuilder.Entity<GalleryItem>(entity =>
        {
            entity.HasKey(g => g.Id);

            entity.HasOne(g => g.Uploader)
                  .WithMany()
                  .HasForeignKey(g => g.UploaderId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(g => g.Receiver)
                  .WithMany()
                  .HasForeignKey(g => g.ReceiverId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // ── Pairing System ────────────────────────────────────────────────
        modelBuilder.Entity<CoupleInvitation>(entity =>
        {
            entity.HasKey(i => i.Id);
            entity.HasIndex(i => i.InviteCode).IsUnique();

            entity.HasOne(i => i.Inviter)
                  .WithMany()
                  .HasForeignKey(i => i.InviterUserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<CouplePair>(entity =>
        {
            entity.HasKey(p => p.Id);
            
            // A user can only be in one pair.
            entity.HasIndex(p => p.User1Id).IsUnique();
            entity.HasIndex(p => p.User2Id).IsUnique();

            entity.HasOne(p => p.User1)
                  .WithMany()
                  .HasForeignKey(p => p.User1Id)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(p => p.User2)
                  .WithMany()
                  .HasForeignKey(p => p.User2Id)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // ── Refresh Tokens ────────────────────────────────────────────────
        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.HasKey(rt => rt.Id);
            entity.HasIndex(rt => rt.TokenHash).IsUnique();

            entity.HasOne(rt => rt.User)
                  .WithMany(u => u.RefreshTokens)
                  .HasForeignKey(rt => rt.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // ── Device Tokens ─────────────────────────────────────────────────
        modelBuilder.Entity<DeviceToken>(entity =>
        {
            entity.HasKey(dt => dt.Id);
            entity.HasIndex(dt => dt.Token).IsUnique(); // Ensure no duplicates globally

            entity.HasOne(dt => dt.User)
                  .WithMany(u => u.DeviceTokens)
                  .HasForeignKey(dt => dt.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // ── DrawWord ──────────────────────────────────────────────────────
        modelBuilder.Entity<DrawWord>(entity =>
        {
            entity.HasKey(w => w.Id);
            entity.Property(w => w.Word).IsRequired().HasMaxLength(100);
            entity.Property(w => w.Category).HasMaxLength(50);
        });

        // ── DrawSession ───────────────────────────────────────────────────
        modelBuilder.Entity<DrawSession>(entity =>
        {
            entity.HasKey(s => s.Id);
            entity.Property(s => s.Word).IsRequired().HasMaxLength(100);

            entity.HasOne(s => s.Drawer)
                  .WithMany()
                  .HasForeignKey(s => s.DrawerId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(s => s.Guesser)
                  .WithMany()
                  .HasForeignKey(s => s.GuesserId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // ── DailyQuestion ─────────────────────────────────────────────────
        modelBuilder.Entity<DailyQuestion>(entity =>
        {
            entity.HasKey(q => q.Id);
            entity.Property(q => q.QuestionText).IsRequired().HasMaxLength(500);
        });

        // ── DailyTask ─────────────────────────────────────────────────────
        modelBuilder.Entity<DailyTask>(entity =>
        {
            entity.HasKey(t => t.Id);
            entity.Property(t => t.TaskText).IsRequired().HasMaxLength(500);
        });

        // ── UserStats ─────────────────────────────────────────────────────
        modelBuilder.Entity<UserStats>(entity =>
        {
            entity.HasKey(s => s.Id);
            entity.HasIndex(s => s.UserId).IsUnique(); // One stats per user
        });

        // ── FlameLevel ────────────────────────────────────────────────────
        modelBuilder.Entity<FlameLevel>(entity =>
        {
            entity.HasKey(f => f.Id);
            entity.HasIndex(f => new { f.UserId, f.RecordedAt }); // For faster time-based queries
        });

        // ── DailyQuestion Seed Data ───────────────────────────────────────
        modelBuilder.Entity<DailyQuestion>().HasData(
            new DailyQuestion { Id = Guid.Parse("20000001-0000-0000-0000-000000000001"), QuestionText = "Kim daha çok uyur?", Category = "Genel" },
            new DailyQuestion { Id = Guid.Parse("20000001-0000-0000-0000-000000000002"), QuestionText = "Kim daha iyi yemek yapar?", Category = "Yetenek" },
            new DailyQuestion { Id = Guid.Parse("20000001-0000-0000-0000-000000000003"), QuestionText = "Kim daha romantiktir?", Category = "İlişki" },
            new DailyQuestion { Id = Guid.Parse("20000001-0000-0000-0000-000000000004"), QuestionText = "Kim daha sakardır?", Category = "Günlük" },
            new DailyQuestion { Id = Guid.Parse("20000001-0000-0000-0000-000000000005"), QuestionText = "Kim daha çok para harcar?", Category = "Finans" }
        );

        // ── DrawWord Seed Data ────────────────────────────────────────────
        modelBuilder.Entity<DrawWord>().HasData(
            // Kolay
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000001"), Word = "Elma",       Category = "Yiyecek",  Difficulty = DrawDifficulty.Easy   },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000002"), Word = "Kedi",        Category = "Hayvan",   Difficulty = DrawDifficulty.Easy   },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000003"), Word = "Köpek",       Category = "Hayvan",   Difficulty = DrawDifficulty.Easy   },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000004"), Word = "Güneş",       Category = "Doğa",     Difficulty = DrawDifficulty.Easy   },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000005"), Word = "Ev",          Category = "Yapılar",  Difficulty = DrawDifficulty.Easy   },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000006"), Word = "Araba",       Category = "Araçlar",  Difficulty = DrawDifficulty.Easy   },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000007"), Word = "Pizza",       Category = "Yiyecek",  Difficulty = DrawDifficulty.Easy   },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000008"), Word = "Çiçek",       Category = "Doğa",     Difficulty = DrawDifficulty.Easy   },
            // Orta
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000009"), Word = "Uçak",        Category = "Araçlar",  Difficulty = DrawDifficulty.Medium },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000010"), Word = "Ejderha",     Category = "Fantastik",Difficulty = DrawDifficulty.Medium },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000011"), Word = "Astronot",    Category = "Meslekler",Difficulty = DrawDifficulty.Medium },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000012"), Word = "Fısıldamak",  Category = "Eylemler", Difficulty = DrawDifficulty.Medium },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000013"), Word = "Yıldırım",    Category = "Doğa",     Difficulty = DrawDifficulty.Medium },
            // Zor
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000014"), Word = "Özgürlük",   Category = "Kavramlar",Difficulty = DrawDifficulty.Hard   },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000015"), Word = "Kıskançlık",  Category = "Duygular", Difficulty = DrawDifficulty.Hard   },
            new DrawWord { Id = Guid.Parse("10000001-0000-0000-0000-000000000016"), Word = "Karantina",   Category = "Kavramlar",Difficulty = DrawDifficulty.Hard   }
        );
    }
}
