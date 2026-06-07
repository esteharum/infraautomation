# Task 2 — Terraform Infrastructure Debugging

The Terraform modules in `terraform/modules/` contain intentional bugs.

Find and fix all bugs, then run:

```bash
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

The infrastructure must be fully provisioned and functional before proceeding to the next task.

---

## Hints

- There are **10 bugs** spread across **5 modules**.
- Some bugs will cause `terraform` commands to fail. Others will only appear after deployment.
- Read **Section 3.2 – 3.6** of the module document carefully. Every bug contradicts at least one specification.
