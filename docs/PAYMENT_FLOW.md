# Payment → dispense flow

```
Kiosk (svm_fe)                      Backend (svm-be)                       RafflesPay
──────────────                      ────────────────                       ──────────
select product
POST /api/v1/kiosk/transactions ──► StartCheckout ── create_charge ───────► POST /payments (signed)
show QR (checkout_url / QRIS) ◄──── pending, expires_at
                                                    customer pays ──────── callback (signed)
                                    POST /api/v1/payments/webhook ◄──────┘
                                    verify → paid
transaction_updated (cable) ◄────── broadcast            (also: GET .../transactions/:uuid polling)
POST .../claim ───────────────────► paid → dispensing (only one claim wins)
save PendingVend, vmc.vend(slot)
POST .../vend_result ─────────────► settled (stock −1) | refund_required | needs_review
```

## Transaction states

| Status | Meaning | Who moves it |
|---|---|---|
| `pending` | QR on screen | StartCheckout |
| `paid` | gateway confirmed | webhook / reconcile |
| `dispensing` | kiosk claimed, motor turning | kiosk `claim` |
| `settled` | product dropped — the only revenue state | kiosk `vend_result` = success |
| `failed` | payment failed or could not be created | webhook / StartCheckout |
| `expired` | not paid before `expires_at` | TransactionSweepJob |
| `cancelled` | customer cancelled | kiosk `cancel` |
| `refund_required` | money taken, nothing dropped | vend failed/aborted/timeout, late payment, amount mismatch, kiosk never claimed |
| `needs_review` | motor may have turned, no result (`UNKNOWN`) | vend unknown, stuck dispense |
| `refunded` | refunded by hand | back office → Transactions → Mark refunded |

Vend outcomes follow the VMC SDK money rules: only `success` charges, `failed`/`aborted`/`timeout`
refund, `unknown` is **never** auto-refunded.

`TransactionSweepJob` runs every minute (config/recurring.yml, production): reconciles pending
payments older than 1 min against the gateway, expires overdue ones, flags paid-but-unclaimed after
2 min and dispensing-without-result after 5 min.

## Backend configuration (ENV)

| Variable | Default | Notes |
|---|---|---|
| `PAYMENT_GATEWAY` | `mock` (dev/test), `raffles_pay` (production) | |
| `APP_BASE_URL` | `http://localhost:3000` | **Required in production.** Public HTTPS URL; the callback is `APP_BASE_URL/api/v1/payments/webhook` |
| `PAYMENT_EXPIRES_IN` | `180` | seconds a QR stays valid |
| `RAFFLESPAY_BASE_URL` | `https://rafflespay.com` | |
| `RAFFLESPAY_API_VERSION` | `v1` | docs say v1, Postman says v2 — confirm with RafflesPay |
| `RAFFLESPAY_CLIENT_ID` / `RAFFLESPAY_CLIENT_SECRET` | | Workspace → Merchants |
| `RAFFLESPAY_PRIVATE_KEY_PATH` (or `RAFFLESPAY_PRIVATE_KEY` with `\n`) | | **your** PKCS8 private key |
| `RAFFLESPAY_PUBLIC_KEY_PATH` (or `RAFFLESPAY_PUBLIC_KEY`) | | **their** "RPAY Public Key" |

With `PAYMENT_GATEWAY=mock`, the checkout URL is a local page (`/mock_gateway/checkouts/:uuid`) with
Pay / Fail buttons that send a signed callback through the real webhook code.

## Kiosk configuration (`--dart-define`)

| Define | Default | |
|---|---|---|
| `API_BASE_URL` | `http://10.10.51.85:3000` | backend |
| `MACHINE_TOKEN` | — | back office → Machines → machine → *Kiosk API token* |
| `VMC_TRANSPORT` | `usb` | `usb` (FTDI adapter, this box), `serial` (`VMC_SERIAL_PATH`), `simulator` |
| `VMC_SLOT_COUNT` | `9` | slots 1..N accepted by the board |

```bash
flutter run --dart-define=API_BASE_URL=http://<laptop-ip>:3000 \
  --dart-define=MACHINE_TOKEN=<token> --dart-define=VMC_TRANSPORT=simulator
```
