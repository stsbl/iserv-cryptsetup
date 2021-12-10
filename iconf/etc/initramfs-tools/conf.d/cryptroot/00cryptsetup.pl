#!/usr/bin/perl -CSDAL

use warnings;
use strict;
use Tie::IxHash;
use String::ShellQuote;
use Stsbl::IServ::Cryptsetup qw(find_root);

my %root = find_root;

do { print "\n"; exit; } if
    not defined $root{root_device} or
    not defined $root{cryptroot} or
    not defined $root{cryptroot_parent}
;

my %args;
tie %args, "Tie::IxHash";

$args{target} = $root{cryptroot}->{name} // "";
$args{source} = "UUID=$root{cryptroot_parent}->{uuid}";
$args{key} = "/etc/keys/cryptkey.gpg";
$args{keyscript} = "/lib/cryptsetup/scripts/decrypt_gnupg_sc";

# Suppress "File descriptor 10 [...] leaked on lvs invocation" warning
$ENV{LVM_SUPPRESS_FD_WARNINGS} = 1;

if ($root{root_device}->{type} eq "lvm")
{
  my $q_device = shell_quote $root{root_device}->{path};
  my $vg_name = (qx(lvs --noheadings -o vg_name $q_device) =~ s/^ +//gr);
  chomp $vg_name;
  push @{ $args{lvm} }, $vg_name;
  push @{ $args{lvm} }, $root{root_device}->{name};
}

print join(",", map {
    my $arg = $_;
    ref $args{$_} eq "ARRAY" ?
        map { $arg . "=" . $_ } @{ $args{$_} } :
        $_ . "=" . $args{$_}
    } keys %args) . "\n";
