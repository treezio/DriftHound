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
   - `chat:write` - Post messages to channels
   - `chat:write.public` - Post to public channels without joining

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

**Message updates** - When drift resolves, DriftHound updates the original Slack message instead of posting a new one, showing how long the drift lasted.

## Troubleshooting

**No notifications?**
1. Check `SLACK_NOTIFICATIONS_ENABLED=true` is set
2. Verify `SLACK_BOT_TOKEN` is set correctly
3. Ensure background jobs are running: `bin/rails solid_queue:start`

**Bot can't post to private channels?**
- Invite the bot: `/invite @DriftHound`

**Need different channels per project?**
- Use `--slack-channel` flag when running `drifthound-cli` for each environment
- Settings are saved automatically
