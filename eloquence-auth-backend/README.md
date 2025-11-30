# Eloquence Auth Backend

Python/FastAPI backend for Eloquence iOS app authentication using Azure Communication Services.

## Features

- Email OTP authentication
- Azure Communication Services for email delivery
- Azure Table Storage for OTP codes and user sessions
- Rate limiting and security controls
- Session management with 30-day expiry

## Setup

### Prerequisites

- Python 3.11+
- Azure account with:
  - Communication Services resource
  - Table Storage account
  - App Service (for deployment)

### Local Development

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Create `.env` file:
```bash
cp .env.example .env
# Edit .env with your Azure connection strings
```

3. Run the server:
```bash
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`

### API Documentation

Once running, visit:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## API Endpoints

### POST /auth/send-otp

Send OTP code to user's email.

**Request:**
```json
{
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "OTP sent to user@example.com",
  "expiresIn": 600
}
```

### POST /auth/verify-otp

Verify OTP code and create session.

**Request:**
```json
{
  "email": "user@example.com",
  "code": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Login successful",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "createdAt": "2025-11-29T...",
    "lastLoginAt": "2025-11-29T..."
  },
  "accessToken": "session-token",
  "expiresIn": 2592000
}
```

### GET /auth/health

Health check endpoint.

## Deployment to Azure

### Using Azure CLI

```bash
# Login to Azure
az login

# Deploy to App Service
az webapp up --name eloquence-auth-api --runtime PYTHON:3.11 --sku B1

# Set environment variables
az webapp config appsettings set --name eloquence-auth-api \
  --resource-group <your-resource-group> \
  --settings \
  AZURE_COMMUNICATION_CONNECTION_STRING="<connection-string>" \
  AZURE_EMAIL_FROM_ADDRESS="DoNotReply@xxx.azurecomm.net" \
  AZURE_STORAGE_CONNECTION_STRING="<storage-connection-string>"
```

## Configuration

All configuration is done via environment variables. See `.env.example` for required values.

### Key Settings

- `OTP_EXPIRY_MINUTES`: How long OTP codes are valid (default: 10)
- `OTP_MAX_ATTEMPTS`: Maximum verification attempts per OTP (default: 3)
- `OTP_RATE_LIMIT_MINUTES`: Minimum time between OTP requests (default: 1)
- `SESSION_EXPIRY_DAYS`: How long sessions are valid (default: 30)

## Security Features

- Rate limiting: 1 OTP request per email per minute
- Max 3 verification attempts per OTP
- 10-minute OTP expiry
- Secure random token generation
- HTTPS enforced on Azure App Service
- Input validation via Pydantic

## Monitoring

View logs in Azure Portal:
- Go to App Service → "Logs" → "Log stream"
- See real-time Python print statements
- Monitor for errors

## License

MIT
