// src/services/whatsapp.service.ts
//
// Sends WhatsApp OTP via Meta Cloud API using an AUTHENTICATION template.
//
// ─── Prerequisites (do once in Meta dashboard) ────────────────────────────────
// 1. Create a WhatsApp Business Account (WABA) on developers.facebook.com
// 2. Add a phone number and get its PHONE_NUMBER_ID
// 3. Generate a permanent System User token → META_ACCESS_TOKEN
// 4. Create an Authentication template named exactly what META_OTP_TEMPLATE_NAME
//    is set to (default: "aimesig_otp") with category AUTHENTICATION,
//    COPY_CODE button, security recommendation ON, expiry 5 min.
//    Template body (fixed by Meta): "<OTP> is your verification code."
// 5. Wait for template status → APPROVED (usually minutes for auth templates)
// ─────────────────────────────────────────────────────────────────────────────

import axios, { AxiosError } from 'axios';

const META_API_VERSION   = 'v20.0';
const META_API_BASE      = `https://graph.facebook.com/${META_API_VERSION}`;

function cfg() {
  const token      = process.env.META_ACCESS_TOKEN;
  const phoneId    = process.env.META_PHONE_NUMBER_ID;
  const template   = process.env.META_OTP_TEMPLATE_NAME ?? 'aimesig_otp';
  const language   = process.env.META_OTP_TEMPLATE_LANG ?? 'en_US';

  if (!token || !phoneId) {
    throw new Error(
      '[whatsapp] META_ACCESS_TOKEN and META_PHONE_NUMBER_ID must be set in .env',
    );
  }
  return { token, phoneId, template, language };
}

/**
 * Send an OTP to `phone` (E.164, e.g. +919876543210) via WhatsApp.
 *
 * Uses the AUTHENTICATION template, which sends:
 *   "<code> is your verification code.
 *    For your security, do not share this code.
 *    This code expires in 5 minutes."
 *
 * The OTP code appears in both:
 *   - components[0].parameters[0] → fills the {{1}} body variable
 *   - components[1].parameters[0] → populates the Copy Code button
 */
export async function sendWhatsAppOtp(phone: string, code: string): Promise<void> {
  const { token, phoneId, template, language } = cfg();

  const payload = {
    messaging_product: 'whatsapp',
    to: phone,              // E.164, no leading +  ← Meta accepts both forms
    type: 'template',
    template: {
      name:     template,
      language: { code: language },
      components: [
        // Body: fills the {{1}} variable with the OTP code
        {
          type:       'body',
          parameters: [{ type: 'text', text: code }],
        },
        // Button: populates the "Copy Code" button payload
        {
          type:     'button',
          sub_type: 'url',
          index:    '0',
          parameters: [{ type: 'text', text: code }],
        },
      ],
    },
  };

  try {
    const response = await axios.post(
      `${META_API_BASE}/${phoneId}/messages`,
      payload,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      },
    );
    console.log(
      `[whatsapp] OTP sent to ${phone} — wamid: ${response.data?.messages?.[0]?.id}`,
    );
  } catch (err) {
    const axErr = err as AxiosError<any>;
    const detail = axErr.response?.data?.error;
    console.error('[whatsapp] Failed to send OTP:', detail ?? axErr.message);
    throw new Error(detail?.message ?? 'Failed to send WhatsApp OTP');
  }
}
