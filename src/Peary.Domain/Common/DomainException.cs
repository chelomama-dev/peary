namespace Peary.Domain.Common;

/// <summary>
/// A business rule was broken (e.g. the last admin tried to leave the group). The API answers 409 with the message
/// as <c>detail</c>, so it is written to be shown to the user, in Spanish.
/// </summary>
public class DomainException(string message) : Exception(message);
