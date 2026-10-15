Reply in Slack to a message that reached this session.

When someone @-mentions the bot, gc hands the message to the mayor with an
instruction to answer through `gc slack reply-current`. slack-mini's only
outbound verb is `gc slack-mini post-message`, so this command takes the
instruction's flags and posts the reply with that verb.

Usage:
  gc slack reply-current --conversation-id <channel-id>
                         (--body-file <path> | --body <text>)
                         [--reply-to <ts>]

Flags:
  --conversation-id  Slack channel id to post in, e.g. C0123ABCD. gc's
                     instruction passes the id of the channel the message
                     came from. Required.
  --body-file        Read the reply from a file.
  --body             The reply text. Give this or --body-file, not both.
  --reply-to         Slack message ts to thread the reply under. Without it
                     the reply goes to the channel. --thread-ts is accepted
                     as another name for it.

Examples:
  gc slack reply-current --conversation-id C0123ABCD --body-file reply.txt

  gc slack reply-current --conversation-id C0123ABCD --body "Three beads are open."

On success, prints Slack's JSON response: {"ok":true,"ts":...,"channel":...}.

Requires the slack-mini import and its service running. GC_API_BASE_URL
points post-message at the supervisor; when it is unset, this command uses
the port in the supervisor's supervisor.toml, or 8372 when that file names none.
