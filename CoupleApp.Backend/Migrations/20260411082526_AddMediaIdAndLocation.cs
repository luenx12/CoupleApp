using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CoupleApp.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddMediaIdAndLocation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "MediaId",
                table: "Messages",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "MediaId",
                table: "Messages");
        }
    }
}
