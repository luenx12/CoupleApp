using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CoupleApp.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddPairingSystem : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CoupleInvitations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    InviterUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    InviteCode = table.Column<string>(type: "character varying(6)", maxLength: 6, nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CoupleInvitations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CoupleInvitations_Users_InviterUserId",
                        column: x => x.InviterUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "CouplePairs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    User1Id = table.Column<Guid>(type: "uuid", nullable: false),
                    User2Id = table.Column<Guid>(type: "uuid", nullable: false),
                    PairedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CouplePairs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CouplePairs_Users_User1Id",
                        column: x => x.User1Id,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CouplePairs_Users_User2Id",
                        column: x => x.User2Id,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CoupleInvitations_InviteCode",
                table: "CoupleInvitations",
                column: "InviteCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CoupleInvitations_InviterUserId",
                table: "CoupleInvitations",
                column: "InviterUserId");

            migrationBuilder.CreateIndex(
                name: "IX_CouplePairs_User1Id",
                table: "CouplePairs",
                column: "User1Id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CouplePairs_User2Id",
                table: "CouplePairs",
                column: "User2Id",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CoupleInvitations");

            migrationBuilder.DropTable(
                name: "CouplePairs");
        }
    }
}
