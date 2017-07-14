#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use Storable;
use JSON qw( decode_json );
use Scalar::Util qw(reftype);
#use Parallel::Iterator qw( iterate );

sub ConvertCompanyToTicker {
	my @args = @_;
	my $company = shift @args;
	my $region = shift @args || "us";
	my $lang = shift @args ||  "en-gb";
	my $json = getJson("http://d.yimg.com/aq/autoc?query=$company&region=$region&lang=$lang");
	if ($json) {
		#print "json:$json\n";
	    my $jObj = decode_json($json);
	    my @queryResult = @{$jObj->{'ResultSet'}{'Result'}};
	    for my $var (@queryResult) { 
		    return $var->{symbol};
	    }
	}
	return undef;
}

sub ConvertTickerToStock {
	my @args = @_;
	my $ticker = shift @args;
	my $json = getJson("https://query.yahooapis.com/v1/public/yql?q=".
		           "select%20*%20from%20yahoo.finance.quotes%20where%20symbol%20in%20(%22" .$ticker.
			   "%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=");
	if($json) {
		#print "json:$json\n";
		my $jObj = decode_json($json);
		my $queryResult = $jObj->{'query'}{'results'}{'quote'};
		return undef if !$queryResult;
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
}

#Global store if all tickers and their stock details(tbd)
my %all;

#Read in Cache of ticker to company names to prevent relookup(expensive)
my $cacheFileName = "co2tick.cache";
my $progressCacheFileName = "progress.cache";
my $haveTickerCache = -e $cacheFileName;
my $haveProgressCache = -e $progressCacheFileName;
my %resolutionCache;
if($haveTickerCache) {
	%resolutionCache = %{ retrieve($cacheFileName) };
}
if($haveProgressCache) {
	%all = %{ retrieve($progressCacheFileName) };
}

$SIG{'INT'} = sub {
	store(\%all,$progressCacheFileName);
	exit 1;
};

# Read in the list of companies
my $lineCount = 0;
while(<>){
	chomp;
	chop;
	next if !$_;
	my $company = $_;
	my $ticker;

	$company =~ s/ /_/g;
	$ticker = $resolutionCache{$company};

	# get a ticker	
	if(!$ticker) { 
		$company =~ s/_/ /g;
	    	print "LIVE convertCompanyToTicker Company:'$company': ";
		$ticker = ConvertCompanyToTicker($company);
		print ($ticker || "could not resolved to a ticker symbol.");
		print "\n";
	};

	if(!$ticker) {
		next;
	}
	$all{$ticker} = undef if(!$all{$ticker});
	$company =~ s/ /_/g;
	$resolutionCache{$company} = $ticker;

	last if $lineCount == 5;	
	$lineCount++;
}

#persist the cache of company to ticker hashes for future lookups...
store(\%resolutionCache,$cacheFileName);

# This is where we should multithread the rest calls to speed up things.
my $processed = 0;
foreach my $ticker (keys %all) {
	if(!$all{$ticker}) {
	    	print "LIVE ConvertTickerToStock $ticker: ";
		my %stock = ConvertTickerToStock($ticker);
		if(%stock) {	
			$all{$ticker} = \%stock;
			print "Symbol:".($all{$ticker}->{'symbol'} || "No symbol found.")
			." Name: ".($all{$ticker}->{'Name'} || "No name found.")
			." Ask: ".($all{$ticker}->{'Ask'} || "No askping price found.")."\n";
		} else { 
			print "no stock data recieved for $ticker\n";
			$all{$ticker} = undef;
			next;
		}
	}
}

# TODO: write all to CSV as output...
foreach my $ticker (keys %all) {
	my $hash = $all{$ticker}; 
	foreach my $key(keys %$hash) {
		my $column = $key;
		my $data = $hash->{$key} || "none";
		print "column: $column data: $data\n";
	}
}
unlink $progressCacheFileName


