# DevBoard Ansible

Ansible configuration for preparing and verifying the DevBoard Ubuntu workstation.

The goal of this project is to automate the machine setup while keeping the Ansible code simple enough to understand and learn from.

---

## 1. What This Ansible Project Does

The Ansible project prepares the DevBoard machine with the tools and configuration needed for AWS, Terraform, and Kubernetes work.

It currently covers:

- AWS CLI v2
- Terraform
- kubectl
- Helm
- GitHub CLI (`gh`)
- jq
- dig / DNS utilities
- Git
- AWS authentication verification
- Terraform version verification
- Shell configuration
- AWS region configuration
- `kubectl` Bash completion
- `k` shortcut for `kubectl`

---

## 2. Basic Ansible Flow

The main playbook starts the process:

```text
site.yml
   |
   v
roles
   |
   v
tasks/main.yml
   |
   v
Ansible modules
   |
   v
Ubuntu machine
```

A role normally contains its tasks in:

```text
roles/<role-name>/tasks/main.yml
```

For example:

```text
roles/
└── tools/
    └── tasks/
        └── main.yml
```

---

## 3. Project Structure

The important files are:

```text
ansible/
├── ansible.cfg
├── inventory.ini
├── site.yml
├── group_vars/
│   └── devboard.yml
├── roles/
│   ├── tools/
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── tasks/
│   │       └── main.yml
│   │
│   └── verify/
│       └── tasks/
│           └── main.yml
│
└── README.md
```

The structure can grow as we add more roles.

---

## 4. Ansible Configuration

### ansible.cfg

`ansible.cfg` contains project-level Ansible settings.

One important setting is the inventory file.

Because the inventory is configured here, we don't need to type:

```bash
-i inventory.ini
```

every time.

Instead of:

```bash
ansible-playbook -i inventory.ini site.yml
```

we can run:

```bash
ansible-playbook site.yml
```

---

## 5. Inventory

The inventory tells Ansible:

> Which machines should I manage?

For a local DevBoard machine, we can have:

```ini
[devboard]
localhost ansible_connection=local
```

The group name is:

```text
devboard
```

A playbook can then target:

```yaml
hosts: devboard
```

---

## 6. Variables

Variables allow us to avoid hard-coding values inside tasks.

Example:

```yaml
aws_region: us-west-2
```

A task can use:

```yaml
{{ aws_region }}
```

Think of it like:

```text
aws_region
    |
    v
us-west-2
    |
    v
{{ aws_region }}
    |
    v
us-west-2
```

### What does `{{ }}` mean?

In Ansible/Jinja:

```yaml
{{ variable }}
```

means:

> Evaluate this expression and insert its value here.

Example:

```yaml
msg: "AWS region is {{ aws_region }}"
```

If:

```yaml
aws_region: us-west-2
```

the result is:

```text
AWS region is us-west-2
```

---

## 7. Ansible Modules

Ansible modules perform the actual work.

Examples used in this project:

```text
ansible.builtin.command
    |
    +-- run a command

ansible.builtin.apt
    |
    +-- install Ubuntu packages

ansible.builtin.get_url
    |
    +-- download a file

ansible.builtin.unarchive
    |
    +-- extract an archive

ansible.builtin.copy
    |
    +-- create/copy files

ansible.builtin.debug
    |
    +-- display information

ansible.builtin.assert
    |
    +-- verify a condition

ansible.builtin.fail
    |
    +-- intentionally stop with a clear message
```

---

## 8. register

`register` saves the result of a task into a variable.

Example:

```yaml
- name: Check Terraform version
  ansible.builtin.command:
    cmd: terraform version -json
  register: terraform_version
```

After the task runs, Ansible creates a result object:

```text
terraform_version
├── stdout
├── stderr
├── rc
├── changed
├── failed
└── ...
```

The important fields are:

```text
terraform_version.stdout
    |
    +-- command output

terraform_version.stderr
    |
    +-- standard error output

terraform_version.rc
    |
    +-- command return code
```

---

## 9. register + loop

This is one of the most important concepts in this project.

Example:

```yaml
- name: Check required command-line tools
  ansible.builtin.command:
    cmd: "{{ item }}"
  loop:
    - aws --version
    - terraform version
    - kubectl version --client
  register: tool_check
```

There are multiple commands, so Ansible creates multiple result objects.

Because the task uses:

```yaml
register: tool_check
```

together with:

```yaml
loop:
```

Ansible stores the individual results under:

```text
tool_check.results
```

Conceptually:

```text
tool_check
└── results
    ├── AWS result
    ├── Terraform result
    └── kubectl result
```

Each result is a complete result object.

For example:

```text
{
    "item": "aws --version",
    "rc": 0,
    "stdout": "aws-cli/2.36.21 ..."
}
```

Another result may be:

```text
{
    "item": "terraform version",
    "rc": 0,
    "stdout": "Terraform v1.15.8..."
}
```

---

## 10. Understanding `tool_check.results`

`tool_check.results` is a list of result objects.

It is not one result.

Think:

```text
tool_check.results
        |
        +---- AWS result
        |
        +---- Terraform result
        |
        +---- kubectl result
        |
        +---- Helm result
        |
        +---- jq result
        |
        +---- dig result
        |
        +---- Git result
        |
        +---- GitHub CLI result
```

Each result object contains many fields:

```text
result
├── ansible_loop_var
├── item
├── cmd
├── stdout
├── stderr
├── rc
├── changed
├── failed
├── invocation
└── ...
```

`invocation` is also part of the same result object.

It contains information about how Ansible called the module.

For example:

```text
result
└── invocation
    └── module_args
        └── cmd
```

This is different from:

```text
result.stdout
```

because `invocation` tells us about how the task was executed, while `stdout` contains the command's output.

---

## 11. loop_var

By default, Ansible uses:

```text
item
```

as the loop variable.

We can give the current loop value a clearer name.

Example:

```yaml
loop: "{{ tool_check.results }}"

loop_control:
  loop_var: tool_result
```

This means:

> Take one result from `tool_check.results` and temporarily call the whole result `tool_result`.

Think:

```text
tool_check.results
        |
        v
   one result
        |
        v
   tool_result
```

The important point:

**`tool_result` represents the entire current result object.**

It is not only `stdout`.

For example:

```text
tool_result
├── item
├── stdout
├── stderr
├── rc
├── cmd
├── invocation
└── ...
```

Therefore:

```yaml
tool_result.item
```

means:

> Get the `item` field from the current result.

And:

```yaml
tool_result.stdout
```

means:

> Get the `stdout` field from the current result.

---

## 12. Example: `tool_result`

Suppose the current result is:

```yaml
tool_result:
  item: "terraform version"
  stdout: "Terraform v1.15.8"
  stderr: ""
  rc: 0
```

Then:

```yaml
tool_result.item
```

returns:

```text
terraform version
```

And:

```yaml
tool_result.stdout
```

returns:

```text
Terraform v1.15.8
```

And:

```yaml
tool_result.rc
```

returns:

```text
0
```

So:

```text
tool_result
    |
    +-- item   → command that was run
    |
    +-- stdout → command output
    |
    +-- stderr → error output
    |
    +-- rc     → return code
```

---

## 13. Why `tool_result.item` Exists

The first loop uses Ansible's default loop variable:

```yaml
loop:
  - aws --version
  - terraform version
  - kubectl version --client
```

During that first loop:

```text
item
```

represents the current command.

When the task is registered, Ansible stores that value inside each result:

```text
tool_check.results
        |
        v
result
├── item: "aws --version"
├── stdout: "aws-cli/..."
└── rc: 0
```

Later, the second loop does:

```yaml
loop: "{{ tool_check.results }}"

loop_control:
  loop_var: tool_result
```

Now:

```text
tool_result
    |
    +-- item   → "aws --version"
    +-- stdout → "aws-cli/..."
    +-- rc     → 0
```

Therefore:

```yaml
tool_result.item
```

is the original command.

---

## 14. `stdout`

`stdout` comes from the command execution result.

It is not something we manually create.

For example:

```bash
aws --version
```

produces:

```text
aws-cli/2.36.21 ...
```

Ansible captures that output:

```text
stdout
    |
    v
aws-cli/2.36.21 ...
```

So:

```yaml
tool_result.stdout
```

gives us the output of the current command.

---

## 15. `stderr`

Commands can also write output to standard error.

That output is stored in:

```yaml
tool_result.stderr
```

Some commands, such as:

```bash
dig -v
```

may write their version information to stderr.

That's why we can use:

```yaml
tool_result.stdout or tool_result.stderr
```

This means:

> Use stdout if it contains something; otherwise use stderr.

---

## 16. `rc`

`rc` means the command's return code.

Usually:

```text
rc = 0
    |
    +-- command succeeded
```

And:

```text
rc != 0
    |
    +-- command failed
```

Example:

```yaml
when: aws_identity.rc == 0
```

means:

> Continue only when the AWS command succeeded.

---

## 17. `changed_when`

Verification commands do not change the machine.

Example:

```yaml
changed_when: false
```

Memory hook:

```text
changed_when: false
        |
        v
"This is only a check.
Don't report it as a change."
```

For example:

```yaml
- name: Check Terraform version
  ansible.builtin.command:
    cmd: terraform version
  register: terraform_version
  changed_when: false
```

The command runs, but Ansible reports:

```text
changed: false
```

---

## 18. `failed_when`

`failed_when` controls when Ansible considers a task failed.

For AWS authentication we use:

```yaml
failed_when: false
```

Memory hook:

```text
failed_when: false
        |
        v
"Don't stop here.
Save the result so I can inspect it myself."
```

Example:

```yaml
- name: Check AWS authentication
  ansible.builtin.command:
    cmd: aws sts get-caller-identity --output json
  register: aws_identity
  failed_when: false
```

Even if the command fails, Ansible saves:

```text
aws_identity
```

including:

```text
aws_identity.rc
aws_identity.stdout
aws_identity.stderr
```

Then we make the decision ourselves.

For example:

```yaml
when: aws_identity.rc == 0
```

means success.

And:

```yaml
when: aws_identity.rc != 0
```

means failure.

---

## 19. `assert`

`assert` means:

> This condition must be true.

Example:

```yaml
- name: Validate Terraform version
  ansible.builtin.assert:
    that:
      - terraform_version >= 1.11.0
```

Think:

```text
Is Terraform >= 1.11.0?

       |
   +---+---+
   |       |
  YES      NO
   |       |
   v       v
continue  FAIL
```

We can provide:

```yaml
fail_msg:
```

to explain why the requirement failed.

And:

```yaml
success_msg:
```

to confirm that the requirement passed.

---

## 20. Terraform Version and `from_json`

Terraform can return its version as JSON:

```bash
terraform version -json
```

Example:

```json
{
  "terraform_version": "1.15.8",
  "platform": "linux_amd64"
}
```

Ansible captures the command output in:

```yaml
terraform_version.stdout
```

But `stdout` is text containing JSON.

So:

```yaml
terraform_version.stdout | from_json
```

converts the JSON text into a structured object.

Then:

```yaml
(terraform_version.stdout | from_json).terraform_version
```

gets:

```text
1.15.8
```

---

## 21. `from_json`

`from_json` is an Ansible/Jinja filter.

It is not provided by AWS.

It is not provided by Terraform.

It is used by Ansible to convert JSON text into a structured object.

Example AWS command:

```bash
aws sts get-caller-identity --output json
```

AWS returns:

```json
{
  "UserId": "...",
  "Account": "031679887831",
  "Arn": "arn:aws:sts::031679887831:assumed-role/mega-project-role/..."
}
```

Ansible stores that JSON text in:

```yaml
aws_identity.stdout
```

So:

```yaml
aws_identity.stdout | from_json
```

converts the text into an object.

Conceptually:

```text
aws_identity.stdout
        |
        v
JSON text
        |
        v
from_json
        |
        v
structured object
        |
        +---- UserId
        +---- Account
        +---- Arn
```

Then:

```yaml
(aws_identity.stdout | from_json).Account
```

returns:

```text
031679887831
```

And:

```yaml
(aws_identity.stdout | from_json).Arn
```

returns the AWS ARN.

---

## 22. Why `{{ }}` Is Used

Ansible/Jinja uses:

```yaml
{{ }}
```

when we want Ansible to evaluate an expression and insert the result.

Example:

```yaml
msg: "AWS Account: {{ account }}"
```

If:

```yaml
account: "031679887831"
```

the output becomes:

```text
AWS Account: 031679887831
```

Therefore:

```yaml
Account: {{ (aws_identity.stdout | from_json).Account }}
```

means:

```text
Evaluate:
(aws_identity.stdout | from_json).Account

Then insert the result here.
```

---

## 23. AWS Authentication

The DevBoard machine uses its EC2 IAM role.

We do not store AWS access keys on the machine.

The verification command is:

```bash
aws sts get-caller-identity --output json
```

The flow is:

```text
EC2 IAM Role
      |
      v
AWS CLI
      |
      v
sts get-caller-identity
      |
      v
AWS JSON
      |
      v
aws_identity.stdout
      |
      v
from_json
      |
      v
Account / Arn
```

Example result:

```text
Account: 031679887831
Identity: arn:aws:sts::031679887831:assumed-role/mega-project-role/...
```

---

## 24. AWS `register` Result

When we write:

```yaml
register: aws_identity
```

Ansible creates a result object similar to:

```text
aws_identity
├── changed
├── cmd
├── rc
├── stdout
├── stderr
├── failed
└── ...
```

The AWS JSON itself is inside:

```yaml
aws_identity.stdout
```

So:

```text
aws_identity
     |
     +-- rc
     |
     +-- stdout
            |
            +-- AWS JSON
```

---

## 25. Shell Configuration

The project creates:

```text
/etc/profile.d/devboard.sh
```

This file contains settings such as:

```bash
export AWS_REGION=us-west-2
export AWS_DEFAULT_REGION=us-west-2

source <(kubectl completion bash)

alias k=kubectl
```

### Why `/etc/profile.d/`?

Linux login shells load shell configuration files from:

```text
/etc/profile.d/
```

So the DevBoard settings can be loaded automatically.

The file is called:

```text
devboard.sh
```

to make its purpose clear.

---

## 26. Kubernetes Bash Completion

This command:

```bash
source <(kubectl completion bash)
```

generates kubectl Bash completion configuration and loads it into the current shell.

This enables tab completion such as:

```bash
kubectl get po<TAB>
```

We also create:

```bash
alias k=kubectl
```

which means:

```bash
k get pods
```

is equivalent to:

```bash
kubectl get pods
```

---

## 27. Why We Use Roles

Roles allow us to separate responsibilities.

For example:

```text
roles/
├── tools/
│   |
│   +-- Install required tools
│
├── configure_aws/
│   |
│   +-- Configure AWS-related settings
│
└── verify/
    |
    +-- Check that everything works
```

This is easier to maintain than putting every task into one huge file.

---

## 28. Tools Role

The tools role installs the required command-line tools.

Current tools include:

```text
AWS CLI
Terraform
kubectl
Helm
GitHub CLI
jq
dig
Git
```

The role uses variables such as:

```yaml
binary_arch
```

to select the correct architecture for downloaded binaries.

For example:

```text
x86_64
   |
   v
amd64
```

and:

```text
aarch64
   |
   v
arm64
```

---

## 29. Verification Role

The verification role answers:

> "Is the DevBoard machine ready?"

It checks:

```text
Required tools
      |
      v
Terraform version
      |
      v
AWS authentication
      |
      v
Ready / Fail
```

The verification tasks should not modify the machine.

That's why the command checks use:

```yaml
changed_when: false
```

---

## 30. Dry Run

Before applying changes, we can use:

```bash
ansible-playbook site.yml --check
```

This is Ansible's check mode.

Think:

```text
--check
   |
   v
"What would Ansible change?"
```

Important:

Not every Ansible module can perfectly simulate its real behavior in check mode.

Tasks involving:

- downloads
- commands
- external APIs
- generated files

may behave differently in check mode.

Therefore, a successful dry run does not always guarantee that the real run will succeed.

---

## 31. Syntax Check

Before running the playbook:

```bash
ansible-playbook site.yml --syntax-check
```

This checks whether the playbook/YAML structure can be parsed.

Successful output:

```text
playbook: site.yml
```

Memory hook:

```text
syntax-check
     |
     v
"Can Ansible understand my YAML?"
```

It does not actually perform the tasks.

---

## 32. Idempotency

An important Ansible concept is **idempotency**.

It means:

> Running the same playbook multiple times should not keep making unnecessary changes.

For example, if a package is already installed:

```yaml
ansible.builtin.apt:
  name: jq
  state: present
```

Ansible should report:

```text
ok
```

instead of installing it again.

The desired state is:

```text
Package required
      |
      v
Is it already installed?
      |
   +--+--+
   |     |
  YES    NO
   |     |
   v     v
 no     install
change
```

This is one of the main reasons we use Ansible instead of a collection of shell scripts.

---

## 33. Check Mode vs Real Run

There are three useful stages:

### 1. Syntax

```bash
ansible-playbook site.yml --syntax-check
```

Question:

> Can Ansible parse the YAML?

### 2. Check mode

```bash
ansible-playbook site.yml --check
```

Question:

> What does Ansible think it would change?

### 3. Real execution

```bash
ansible-playbook site.yml
```

Question:

> Perform the actual configuration.

Think:

```text
syntax-check
     |
     v
YAML valid?
     |
     v
--check
     |
     v
What would change?
     |
     v
real run
     |
     v
Make the changes
```

---

## 34. Useful Commands

Go to the Ansible directory:

```bash
cd ~/devboard/ansible
```

Syntax check:

```bash
ansible-playbook site.yml --syntax-check
```

Dry run:

```bash
ansible-playbook site.yml --check
```

Apply:

```bash
ansible-playbook site.yml
```

Check inventory:

```bash
ansible-inventory --graph
```

Test connectivity:

```bash
ansible all -m ping
```

Check AWS:

```bash
aws sts get-caller-identity
```

Check region:

```bash
echo $AWS_REGION
echo $AWS_DEFAULT_REGION
```

Check kubectl:

```bash
k version --client
```

Check tools:

```bash
aws --version
terraform version
kubectl version --client
helm version --short
gh --version
jq --version
dig -v
git --version
```

---

## 35. Typical Development Workflow

When adding or changing Ansible code:

```text
1. Understand the task
       |
       v
2. Edit the task
       |
       v
3. Syntax check
       |
       v
4. Dry run
       |
       v
5. Run the playbook
       |
       v
6. Verify the result
```

Commands:

```bash
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --check
ansible-playbook site.yml
```

Then run the verification playbook when appropriate.

---

## 36. Debugging Registered Variables

During learning, it is useful to see the complete registered variable.

Example:

```yaml
- name: Show complete tool_check result
  ansible.builtin.debug:
    var: tool_check
```

This can show:

```text
tool_check
├── changed
├── msg
└── results
    ├── result 1
    ├── result 2
    ├── result 3
    └── ...
```

For AWS:

```yaml
- name: Show complete AWS identity result
  ansible.builtin.debug:
    var: aws_identity
```

This helps us understand where values such as:

```text
aws_identity.stdout
aws_identity.stderr
aws_identity.rc
```

come from.

Once the code is fully understood, verbose debug tasks can be reduced or removed from a production version.

---

## 37. Reading Ansible Expressions

When you see something like:

```yaml
msg: "{{ (aws_identity.stdout | from_json).Account }}"
```

read it from left to right:

```text
aws_identity
      |
      v
stdout
      |
      v
JSON text
      |
      v
from_json
      |
      v
structured object
      |
      v
.Account
      |
      v
Account value
```

When you see:

```yaml
msg: "{{ tool_result.stdout }}"
```

read it as:

```text
tool_result
      |
      v
current result object
      |
      v
stdout
      |
      v
command output
```

---

## 38. Important Mental Models

### Registered loop

```text
First task
    |
    | loop over commands
    v
register: tool_check
    |
    v
tool_check.results
    |
    | second loop
    v
tool_result
    |
    +-- item
    +-- stdout
    +-- stderr
    +-- rc
    +-- ...
```

### AWS JSON

```text
AWS command
    |
    v
AWS returns JSON
    |
    v
aws_identity.stdout
    |
    v
JSON text
    |
    v
from_json
    |
    v
structured object
    |
    +-- .Account
    +-- .Arn
    +-- .UserId
```

### assert

```text
Condition
    |
    +---- TRUE ----> Continue
    |
    +---- FALSE ---> Fail
```

### failed_when

```text
Command
    |
    v
Save result
    |
    v
Check rc ourselves
    |
    +---- rc = 0 ----> Success
    |
    +---- rc != 0 ---> Handle failure
```

### changed_when

```text
Task
    |
    v
Did this task change the machine?
    |
    +---- No ----> changed_when: false
```

---

## 39. Quick Reference

| Ansible concept | Meaning |
|---|---|
| `{{ variable }}` | Evaluate and insert a variable/expression |
| `register` | Save the result of a task |
| `results` | List of results when `register` is used with a loop |
| `loop_var` | Give the current loop value a custom name |
| `stdout` | Normal command output |
| `stderr` | Standard error output |
| `rc` | Command return code |
| `changed_when: false` | Do not report this check as changed |
| `failed_when: false` | Do not fail here; inspect the result yourself |
| `from_json` | Convert JSON text into a structured object |
| `assert` | Require a condition to be true |
| `debug` | Display information |
| `when` | Run a task only when a condition is true |
| `fail` | Stop the playbook with a custom message |
| `--check` | Run Ansible in check/dry-run mode |
| `--syntax-check` | Validate playbook syntax |

---

## 40. Current Goal

Build the DevBoard Ansible automation in small, understandable pieces.

The priorities are:

1. Understand the Ansible code.
2. Keep the configuration readable.
3. Use comments to explain important concepts.
4. Test each section before moving forward.
5. Use the reference repository for ideas.
6. Write our own implementation rather than blindly copying the reference.
7. Keep the README updated as new Ansible concepts are introduced.

---

## 41. Final Learning Checklist

When reading any Ansible task, ask:

```text
1. What is this task trying to do?

2. Which Ansible module is being used?

3. What variables does it use?

4. Is there a register?

5. If register is used:
      What does the registered variable contain?

6. Is there a loop?

7. If there is a loop:
      What are we looping over?

8. If register + loop are used:
      Where are the individual results?
      Answer: <registered_variable>.results

9. Is loop_var being used?
      What is the current result called?

10. If stdout is used:
       Which command produced that stdout?

11. If from_json is used:
       Is the current value JSON text?

12. If .Account / .Arn / another field is used:
       What JSON/object contains that field?

13. If assert is used:
       What condition must be true?

14. If changed_when is used:
       Should this task be reported as changed?

15. If failed_when is used:
       Who is deciding whether the task should fail?

16. If when is used:
       Under what condition does this task run?
```

---

## 42. Next Steps

Continue building the DevBoard automation one section at a time.

For each new section:

```text
Understand
   |
   v
Write
   |
   v
Comment
   |
   v
Syntax check
   |
   v
Run
   |
   v
Verify
```

The reference repository is used as a guide, but the DevBoard implementation should remain simple, readable, and understandable.
