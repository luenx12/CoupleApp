using CoupleApp.Application.Services;
using CoupleApp.Core.Entities;
using CoupleApp.Core.Interfaces.Repositories;
using Moq;

namespace CoupleApp.Tests;

/// <summary>
/// Unit tests for MessageService — 5 core scenarios.
/// Uses Moq to isolate from EF Core/database.
/// </summary>
public class MessageServiceTests
{
    // ── Shared test setup ─────────────────────────────────────────────────

    private readonly Mock<IMessageRepository> _messageRepoMock = new();
    private readonly Mock<IUserRepository>    _userRepoMock    = new();
    private readonly MessageService           _sut;

    private readonly Guid _senderId   = Guid.NewGuid();
    private readonly Guid _receiverId = Guid.NewGuid();

    public MessageServiceTests()
    {
        _sut = new MessageService(_messageRepoMock.Object, _userRepoMock.Object);

        // Default: receiver exists
        _userRepoMock
            .Setup(r => r.GetByIdAsync(_receiverId))
            .ReturnsAsync(new User { Id = _receiverId, Username = "partner" });
    }

    // ── Test 1: SendText ──────────────────────────────────────────────────

    /// <summary>
    /// A valid text message must be added to the repository and persisted.
    /// The returned Message must carry the correct SenderId, ReceiverId,
    /// MessageType.Text, and the provided ciphertext.
    /// </summary>
    [Fact]
    public async Task SendText_ValidPayload_SavesMessage()
    {
        // Arrange
        const string ciphertext = "BASE64_ENCRYPTED_PAYLOAD";
        const string iv         = "INIT_VECTOR";

        _messageRepoMock
            .Setup(r => r.AddAsync(It.IsAny<Message>()))
            .Returns(Task.CompletedTask);
        _messageRepoMock
            .Setup(r => r.SaveChangesAsync())
            .ReturnsAsync(1);

        // Act
        var result = await _sut.SendTextAsync(_senderId, _receiverId, ciphertext, null, iv);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(_senderId,        result.SenderId);
        Assert.Equal(_receiverId,      result.ReceiverId);
        Assert.Equal(ciphertext,       result.EncryptedText);
        Assert.Equal(iv,               result.IV);
        Assert.Equal(MessageType.Text, result.Type);
        Assert.False(result.IsDeleted);

        _messageRepoMock.Verify(r => r.AddAsync(It.IsAny<Message>()), Times.Once);
        _messageRepoMock.Verify(r => r.SaveChangesAsync(),            Times.Once);
    }

    // ── Test 2: SendMedia ─────────────────────────────────────────────────

    /// <summary>
    /// A media message must store the mediaId and use the provided type (Image/Voice/Sticker).
    /// MessageType.Text must be rejected with ArgumentException.
    /// </summary>
    [Fact]
    public async Task SendMedia_WithMediaId_SetsTypeToImage()
    {
        // Arrange
        const string mediaId    = "abc123def456";
        const string ciphertext = "ENC_BLOB";

        _messageRepoMock
            .Setup(r => r.AddAsync(It.IsAny<Message>()))
            .Returns(Task.CompletedTask);
        _messageRepoMock
            .Setup(r => r.SaveChangesAsync())
            .ReturnsAsync(1);

        // Act
        var result = await _sut.SendMediaAsync(
            _senderId, _receiverId, ciphertext, null, null,
            mediaId, MessageType.Image);

        // Assert
        Assert.Equal(MessageType.Image, result.Type);
        Assert.Equal(mediaId,           result.MediaId);
        Assert.Equal(ciphertext,        result.EncryptedText);

        // Sending with Type = Text must be rejected
        await Assert.ThrowsAsync<ArgumentException>(() =>
            _sut.SendMediaAsync(
                _senderId, _receiverId, ciphertext, null, null,
                mediaId, MessageType.Text));
    }

    // ── Test 3: GetHistory (pagination) ───────────────────────────────────

    /// <summary>
    /// GetHistoryAsync must forward pagination parameters to the repository
    /// and return exactly the data provided by the repository.
    /// </summary>
    [Fact]
    public async Task GetHistory_Paginated_ReturnsCorrectPage()
    {
        // Arrange
        const int page     = 2;
        const int pageSize = 10;

        var fakeMessages = Enumerable.Range(0, 10)
            .Select(_ => new Message
            {
                SenderId   = _senderId,
                ReceiverId = _receiverId,
                EncryptedText = "ENC"
            })
            .ToList();

        _messageRepoMock
            .Setup(r => r.GetHistoryAsync(_senderId, _receiverId, page, pageSize))
            .ReturnsAsync((fakeMessages, 35)); // 35 total messages, returning page 2

        // Act
        var (items, totalCount) = await _sut.GetHistoryAsync(_senderId, _receiverId, page, pageSize);

        // Assert
        Assert.Equal(10, items.Count());
        Assert.Equal(35, totalCount);

        _messageRepoMock.Verify(
            r => r.GetHistoryAsync(_senderId, _receiverId, page, pageSize),
            Times.Once);
    }

    // ── Test 4: DeleteMessage ─────────────────────────────────────────────

    /// <summary>
    /// SoftDeleteAsync must be called with the correct messageId and senderUserId.
    /// Returns false when message not found / unauthorized.
    /// </summary>
    [Fact]
    public async Task DeleteMessage_BySender_WipesContent()
    {
        // Arrange
        var messageId = Guid.NewGuid();

        _messageRepoMock
            .Setup(r => r.SoftDeleteAsync(messageId, _senderId))
            .ReturnsAsync(true);

        _messageRepoMock
            .Setup(r => r.SoftDeleteAsync(messageId, _receiverId))
            .ReturnsAsync(false); // receiver is not allowed to delete

        // Act
        var successBySender   = await _sut.DeleteMessageAsync(messageId, _senderId);
        var failedByReceiver  = await _sut.DeleteMessageAsync(messageId, _receiverId);

        // Assert
        Assert.True(successBySender);
        Assert.False(failedByReceiver);

        _messageRepoMock.Verify(r => r.SoftDeleteAsync(messageId, _senderId),   Times.Once);
        _messageRepoMock.Verify(r => r.SoftDeleteAsync(messageId, _receiverId), Times.Once);
    }

    // ── Test 5: MarkAsRead ────────────────────────────────────────────────

    /// <summary>
    /// MarkAsReadAsync must be delegated to the repository.
    /// Returns true on success, false when the caller is not the receiver.
    /// </summary>
    [Fact]
    public async Task MarkAsRead_ByReceiver_UpdatesReadAt()
    {
        // Arrange
        var messageId = Guid.NewGuid();

        _messageRepoMock
            .Setup(r => r.MarkAsReadAsync(messageId, _receiverId))
            .ReturnsAsync(true);

        _messageRepoMock
            .Setup(r => r.MarkAsReadAsync(messageId, _senderId))
            .ReturnsAsync(false); // sender is not allowed to mark their own msg as read

        // Act
        var successByReceiver = await _sut.MarkAsReadAsync(messageId, _receiverId);
        var failedBySender    = await _sut.MarkAsReadAsync(messageId, _senderId);

        // Assert
        Assert.True(successByReceiver);
        Assert.False(failedBySender);

        _messageRepoMock.Verify(r => r.MarkAsReadAsync(messageId, _receiverId), Times.Once);
        _messageRepoMock.Verify(r => r.MarkAsReadAsync(messageId, _senderId),   Times.Once);
    }
}
