# Server Dropbear Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a new official `iserv-server-dropbear` package from the generic Dropbear/firewall/PPP initramfs parts of `stsbl-iserv-cryptsetup`, then update `stsbl-iserv-cryptsetup` to depend on and use it.

**Architecture:** Build a new `iserv/server-dropbear` repository with `igit init`, reduce it to a small server package, transplant generic initramfs remote-access logic into it, and leave cryptsetup/GPG/smartcard-specific logic in `stsbl-iserv-cryptsetup`. Add an initramfs-compatible two-key 2FA concept and optional dedicated Dropbear allowlisting with fallback to the normal remote support list.

**Tech Stack:** Debian packaging, igit, iservchk, iconf, initramfs-tools hooks/scripts, shell, Dropbear initramfs, nftables/iptables, PPP initramfs integration

## Global Constraints

- New repository/package name must be `iserv/server-dropbear` and `iserv-server-dropbear`.
- Bootstrap the new repository with `igit init`.
- `iserv-server-dropbear` owns generic Dropbear initramfs integration, firewall support, PPP initramfs networking, access-control config, and two-key initramfs 2FA.
- `stsbl-iserv-cryptsetup` keeps cryptsetup, cryptroot/crypttab, GPG, and smartcard logic.
- Dedicated Dropbear access-list configuration must be optional.
- If dedicated Dropbear allowlisting is disabled, authorization must fall back to the normal remote support list.
- The independent second-factor concept must work in initramfs without PAM or online services.
- The initial supported second-factor concept is two SSH keys.
- Keep package-owned initramfs rebuild triggers only where required by files that package ships.
- Follow existing IServ packaging conventions and commit wording with ticket reference.

---

## File Structure

### New repository: `/home/felix.jacobi/git/iserv/server-dropbear`

- `debian/control` — package metadata and runtime dependencies
- `debian/changelog` — package changelog
- `debian/*.install` / `debian/*.iservinstall` / maintainer scripts — shipping metadata
- `config/*` — Dropbear access/network/2FA configuration keys
- `iconf/**` — generated config templates if needed
- `iservchk/**` — Dropbear, firewall, PPP, authorization, and initramfs-update checks
- `usr/share/initramfs-tools/hooks/*` — initramfs hook installation
- `usr/share/initramfs-tools/scripts/**` — initramfs runtime scripts
- `usr/share/iserv/server-dropbear/**` or equivalent — package-owned static helper assets
- helper scripts under `lib/` or `sbin/` if needed for two-key auth material generation

### Existing repository: `/home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup`

- `debian/control` — add dependency on `iserv-server-dropbear`, remove moved runtime deps
- `debian/*.iservinstall` / maintainer metadata — remove moved files
- `config/80cryptsetup` — remove or adapt config keys moved to new package
- `iservchk/40dropbear/**` — delete after transfer
- `usr/share/initramfs-tools/hooks/{iptables,nft}` — delete after transfer
- `usr/share/initramfs-tools/scripts/init-premount/*` and `init-bottom/*` — delete moved generic scripts
- `usr/share/stsbl/iserv-cryptsetup/nft/**` — move generic nft asset if still generic
- keep `iservchk/40cryptsetup/**`, `lib/cryptsetup/**`, `system-root/lib/cryptsetup/scripts/decrypt_gnupg_sc`, `usr/share/initramfs-tools/hooks/cryptgnupg_sc`

### Interfaces

- `iserv-server-dropbear` consumes generic account/network policy input from config and/or existing remote support sources.
- `iserv-server-dropbear` produces Dropbear/initramfs authorization material, firewall scripts, PPP/network setup, and initramfs rebuild hooks.
- `stsbl-iserv-cryptsetup` consumes `iserv-server-dropbear` as a runtime dependency and produces only cryptsetup-specific initramfs behavior.

### Task 1: Create and inspect the new repository skeleton

**Files:**
- Create: `/home/felix.jacobi/git/iserv/server-dropbear/**`
- Test: `/home/felix.jacobi/git/iserv/server-dropbear/.git`, `/home/felix.jacobi/git/iserv/server-dropbear/debian/control`

**Interfaces:**
- Consumes: repository name `server-dropbear`, package name `iserv-server-dropbear`
- Produces: a bootstrap repository ready to receive extracted files

- [ ] **Step 1: Create the target directory parent if needed**

```bash
mkdir -p /home/felix.jacobi/git/iserv
```

- [ ] **Step 2: Run `igit init` for the new package**

Run interactively in:

```bash
cd /home/felix.jacobi/git/iserv
igit init
```

Use answers equivalent to:

```text
vendor: iserv
project name: server-dropbear
description: Dropbear initramfs integration for IServ
branch: 90977-server-dropbear
skeleton type: skeleton
```

Expected: a new repository at `/home/felix.jacobi/git/iserv/server-dropbear`.

- [ ] **Step 3: Record the generated structure**

Run:

```bash
cd /home/felix.jacobi/git/iserv/server-dropbear
find . -maxdepth 3 | sort
```

Expected: repository layout is present and includes `debian/`, `mk/`, `iconf/`, `iservchk/`, and git metadata.

- [ ] **Step 4: Commit the raw bootstrap**

```bash
cd /home/felix.jacobi/git/iserv/server-dropbear
git add .
git commit -S -m "Bootstrap iserv-server-dropbear package (refs #90977)"
```

### Task 2: Reduce the skeleton to a server-package baseline

**Files:**
- Modify: `/home/felix.jacobi/git/iserv/server-dropbear/debian/control`
- Modify: `/home/felix.jacobi/git/iserv/server-dropbear/debian/changelog`
- Modify: `/home/felix.jacobi/git/iserv/server-dropbear/mk/config.mk`
- Modify: `/home/felix.jacobi/git/iserv/server-dropbear/make.targets`
- Delete: portal-web/application files generated by `igit init` that are not needed for a system package

**Interfaces:**
- Consumes: generated skeleton from Task 1
- Produces: a minimal package layout focused on Debian/iservchk/iconf/initramfs integration

- [ ] **Step 1: Inventory generated files and decide removals**

Run:

```bash
cd /home/felix.jacobi/git/iserv/server-dropbear
find . -maxdepth 3 | sort > /tmp/server-dropbear-generated-tree.txt
```

Expected: reviewable list for trimming app/web-only files.

- [ ] **Step 2: Remove unused portal-web/app scaffolding**

Delete only generated files not needed for a server package, such as:

```bash
cd /home/felix.jacobi/git/iserv/server-dropbear
rm -rf app bin db iserv-module.json renovate.json .gitlab-ci.yml
```

Also remove any now-broken packaging references to those paths.

- [ ] **Step 3: Rewrite build metadata for a non-portal package**

Ensure `mk/config.mk` and `make.targets` only reference targets still used by the package, for example:

```makefile
# mk/config.mk
PACKAGE=iserv-server-dropbear
```

```text
# make.targets
mk/config.mk
iservinstall
```

Expected: no references remain to webpack, composer, phpunit, or portal-web assets.

- [ ] **Step 4: Normalize package description and dependencies**

Update `debian/control` so the package describes Dropbear/initramfs integration rather than a skeleton package.

Expected runtime dependency seed:

```debcontrol
Package: iserv-server-dropbear
Architecture: all
Depends: ${misc:Depends},
 dropbear-initramfs,
 initramfs-tools
Description: Dropbear initramfs integration for IServ
 Generic remote initramfs access for IServ systems, including
 Dropbear-based access control, firewall integration, and
 boot-time network support.
```

- [ ] **Step 5: Commit the reduced baseline**

```bash
cd /home/felix.jacobi/git/iserv/server-dropbear
git add -A
git commit -S -m "Reduce server-dropbear skeleton to server package baseline (refs #90977)"
```

### Task 3: Move generic Dropbear, firewall, and PPP files into the new package

**Files:**
- Create/Modify: `/home/felix.jacobi/git/iserv/server-dropbear/config/*`
- Create/Modify: `/home/felix.jacobi/git/iserv/server-dropbear/iservchk/**`
- Create/Modify: `/home/felix.jacobi/git/iserv/server-dropbear/usr/share/initramfs-tools/hooks/*`
- Create/Modify: `/home/felix.jacobi/git/iserv/server-dropbear/usr/share/initramfs-tools/scripts/**`
- Create/Modify: package-owned nft asset paths
- Source files from `/home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/...`

**Interfaces:**
- Consumes: generic files from `stsbl-iserv-cryptsetup`
- Produces: self-contained generic initramfs remote-access package contents

- [ ] **Step 1: Copy the generic file set into a staging branch of the new repo**

Run commands equivalent to:

```bash
cd /home/felix.jacobi/git/iserv/server-dropbear
mkdir -p config iservchk/40dropbear usr/share/initramfs-tools/hooks usr/share/initramfs-tools/scripts/init-premount usr/share/initramfs-tools/scripts/init-bottom
cp /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/iservchk/40dropbear/20cryptsetup iservchk/40dropbear/
cp /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/iservchk/40dropbear/20cryptsetup_authorized_keys.sh iservchk/40dropbear/
cp /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/iservchk/40dropbear/90cryptsetup_update-initramfs iservchk/40dropbear/
cp /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/usr/share/initramfs-tools/hooks/iptables usr/share/initramfs-tools/hooks/
cp /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/usr/share/initramfs-tools/hooks/nft usr/share/initramfs-tools/hooks/
cp /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/usr/share/initramfs-tools/scripts/init-premount/iptables usr/share/initramfs-tools/scripts/init-premount/
cp /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/usr/share/initramfs-tools/scripts/init-premount/nft usr/share/initramfs-tools/scripts/init-premount/
cp /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/usr/share/initramfs-tools/scripts/init-premount/nft-default usr/share/initramfs-tools/scripts/init-premount/
cp /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/usr/share/initramfs-tools/scripts/init-bottom/iptables usr/share/initramfs-tools/scripts/init-bottom/
cp /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/usr/share/initramfs-tools/scripts/init-bottom/nft usr/share/initramfs-tools/scripts/init-bottom/
```

Expected: the generic initramfs assets exist in the new repository.

- [ ] **Step 2: Create package-local config keys**

Split the extracted config out of `config/80cryptsetup` into package-local definitions such as:

```text
DropbearAuthorizedAccounts
DropbearDedicatedAuthorizedAccounts
DropbearUseDedicatedAuthorizedAccounts
InitramfsNetworkInterface
InitramfsNetworkConfigureStatic
DropbearRequireTwoFactor
DropbearSecondFactorAccounts
```

Expected: no new key is still named as cryptsetup-specific unless it truly is.

- [ ] **Step 3: Rename scripts and ownership references**

Adjust filenames and contents so they stop referring to `cryptsetup` where behavior is generic, for example:

```text
20cryptsetup_authorized_keys.sh -> 20dropbear_authorized_keys.sh
90cryptsetup_update-initramfs -> 90dropbear_update-initramfs
```

Also move nft asset paths away from `usr/share/stsbl/iserv-cryptsetup/...`.

- [ ] **Step 4: Add PPP ownership to the new package**

Inspect `iservchk/40dropbear/20cryptsetup` and related config generation, then rename/adapt it so PPP/initramfs networking becomes explicitly owned by `iserv-server-dropbear`.

Expected: the new package owns PPP initramfs setup needed for DSL boot access.

- [ ] **Step 5: Commit the generic extraction in the new repo**

```bash
cd /home/felix.jacobi/git/iserv/server-dropbear
git add -A
git commit -S -m "Add generic Dropbear, firewall, and PPP initramfs integration (refs #90977)"
```

### Task 4: Implement authorization source selection and two-key 2FA in the new package

**Files:**
- Modify/Create: `/home/felix.jacobi/git/iserv/server-dropbear/config/*`
- Modify/Create: `/home/felix.jacobi/git/iserv/server-dropbear/iservchk/**`
- Modify/Create: helper scripts under `/home/felix.jacobi/git/iserv/server-dropbear/lib/**` or `/sbin/**`
- Test: generated authorized-keys/config outputs

**Interfaces:**
- Consumes: remote support list and optional dedicated Dropbear access list
- Produces: auditable Dropbear authorization material with optional dedicated allowlisting and two-key factor support

- [ ] **Step 1: Define authorization-source behavior in config**

Create or update config keys to express:

```text
DropbearUseDedicatedAuthorizedAccounts (bool)
DropbearAuthorizedAccounts (fallback/default source)
DropbearDedicatedAuthorizedAccounts (optional dedicated source)
DropbearRequireTwoFactor (bool)
DropbearFirstFactorAccounts / DropbearSecondFactorAccounts or equivalent explicit split
```

Expected: the fallback path to the normal remote support list is explicit when dedicated mode is off.

- [ ] **Step 2: Implement authorization-material generation**

Write a helper script or iservchk shell fragment that:

```sh
# Pseudocode
if DropbearUseDedicatedAuthorizedAccounts=true; then
    authorized_source="$DropbearDedicatedAuthorizedAccounts"
else
    authorized_source="$RemoteSupportAccounts"
fi

generate_factor_1_material "$authorized_source"
generate_factor_2_material "$second_factor_source"
```

Expected: generated outputs clearly separate factor 1 and factor 2.

- [ ] **Step 3: Implement the two-key login concept**

If Dropbear cannot natively require two keys in a single session, add wrapper/helper enforcement that makes the factor check explicit and reproducible. Document the exact mechanism in code comments and README/package docs.

Expected: the package contains a concrete, testable implementation path for “two SSH keys required”.

- [ ] **Step 4: Add deterministic checks**

Use `iservchk` or helper commands to ensure generated authorization files are reproducible, for example:

```text
Check /etc/dropbear-initramfs/authorized_keys
Check /etc/dropbear-initramfs/config
```

or Debian-version-specific equivalents under `/etc/dropbear/initramfs/`.

- [ ] **Step 5: Commit the access-control/2FA implementation**

```bash
cd /home/felix.jacobi/git/iserv/server-dropbear
git add -A
git commit -S -m "Implement Dropbear allowlisting and two-key 2FA (refs #90977)"
```

### Task 5: Clean `stsbl-iserv-cryptsetup` down to cryptsetup-specific ownership

**Files:**
- Modify: `/home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup/debian/control`
- Modify/Delete: moved generic files in config/iservchk/usr/share
- Keep: cryptsetup/GPG/smartcard-specific files only

**Interfaces:**
- Consumes: the new `iserv-server-dropbear` package as dependency
- Produces: a lean cryptsetup package with only unlock-specific behavior

- [ ] **Step 1: Remove moved runtime dependencies from `debian/control`**

Review and reduce generic runtime dependencies, especially where they now belong in `iserv-server-dropbear`, while adding:

```debcontrol
Depends: ${misc:Depends},
 ${perl:Depends},
 iserv-server-dropbear,
 ...
```

- [ ] **Step 2: Remove moved config keys and generic files**

Delete or adapt:

```text
config/80cryptsetup entries for Dropbear/networking
iservchk/40dropbear/**
usr/share/initramfs-tools/hooks/iptables
usr/share/initramfs-tools/hooks/nft
usr/share/initramfs-tools/scripts/init-premount/iptables
usr/share/initramfs-tools/scripts/init-premount/nft
usr/share/initramfs-tools/scripts/init-premount/nft-default
usr/share/initramfs-tools/scripts/init-bottom/iptables
usr/share/initramfs-tools/scripts/init-bottom/nft
generic nft assets if moved to the new package
```

- [ ] **Step 3: Keep cryptsetup-specific hooks coherent**

Verify that these still exist and still reference valid paths:

```text
iservchk/40cryptsetup/20cryptsetup.templ
lib/cryptsetup/find_cryptdevices
lib/cryptsetup/query_cryptroot
system-root/lib/cryptsetup/scripts/decrypt_gnupg_sc
usr/share/initramfs-tools/hooks/cryptgnupg_sc
```

Expected: no remaining reference points at deleted generic Dropbear asset locations.

- [ ] **Step 4: Update packaging manifests**

Adjust `debian/*.iservinstall`, `links`, `maintscript`, or other package manifests so the removed files are no longer shipped by `stsbl-iserv-cryptsetup`.

- [ ] **Step 5: Commit the consumer-package cleanup**

```bash
cd /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup
git add -A
git commit -S -m "Use iserv-server-dropbear for generic initramfs access (refs #90977)"
```

### Task 6: Verify the split in both repositories

**Files:**
- Test: both repositories’ packaging and generated file references

**Interfaces:**
- Consumes: completed changes from Tasks 1-5
- Produces: proof that ownership and path references are coherent

- [ ] **Step 1: Search for stale ownership references in the new package**

Run:

```bash
cd /home/felix.jacobi/git/iserv/server-dropbear
grep -RIn "stsbl-iserv-cryptsetup\\|cryptsetup_update-initramfs\\|20cryptsetup_authorized_keys\\|usr/share/stsbl/iserv-cryptsetup" .
```

Expected: no stale generic ownership references remain unless intentionally documented.

- [ ] **Step 2: Search for stale references in the old package**

Run:

```bash
cd /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup
grep -RIn "dropbear.*authorized\\|usr/share/stsbl/iserv-cryptsetup/nft\\|init-premount/nft\\|init-bottom/iptables" .
```

Expected: results are limited to cryptsetup-specific references that still make sense after the split.

- [ ] **Step 3: Run narrow packaging/build checks**

Run the narrowest available package validation commands in each repo, for example:

```bash
cd /home/felix.jacobi/git/iserv/server-dropbear
iservmake iservinstall

cd /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup
iservmake iservinstall
```

Expected: packaging/install metadata resolves without missing shipped-file paths.

- [ ] **Step 4: Capture final repo states**

Run:

```bash
cd /home/felix.jacobi/git/iserv/server-dropbear && git status --short
cd /home/felix.jacobi/git/stsbl/stsbl-iserv-cryptsetup && git status --short
```

Expected: only intentional tracked changes remain.

- [ ] **Step 5: Prepare handoff summary**

Summarize:

```text
- files moved to iserv-server-dropbear
- files retained in stsbl-iserv-cryptsetup
- how fallback allowlisting works
- how the two-key 2FA mechanism is implemented
- verification commands run and outcomes
```
