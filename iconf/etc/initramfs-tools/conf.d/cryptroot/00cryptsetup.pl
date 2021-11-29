#!/usr/bin/perl -CSDAL

use warnings;
use strict;
use Tie::IxHash;
use String::ShellQuote;
use Stsbl::IServ::Cryptsetup qw(find_root);

my %root = find_root;

my %args;
tie %args, "Tie::IxHash";

$args{target} = $root{cryptroot}->{name};
$args{source} = "UUID=$root{cryptroot_parent}->{uuid}";
$args{key} = "/etc/keys/cryptkey.gpg";
$args{keyscript} = "/lib/cryptsetup/scripts/decrypt_gnupg_sc";

die "Could not obtain cryptroot information!\n" if
    not defined $root{root_device} or
    not defined $root{cryptroot} or
    not defined $root{cryptroot_parent}
;

if ($root{root_device}->{type} eq "lvm")
{
  my $q_device = shell_quote $root{root_device}->{path};
  $args{lvm} = (qx(lvs --noheadings -o vg_name $q_device) =~ s/^ +//gr);
  chomp $args{lvm};
}

print join(",", map { $_ . "=" . $args{$_} } keys %args) . "\n";
