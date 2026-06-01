
## Deployment Topology

| Container | Hosting | Notes |
|-----------|---------|-------|
| iOS App | App Store distribution | Universal Links configured for invite deep-linking. |
| API Server | AWS ECS Fargate *or* App Runner | Stateless, horizontally scalable. Choice between Fargate and App Runner is an **open ADR** — see `adr.md`. |
| Database | AWS RDS PostgreSQL with PostGIS | Single-AZ for MVP; Multi-AZ deferred (see `adr.md`). Automated backups enabled. |
| Object Storage | AWS S3 | Private bucket. No public-read ACLs. All reads go through pre-signed URLs issued by the API. |
| Secrets Store | AWS Secrets Manager | Region-local. Rotation policies TBD. |

## CI/CD

| Stage | Tool | Triggers |
|-------|------|----------|
| Build, unit + property tests | GitHub Actions | On every PR |
| Integration tests (Testcontainers: PostgreSQL+PostGIS, LocalStack for S3) | GitHub Actions | On every PR |
| Staging deploy | GitHub Actions | On merge to `main` |
| Production deploy | GitHub Actions | Manual gate after staging soak |

iOS app CI is separate (Xcode Cloud or GitHub Actions with macOS runners — TBD). It does not share infrastructure with the backend pipeline.


iOS:
CI: Tests run on Xcode Cloud or GitHub Actions with macOS runners on every PR. Specific pipeline TBD.