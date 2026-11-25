var builder = DistributedApplication.CreateBuilder(args);

// Fixed port, apart from Plumy's (14330), so both can run at once
var sql = builder.AddSqlServer("sql", port: 14331)
    .WithLifetime(ContainerLifetime.Persistent)
    .WithDataVolume();

var db = sql.AddDatabase("pearydb");

// The API keeps its own port (launchSettings, 5080): the Android emulator reaches it at http://10.0.2.2:5080.
// Without the Entra section it runs with the development sign-in (see Peary.Api/Common/Authentication.cs)
builder.AddProject<Projects.Peary_Api>("api")
    .WithReference(db)
    .WaitFor(db);

builder.Build().Run();
