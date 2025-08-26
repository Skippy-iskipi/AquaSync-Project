from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel
from typing import Optional, Any, Dict
from datetime import datetime, timezone
import hmac
import hashlib
import os
import json
import logging

from ..supabase_config import get_supabase_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks", tags=["payments"])

# NOTE: This was a generic webhook shape used by a custom client.
# PayMongo will NOT post this shape, so keep it but make it tolerant and never return 4xx/5xx to PayMongo.
class PaymentEvent(BaseModel):
    user_id: str
    status: str
    tier_plan: Optional[str] = "pro"
    event: Optional[str] = None
    provider: Optional[str] = None

def _safe_update_plan(user_id: str, new_plan: str) -> Dict[str, Any]:
    """Update the user's plan in Supabase. Log errors and never throw outward."""
    try:
        supabase = get_supabase_client()
        # Ensure the profile exists
        profile_resp = supabase.table("profiles").select("id").eq("id", user_id).single().execute()
        if not profile_resp.data:
            logger.warning(f"Webhook: profile not found for user_id={user_id}")
            return {"ok": True, "updated": False, "reason": "profile_not_found"}

        update_resp = (
            supabase
            .table("profiles")
            .update({
                "tier_plan": new_plan,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            })
            .eq("id", user_id)
            .execute()
        )
        return {"ok": True, "updated": True, "data": update_resp.data}
    except Exception as e:
        logger.error(f"Webhook plan update failed for user_id={user_id}: {e}")
        return {"ok": True, "updated": False, "error": str(e)}

@router.post("/payment")
async def payment_webhook(event: PaymentEvent, request: Request, x_signature: Optional[str] = Header(default=None)):
    # Keep behavior tolerant; never raise outward.
    try:
        status_val = (event.status or "").lower()
        if status_val not in ("paid", "succeeded", "success", "completed"):
            return {"ok": True, "ignored": True}

        user_id = event.user_id
        new_plan = (event.tier_plan or "pro").strip().lower()
        if new_plan != "pro":
            new_plan = "pro"  # normalize

        return _safe_update_plan(user_id, new_plan)
    except Exception as e:
        logger.error(f"/webhooks/payment processing error: {e}")
        return {"ok": True, "ignored": True, "error": str(e)}

def verify_paymongo_signature(payload: bytes, signature_header: Optional[str], secret: str) -> bool:
    """Verify PayMongo webhook signature.
    Header format example: "t=timestamp,v1=hex_signature".
    We compute HMAC SHA256 of payload using the webhook secret, compare against provided signature.
    If header is missing or malformed, return False.
    """
    try:
        if not signature_header or not secret:
            return False
        # Very tolerant parsing (PayMongo typically uses t=..., v1=...)
        parts = dict(
            p.split("=", 1) for p in [seg.strip() for seg in signature_header.split(",") if "=" in seg]
        )
        provided_sig = parts.get("v1") or parts.get("signature") or ""
        if not provided_sig:
            return False
        computed = hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()
        # Use constant-time compare
        return hmac.compare_digest(computed, provided_sig)
    except Exception as e:
        logger.warning(f"Signature parse/verify failed: {e}")
        return False

@router.post("/paymongo")
async def paymongo_webhook(request: Request, paymongo_signature: Optional[str] = Header(default=None, alias="Paymongo-Signature")):
    """Robust PayMongo webhook endpoint.
    - Accepts raw JSON (no strict schema) to avoid 422.
    - Verifies signature when secret is set (PAYMONGO_WEBHOOK_SECRET).
    - Always returns 200 to avoid webhook disablement.
    """
    try:
        raw = await request.body()
        secret = os.getenv("PAYMONGO_WEBHOOK_SECRET", "")

        is_valid = verify_paymongo_signature(raw, paymongo_signature, secret) if secret else True
        if not is_valid:
            logger.warning("PayMongo signature invalid; event ignored")
            return {"ok": True, "ignored": True, "reason": "invalid_signature"}

        # Parse JSON body
        try:
            data: Dict[str, Any] = json.loads(raw.decode("utf-8")) if raw else {}
        except Exception as e:
            logger.warning(f"PayMongo payload not JSON: {e}")
            return {"ok": True, "ignored": True, "reason": "invalid_json"}

        # Extract fields based on typical PayMongo structure
        # Adjust mapping as needed for your exact event type
        attributes = (
            (data.get("data") or {}).get("attributes") or {}
        )
        event_type = attributes.get("type") or data.get("type") or ""
        payment_status = (
            (attributes.get("data") or {}).get("attributes", {}).get("status")
            or attributes.get("status")
            or data.get("status")
            or ""
        )
        # If you store the user id in metadata when creating the payment intent/source, fetch it here
        metadata = (
            (attributes.get("data") or {}).get("attributes", {}).get("metadata")
            or attributes.get("metadata")
            or {}
        )
        user_id = metadata.get("user_id") or metadata.get("uid") or ""

        logger.info(f"PayMongo webhook received: type={event_type}, status={payment_status}, user_id={user_id}")

        # Decide if this represents a successful payment
        success_markers = {"paid", "succeeded", "success", "completed"}
        if str(payment_status).lower() in success_markers and user_id:
            res = _safe_update_plan(user_id=user_id, new_plan="pro")
            return {"ok": True, "processed": True, **res}

        # Otherwise simply acknowledge
        return {"ok": True, "ignored": True}
    except Exception as e:
        # Never return 4xx/5xx to PayMongo. Log and ack.
        logger.error(f"Unhandled PayMongo webhook error: {e}")
        return {"ok": True, "ignored": True, "error": str(e)}
