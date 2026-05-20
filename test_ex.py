
data = {
    "age": 30,
    "weight": 70.0,
    "height": 175.0,
    "gender": "Erkek",
    "risk_level": "low",
    "force_refresh": True
}

try:
    # Get a token first
    # Or just hit the endpoint, wait, we need auth.
    # The endpoint uses `Depends(get_current_user)`.
    pass
except Exception:
    pass
