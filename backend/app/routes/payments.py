from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timezone

from ..supabase_config import get_supabase_client

router = APIRouter(prefix="/webhooks", tags=["payments"])

# NOTE: This is a generic webhook shape.
# Adapt verification for your provider (Stripe/PayMongo/etc.).
class PaymentEvent(BaseModel):
    user_id: str
    status: str
    tier_plan: Optional[str] = "pro"
    event: Optional[str] = None
    provider: Optional[str] = None

@router.post("/payment")
async def payment_webhook(event: PaymentEvent, request: Request, x_signature: Optional[str] = Header(default=None)):
    # TODO: Verify signature based on provider. For now, accept for development/testing.
    # If you use Stripe, verify using stripe.Webhook with endpoint secret.
    # If you use PayMongo, verify using the signature header and webhook secret.

    if event.status.lower() not in ("paid", "succeeded", "success", "completed"):
        # Ignore non-successful events
        return {"ok": True, "ignored": True}

    user_id = event.user_id
    new_plan = (event.tier_plan or "pro").strip().lower()
    if new_plan != "pro":
        new_plan = "pro"  # normalize

    supabase = get_supabase_client()

    try:
        # Ensure the profile exists
        profile_resp = supabase.table("profiles").select("id").eq("id", user_id).single().execute()
        if not profile_resp.data:
            raise HTTPException(status_code=404, detail=f"Profile not found for user_id {user_id}")

        # Update plan (and optionally a timestamp)
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
    except HTTPException:
        raise
    except Exception as e:
        # Log and propagate
        raise HTTPException(status_code=500, detail=f"Failed to update plan: {e}")
