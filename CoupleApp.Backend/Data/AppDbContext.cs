using CoupleApp.Backend.Entities;
using Microsoft.EntityFrameworkCore;

namespace CoupleApp.Backend.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<Activity> Activities => Set<Activity>();
    public DbSet<GameTask> GameTasks => Set<GameTask>();
    public DbSet<GalleryItem> GalleryItems => Set<GalleryItem>();

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
    }
}
