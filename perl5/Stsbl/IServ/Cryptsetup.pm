package Stsbl::IServ::Cryptsetup;

use warnings;
use strict;
use feature qw(current_sub);
use JSON;

BEGIN
{
  use Exporter;
  our @ISA = qw(Exporter);
  our @EXPORT = qw(find_root find_cryptdevices);
};

sub find_root()
{
  my $json = JSON->new->allow_nonref;
  my $lsblk_out = qx(lsblk --json -o name,mountpoint,path,type,uuid);

  my $blk_dev = $json->decode($lsblk_out) or die "Could not parse lsblk output.\n";

  my ($cryptroot, $cryptroot_parent, $root_device);

  my sub iterate_block_devices(@)
  {
    for my $block_device (@_)
    {
      return if defined $root_device;
      $cryptroot_parent = $block_device if not defined $cryptroot and
          $block_device->{type} ne "crypt";
      $cryptroot = $block_device if $block_device->{type} eq "crypt"; 

      if (defined $block_device->{mountpoint} and $block_device->{mountpoint} eq "/")
      {
      	$root_device = $block_device;
      	last;
      }
      elsif (not defined $block_device->{children})
      {
      	undef $root_device;
      	undef $cryptroot_parent;
      	undef $cryptroot;
      }
      else
      {
      	__SUB__->(@{ $block_device->{children} });
      }
    }
  }

  iterate_block_devices(@{ $blk_dev->{blockdevices} });

  undef $cryptroot_parent if not defined $cryptroot;

  return (
    cryptroot => $cryptroot,
    cryptroot_parent => $cryptroot_parent,
    root_device => $root_device
  );
}

sub find_cryptdevices()
{
  my $json = JSON->new->allow_nonref;
  my $lsblk_out = qx(lsblk --json -o name,mountpoint,path,type,uuid);

  my $blk_dev = $json->decode($lsblk_out) or die "Could not parse lsblk output.\n";
  my @cryptdevices;
  my $previous_device;
  
  my sub iterate_block_devices(@)
  {
    for my $block_device (@_)
    {
      $block_device->{parent} = $previous_device;
      push @cryptdevices, $block_device if $block_device->{type} eq "crypt";
      $previous_device = $block_device;
      __SUB__->(@{ $block_device->{children} })
          if defined $block_device->{children};
    }
  }

  iterate_block_devices @{ $blk_dev->{blockdevices} };

  my %name_hash = map { $_->{name} => $_ } @cryptdevices;

  map { $name_hash{$_} } sort keys %name_hash;
}

1;
