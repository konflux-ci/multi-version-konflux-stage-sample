Using this project to perform a Konflux STAGE test
==================================================

We can use this repo to perform a test for the [project-controller][pc] in the
Konflux STAGE environment.

[pc]: http://github.com/konflux-ci/project-controller

Overview
--------

The process for using this repo to run STAGE test for project-controller is as
follows:

1. Ensure we have no left-overs from previous tests.
2. Onboard this repo's `test-main` branch to the Konflux STAGE cluster
3. Wait for the Konflux on-boarding PR to get created, for the build pipeline
   to pass successfully and then merge the PR.
4. Create a `v1.0.0` branch from `test-main`.
5. Apply project-controller configuration to setup Konflux for the new `v1.0.0`
   branch, and ensure the project development stream template is successfully applied.
6. Create a PR for the v1.0.0 branch to update the CEL expressions for the files
   in the branch.
7. Ensure that the Konflux pipelines are running for the new PR.
8. Create a test report with results and post it as a Gist.

Critical success criteria
--------------------------

**A clean initial state is mandatory.** The `test-main` branch at the commit
`stage-test-start` must *not* contain any pipeline configuration (e.g. no
`.tekton` directory or no Pipelines as Code files for this component). If
`test-main` already includes pipeline configuration when you start, the state
is dirty and the test is invalid—the Konflux build service will not create a new
on-boarding PR, and you will not be testing the full flow.

**Steps 3 and 7 are the essence of the test and must not be skipped or failed:**

- **Step 3:** The Konflux build service must *create* the on-boarding PR
  (title beginning with "Konflux Staging update"), the build and
  enterprise-contract checks must *run and pass*, and you must *merge* that PR.
  Skipping this step (e.g. because pipeline config already exists) or merging
  without successful checks is a **complete test failure**.

- **Step 7:** After opening the CEL-update PR (Step 6), Konflux pipeline
  checks must *run and pass* on that PR. If checks do not appear or do not
  succeed, the test has **failed**.

Warning - before you begin
--------------------------

This file contains instructions that include forceful modifications to the very
repo this file resides in. to avoid losing this file and the instructions within
it, make sure to avoid modifying any branches that are not explicitly mentioned
in the following instructions.

When changes need to be made to files in this repo, it's recommended to make another
clone in a temporary directory in order to avoid losing access to this file.

**Instructions for the agent (AI) performing this test**

Before running any part of this test—especially git operations such as creating,
resetting, or checking out branches—you **must** check whether you are operating
in **worktree mode** (a separate Cursor worktree so the user's main branch and
working tree are not modified).

- **If you are in worktree mode:** You may proceed with the test, including git
  operations, in this environment.
- **If you are not in worktree mode, or you cannot confirm it:** Do **not** perform
  git branch operations (e.g. `git checkout`, `git reset`, `git push`, creating
  branches) in the user's workspace. Instead, **stop and instruct the user**:

  > To avoid changing your main branch and workflow, please enable **worktree mode**
  > in Cursor's UI so I run this test in a separate worktree. After you enable it
  > and open or switch to that worktree, ask me again to perform the STAGE test.

  Only continue with the test once the user has enabled worktree mode and you are
  operating in that separate environment.

Test process in detail
----------------------

### Prerequisites

1. The OpenShift CLI (`oc`)
2. The GitHub CLI (`gh`)
3. CLI access to the Konflux STAGE (`stone-stg-rh01`) cluster. May be obtained with:

   ```bash
   oc login --web --server=https://api.stone-stg-rh01.l2vh.p1.openshiftapps.com:6443
   ```

The software dependencies may be obtained using [Mise][mise] and configuration
in this repo. To set up the dependencies, run:

```bash
mise install
```

[mise]: https://mise.jdx.dev/

### Setup Test Environment

1. **Create a temporary directory for test files:**

   ```bash
   mkdir -p test-temp
   ```

This setup ensures that temporary files and test reports are organized in a
dedicated directory.

### Ensuring we have no left-overs from previous tests

1. In the STAGE cluster, ensure the following resources do not exist (delete any
   that do). In the `konflux-samples-tenant` namespace:
    1. Any `Application.appstudio.redhat.com` whose name starts with `prjctl-tst`
    2. Any `Component.appstudio.redhat.com` whose name starts with `prjctl-tst`
    3. Any `ImageRepository.appstudio.redhat.com` whose name starts with
       `imagerepository-for-prjctl-tst`
    4. Any `IntegrationTestScenario.appstudio.redhat.com` whose name starts with
       `prjctl-tst`
    5. Any `Project.projctl.konflux.dev` named `project-controller-test` or
       `prjctl-tst`
    6. Any `ProjectDevelopmentStreamTemplate.projctl.konflux.dev` named
       `prjctl-tst-template`
    7. Any `ProjectDevelopmentStream.projctl.konflux.dev` whose name starts with
       `prjctl-tst-`

2. There should be no open PRs targeting the `test-main` branch of this repo in
   GitHub. Close or merge them before proceeding.

3. There should be no branches with names like `v1.0.0` (`v` followed by a
   version number) for this repo locally or on the remote. Delete them (e.g.
   `git push origin --delete v1.0.0`) so that `v1.0.0` is created only in Step 4
   from the merged on-boarding state.

4. The `test-main` branch must be reset to the commit tagged as `stage-test-start`:

   ```bash
   git checkout test-main
   git reset --hard stage-test-start
   git push --force-with-lease origin test-main
   ```

5. **Verify clean initial state:** The commit at `stage-test-start` must *not*
   contain pipeline configuration for this component (e.g. no `.tekton`
   directory, or no files like `prjctl-tst-cmp1-main-*.yaml` there). If it does,
   the initial state is dirty and the test will be invalid—the build service will
   not create a new on-boarding PR. You can verify with:

   ```bash
   git ls-tree --name-only stage-test-start
   ```
   There should be no `.tekton` directory in the output.

### Onboard this repo's `test-main` branch to the Konflux STAGE cluster

This could be done by applying the following resources to the cluster.
Create these files in the `test-temp` directory:

The application resource (`test-temp/application.yaml`):

```yaml
kind: Application
apiVersion: appstudio.redhat.com/v1alpha1
metadata:
  name: prjctl-tst-main
spec:
  displayName: prjctl-tst-main
```

The component resource (`test-temp/component.yaml`):

```yaml
kind: Component
apiVersion: appstudio.redhat.com/v1alpha1
metadata:
  annotations:
    build.appstudio.openshift.io/pipeline: '{"name":"docker-build-oci-ta","bundle":"latest"}'
    build.appstudio.openshift.io/request: "configure-pac"
  name: prjctl-tst-cmp1-main
spec:
  application: prjctl-tst-main
  componentName: prjctl-tst-cmp1-main
  resources: {}
  source:
    git:
      url: 'https://github.com/konflux-ci/multi-version-konflux-stage-sample.git'
      revision: "test-main"
```

The image repository resource (`test-temp/imagerepository.yaml`):

```yaml
kind: ImageRepository
apiVersion: appstudio.redhat.com/v1alpha1
metadata:
  annotations:
    image-controller.appstudio.redhat.com/update-component-image: "true"
  name: imagerepository-for-prjctl-tst-cmp1-main
  labels:
    appstudio.redhat.com/application: prjctl-tst-main
    appstudio.redhat.com/component: prjctl-tst-cmp1-main
spec:
  image:
    name: konflux-samples-tenant/prjctl-tst/prjctl-tst-cmp1-main
    visibility: public
  notifications:
    - config:
        url: 'https://bombino.preprod.api.redhat.com/v1/sbom/quay/push'
      event: repo_push
      method: webhook
      title: SBOM-event-to-Bombino
```

The integration test scenario resource (`test-temp/integrationtestscenario.yaml`):

```yaml
kind: IntegrationTestScenario
apiVersion: appstudio.redhat.com/v1beta2
metadata:
  annotations:
    test.appstudio.openshift.io/kind: enterprise-contract
  name: prjctl-tst-main-enterprise-contract
spec:
  application: prjctl-tst-main
  contexts:
    - description: Application testing
      name: application
  resolverRef:
    params:
      - name: url
        value: 'https://github.com/konflux-ci/build-definitions'
      - name: revision
        value: main
      - name: pathInRepo
        value: pipelines/enterprise-contract.yaml
    resolver: git
```

### Monitoring the Konflux on-boarding PR (Step 3 — mandatory)

After creating the resources specified above, the Konflux build service should
automatically create a PR in this repo to configure a build pipeline for it.
**This step is mandatory.** Do not skip it. If no new on-boarding PR is
created (e.g. because pipeline config already exists on `test-main`), the
initial state was dirty and the test has already failed. You must wait for the
new PR, ensure its checks pass, and merge it before proceeding to Step 4.

The PR would be targeting the branch we have onboarded (`test-main`), it would be
sent by the `konflux-staging` bot account, its title would begin with "Konflux
Staging update" and its description will include the text "Pipelines as Code
configuration proposal".

It might take the build service 2-5 minutes to create the PR. If no PR appears
after 10 minutes, check the component status:

```bash
oc get component prjctl-tst-cmp1-main -n konflux-samples-tenant -o yaml
```

If the component status says it is "waiting for spec.containerImage to be set by
ImageRepository", the build service may not create the on-boarding PR until the
image controller has set `spec.containerImage` on the component. Check that the
ImageRepository has `status.state: ready` and `status.image.url` set, and check
image controller logs if the component never receives `spec.containerImage`.

Soon after the PR is created we should be able to see Konflux CI checks running
for it in GitHub (Konflux is using the GitHub checks API to post status). We
should observe the following checks running and being completed successfully:

1. Konflux Staging / prjctl-tst-cmp1-main-on-pull-request
2. Konflux Staging / prjctl-tst-cmp1-main-enterprise-contract / prjctl-tst-cmp1-main

Note the match between the check names and the component and integration test
scenario names.

**If checks fail or don't appear:**

- Wait up to 5 minutes for checks to appear
- Check the PR description for any error messages
- Verify the component configuration in the cluster
- Check build pipeline logs for errors

Once the checks complete successfully we can instruct GitHub to merge the PR.
**The test fails if you merge without successful checks or if you skip merging.**

```bash
gh pr merge [PR-NUMBER] --merge --delete-branch
```

Record the merged PR URL and merge timestamp (RFC 5322 format); you will need
them for the project-controller template in Step 5.

### Creating a `v1.0.0` branch

Once the Konflux on-boarding PR is merged, a branch called `v1.0.0` needs to be created
out of an updated version of the `test-main` branch. Care must be taken to ensure
we use an up-to-date version of that branch that includes the pipeline files introduced
by the on-boarding PR. The new branch should be pushed to GitHub:

```bash
# First, ensure we have the latest changes
git checkout test-main
git pull origin test-main

# Create and push the new branch
git checkout -b v1.0.0
git push origin v1.0.0
```

### Applying project-controller configuration

We will use project-controller to setup Konflux for the new `v1.0.0` branch. To do
so we need to apply the following resources to the cluster. Create these files
in the `test-temp` directory:

A project resource (`test-temp/project.yaml`):

```yaml
apiVersion: projctl.konflux.dev/v1beta1
kind: Project
metadata:
  name: prjctl-tst
spec:
  displayName: "Multi-version demonstration sample project [STAGE version]"
  description: |
    A sample showing the use of the project-controller to manage multiple 
    project versions [STAGE version]
```

A project development stream template resource (`test-temp/project-development-stream-template.yaml`):

Note the places in the YAML below where it says `PR-URL-HERE` and `PR-TIME-HERE`.
Those strings should be replaced with:

- `PR-URL-HERE`: The URL of the build pipeline configuration PR we dealt with earlier
- `PR-TIME-HERE`: The time the PR was merged in RFC 5322 format (`+%a, %d %b %Y %H:%M:%S %Z`)

**Example replacements:**

- PR-URL-HERE → `https://github.com/konflux-ci/multi-version-konflux-stage-sample/pull/123`
- PR-TIME-HERE → `Mon, 15 Jan 2024 14:30:00 UTC`

**To find the PR URL:** Look in the GitHub repository for the merged PR with
title starting with "Konflux Staging update".

**To get the merge time:** Click on the PR and look at the "merged" timestamp,
then convert to RFC 5322 format.

```yaml
apiVersion: projctl.konflux.dev/v1beta1
kind: ProjectDevelopmentStreamTemplate
metadata:
  name: prjctl-tst-template
spec:
  project: prjctl-tst
  variables:
  - name: version
    description: A version number for a new development stream
  - name: versionName
    description: A K8s-compliant name for the version
    defaultValue: "{{hyphenize .version}}"

  resources:
  - kind: Application
    apiVersion: appstudio.redhat.com/v1alpha1
    metadata:
      annotations:
        application.thumbnail: '9'
      name: prjctl-tst-{{.versionName}}
    spec:
      appModelRepository:
        url: ''
      displayName: prjctl-tst-{{.versionName}}
      gitOpsRepository:
        url: ''

  - kind: Component
    apiVersion: appstudio.redhat.com/v1alpha1
    metadata:
      annotations:
        build.appstudio.openshift.io/pipeline: '{"name":"docker-build-oci-ta","bundle":"latest"}'
        build.appstudio.openshift.io/status: '{"pac":{"state":"enabled","merge-url":"PR-URL-HERE","configuration-time":"PR-TIME-HERE"},"message":"done"}'
      name: prjctl-tst-cmp1-{{.versionName}}
    spec:
      application: prjctl-tst-{{.versionName}}
      componentName: prjctl-tst-cmp1-{{.versionName}}
      resources: {}
      source:
        git:
          url: 'https://github.com/konflux-ci/multi-version-konflux-stage-sample.git'
          revision: "{{.version}}"

  - kind: ImageRepository
    apiVersion: appstudio.redhat.com/v1alpha1
    metadata:
      annotations:
        image-controller.appstudio.redhat.com/update-component-image: "true"
      name: imagerepository-for-prjctl-tst-cmp1-{{.versionName}}
      labels:
        appstudio.redhat.com/application: prjctl-tst-{{.versionName}}
        appstudio.redhat.com/component: prjctl-tst-cmp1-{{.versionName}}
    spec:
      image:
        name: konflux-samples-tenant/prjctl-tst/prjctl-tst-cmp1-{{.versionName}}
        visibility: public
      notifications:
        - config:
            url: 'https://bombino.preprod.api.redhat.com/v1/sbom/quay/push'
          event: repo_push
          method: webhook
          title: SBOM-event-to-Bombino

  - kind: IntegrationTestScenario
    apiVersion: appstudio.redhat.com/v1beta2
    metadata:
      annotations:
        test.appstudio.openshift.io/kind: enterprise-contract
      name: prjctl-tst-{{.versionName}}-enterprise-contract
    spec:
      application: prjctl-tst-{{.versionName}}
      contexts:
        - description: Application testing
          name: application
      resolverRef:
        params:
          - name: url
            value: 'https://github.com/konflux-ci/build-definitions'
          - name: revision
            value: main
          - name: pathInRepo
            value: pipelines/enterprise-contract.yaml
        resolver: git
```

A project development stream resource (`test-temp/project-development-stream.yaml`):

```yaml
apiVersion: projctl.konflux.dev/v1beta1
kind: ProjectDevelopmentStream
metadata:
  name: prjctl-tst-v1-0-0
spec:
  project: prjctl-tst
  template:
    name: prjctl-tst-template
    values:
    - name: version
      value: "v1.0.0"
```

Once we apply these resources, we should be able to observe the following
resources being created by the project-controller. This typically takes 2-5 minutes.

**To monitor the creation process:**

```bash
# Watch for the resources being created
oc get applications,components,imagerepositories,integrationtestscenarios -n konflux-samples-tenant -w
```

Resource name                             | Kind                    | API version
------------------------------------------|-------------------------|------------------------------
prjctl-tst-v1-0-0                          | Application             | appstudio.redhat.com/v1alpha1
prjctl-tst-cmp1-v1-0-0                     | Component               | appstudio.redhat.com/v1alpha1
imagerepository-for-prjctl-tst-cmp1-v1-0-0 | ImageRepository         | appstudio.redhat.com/v1alpha1
prjctl-tst-v1-0-0-enterprise-contract      | IntegrationTestScenario | appstudio.redhat.com/v1beta2

If the resources do not get created within 10 minutes, we can declare that our
integration test has failed.

**To debug the issue, check the following:**

1. **Check ProjectDevelopmentStream events:**

   ```bash
   oc describe projectdevelopmentstream prjctl-tst-v1-0-0 -n konflux-samples-tenant
   ```

2. **Check project-controller logs:**

   ```bash
   oc logs -n konflux-project-controller-system \
     deployment/konflux-project-controller-manager --tail=100
   ```

3. **Verify the template exists:**

   ```bash
   oc get projectdevelopmentstreamtemplate prjctl-tst-template -n konflux-samples-tenant
   ```

The project-controller should report any issues in the events and logs.

### Updating pipeline CEL expressions in the v1.0.0 branch

Within the `v1.0.0` branch we have created we should have files in the `.tekton`
directory:

- `prjctl-tst-cmp1-main-pull-request.yaml`
- `prjctl-tst-cmp1-main-push.yaml`

These files should contain annotations called `pipelinesascode.tekton.dev/on-cel-expression`.
The values should resemble the following:

```cel-expression
event == "pull_request" && target_branch == "main"
```

Note: The actual values in the files might contain newlines.

**We need to change the target branch in both expressions to match our `v1.0.0` branch:**

```cel-expression
event == "pull_request" && target_branch == "v1.0.0"
```

**Steps to make the changes:**

1. **Create a new branch for the changes:**

    ```bash
    git checkout v1.0.0
    git checkout -b update-cel-expressions
    ```

2. **Edit both files to change `target_branch == "main"` to `target_branch == "v1.0.0"`**

3. **Commit and push the changes:**

    ```bash
    git add .tekton/
    git commit -m "Update CEL expressions to target v1.0.0 branch"
    git push origin update-cel-expressions
    ```

4. **Create a PR targeting the v1.0.0 branch:**

    ```bash
    gh pr create --base v1.0.0 --head update-cel-expressions \
      --title "Update CEL expressions for v1.0.0 branch" \
      --body "Updates CEL expressions in pipeline files to target v1.0.0 branch instead of test-main" \
      --fill
    ```

### Ensuring that the Konflux pipelines are running for the new PR (Step 7 — mandatory)

**This step is mandatory.** The test fails if Konflux checks do not run on the
CEL-update PR or if they do not complete successfully. Do not consider the
test passed until these checks are green.

If all goes well we should see Konflux PR checks starting to run and completing
successfully within 3-5 minutes. Here are the names of checks we should see:

1. Konflux Staging / prjctl-tst-cmp1-main-on-pull-request
2. Konflux Staging / prjctl-tst-cmp1-v1-0-0-enterprise-contract / prjctl-tst-cmp1-main

**If checks don't appear or fail:**

1. **Wait up to 10 minutes** - sometimes there are delays in the system
2. **Check the PR in GitHub** - look for any error messages or failed checks
3. **Verify the CEL expressions** - ensure they exactly match the expected format
4. **Check component status in the cluster:**

   ```bash
   oc get component prjctl-tst-cmp1-v1-0-0 -n konflux-samples-tenant -o yaml
   ```

5. **Check build pipeline logs:**

   ```bash
   oc get pipelineruns -n konflux-samples-tenant --sort-by=.metadata.creationTimestamp
   ```

Reporting
---------

After performing the test, create a comprehensive report:

1. **Create a test report file:**

   ```bash
   cat > test-temp/TEST-REPORT.md << 'EOF'
   # Konflux STAGE Test Report
   
   **Date**: $(date '+%B %d, %Y')
   **Test Duration**: [Record total time]
   **Status**: ✅ **SUCCESSFUL** / ❌ **FAILED**
   **Test Procedure**: [STAGE-TEST.md](https://github.com/konflux-ci/multi-version-konflux-stage-sample/blob/stage-test-instructions/STAGE-TEST.md)
   
   ## Test Overview
   
   [Brief description of the test performed]
   
   ## Test Stages Completed
   
   ### 1. Prerequisites Setup ✅/❌
   - **Duration**: [Time taken]
   - **Status**: [Success/Failure]
   - **Notes**: [Any observations]
   
   [Continue for each stage...]
   
   ## Issues Identified
   
   [List any issues found during testing]
   
   ## Recommendations
   
   [Suggestions for improvement]
   
   ## Conclusion
   
   [Overall assessment of the test]
   EOF
   ```

2. **Post the report as a Gist:**

   ```bash
   gh gist create test-temp/TEST-REPORT.md --public \
     --desc "Konflux STAGE Test Report - Project Controller Test Results $(date -u)"
   ```

The test report should include:

1. Whether the test was successful
2. The stages carried out
3. The time it took for each stage of the work
4. Any observations made
5. Any issues encountered and how they were dealt with
6. A link to the test procedure

