using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace CoupleApp.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddDrawGameEntities : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "DrawSessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    DrawerId = table.Column<Guid>(type: "uuid", nullable: false),
                    GuesserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Word = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    StartedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    GuessedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    WinnerUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    ScoreAwarded = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DrawSessions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DrawSessions_Users_DrawerId",
                        column: x => x.DrawerId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DrawSessions_Users_GuesserId",
                        column: x => x.GuesserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "DrawWords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Word = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Category = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    Difficulty = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DrawWords", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "DrawWords",
                columns: new[] { "Id", "Category", "Difficulty", "Word" },
                values: new object[,]
                {
                    { new Guid("10000001-0000-0000-0000-000000000001"), "Yiyecek", 0, "Elma" },
                    { new Guid("10000001-0000-0000-0000-000000000002"), "Hayvan", 0, "Kedi" },
                    { new Guid("10000001-0000-0000-0000-000000000003"), "Hayvan", 0, "Köpek" },
                    { new Guid("10000001-0000-0000-0000-000000000004"), "Doğa", 0, "Güneş" },
                    { new Guid("10000001-0000-0000-0000-000000000005"), "Yapılar", 0, "Ev" },
                    { new Guid("10000001-0000-0000-0000-000000000006"), "Araçlar", 0, "Araba" },
                    { new Guid("10000001-0000-0000-0000-000000000007"), "Yiyecek", 0, "Pizza" },
                    { new Guid("10000001-0000-0000-0000-000000000008"), "Doğa", 0, "Çiçek" },
                    { new Guid("10000001-0000-0000-0000-000000000009"), "Araçlar", 1, "Uçak" },
                    { new Guid("10000001-0000-0000-0000-000000000010"), "Fantastik", 1, "Ejderha" },
                    { new Guid("10000001-0000-0000-0000-000000000011"), "Meslekler", 1, "Astronot" },
                    { new Guid("10000001-0000-0000-0000-000000000012"), "Eylemler", 1, "Fısıldamak" },
                    { new Guid("10000001-0000-0000-0000-000000000013"), "Doğa", 1, "Yıldırım" },
                    { new Guid("10000001-0000-0000-0000-000000000014"), "Kavramlar", 2, "Özgürlük" },
                    { new Guid("10000001-0000-0000-0000-000000000015"), "Duygular", 2, "Kıskançlık" },
                    { new Guid("10000001-0000-0000-0000-000000000016"), "Kavramlar", 2, "Karantina" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_DrawSessions_DrawerId",
                table: "DrawSessions",
                column: "DrawerId");

            migrationBuilder.CreateIndex(
                name: "IX_DrawSessions_GuesserId",
                table: "DrawSessions",
                column: "GuesserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DrawSessions");

            migrationBuilder.DropTable(
                name: "DrawWords");
        }
    }
}
