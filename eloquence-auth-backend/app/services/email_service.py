from azure.communication.email import EmailClient
from azure.core.exceptions import HttpResponseError
from app.config import settings

class EmailService:
    def __init__(self):
        self.client = EmailClient.from_connection_string(
            settings.azure_communication_connection_string
        )

    def send_otp_email(self, to_email: str, otp_code: str) -> bool:
        """Send OTP code via email. Returns True if successful."""

        message = {
            "senderAddress": settings.azure_email_from_address,
            "recipients": {
                "to": [{"address": to_email}]
            },
            "content": {
                "subject": "Your Eloquence Login Code",
                "plainText": f"""
Hello,

Your Eloquence login code is: {otp_code}

This code will expire in {settings.otp_expiry_minutes} minutes.

If you didn't request this code, please ignore this email.

Best regards,
The Eloquence Team
                """.strip(),
                "html": f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .code {{ font-size: 32px; font-weight: bold; color: #CA8A04; letter-spacing: 8px; text-align: center; padding: 20px; background: #1E1E1E; border-radius: 8px; margin: 30px 0; }}
        .footer {{ color: #666; font-size: 12px; margin-top: 30px; }}
    </style>
</head>
<body>
    <div class="container">
        <h2>Your Eloquence Login Code</h2>
        <p>Use this code to complete your login:</p>
        <div class="code">{otp_code}</div>
        <p>This code will expire in {settings.otp_expiry_minutes} minutes.</p>
        <p>If you didn't request this code, please ignore this email.</p>
        <div class="footer">
            <p>Best regards,<br>The Eloquence Team</p>
        </div>
    </div>
</body>
</html>
                """.strip()
            }
        }

        try:
            poller = self.client.begin_send(message)
            result = poller.result()
            print(f"Email sent successfully. Message ID: {result.get('id', 'N/A')}")
            return True

        except HttpResponseError as e:
            print(f"Failed to send email: {e}")
            return False
        except Exception as e:
            print(f"Unexpected error sending email: {e}")
            return False
