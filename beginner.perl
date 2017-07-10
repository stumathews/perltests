#!/bin/perl

# beginner.perl
# showcasing basic stuff about perl
#

use strict;
use warnings;
use v5.14;

print "Hello World!\n";
my $scalar = "test";
print "my first scalar containts: $scalar\n";

my @array = ("stuart","mathews",2,$scalar);
print "@array";

my %hash = ( name=>"Stuart", surname=>"mathews", age=>30);
print "my hash's name entry is: $hash{name} and my surname is $hash{'surname'}\n";
$hash{"array"} = [@array];
print "the array in the hash is $hash{array}[3]\n";

say "say, look at my newline!";
my @array1 = ("bits", "and", "pieces",1,2+3);
my @array2 = ("more", "bits", "and pices");
say sort @array1, @array2;

#regular expression fun:

open( FILE, "<:utf8", "/etc/passwd") or die "can't open passwd file";
my %passwords;
while(my $line = <FILE>){
	my @parts = split(':',$line);
	$passwords{$parts[0]} = @parts;
	for my $part (@parts){
		print "$part\t";;
	}
	print "\n";
}

