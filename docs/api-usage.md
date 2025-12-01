# API Usage

DriftHound provides a RESTful API for submitting Terraform drift check results.

## Authentication

All API requests require authentication using a Bearer token in the `Authorization` header:

```bash
Authorization: Bearer YOUR_API_TOKEN
```

See [API Token Management](#api-token-management) for details on generating tokens.

## Endpoints

### Submit a Drift Check

Submit the results of a Terraform drift check for a specific project and environment.

**Endpoint:** `POST /api/v1/projects/:project_key/environments/:environment_key/checks`

**Example Request:**

```bash
curl -X POST \
  http://localhost:3000/api/v1/projects/my-project/environments/my-env/checks \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "drift",
    "add_count": 2,
    "change_count": 1,
    "destroy_count": 0,
    "duration": 8.2,
    "raw_output": "Plan: 2 to add, 1 to change, 0 to destroy."
  }'
```

### Request Parameters

#### URL Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `project_key` | string | Yes | Unique identifier for the project (alphanumeric, dashes, underscores) |
| `environment_key` | string | Yes | Unique identifier for the environment (alphanumeric, dashes, underscores) |

#### Body Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `status` | string | Yes | One of: `ok`, `drift`, `error`, `unknown` |
| `add_count` | integer | No | Number of resources to add |
| `change_count` | integer | No | Number of resources to change |
| `destroy_count` | integer | No | Number of resources to destroy |
| `duration` | float | No | Execution duration in seconds |
| `raw_output` | text | No | Full Terraform plan output |
| `notification_channel` | object | No | Optional notification channel configuration (see [Advanced Features](#advanced-features)) |

### Response

**Success Response (201 Created):**

```json
{
  "id": 123,
  "project_key": "my-project",
  "environment_key": "my-env",
  "status": "drift",
  "created_at": "2025-11-27T10:30:00Z"
}
```

**Error Responses:**

- `401 Unauthorized` - Missing or invalid API token
- `422 Unprocessable Entity` - Invalid status value or validation error

### Status Values

| Status | Description |
|--------|-------------|
| `ok` | No drift detected - infrastructure matches state |
| `drift` | Drift detected - changes pending |
| `error` | Error running drift check |
| `unknown` | Initial state or unable to determine |

## Advanced Features

### Notification Channel Configuration

You can optionally configure Slack notification channels per environment via the API:

```bash
curl -X POST \
  http://localhost:3000/api/v1/projects/my-project/environments/production/checks \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "drift",
    "add_count": 2,
    "change_count": 1,
    "destroy_count": 0,
    "notification_channel": {
      "channel_type": "slack",
      "enabled": true,
      "config": {
        "channel": "#custom-alerts"
      }
    }
  }'
```

**Notification Channel Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `channel_type` | string | Yes | Currently only `"slack"` is supported |
| `enabled` | boolean | No | Enable or disable notifications for this environment |
| `config.channel` | string | No | Slack channel name (e.g., `"#alerts"`). Falls back to global default if not provided |

**Notes:**
- The Slack token is always taken from the global configuration (`SLACK_BOT_TOKEN` or `config/notifications.yml`)
- This allows you to override the notification channel per environment without exposing tokens in API requests
- See [Slack Notifications documentation](slack-notifications.md) for more details on notification setup

## API Token Management

DriftHound uses rake tasks to manage API tokens:

### Generate a New Token

```bash
bin/rails api_tokens:generate[token-name]
```

This will create a new token and display it in the console. Save it securely - you won't be able to retrieve it again.

### List All Tokens

```bash
bin/rails api_tokens:list
```

### Revoke a Token

```bash
bin/rails api_tokens:revoke[TOKEN_ID]
```

## Health Check Endpoint

DriftHound provides a health check endpoint for load balancers and monitoring systems:

**Endpoint:** `GET /up`

**Response:**
- `200 OK` - Application is healthy
- `500 Internal Server Error` - Application failed to boot

**Note:** Health check requests are not logged in production to prevent log clutter.

## Best Practices

1. **Use descriptive project and environment keys** - Use kebab-case names like `infrastructure-prod` rather than cryptic codes
2. **Always include raw_output** - Helps with debugging and provides detailed context in the dashboard
3. **Set appropriate durations** - Helps track performance over time
4. **Use environment variables for tokens** - Never hardcode tokens in scripts
5. **Configure notifications per environment** - Use different Slack channels for production vs. staging alerts

## Example Integration

### GitHub Actions

```yaml
- name: Check Terraform Drift
  run: |
    drifthound --tool=terraform \
      --project=my-infrastructure \
      --environment=production \
      --token=${{ secrets.DRIFTHOUND_TOKEN }} \
      --api-url=${{ secrets.DRIFTHOUND_URL }} \
      --dir=./terraform
```

### GitLab CI

```yaml
drift_check:
  script:
    - drifthound --tool=terraform
        --project=my-infrastructure
        --environment=production
        --token=$DRIFTHOUND_TOKEN
        --api-url=$DRIFTHOUND_URL
        --dir=./terraform
```

## See Also

- [CLI Usage Guide](cli-usage.md) - For automated drift checking in CI/CD
- [Slack Notifications](slack-notifications.md) - Configure Slack alerts
