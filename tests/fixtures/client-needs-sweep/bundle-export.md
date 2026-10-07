# steer clarification questionnaire
<!-- steer:clarification-bundle -->
Fill in each **Answer** block below, then send this file back.
Do not change the "[feature] Q-NNN" heading lines - they map your answers to the spec.

## [product] Q-003 - Who should be invited to the AWS account as deployer for prod? [BLOCKING] [ACCESS]
<!-- steer:q feature=product id=Q-003 kind=access source=spec/vision.md -->
> Context: policy/delivery.yml gates production through a prod-branch PR, but no deploy target or deployer is recorded.
> Do not paste passwords, keys or tokens here. Name who should get access, or where an existing secret is stored - never the secret itself.

**Answer:**
Invite ops@client.example as deployer; the account is 1234-5678-9012, role DeployRole.

## [product] Q-004 - Which error-tracking account should the deployed app report to? [TOOLING]
<!-- steer:q feature=product id=Q-004 kind=tooling source=spec/vision.md -->
> Context: policy/delivery.yml lists no observability tool yet.

**Answer:**
Use our existing Sentry org "client-prod"; we will invite the dev lead.

## [product] Q-002 - Do we bill per seat or per workspace for the first release? [BLOCKING] [DECISION]
<!-- steer:q feature=product id=Q-002 kind=decision source=spec/vision.md -->
> Context: issue #412 is waiting on this pricing call.

**Answer:**
Per workspace.

## [product] Q-001 - Should archived invoices be shown by default?
<!-- steer:q feature=product id=Q-001 source=spec/vision.md -->
> Context: the vision leaves the default invoice list filter open.

**Answer:**
No - hidden behind an "Archived" filter.

---
