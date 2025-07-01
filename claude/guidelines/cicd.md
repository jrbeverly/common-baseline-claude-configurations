# CI/CD Guidelines (Gitea Actions)

**Status:** GUIDELINES - Preferred approaches, deviations allowed with justification

**Purpose:** Standard patterns for continuous integration and deployment using Gitea Actions.

---

## Gitea Actions Usage

**Principle:** Use Gitea Actions for CI/CD pipelines in self-hosted or Gitea Cloud environments.

**Why Gitea Actions?**
- **GitHub Actions Compatible:** Uses same YAML syntax and many actions
- **Self-Hosted:** Full control, no vendor lock-in
- **Cost Control:** Free for self-hosted runners, predictable for cloud
- **Privacy:** Code and artifacts stay in your infrastructure
- **Open Source:** Community-driven, transparent

**Migration from GitHub:** Minimal changes required (mostly runner labels).

**Workflow Location:**

```
.gitea/
└── workflows/
    ├── ci.yml              # Build and test on every push
    ├── deploy-staging.yml  # Deploy to staging on main branch
    ├── deploy-prod.yml     # Deploy to prod on release tag
    └── cleanup.yml         # Nightly cleanup of sandbox environments
```

---

## Cost-Aware Pipeline Design

**Principle:** Minimize CI/CD costs through efficient pipeline design and selective execution.

**Strategies:**

### 1. Path-Based Triggers

**Run pipelines only when relevant files change:**

```yaml
# .gitea/workflows/backend-ci.yml
name: Backend CI

on:
  push:
    branches: [main, develop]
    paths:
      - 'src/**'           # Backend code
      - 'test/**'          # Tests
      - '.gitea/workflows/backend-ci.yml'  # This workflow
  pull_request:
    paths:
      - 'src/**'
      - 'test/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build backend
        run: dotnet build src/LibraryService/LibraryService.sln
```

### 2. Conditional Job Execution

**Skip expensive jobs when not needed:**

```yaml
# .gitea/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      backend: ${{ steps.filter.outputs.backend }}
      frontend: ${{ steps.filter.outputs.frontend }}
      infra: ${{ steps.filter.outputs.infra }}
    steps:
      - uses: actions/checkout@v3
      - uses: dorny/paths-filter@v2
        id: filter
        with:
          filters: |
            backend:
              - 'src/**'
            frontend:
              - 'app/**'
            infra:
              - 'env/**'
              - 'modules/**'

  backend-build:
    needs: changes
    if: needs.changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: dotnet build

  frontend-build:
    needs: changes
    if: needs.changes.outputs.frontend == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: npm run build
```

### 3. Caching Dependencies

**Cache npm/NuGet packages to speed up builds:**

```yaml
jobs:
  build-dotnet:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '8.0.x'

      - name: Cache NuGet packages
        uses: actions/cache@v3
        with:
          path: ~/.nuget/packages
          key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj') }}
          restore-keys: |
            ${{ runner.os }}-nuget-

      - name: Restore dependencies
        run: dotnet restore

      - name: Build
        run: dotnet build --no-restore

  build-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Cache npm packages
        uses: actions/cache@v3
        with:
          path: ~/.npm
          key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-npm-

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build
```

---

## Nightly Builds Over Per-Push

**Principle:** For expensive or non-critical jobs, use scheduled builds instead of running on every push.

**When to Use Nightly Builds:**
- Integration tests against real AWS services
- End-to-end tests (Playwright, Selenium)
- Security scans (SAST, dependency checks)
- Documentation builds
- Sandbox environment cleanup

**Example - Nightly Integration Tests:**

```yaml
# .gitea/workflows/nightly-integration.yml
name: Nightly Integration Tests

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM daily
  workflow_dispatch:     # Allow manual trigger

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    env:
      AWS_REGION: us-east-1
      ENVIRONMENT: integration

    steps:
      - uses: actions/checkout@v3

      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '8.0.x'

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Run integration tests
        run: dotnet test --filter Category=Integration

      - name: Cleanup test resources
        if: always()
        run: |
          # Delete test DynamoDB tables, S3 objects, etc.
          aws dynamodb delete-table --table-name test-table-${{ github.run_id }} || true
```

**Example - Weekly Security Scan:**

```yaml
# .gitea/workflows/security-scan.yml
name: Security Scan

on:
  schedule:
    - cron: '0 3 * * 1'  # 3 AM every Monday
  workflow_dispatch:

jobs:
  dependency-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run Snyk security scan
        uses: snyk/actions/dotnet@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

      - name: Upload results
        if: failure()
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: snyk.sarif
```

---

## Separation of Infrastructure and Application Delivery

**Principle:** Infrastructure changes and application deployments are separate pipelines with different triggers and approval processes.

**Why Separate?**
- **Different lifecycles:** Infrastructure changes are infrequent, app deployments are frequent
- **Risk management:** Infrastructure changes are higher risk
- **Approval workflows:** Infrastructure may require manual approval
- **Blast radius:** App deployments can rollback easily, infrastructure changes cannot

**Infrastructure Pipeline:**

```yaml
# .gitea/workflows/infra-deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'env/**'
      - 'modules/**'
      - '.gitea/workflows/infra-deploy.yml'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - staging
          - prod

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.6.0

      - name: Terraform Init
        working-directory: env/portal-service/${{ inputs.environment || 'staging' }}
        run: terraform init

      - name: Terraform Plan
        working-directory: env/portal-service/${{ inputs.environment || 'staging' }}
        run: terraform plan -out=tfplan

      - name: Upload plan
        uses: actions/upload-artifact@v3
        with:
          name: tfplan
          path: env/portal-service/${{ inputs.environment || 'staging' }}/tfplan

  apply:
    needs: plan
    runs-on: ubuntu-latest
    # Require manual approval for prod
    environment: ${{ inputs.environment || 'staging' }}
    steps:
      - uses: actions/checkout@v3

      - name: Download plan
        uses: actions/download-artifact@v3
        with:
          name: tfplan
          path: env/portal-service/${{ inputs.environment || 'staging' }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Terraform Init
        working-directory: env/portal-service/${{ inputs.environment || 'staging' }}
        run: terraform init

      - name: Terraform Apply
        working-directory: env/portal-service/${{ inputs.environment || 'staging' }}
        run: terraform apply tfplan
```

**Application Pipeline:**

```yaml
# .gitea/workflows/app-deploy.yml
name: Deploy Application

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'app/**'
      - '.gitea/workflows/app-deploy.yml'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '8.0.x'

      - name: Build Lambda function
        run: |
          cd src/LibraryService/LibraryService.Api
          dotnet lambda package -c Release -o bin/Release/net8.0/function.zip

      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: lambda-package
          path: src/LibraryService/LibraryService.Api/bin/Release/net8.0/function.zip

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v3
        with:
          name: lambda-package

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Deploy to Lambda
        run: |
          aws lambda update-function-code \
            --function-name portal-api-staging \
            --zip-file fileb://function.zip

  deploy-prod:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: prod  # Requires manual approval
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v3
        with:
          name: lambda-package

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_PROD }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_PROD }}
          aws-region: us-east-1

      - name: Deploy to Lambda
        run: |
          aws lambda update-function-code \
            --function-name portal-api-prod \
            --zip-file fileb://function.zip
```

---

## Environment-Aware Deployments

**Principle:** Use Gitea environments for deployment approval, secrets management, and environment-specific configuration.

**Environment Configuration (Gitea UI):**

```
Settings → Environments → Add Environment

Name: prod
Protection Rules:
  ✅ Required reviewers: 1
  ✅ Prevent deployment from branches: main only

Secrets:
  AWS_ACCESS_KEY_ID_PROD
  AWS_SECRET_ACCESS_KEY_PROD
  DATABASE_CONNECTION_STRING
```

**Environment-Specific Deployment:**

```yaml
# .gitea/workflows/deploy.yml
name: Deploy

on:
  push:
    tags:
      - 'v*.*.*'  # Prod deployments only on version tags

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [staging, prod]
    environment: ${{ matrix.environment }}
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to ${{ matrix.environment }}
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          FUNCTION_NAME: portal-api-${{ matrix.environment }}
        run: |
          aws lambda update-function-code \
            --function-name ${{ env.FUNCTION_NAME }} \
            --zip-file fileb://function.zip
```

**Branch-Based Deployment:**

```yaml
# .gitea/workflows/deploy-by-branch.yml
name: Deploy by Branch

on:
  push:
    branches:
      - main     # Staging
      - release  # Production

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.ref == 'refs/heads/main' && 'staging' || 'prod' }}
    steps:
      - uses: actions/checkout@v3

      - name: Determine environment
        id: env
        run: |
          if [ "${{ github.ref }}" == "refs/heads/main" ]; then
            echo "environment=staging" >> $GITHUB_OUTPUT
          else
            echo "environment=prod" >> $GITHUB_OUTPUT
          fi

      - name: Deploy
        run: echo "Deploying to ${{ steps.env.outputs.environment }}"
```

---

## Minimal Fixed CI Cost

**Principle:** Optimize CI/CD to minimize fixed monthly costs using self-hosted runners and efficient scheduling.

**Strategies:**

### 1. Self-Hosted Runners (When Possible)

**Advantages:**
- No per-minute charges
- Full control over runner environment
- Can run on existing infrastructure
- Better performance (closer to resources)

**Configuration:**

```yaml
# .gitea/workflows/ci.yml
jobs:
  build:
    runs-on: self-hosted  # Use your own runner
    steps:
      - uses: actions/checkout@v3
      - run: dotnet build
```

**Self-Hosted Runner Setup (Docker):**

```bash
# Run Gitea Actions runner in Docker
docker run -d \
  --name gitea-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e GITEA_INSTANCE_URL=https://gitea.example.com \
  -e GITEA_RUNNER_REGISTRATION_TOKEN=$TOKEN \
  gitea/act_runner:latest
```

### 2. Limit Concurrent Jobs

**Prevent runaway costs:**

```yaml
# .gitea/workflows/expensive-tests.yml
concurrency:
  group: expensive-tests
  cancel-in-progress: false  # Don't cancel, queue instead

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 30  # Kill after 30 minutes
    steps:
      - run: npm test
```

### 3. Scheduled Cleanup

**Destroy expensive resources automatically:**

```yaml
# .gitea/workflows/cleanup-sandbox.yml
name: Cleanup Sandbox

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM daily

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Destroy sandbox environment
        working-directory: env/portal-service/sandbox
        run: |
          terraform init
          terraform destroy -auto-approve

      - name: Delete old Lambda versions
        run: |
          # Keep only latest 3 versions
          aws lambda list-versions-by-function \
            --function-name portal-api-staging \
            --query 'Versions[?Version!=`$LATEST`] | reverse(@) | [3:]' \
            --output text | \
          while read version; do
            aws lambda delete-function --function-name portal-api-staging:$version
          done
```

---

## Best Practices Summary

**Cost Optimization:**
- ✅ Use path-based triggers to avoid unnecessary runs
- ✅ Conditional job execution based on file changes
- ✅ Cache dependencies (npm, NuGet, Docker layers)
- ✅ Nightly builds for expensive tests
- ✅ Self-hosted runners when possible
- ✅ Timeout limits on all jobs

**Pipeline Design:**
- ✅ Separate infrastructure and application deployments
- ✅ Environment-based approvals (staging auto, prod manual)
- ✅ Matrix builds for multiple environments
- ✅ Artifact uploading/downloading for multi-job workflows

**Security:**
- ✅ Use Gitea environments for secrets management
- ✅ Separate credentials per environment
- ✅ Least privilege IAM roles
- ✅ No secrets in logs

**Reliability:**
- ✅ Automatic cleanup of test resources
- ✅ Timeout limits prevent hung jobs
- ✅ Retry strategies for flaky tests
- ✅ Rollback mechanisms

---
