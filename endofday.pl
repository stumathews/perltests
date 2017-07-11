#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use Storable;
use JSON qw( decode_json );
 
sub ConvertCompanyToTicker {
	my @args = @_;
	my $company = shift @args;
	my $region = shift @args || "us";
	my $lang = shift @args ||  "en-gb";
	my $json = getJson("http://d.yimg.com/aq/autoc?query=$company&region=$region&lang=$lang");
	if ($json) {
	    my $jObj = decode_json($json);
	    my @queryResult = @{$jObj->{'ResultSet'}{'Result'}};
	    for my $var (@queryResult) { 
		    print "LIVE convertCompanyToTicker\n";
		    return $var->{symbol};
	    }
	} else {
	    return undef;
	}
	return undef;
}

sub ConvertTickerToStock {
	my @args = @_;
	my $ticker = shift @args;
	my $json = getJson("https://query.yahooapis.com/v1/public/yql?q=".
		           "select%20*%20from%20yahoo.finance.quotes%20where%20symbol%20in%20(%22" .
			   $ticker .
			   "%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=");
	if($json){
		my $jObj = decode_json($json);
		my $queryResult = $jObj->{'query'}{'results'}{'quote'};
		#interpret hashref into a hash
		my %hash = %$queryResult;
		return %hash;
	}
	return undef;
}

sub getJson {
	my @args = @_;
	my $url = shift @args;
	my $req = HTTP::Request->new(GET => $url);
           $req->header('content-type' => 'application/json');
	my $ua = LWP::UserAgent->new;
        my $resp = $ua->request($req);

        if ($resp->is_success) {
	    return $resp->decoded_content;
        } else {
            print "HTTP GET error code: ", $resp->code, "\n";
            print "HTTP GET error message: ", $resp->message, "\n";
	    return undef;
        }
	return undef;
}

#Read in Cache of ticker to company names
my $cachefile = "co2tick.cache";
my $haveTickerCache = -e $cachefile;
my %cache;
if($haveTickerCache) {
	print "cache file found \n";
	%cache = %{ retrieve($cachefile) };
}


my %all;

# Read in the list of companies
my $lineCount = 0;
while(<>){
	chomp;
	chop;
	my $company = $_;
	next if !$_;
	#TODO: lookup cache for previous company to ticker resolutions, so we dont have to call extra rest call
	my $ticker;
	$ticker = $cache{$company};
	if($ticker) { 
		print "cache hit for '$company' as '$ticker'!\n"; 
	} else{
 		$ticker = ConvertCompanyToTicker($company);
	};
	next if !$ticker;
	$cache{$company} = $ticker if(!$cache{$company});
	## save ticker details in global ticker hash
	my %stock = ConvertTickerToStock($ticker);
	if(%stock) {	
		$all{$ticker} = %stock;
		print "$stock{'symbol'}\n";
	} else { next; }
	if($lineCount == 3) {last;}

	#TODO: update cache of companies to ticker symbols
	
# 
#	foreach my $var (keys %stock) {
#		$stock{$var} = "empty" if !$stock{$var};
#		print "$var = ".$stock{$var}."\n";
#	}	
	$lineCount++;
}
store(\%cache,$cachefile);

# This is where we should multithread the rest calls to speed up things.
foreach my $ticker (keys %all) {
	print "Ticker is $ticker\n";
}
