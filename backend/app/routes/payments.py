from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel
from typing import Optional, Any, Dict
from datetime import datetime, timezone
import hmac
import hashlib
import re
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
        # Accept commas or semicolons as separators
        segs = [seg.strip() for seg in re.split(r"[,;]", signature_header) if "=" in seg]
        parts = dict(p.split("=", 1) for p in segs)
        # Accept multiple possible signature keys
        provided_candidates = [
            parts.get("v1"),
            parts.get("signature"),
            parts.get("s"),
            parts.get("sig"),
            parts.get("mac"),
        ]
        provided_candidates = [p.strip().strip('"') for p in provided_candidates if p]
        # Also include lowercase variants to handle uppercase hex signatures
        provided_candidates = list({*(provided_candidates + [p.lower() for p in provided_candidates])})
        ts = parts.get("t") or parts.get("timestamp") or ""
        if not provided_candidates:
            return False

        # Try multiple canonicalization strategies:
        # 1) HMAC(raw_body)
        # 2) HMAC(f"{ts}.{raw_body}") if timestamp is provided (some providers sign this way)
        secret_bytes = secret.encode("utf-8")
        raw_hmac = hmac.new(secret_bytes, payload, hashlib.sha256)
        candidates = [
            raw_hmac.hexdigest(),
            raw_hmac.digest().hex(),  # same as hexdigest, for completeness
            # base64-encoded possibility
        ]
        try:
            import base64
            candidates.append(base64.b64encode(raw_hmac.digest()).decode("ascii"))
        except Exception:
            pass
        if ts:
            # Build timestamped message purely in bytes: ts + '.' + raw_body
            ts_payload = ts.encode("utf-8") + b"." + payload
            ts_hmac = hmac.new(secret_bytes, ts_payload, hashlib.sha256)
            candidates.extend([
                ts_hmac.hexdigest(),
                ts_hmac.digest().hex(),
            ])
            try:
                import base64
                candidates.append(base64.b64encode(ts_hmac.digest()).decode("ascii"))
            except Exception:
                pass

        for provided_sig in provided_candidates:
            for comp in candidates:
                if hmac.compare_digest(comp, provided_sig):
                    return True

        # Minimal debug to aid setup; does not leak payload
        logger.warning(
            "PayMongo signature mismatch; tried %d computed variants against %d provided keys (%s); ts_present=%s; provided_len=%s",
            len(candidates),
            len(provided_candidates),
            ",".join(parts.keys()),
            bool(ts),
            [len(s) for s in provided_candidates],
        )
        return False
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

        # Fallback: try to locate signature from any header if alias didn't capture it
        sig = paymongo_signature
        if not sig:
            header_names = []
            for k, v in request.headers.items():
                kl = k.lower()
                header_names.append(kl)
                if "paymongo-signature" in kl or kl == "signature":
                    sig = v
                    # Do not break immediately; prefer PayMongo-Signature if present
                    if "paymongo-signature" in kl:
                        break
            try:
                logger.info("Webhook headers present: %s", ",".join(sorted(set(header_names))))
            except Exception:
                pass
        if not sig:
            logger.warning("PayMongo signature header missing; event ignored")

        is_valid = verify_paymongo_signature(raw, sig, secret) if secret else True
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
        # Primary envelope
        envelope = data.get("data") or {}
        attributes = envelope.get("attributes") or {}
        event_type = attributes.get("type") or data.get("type") or ""

        # Status may be present in different nests depending on event
        nested = (attributes.get("data") or {}).get("attributes", {})
        payment_status = (
            nested.get("status")
            or attributes.get("status")
            or data.get("status")
            or ""
        )

        # Try to extract metadata-provided user id (for intents/sources flows)
        metadata = (
            (attributes.get("data") or {}).get("attributes", {}).get("metadata")
            or attributes.get("metadata")
            or {}
        )
        user_id = metadata.get("user_id") or metadata.get("uid") or ""

        # Also try to extract the link id for Link events (attributes.data.id)
        link_container = attributes.get("data") or {}
        link_id = link_container.get("id") or attributes.get("id") or envelope.get("id") or ""

        logger.info(
            f"PayMongo webhook received: event_type={event_type}, status={payment_status}, user_id={user_id}, link_id={link_id}"
        )

        success_markers = {"paid", "succeeded", "success", "completed"}

        # If a user_id is present and status indicates success, update directly
        if str(payment_status).lower() in success_markers and user_id:
            res = _safe_update_plan(user_id=user_id, new_plan="pro")
            return {"ok": True, "processed": True, **res}

        # If this is a Link event (e.g., link.paid) we won't have metadata.
        # Use the link_id to look up our pending subscription and then update plan.
        try:
            if str(payment_status).lower() in success_markers and link_id:
                supabase = get_supabase_client()
                # Find the subscription created at link creation time
                sub_resp = (
                    supabase
                    .table("subscriptions")
                    .select("id,user_id,status,tier_plan")
                    .eq("paymongo_payment_id", link_id)
                    .order("created_at", desc=True)
                    .limit(1)
                    .execute()
                )
                if sub_resp.data:
                    sub = sub_resp.data[0]
                    uid = sub.get("user_id")
                    if uid:
                        # Mark subscription active
                        now_iso = datetime.now(timezone.utc).isoformat()
                        (
                            supabase
                            .table("subscriptions")
                            .update({
                                "status": "active",
                                "last_payment_date": now_iso,
                                "updated_at": now_iso,
                            })
                            .eq("id", sub.get("id"))
                            .execute()
                        )
                        # Update user plan
                        res = _safe_update_plan(user_id=uid, new_plan="pro")
                        logger.info(f"Subscription activated and plan updated for user_id={uid} via link_id={link_id}")
                        return {"ok": True, "processed": True, **res}
        except Exception as e:
            logger.error(f"Link resolution/update failed: {e}")

        # Otherwise simply acknowledge
        return {"ok": True, "ignored": True}
    except Exception as e:
        # Never return 4xx/5xx to PayMongo. Log and ack.
        logger.error(f"Unhandled PayMongo webhook error: {e}")
        return {"ok": True, "ignored": True, "error": str(e)}
