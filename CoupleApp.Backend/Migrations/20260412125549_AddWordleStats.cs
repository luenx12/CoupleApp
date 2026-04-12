using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CoupleApp.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddWordleStats : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "WordleAverageAttempts",
                table: "UserStats",
                type: "double precision",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<int>(
                name: "WordleCurrentStreak",
                table: "UserStats",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "WordleMaxStreak",
                table: "UserStats",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "WordleTotalPlayed",
                table: "UserStats",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000001"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 12, 12, 55, 48, 770, DateTimeKind.Utc).AddTicks(9733));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000002"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 12, 12, 55, 48, 770, DateTimeKind.Utc).AddTicks(9749));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000003"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 12, 12, 55, 48, 770, DateTimeKind.Utc).AddTicks(9750));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000004"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 12, 12, 55, 48, 770, DateTimeKind.Utc).AddTicks(9752));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000005"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 12, 12, 55, 48, 770, DateTimeKind.Utc).AddTicks(9754));
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "WordleAverageAttempts",
                table: "UserStats");

            migrationBuilder.DropColumn(
                name: "WordleCurrentStreak",
                table: "UserStats");

            migrationBuilder.DropColumn(
                name: "WordleMaxStreak",
                table: "UserStats");

            migrationBuilder.DropColumn(
                name: "WordleTotalPlayed",
                table: "UserStats");

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000001"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 12, 12, 41, 55, 545, DateTimeKind.Utc).AddTicks(3669));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000002"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 12, 12, 41, 55, 545, DateTimeKind.Utc).AddTicks(3682));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000003"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 12, 12, 41, 55, 545, DateTimeKind.Utc).AddTicks(3691));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000004"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 12, 12, 41, 55, 545, DateTimeKind.Utc).AddTicks(3693));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000005"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 12, 12, 41, 55, 545, DateTimeKind.Utc).AddTicks(3695));
        }
    }
}
