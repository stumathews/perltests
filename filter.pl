#!/usr/bin/perl
use strict;

sub encode_name {
	my $name = shift @_;
	$name  =~ s/ /_/g;
	return $name;	
}

sub decode_name {
	my $name = shift @_;
	$name  =~ s/_/ /g;
	return $name;	
}

my $excludeFile = "exclude.csv";
my @companies = <>;
open (EXCLUDE, "< $excludeFile") or die "Can't open $excludeFile for read: $!";
my @lines = <EXCLUDE>;


#//@companies = map { encode_name($_)} @companies;
#@lines = map { encode_name($_)} @lines;

#@lines = grep {chop } @lines;
#@companies = grep {chop} @companies;


 #@companies = qw(BERDEEN ASIAN INCOME FUND LT ABERDEEN DIVERSIFIED INCOME AND GROWTH TRUST PL ABERDEEN NEW INDIA INVESTMENT TRUST PL ABERFORTH SPLIT LEVEL INCOME TRUST PL Four);
 #@lines = qw(ABERDEEN ASIAN INCOME FUND LT ABERDEEN DIVERSIFIED INCOME AND GROWTH TRUST PL ABERDEEN NEW INDIA INVESTMENT TRUST PL ABERFORTH SPLIT LEVEL INCOME TRUST PL);
 



print "There are $#lines excludes\n";
print "There are $#companies companies before exclude filter\n";
# exclude from companies those that are in exclude file	
my %exclude;
foreach my $line(@lines){
	$exclude{$line} = undef;
}


@companies = grep {not exists $exclude{$_}} @companies;


print "There are $#companies companies After exclude filter\n";
exit 0;
close EXCLUDE or die "Cannot close $excludeFile: $!"; 

