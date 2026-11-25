namespace Peary.Application.Abstractions;

/// <summary>The signed-in user, as the access token describes them (ADR 0001).</summary>
public interface ICurrentUser
{
    /// <summary>Object id in Entra External ID (<c>oid</c> claim): the user's identity in Peary.</summary>
    Guid ObjectId { get; }

    string? Name { get; }

    /// <summary>Verified by Entra at sign-up; invitations are matched against it (ADR 0002).</summary>
    string? Email { get; }
}
