# MLC-LLM CI/CD Pipeline

This project uses GitHub Actions for a complete CI/CD workflow, including Docker image builds, automated testing, Python wheel packaging, GitHub Releases, and demo deployment.

## Pipeline Overview

1. **Build and Push Docker Image**
   - Builds a multipurpose Docker image (for development and build).
   - Pushes the image to GitHub Container Registry (GHCR).

2. **Automated Tests**
   - Runs all tests inside the Docker image.
   - Gates further stages; if tests fail, the pipeline stops.

3. **Build Python Wheels**
   - Builds Python wheels for Linux, Windows, and macOS.
   - Uploads wheels as workflow artifacts.

4. **Create GitHub Release**
   - On pushing a tag like `v1.0.0`, downloads wheel artifacts.
   - Publishes a new GitHub Release with the built wheels attached.

5. **Deploy and Validate Demo Model**
   - Deploys the latest Docker image as a demo server.
   - Runs a health check to ensure the service is running.

---

## How to Use the Pipeline

### 1. On Every Push or Pull Request

- The workflow runs on every push to `main` and on pull requests targeting `main`.
- It builds the Docker image and runs all tests.

### 2. Building and Publishing a Release

To trigger a full release (including GitHub Release and deployment):

1. **Create a version tag** (must start with `v`, e.g., `v1.2.3`):

   ```sh
   git tag v1.2.3
   git push origin v1.2.3
   ```

2. The workflow will:
   - Build and push the Docker image.
   - Run all tests.
   - Build wheels for all platforms.
   - Create a GitHub Release with the wheels attached.
   - Deploy and validate the demo server.

### 3. Manual Workflow Run

- You can also trigger the workflow manually from the GitHub Actions UI using the "Run workflow" button.
- Note: The release stage will only run if the workflow is triggered by a tag starting with `v`.

---

## Requirements

- **Secrets:**  
  - `GHCR_PAT`: Personal Access Token for pushing Docker images to GHCR (with `write:packages` scope).
  - (Optional) `GH_PAT`: Personal Access Token with `repo` scope if you want to use a PAT for GitHub Releases.

- **Permissions:**  
  The workflow sets `permissions: contents: write` to allow creating releases.

---

## Notes

- The release stage will be **skipped** unless all wheel builds succeed and the workflow is triggered by a tag starting with `v`.
- The demo deployment will only run after a successful release.

---

## Troubleshooting

- **Release job skipped:**  
  Make sure you pushed a tag starting with `v` and all previous jobs succeeded.
- **403 error on release:**  
  Ensure your workflow has `permissions: contents: write` and is running in the main repository, not a fork.

---

## Example Workflow Trigger

```sh
# Tag a new release
git tag v1.3.0
git push origin v1.3.0
```

This will run the full pipeline and publish a new release if all steps succeed.