# Customer export

> Status: draft

## PO acceptance

Pending PO review.

## What this feature does

Lets an authenticated user export their customer list as a CSV file.

## Why we are building it

Customers have asked to move their data into their own spreadsheets and BI tools.

## User experience

A user clicks "Export" on the customers page and downloads a `.csv`.

## Key concepts & data

A customer record: name, email, created date.

## What is in scope

- CSV export of the current user's own customers.

## What is out of scope

- Scheduled or recurring exports.

## Open questions

### Q-001 — Which columns belong in the export?

- created: 2026-06-19
- status: open
- impact: non-blocking

## Recommended next actions

### Human decision required

PO to validate the drafted intent for `customer-export`.

### Current recommended action

PO reviews and approves the `customer-export` intent.
Suggested command: `/steer:spec customer-export`
