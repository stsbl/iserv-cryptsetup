# iserv-server-dropbear Extraction Design

## Goal

Extract the generic initramfs Dropbear remote-access functionality from `stsbl-iserv-cryptsetup` into a new official IServ package `iserv-server-dropbear`, while keeping cryptsetup, GPG, and smartcard unlocking logic in `stsbl-iserv-cryptsetup`.

## Scope

This design covers:

- creating a new official package/repository `iserv/server-dropbear` via `igit init`
- moving the generic Dropbear initramfs integration out of `stsbl-iserv-cryptsetup`
- moving generic initramfs firewall support out of `stsbl-iserv-cryptsetup`
- moving PPP initramfs networking support out of `stsbl-iserv-cryptsetup`
- updating `stsbl-iserv-cryptsetup` to consume the new package

This design does not cover:

- redesigning the GPG/smartcard unlock flow
- changing the cryptsetup feature set
- generalizing the unlock mechanism beyond the current Dropbear-based remote access path

## Problem Statement

`stsbl-iserv-cryptsetup` currently mixes two concerns:

1. a reusable transport layer for remote access to the initramfs environment
2. a cryptsetup-specific unlock implementation using GPG and smartcards

Ticket #90977 requires an official IServ package for the reusable part. The extracted package should be generally usable for initramfs SSH access, including hosts that need PPP networking on boot, while `stsbl-iserv-cryptsetup` remains responsible for disk-unlock-specific behavior.

## Package Boundary

### New package: `iserv-server-dropbear`

The new package owns generic initramfs remote-access functionality:

- Dropbear initramfs integration
- SSH authorized-keys materialization for initramfs access
- an initramfs-compatible independent second-factor concept for Dropbear access
- initramfs network configuration inputs
- PPP initramfs networking support
- generic initramfs firewall hooks and assets
- initramfs rebuild hooks related to the above

### Existing package: `stsbl-iserv-cryptsetup`

The existing package keeps unlock-specific functionality:

- crypttab / cryptroot handling
- cryptsetup-specific config generation
- GPG-encrypted key handling
- smartcard-based decryption logic
- cryptsetup-specific initramfs hooks

## File Ownership Plan

### Move to `iserv-server-dropbear`

From `stsbl-iserv-cryptsetup`, move or adapt the generic parts:

- `config/80cryptsetup`
  - `DropbearAuthorizedAccounts`
  - `InitramfsNetworkInterface`
  - `InitramfsNetworkConfigureStatic`
- `iservchk/40dropbear/**`
- `usr/share/initramfs-tools/hooks/iptables`
- `usr/share/initramfs-tools/hooks/nft`
- `usr/share/initramfs-tools/scripts/init-premount/iptables`
- `usr/share/initramfs-tools/scripts/init-premount/nft`
- `usr/share/initramfs-tools/scripts/init-premount/nft-default`
- `usr/share/initramfs-tools/scripts/init-bottom/iptables`
- `usr/share/initramfs-tools/scripts/init-bottom/nft`
- shared nft assets below `usr/share/.../nft`
- PPP initramfs setup currently coupled to Dropbear boot networking

These files may need renaming or path adjustment so they no longer reference `stsbl`-specific package naming.

### Keep in `stsbl-iserv-cryptsetup`

- `iservchk/40cryptsetup/**`
- `lib/cryptsetup/**`
- `system-root/lib/cryptsetup/scripts/decrypt_gnupg_sc`
- `usr/share/initramfs-tools/hooks/cryptgnupg_sc`
- cryptsetup-specific Debian packaging, metadata, and upgrade handling

## New Package Structure

The new repository will be created with `igit init`, but the generated skeleton will be reduced to a system-package structure appropriate for a server integration package rather than a portal-web feature module.

The package should contain:

- Debian packaging metadata for `iserv-server-dropbear`
- `config/` definitions for Dropbear/initramfs network settings
- `config/` definitions for Dropbear access-control and second-factor policy
- `iconf/` templates as needed for shipped config files
- `iservchk/` checks for Dropbear, initramfs networking, PPP, and initramfs rebuild triggers
- `usr/share/initramfs-tools/` hooks and scripts for firewall/network integration
- package-owned shared assets such as default nftables structure

The package should not contain cryptsetup, GPG, or smartcard decryption code.

## Dependency Model

`iserv-server-dropbear` will depend on the generic runtime it actually needs, especially:

- `dropbear-initramfs`
- any initramfs/network/firewall runtime packages required by the moved functionality
- PPP-related packages needed for initramfs DSL support

`stsbl-iserv-cryptsetup` will be changed to depend on `iserv-server-dropbear` and will no longer ship the moved generic Dropbear/firewall/PPP pieces itself.

## Access Control and 2FA Concept

`iserv-server-dropbear` must not assume PAM-based second factors such as Duo Push, because the initramfs Dropbear environment does not provide the booted system's PAM stack.

Instead, the package should implement an initramfs-compatible independent second-factor concept based on two SSH keys:

- Dropbear access requires two distinct configured SSH credentials
- both factors are possession factors, but they must be modeled as separate credentials rather than one key reused twice
- the generated authorization material and helper logic must make the factor split explicit and auditable

This concept is the baseline replacement for PAM/Duo-based interactive second-factor enforcement during initramfs access.

### Authorization source

The package should support two authorization modes:

1. **Dedicated Dropbear access list enabled**
   - use a package-specific configuration option to define who may access Dropbear in initramfs

2. **Dedicated Dropbear access list disabled**
   - fall back to the normal remote support list as the authorization source

This keeps deployment simple for environments that already maintain the normal remote support list, while allowing a stricter separate Dropbear policy when desired.

### Design constraints

- the dedicated Dropbear access-list configuration must be optional
- fallback to the normal remote support list must be automatic when the dedicated list is not enabled
- the second-factor model must remain functional without external online services
- the implementation should leave room for later hardening, but the initial supported concept is two-key authentication

## Integration Rules

The extraction follows this rule:

- if a file is usable without knowing about crypt devices, GPG, or smartcards, it belongs in `iserv-server-dropbear`
- if a file knows about cryptroot, encrypted key material, GPG, or smartcard unlock flow, it stays in `stsbl-iserv-cryptsetup`

This keeps the new package reusable for remote initramfs access on systems that are not tied to the current unlock implementation.

## Migration Strategy

1. Create the new repo/package `iserv/server-dropbear` with `igit init`.
2. Reduce the generated skeleton to the parts appropriate for a server package.
3. Transplant the generic Dropbear/firewall/PPP assets from `stsbl-iserv-cryptsetup`.
4. Adjust package names, paths, and ownership so the new package is self-contained.
5. Update `stsbl-iserv-cryptsetup` to remove the moved files.
6. Add a dependency from `stsbl-iserv-cryptsetup` to `iserv-server-dropbear`.
7. Verify that cryptsetup-specific functionality still has all required hooks and config after the split.

## Risks and Mitigations

### Risk: hidden coupling between Dropbear and cryptsetup logic

Mitigation:

- inspect all moved files for implicit assumptions about cryptroot-specific paths or files
- leave any cryptsetup-aware behavior in `stsbl-iserv-cryptsetup`

### Risk: PPP support is not fully generic yet

Mitigation:

- move PPP support together with Dropbear networking ownership
- keep PPP checks limited to generic initramfs remote-access requirements

### Risk: the two-key second-factor design is hard to express in Dropbear tooling

Mitigation:

- make the factor split explicit in config and generated authorization material
- keep the first implementation narrowly scoped to the approved two-key concept
- validate early whether helper scripts or wrapper logic are required around Dropbear's normal key handling

### Risk: duplicate initramfs update triggers

Mitigation:

- review both packages after extraction
- keep rebuild hooks only where package-owned files actually require them

## Verification Plan

The implementation is complete when:

- `iserv-server-dropbear` exists as a new official package created with `igit init`
- generic Dropbear/firewall/PPP files are owned by `iserv-server-dropbear`
- `stsbl-iserv-cryptsetup` no longer ships those generic files
- `stsbl-iserv-cryptsetup` depends on `iserv-server-dropbear`
- `iserv-server-dropbear` has a documented access-control model with optional dedicated Dropbear allowlisting and fallback to the normal remote support list
- `iserv-server-dropbear` has an initramfs-compatible independent second-factor concept based on two SSH keys
- cryptsetup, GPG, and smartcard-specific logic remains present and coherent in `stsbl-iserv-cryptsetup`
- the resulting package layouts and shipped hook paths are internally consistent
