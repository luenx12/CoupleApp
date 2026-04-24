using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CoupleApp.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddUserGender : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Gender",
                table: "Users",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000001"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 24, 19, 3, 17, 962, DateTimeKind.Utc).AddTicks(8129));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000002"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 24, 19, 3, 17, 962, DateTimeKind.Utc).AddTicks(8145));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000003"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 24, 19, 3, 17, 962, DateTimeKind.Utc).AddTicks(8148));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000004"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 24, 19, 3, 17, 962, DateTimeKind.Utc).AddTicks(8162));

            migrationBuilder.UpdateData(
                table: "DailyQuestions",
                keyColumn: "Id",
                keyValue: new Guid("20000001-0000-0000-0000-000000000005"),
                column: "CreatedAt",
                value: new DateTime(2026, 4, 24, 19, 3, 17, 962, DateTimeKind.Utc).AddTicks(8164));
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Gender",
                table: "Users");

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
    }
}
