#!/usr/bin/perl
use strict;

my @list = qw(Gender Name Surname Age);
my @pref = qw(Name Age);
my @newListWithout = grep {!/join("|", @pref)/} @list;
my @reOrder = ("Name","Age",@newListWithout);
print "before : @list, after: @newListWithout\n";
print "reoder : @reOrder\n";
