from azure.data.tables import TableServiceClient, TableEntity
from azure.core.exceptions import ResourceNotFoundError
from datetime import datetime
from typing import Optional, Dict, Any
import uuid
from app.config import settings

class StorageService:
    def __init__(self):
        self.service_client = TableServiceClient.from_connection_string(
            settings.azure_storage_connection_string
        )
        self._ensure_tables_exist()

    def _ensure_tables_exist(self):
        """Create tables if they don't exist."""
        try:
            self.service_client.create_table("otpcodes")
        except Exception:
            pass  # Table already exists

        try:
            self.service_client.create_table("usersessions")
        except Exception:
            pass  # Table already exists

    # OTP Operations
    def save_otp(self, email: str, code: str, expires_at: datetime) -> str:
        """Save OTP code to storage. Returns the row key."""
        table_client = self.service_client.get_table_client("otpcodes")
        row_key = str(uuid.uuid4())

        entity = {
            "PartitionKey": email.lower(),
            "RowKey": row_key,
            "code": code,
            "createdAt": datetime.utcnow().isoformat(),
            "expiresAt": expires_at.isoformat(),
            "attempts": 0,
            "isUsed": False
        }

        table_client.create_entity(entity)
        return row_key

    def get_latest_otp(self, email: str) -> Optional[Dict[str, Any]]:
        """Get the most recent OTP for an email."""
        table_client = self.service_client.get_table_client("otpcodes")

        try:
            # Query for this email's OTPs, ordered by creation time
            query_filter = f"PartitionKey eq '{email.lower()}' and isUsed eq false"
            entities = list(table_client.query_entities(query_filter))

            if not entities:
                return None

            # Sort by createdAt descending and return the most recent
            entities.sort(key=lambda x: x.get('createdAt', ''), reverse=True)
            return entities[0]

        except Exception as e:
            print(f"Error retrieving OTP: {e}")
            return None

    def increment_otp_attempts(self, email: str, row_key: str) -> int:
        """Increment OTP attempt counter. Returns new attempt count."""
        table_client = self.service_client.get_table_client("otpcodes")

        try:
            entity = table_client.get_entity(email.lower(), row_key)
            entity['attempts'] = entity.get('attempts', 0) + 1
            table_client.update_entity(entity, mode="merge")
            return entity['attempts']
        except Exception as e:
            print(f"Error incrementing attempts: {e}")
            return 999  # High number to trigger max attempts

    def mark_otp_used(self, email: str, row_key: str):
        """Mark OTP as used."""
        table_client = self.service_client.get_table_client("otpcodes")

        try:
            entity = table_client.get_entity(email.lower(), row_key)
            entity['isUsed'] = True
            entity['usedAt'] = datetime.utcnow().isoformat()
            table_client.update_entity(entity, mode="merge")
        except Exception as e:
            print(f"Error marking OTP as used: {e}")

    # Session Operations
    def create_session(self, email: str, token: str, expires_at: datetime) -> Dict[str, Any]:
        """Create a new user session."""
        table_client = self.service_client.get_table_client("usersessions")

        user_id = str(uuid.uuid4())  # Generate new user ID
        now = datetime.utcnow().isoformat()

        entity = {
            "PartitionKey": email.lower(),
            "RowKey": token,
            "userId": user_id,
            "createdAt": now,
            "expiresAt": expires_at.isoformat(),
            "lastAccessedAt": now
        }

        table_client.create_entity(entity)
        return entity

    def get_session(self, token: str) -> Optional[Dict[str, Any]]:
        """Retrieve a session by token."""
        table_client = self.service_client.get_table_client("usersessions")

        try:
            # Query across all partitions for this token
            query_filter = f"RowKey eq '{token}'"
            entities = list(table_client.query_entities(query_filter))

            if not entities:
                return None

            return entities[0]
        except Exception as e:
            print(f"Error retrieving session: {e}")
            return None

    def delete_old_otps(self, email: str):
        """Delete old OTPs for an email (cleanup)."""
        table_client = self.service_client.get_table_client("otpcodes")

        try:
            query_filter = f"PartitionKey eq '{email.lower()}'"
            entities = list(table_client.query_entities(query_filter))

            for entity in entities:
                table_client.delete_entity(entity['PartitionKey'], entity['RowKey'])
        except Exception as e:
            print(f"Error deleting old OTPs: {e}")
