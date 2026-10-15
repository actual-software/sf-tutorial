# ADR 0005: Phone-number identity behind one module

- Status: Accepted
- Date: 2026-10-14

## Context

The MVP has no external auth provider. Customers are identified only by the phone number on their orders. The manifest expects this to be replaced later (magic link, OTP), and asks that the swap touch one module. The Security standards require phone numbers to be validated and normalized server-side, and an order lookup to return only that phone's orders.

## Decision

1. There are no customer accounts or sessions. A customer is the phone number on their orders.
2. Phone parsing lives in exactly one place:
   - `shared/src/phone.ts`: pure normalize and format functions, also used by client forms.
   - `server/src/identity/`: the server boundary, which exposes `resolveCustomerIdentity`.

   Routes validate the request shape with zod, typing the phone as a plain string, and pass that raw value to `resolveCustomerIdentity`. Routes, services, and repositories never parse or normalize phone numbers themselves. Moving to OTP or magic links later means replacing this module.

3. Accepted numbers are North American Numbering Plan numbers: 10 digits, optionally preceded by `1` or `+1`, with common punctuation or spaces. They are stored and compared in E.164 form (`+1XXXXXXXXXX`). Anything else is rejected with 400 `INVALID_PHONE_NUMBER`. This assumes a US/Canada neighborhood restaurant; supporting other countries needs a new ADR.
4. Customer endpoints return only orders whose `phone_number` equals the normalized phone in the request. No customer endpoint lists phone numbers or other customers' orders. Staff endpoints, under `/api/staff`, may show phone numbers.
5. Phone numbers are personal data. Do not log them (no logging of request bodies or query strings), and do not put them in error messages.

## Consequences

- Anyone who knows a phone number can see that number's orders. The manifest accepts this for the MVP, and the single identity module is where a stronger check goes.
- Formatting differences such as `(555) 123-4567` and `+1 555-123-4567` resolve to the same customer.
