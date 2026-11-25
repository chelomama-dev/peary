# API contract

The HTTP contract between the backend (`src/Peary.Api`) and the Flutter app (`mobile/`). It changes **before** the
API or the app do, and each side uses only what it describes ([AGENTS.md](../AGENTS.md)).

> **Status: draft for v0.1, nothing implemented yet.** Until an endpoint is implemented, the app uses its demo
> repositories (`--dart-define=DEMO=true`) with the examples below. Every change goes in the
> [changelog](#changelog).

| Endpoint | Purpose | Implemented |
|---|---|---|
| `GET /api/me` | The signed-in user, their groups and pending invitations | No |
| `PUT /api/me/devices/{installationId}` | Register this phone for push notifications | No |
| `DELETE /api/me/devices/{installationId}` | Stop push notifications to this phone (sign out) | No |
| `POST /api/groups` | Create a group | No |
| `GET /api/groups/{groupId}` | A group and its members | No |
| `PATCH /api/groups/{groupId}` | Rename a group or change its time zone (admin) | No |
| `PATCH /api/groups/{groupId}/members/{userId}` | Change a member's role (admin) | No |
| `DELETE /api/groups/{groupId}/members/{userId}` | Remove a member (admin) or leave the group (yourself) | No |
| `GET /api/groups/{groupId}/invitations` | Open invitations of a group (admin) | No |
| `POST /api/groups/{groupId}/invitations` | Invite someone by email (admin) | No |
| `DELETE /api/groups/{groupId}/invitations/{invitationId}` | Cancel an invitation (admin) | No |
| `POST /api/invitations/{invitationId}/accept` | Join the group you were invited to | No |
| `POST /api/invitations/{invitationId}/decline` | Turn an invitation down | No |
| `GET /api/groups/{groupId}/tasks` | A group's tasks, filtered | No |
| `POST /api/groups/{groupId}/tasks` | Create a task | No |
| `GET /api/groups/{groupId}/tasks/{taskId}` | One task | No |
| `PATCH /api/groups/{groupId}/tasks/{taskId}` | Change a task | No |
| `DELETE /api/groups/{groupId}/tasks/{taskId}` | Delete a task | No |
| `POST /api/groups/{groupId}/tasks/{taskId}/complete` | Mark a task done (and schedule the next one) | No |
| `POST /api/groups/{groupId}/tasks/{taskId}/reopen` | Undo a completion | No |

Attachments on tasks are part of v0.1 too; their endpoints are added here before they are built.

## Conventions

- **Base URL**: local `http://localhost:5080` (`http://10.0.2.2:5080` from the Android emulator). All paths start
  with `/api`.
- **JSON** in camelCase. Fields marked *nullable* can be `null`; all other fields are always present. Unknown
  fields must be ignored by the app, so adding a field is never a breaking change.
- **IDs** are UUIDs as strings. Don't parse them.
- **Users are identified by `userId`**, the same in every group they belong to.
- **Timestamps** are UTC ISO 8601 (`"2026-11-25T17:46:00Z"`). **Dates** with no time are `"2026-11-28"` and
  **times of day** are `"17:30"`; both are in the **group's time zone** (`timeZone`, an IANA name such as
  `"Europe/Madrid"`), because "the dentist on Friday at 17:30" means the same for every member.
- **PATCH** sends only the fields that change. To clear a nullable field, send it as `null`.
- **Auth**: none in local development. In Azure, every request needs `Authorization: Bearer <token>`: an Entra
  External ID access token with the scope `api://<API client id>/access_as_user`
  ([ADR 0001](adr/0001-authentication-with-entra-external-id.md)). Without a valid token the API answers `401`.
  Health checks are the only anonymous endpoints.
- **Groups** ([ADR 0002](adr/0002-groups-are-the-tenants.md)): any `/api/groups/{groupId}/...` endpoint answers
  `404` if the group doesn't exist **or the caller isn't a member**. Endpoints marked *admin* answer `403` to a
  member who isn't an admin.
- **Errors** use ProblemDetails (RFC 9457), `Content-Type: application/problem+json`:

  ```json
  {
    "type": "https://tools.ietf.org/html/rfc9110#section-15.5.5",
    "title": "Not Found",
    "status": 404,
    "detail": "Task 3f2c… was not found."
  }
  ```

  Validation errors (`400`) add an `errors` object: field name → list of messages. Business rule errors (`409`)
  have a `detail` written to be shown to the user, **in Spanish**. The app shows `detail` if it is there,
  otherwise a generic Spanish message.

## Me

### Get the signed-in user

`GET /api/me`

Creates the user on their first call and refreshes the copy of their name and email from the token on every call.
The app calls it right after signing in and when it comes back to the foreground.

`200 OK`

```json
{
  "userId": "6b1d2c8e-5f0a-4c1e-9a7b-2d3e4f5a6b7c",
  "name": "Roberto",
  "email": "roberto@example.com",
  "groups": [
    {
      "groupId": "0c9a7e52-3b1f-4d6a-8e2c-1f2a3b4c5d6e",
      "name": "Casa",
      "role": "admin",
      "memberCount": 4
    }
  ],
  "invitations": [
    {
      "invitationId": "9e8d7c6b-5a4f-4e3d-2c1b-0a9f8e7d6c5b",
      "group": { "groupId": "1d2e3f4a-5b6c-4d7e-8f9a-0b1c2d3e4f5a", "name": "Piso de la abuela" },
      "invitedBy": "Lucía",
      "expiresAt": "2026-12-02T10:00:00Z"
    }
  ]
}
```

- `name`: *nullable* if the token has none.
- `role`: `admin` or `member`.
- `invitations[].invitedBy`: *nullable*, the inviter's name, `null` if their token had none (the app then shows
  "Alguien").
- `groups` is ordered by name; `invitations` lists only open (not expired) invitations sent to the user's email.

### Register this phone for push notifications

`PUT /api/me/devices/{installationId}`

`installationId` is a UUID the app generates once per installation and keeps. Calling it again replaces the token
(FCM rotates them).

```json
{ "platform": "android", "pushToken": "fcm-registration-token" }
```

`204 No Content`.

### Stop push notifications to this phone

`DELETE /api/me/devices/{installationId}`

Called when signing out. `204 No Content`, also if it didn't exist.

## Groups

### The group object

```json
{
  "groupId": "0c9a7e52-3b1f-4d6a-8e2c-1f2a3b4c5d6e",
  "name": "Casa",
  "timeZone": "Europe/Madrid",
  "myRole": "admin",
  "members": [
    {
      "userId": "6b1d2c8e-5f0a-4c1e-9a7b-2d3e4f5a6b7c",
      "name": "Roberto",
      "email": "roberto@example.com",
      "role": "admin",
      "joinedAt": "2026-11-25T17:46:00Z"
    },
    {
      "userId": "7c2e3d9f-6a1b-4d2f-8b8c-3e4f5a6b7c8d",
      "name": "Lucía",
      "email": "lucia@example.com",
      "role": "member",
      "joinedAt": "2026-11-26T09:12:00Z"
    }
  ],
  "createdAt": "2026-11-25T17:46:00Z"
}
```

- `name`: 1 to 60 characters. `members[].name`: *nullable*. Members are ordered by `joinedAt`.

### Create a group

`POST /api/groups`

```json
{ "name": "Casa", "timeZone": "Europe/Madrid" }
```

The caller becomes its first admin. `timeZone` must be a valid IANA name; the app sends the phone's.
`201 Created` with the group object and a `Location` header.

### Get a group

`GET /api/groups/{groupId}` → `200 OK` with the group object.

### Change a group (admin)

`PATCH /api/groups/{groupId}` with any of `name`, `timeZone` → `200 OK` with the group object.

### Change a member's role (admin)

`PATCH /api/groups/{groupId}/members/{userId}`

```json
{ "role": "member" }
```

`200 OK` with the group object. `409` if it would leave the group with no admin.

### Remove a member, or leave

`DELETE /api/groups/{groupId}/members/{userId}`

An admin can remove anyone; any member can remove themselves (leave). `204 No Content`.

- `409` if the caller is the last admin and other members remain: they must make someone else admin first.
- If the last member leaves, the group and all its data are deleted.
- Tasks assigned to the person who leaves become unassigned.

## Invitations

### The invitation object (as the group's admins see it)

```json
{
  "invitationId": "9e8d7c6b-5a4f-4e3d-2c1b-0a9f8e7d6c5b",
  "email": "lucia@example.com",
  "invitedBy": "Roberto",
  "createdAt": "2026-11-25T18:00:00Z",
  "expiresAt": "2026-12-02T18:00:00Z"
}
```

`invitedBy` is *nullable*, as in `GET /api/me`.

### List open invitations (admin)

`GET /api/groups/{groupId}/invitations` → `200 OK` with `{ "items": [ invitation, ... ] }`, newest first.

### Invite someone (admin)

`POST /api/groups/{groupId}/invitations`

```json
{ "email": "lucia@example.com" }
```

`201 Created` with the invitation. The address is trimmed and lowercased. If there's already an open invitation for
it, that one is renewed (7 more days) and returned with `200 OK`. `409` if that address already belongs to a
member. No email is sent ([ADR 0002](adr/0002-groups-are-the-tenants.md)).

### Cancel an invitation (admin)

`DELETE /api/groups/{groupId}/invitations/{invitationId}` → `204 No Content`.

### Accept or decline an invitation

`POST /api/invitations/{invitationId}/accept` → `200 OK` with the group object.

`POST /api/invitations/{invitationId}/decline` → `204 No Content`.

Both answer `404` if the invitation doesn't exist, has expired, was cancelled, or wasn't sent to the caller's
email.

## Tasks

### The task object

```json
{
  "taskId": "4a5b6c7d-8e9f-4a0b-9c1d-2e3f4a5b6c7d",
  "title": "Dentista de Pablo",
  "notes": "Llevar la tarjeta sanitaria",
  "assignee": { "userId": "7c2e3d9f-6a1b-4d2f-8b8c-3e4f5a6b7c8d", "name": "Lucía" },
  "dueDate": "2026-11-28",
  "dueTime": "17:30",
  "recurrence": "none",
  "reminderMinutesBefore": 60,
  "status": "open",
  "completedAt": null,
  "completedBy": null,
  "createdBy": { "userId": "6b1d2c8e-5f0a-4c1e-9a7b-2d3e4f5a6b7c", "name": "Roberto" },
  "createdAt": "2026-11-25T18:10:00Z",
  "updatedAt": "2026-11-25T18:10:00Z"
}
```

| Field | Rules |
|---|---|
| `title` | 1 to 200 characters |
| `notes` | *nullable*, up to 2000 characters |
| `assignee` | *nullable*: `null` means anyone in the group can do it. Must be a member of the group |
| `dueDate` | *nullable*: a task with no date is "whenever" |
| `dueTime` | *nullable*: only with `dueDate`. Without it, the task is for the whole day |
| `recurrence` | `none`, `daily`, `weekly` or `monthly`. Anything but `none` needs `dueDate` |
| `reminderMinutesBefore` | *nullable*, 0 to 10080 (a week). Needs `dueTime`. The assignee gets a push at that time; if there's no assignee, every member does |
| `status` | `open` or `done` |
| `completedAt`, `completedBy` | *nullable*, set when `status` is `done` |

`assignee`, `completedBy` and `createdBy` are `{ userId, name }`, with `name` *nullable*. A user who left the group
keeps their name here.

### List tasks

`GET /api/groups/{groupId}/tasks`

| Query parameter | Values | Default |
|---|---|---|
| `status` | `open`, `done` | `open` |
| `assignee` | `me`, `unassigned`, or a `userId` | all |
| `cursor` | the `nextCursor` of the previous page | first page |
| `limit` | 1 to 100 | 50 |

Open tasks come by `dueDate` and `dueTime` (the earliest first, overdue included); on the same date, tasks for the
whole day (`dueTime` `null`) come before the ones with a time, and ties go by `createdAt`. Then the ones with no
date, by `createdAt`. Done tasks come by `completedAt`, newest first.

`200 OK`

```json
{
  "items": [ task, ... ],
  "nextCursor": "opaque-string-or-null"
}
```

`nextCursor` is *nullable*: `null` when there are no more pages. It's opaque: don't parse it.

### Create a task

`POST /api/groups/{groupId}/tasks`

```json
{
  "title": "Recoger la secadora",
  "notes": null,
  "assigneeId": "7c2e3d9f-6a1b-4d2f-8b8c-3e4f5a6b7c8d",
  "dueDate": "2026-11-26",
  "dueTime": null,
  "recurrence": "weekly",
  "reminderMinutesBefore": null
}
```

Only `title` is required; the rest default to `null` and `none`. `201 Created` with the task and a `Location`
header. If it's assigned to someone else, they get a push notification.

### Get, change or delete a task

- `GET /api/groups/{groupId}/tasks/{taskId}` → `200 OK` with the task.
- `PATCH /api/groups/{groupId}/tasks/{taskId}` with any of the fields of *create* → `200 OK` with the task.
  Changing `assigneeId` to someone else notifies them. A done task can't be changed (`409`): reopen it first.
- `DELETE /api/groups/{groupId}/tasks/{taskId}` → `204 No Content`.

### Complete a task

`POST /api/groups/{groupId}/tasks/{taskId}/complete`

Marks it `done` by the caller. If it repeats, a new open task is created with the same fields and the next
`dueDate` (a day, a week or a month later; a monthly task on the 31st falls on the last day of shorter months).

`200 OK`

```json
{
  "completed": task,
  "next": task
}
```

`next` is *nullable*: `null` if the task doesn't repeat. Completing a task that is already done is `409`.

### Reopen a task

`POST /api/groups/{groupId}/tasks/{taskId}/reopen` → `200 OK` with the task, back to `open`. It doesn't delete
the `next` task a completion created. Reopening a task that is already open is `409`, like completing one that is
already done.

## Push notifications

Sent with FCM to every registered device of the recipients. The `data` payload lets the app open the right screen:

| When | Who gets it | `data` |
|---|---|---|
| A task is assigned to you by someone else | the assignee | `{ "type": "taskAssigned", "groupId": "…", "taskId": "…" }` |
| A task's reminder time arrives | the assignee, or every member if it has none | `{ "type": "taskReminder", "groupId": "…", "taskId": "…" }` |

The title and body come already written in Spanish ("Lucía te ha asignado: Recoger la secadora").

## Changelog

- 2026-11-25: first draft for v0.1: me, devices, groups, members, invitations and tasks.
- 2026-11-25: `invitedBy` is nullable; whole-day tasks sort before timed ones on the same date; reopening an open
  task is `409` (questions from the app's first PR).
