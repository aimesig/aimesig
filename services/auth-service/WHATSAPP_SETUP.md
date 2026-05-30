# WhatsApp OTP Setup (Meta Cloud API)

Follow these steps **once** before deploying.

---

## 1. Create / access your Meta App

1. Go to [developers.facebook.com](https://developers.facebook.com) → **My Apps → Create App**
2. Choose **Business** type
3. Add the **WhatsApp** product to the app

---

## 2. Get your credentials

In your app dashboard → **WhatsApp → API Setup**:

| Value | Where to find it | .env key |
|-------|-----------------|---------|
| Phone Number ID | Shown on API Setup page | `META_PHONE_NUMBER_ID` |
| Permanent access token | Business Settings → System Users → Generate token (whatsapp_business_messaging + whatsapp_business_management) | `META_ACCESS_TOKEN` |

---

## 3. Create the Authentication template

Go to **WhatsApp Manager → Message Templates → Create Template**

| Field | Value |
|-------|-------|
| Category | **Authentication** |
| Name | `aimesig_otp` (must match `META_OTP_TEMPLATE_NAME`) |
| Language | English (US) |
| Security recommendation | ✅ On — adds "For your security, do not share this code." |
| Code expiry footer | ✅ On — 5 minutes |
| Button type | **Copy Code** — text: `Copy Code` |

Submit for review. Authentication templates are usually approved in minutes.

> The body text is **fixed by Meta**: `{{1}} is your verification code.`  
> You cannot customise it. Your code fills the `{{1}}` variable at send time.

---

## 4. Add test numbers (sandbox only)

Until your WABA is approved for production:
- Go to **API Setup → To → Manage phone number list**
- Add the WhatsApp numbers you want to test with
- Meta will send each number a verification code on WhatsApp

---

## 5. Add env vars

```env
META_ACCESS_TOKEN=EAAxxxxxxxxxxxxxxx
META_PHONE_NUMBER_ID=123456789012345
META_OTP_TEMPLATE_NAME=aimesig_otp
META_OTP_TEMPLATE_LANG=en_US
```

---

## 6. Dev fallback (no Meta creds)

If `META_ACCESS_TOKEN` or `META_PHONE_NUMBER_ID` are missing, the service
throws an error at startup — check the logs and the OTP code will be printed
there so you can still test locally without a live WhatsApp number.

---

## What the user receives

```
123456 is your verification code.
For your security, do not share this code.
This code expires in 5 minutes.

[Copy Code]
```
