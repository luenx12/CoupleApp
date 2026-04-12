using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace CoupleApp.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddMiniGamesEntities : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "DailyQuestions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    QuestionText = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    Category = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DailyQuestions", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "DailyTasks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    PairId = table.Column<Guid>(type: "uuid", nullable: false),
                    TaskText = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    Points = table.Column<int>(type: "integer", nullable: false),
                    Category = table.Column<string>(type: "text", nullable: false),
                    AssignedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    IsAccepted = table.Column<bool>(type: "boolean", nullable: false),
                    IsCompleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DailyTasks", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "FlameLevels",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Level = table.Column<double>(type: "double precision", nullable: false),
                    RecordedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FlameLevels", x => x.Id);
                    table.ForeignKey(
                        name: "FK_FlameLevels_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserStats",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    TotalPoints = table.Column<int>(type: "integer", nullable: false),
                    WhoIsMoreMatches = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserStats", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserStats_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "DailyQuestions",
                columns: new[] { "Id", "Category", "CreatedAt", "QuestionText" },
                values: new object[,]
                {
                    { new Guid("20000001-0000-0000-0000-000000000001"), "Genel", new DateTime(2026, 4, 12, 12, 41, 55, 545, DateTimeKind.Utc).AddTicks(3669), "Kim daha çok uyur?" },
                    { new Guid("20000001-0000-0000-0000-000000000002"), "Yetenek", new DateTime(2026, 4, 12, 12, 41, 55, 545, DateTimeKind.Utc).AddTicks(3682), "Kim daha iyi yemek yapar?" },
                    { new Guid("20000001-0000-0000-0000-000000000003"), "İlişki", new DateTime(2026, 4, 12, 12, 41, 55, 545, DateTimeKind.Utc).AddTicks(3691), "Kim daha romantiktir?" },
                    { new Guid("20000001-0000-0000-0000-000000000004"), "Günlük", new DateTime(2026, 4, 12, 12, 41, 55, 545, DateTimeKind.Utc).AddTicks(3693), "Kim daha sakardır?" },
                    { new Guid("20000001-0000-0000-0000-000000000005"), "Finans", new DateTime(2026, 4, 12, 12, 41, 55, 545, DateTimeKind.Utc).AddTicks(3695), "Kim daha çok para harcar?" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_FlameLevels_UserId_RecordedAt",
                table: "FlameLevels",
                columns: new[] { "UserId", "RecordedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_UserStats_UserId",
                table: "UserStats",
                column: "UserId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DailyQuestions");

            migrationBuilder.DropTable(
                name: "DailyTasks");

            migrationBuilder.DropTable(
                name: "FlameLevels");

            migrationBuilder.DropTable(
                name: "UserStats");
        }
    }
}
