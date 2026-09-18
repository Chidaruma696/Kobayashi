[🇪🇸 Español](README.es.md)

<div align="center">
  <br/>

# Kobayashi

**帳 · Point of sale and back office for a meat plant that labels by weight, supplies its own shops and delivers to route customers. Ruby on Rails.**

<br/>

![Rails 8.1](https://img.shields.io/badge/rails-8.1-cc0000?style=for-the-badge&logo=rubyonrails&logoColor=white)
![Ruby 3.4](https://img.shields.io/badge/ruby-3.4-cc342d?style=for-the-badge&logo=ruby&logoColor=white)
![SQLite](https://img.shields.io/badge/sqlite-single%20server-003b57?style=for-the-badge&logo=sqlite&logoColor=white)
![MIT License](https://img.shields.io/badge/license-MIT-1b150d?style=for-the-badge)

<br/>

*Identity barcodes · append-only stock ledger · money in integer cents · one transaction per operation · nothing leaves without a scan*

</div>

---

> [!NOTE]
> Kobayashi is the successor of [ToyPOS](https://github.com/Chidaruma696/ToyPOS): same business, but built **register first** instead of domain first. It runs on one server for the headquarters and its shops. It is in active development and has not yet run a real day of sales.

<br/>

## 🏪 What it is

The headquarters produces meat, **labels every package on a scale**, sells at its own counter, supplies its shops and delivers to route customers who pay on delivery. Every package, box and pallet carries an **EAN-13 identity barcode**: the code names the row in the database, the weight lives in the database, never inside the code.

| Module | What it does | Rule it enforces |
|---|---|---|
| **Orders** | A shop or a route customer asks for goods; the headquarters fulfils line by line. | Fulfilled quantity is always the sum of the labels linked to the line, never a stored counter. |
| **Production** | Raw product goes in, labelled cuts come out, the difference is waste. | Nothing comes out that did not go in; no production without an order or an authorised PIN. |
| **Labels** | Package, box and pallet with identity barcodes, printed at 55×45 mm. | No free labelling: every label comes from an order line, a production run, or a recorded authorisation. |
| **Dispatch** | Scan to pick, a second person scans to verify the load, seal, send. | The picker cannot verify their own load. A label can be in only one active dispatch. |
| **Receiving** | The shop scans package by package (or a whole pallet); missing or broken packages are reported by barcode. | What is not scanned does not enter stock. Boxes are not accepted whole. |
| **Register** | Scan or type, scale for loose kilos, mixed payments, 80 mm ticket with its own barcode, cash drawer with float, withdrawals and close. | No sale without stock, without an open drawer, or above the cash limit. Price cuts need a PIN and never go under half the list price. |
| **Routes** | A trip per route and day: sealed deliveries board in stop order, the truck leaves, and the driver works from the phone: scan what gets off, reject what the customer refused, collect cash, take the order for the next visit. Back at the office the trip is settled: cash collected minus expenses is what the driver hands in; any shortfall is charged to the driver. | Money collected on the road is not in the drawer until settlement. Rejected goods return to stock the moment they are refused. Delivering without scanning is allowed but goes to the review tray. |
| **Route credit** | Each customer has a credit type as the business runs it: cash only, note by note, limit, weekly (pays at the cut-off), cash-while-paying-down (7 days), special (own cut-off day). At the stop the driver can leave the note on account if the rule allows; the customer can also pay down old debt. Collections screen with balances, ageing, statements, office payments and a manual block that overrides the rule. | Blocking is computed live from the account: when the customer pays, it opens by itself. The point of sale stays cash only. |
| **Shipping without scanning** | A line without a label can go in any dispatch with a reason, and a dispatch can be sealed without the second scan with a reason. | Both land in the review tray in the name of whoever did it. The double scan (pick, verify) is the norm, not a wall. |
| **Route sales** | Dispatch to a customer closes a note payable on delivery; the driver comes back and the delivery is charged into the open drawer. | Rejected goods come back as a return against the ticket. Cash only. |
| **Counts** | The supervisor scans everything; the count wins. | Stock is adjusted, unseen labels die, and the shortage is charged to the cashier. |
| **Prices** | List price, per-shop overrides, promotions (special price, percentage, volume). | The register applies the cheapest valid rule by itself; a promotion never raises a price. |
| **Deferred authorization** | Anything that would need a supervisor (free labelling, production without an order, a line without a label, a stock adjustment, a cash withdrawal) goes through with a reason when nobody is around, and lands in a review tray. | The flow never stops; the supervisor approves or flags each one at the end of the day, and a flagged one can be charged to whoever did it. A PIN from someone with permission skips the tray. Selling below list price still needs the PIN. |
| **Dashboard & admin** | Sales, tickets, payment mix, closes, waste, counts, valued stock, CSV by product; products, users, roles, shops, customers, routes. | Permissions by key, ribbon tabs appear only for what the user may do. |

<br/>

## 🧭 Design

- **The ledger is the truth.** `Movimiento` is insert-only; `Existencia` is a projection updated in the same transaction, with `CHECK (cantidad >= 0)` in the database.
- **Spanish models and tables**, because the business already speaks that language: pesada, caja, traspaso, corte, folio.
- **One transaction per operation**, one code path per operation. No fallbacks.
- **Kilos to three decimals, money in integer cents**, one clock (Mexico City), business date separate from capture time.
- **Scale in the browser** through Web Serial with [Kana](https://github.com/Chidaruma696/Kana) (Chrome or Edge only).
- **Office-style ribbon**: tabs per module, big buttons per action, filtered by permission.

<br/>

## 🚀 Run it

```
bin/setup        # bundle, database, seeds
bin/dev          # http://localhost:3000
```

Development seeds create `admin` / `admin1234` (PIN `1234`), a headquarters, a shop and a handful of products. Tests: `bin/rails test`.

<br/>

## 📚 Credits and names

Kobayashi, Kana and Tohru take their names from *Miss Kobayashi's Dragon Maid* by Coolkyousinnjya; nothing here is affiliated with the author or the publishers. Scale protocol via [Kana](https://github.com/Chidaruma696/Kana) (MIT). Built with Rails, Hotwire and Tailwind.

## 📄 License

MIT. See [LICENSE](LICENSE).
