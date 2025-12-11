# Slack Notifications Setup

DriftHound can send notifications to Slack when infrastructure drift is detected or resolved.

## Quick Start

### 1. Create a Slack App

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Click **"Create New App"** → **"From scratch"**
3. Name your app (e.g., "DriftHound") and select your workspace
4. Click **"Create App"**

### 2. Configure Bot Permissions

1. In your app settings, navigate to **"OAuth & Permissions"**
2. Scroll to **"Scopes"** → **"Bot Token Scopes"**
3. Add these scopes:
   - `chat:write` - Post and update messages in channels
   - `chat:write.public` - Post to public channels without joining
   - `channels:read` - View basic channel info (needed for message updates)

### 3. Install App to Workspace

1. Scroll to the top of the **"OAuth & Permissions"** page
2. Click **"Install to Workspace"**
3. Review permissions and click **"Allow"**
4. Copy the **"Bot User OAuth Token"** (starts with `xoxb-`)

### 4. Configure DriftHound

Set these environment variables:

```bash
export SLACK_NOTIFICATIONS_ENABLED=true
export SLACK_BOT_TOKEN=xoxb-your-token-here
export SLACK_DEFAULT_CHANNEL=#infrastructure-drift
```

That's it! New projects will automatically send notifications to your default channel.

## Customizing Channels

### Option 1: Via CLI (Recommended)

Configure a specific Slack channel when running drift checks:

```bash
bin/drifthound-cli \
  --tool=terraform \
  --project=my-app \
  --environment=production \
  --token=$API_TOKEN \
  --api-url=$DRIFTHOUND_URL \
  --slack-channel=#production-alerts
```

The channel setting persists - you only need to specify it once. Future runs will use the saved channel.

### Option 2: Via Environment Variables

Set different defaults per environment in `config/notifications.yml`:

```yaml
production:
  slack:
    enabled: <%= ENV.fetch('SLACK_NOTIFICATIONS_ENABLED', 'false') == 'true' %>
    token: <%= ENV['SLACK_BOT_TOKEN'] %>
    default_channel: <%= ENV.fetch('SLACK_DEFAULT_CHANNEL', '#infrastructure-drift') %>
```

## How Notifications Work

**Smart notifications** - Only sends alerts when status changes:
- `ok` → `drift` = New message posted
- `drift` → `ok` = Original message updated (shows resolution time)
- `drift` → `drift` = No notification (anti-spam)

**Message updates** - When drift resolves, DriftHound updates the original Slack message in place. The message changes from red/orange to green, showing that the issue was resolved and how long it lasted. This keeps your channel clean and makes it easy to see which alerts are still active.

### First Check Behavior

By default, the **first drift check** for a new environment does not trigger a notification. This is because:
- New environments start with `unknown` status
- The first check establishes a baseline
- This prevents notification spam when onboarding many environments

**To receive notifications on first drift/error detection:**

```bash
export NOTIFY_ON_FIRST_CHECK=true
```

| First Check Result | `NOTIFY_ON_FIRST_CHECK=false` (default) | `NOTIFY_ON_FIRST_CHECK=true` |
|-------------------|----------------------------------------|------------------------------|
| `unknown → ok`    | No notification                        | No notification              |
| `unknown → drift` | No notification (baseline)             | Drift Detected               |
| `unknown → error` | No notification (baseline)             | Error Detected               |

## Troubleshooting

**No notifications?**
1. Check `SLACK_NOTIFICATIONS_ENABLED=true` is set
2. Verify `SLACK_BOT_TOKEN` is set correctly
3. Ensure background jobs are running: `bin/rails solid_queue:start`

**Bot can't post to private channels?**
- Invite the bot: `/invite @DriftHound`

**Resolved notifications not updating the original message?**
- Your Slack app may be missing required scopes
- Go to your Slack app settings → OAuth & Permissions
- Ensure you have: `chat:write`, `chat:write.public`, and `channels:read`
- **Reinstall the app** to your workspace after adding scopes
- Update your `SLACK_BOT_TOKEN` with the new token

**Need different channels per project?**
- Use `--slack-channel` flag when running `drifthound-cli` for each environment
- Settings are saved automatically
