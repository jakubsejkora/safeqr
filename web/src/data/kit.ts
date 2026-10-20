import { EXAMPLE_IBAN } from "./gallery.ts";

export const kitCodes = {
  payment: {
    id: "kit-payment",
    payload: `SPD*1.0*ACC:${EXAMPLE_IBAN}*AM:499.00*CC:CZK*RN:FIKTIVNI NABIDKY DEMO*X-VS:20261020*MSG:SAFE QR DEMO - NEPLATIT https://example.com/bonus`,
  },
  sms: {
    id: "kit-premium-sms",
    payload: "SMSTO:9030099:START",
  },
} as const;
