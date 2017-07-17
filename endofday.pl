#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use Storable;
use JSON qw( decode_json );
use Scalar::Util qw(reftype);
use Parallel::Iterator qw( iterate_as_hash );
use Data::Dumper;
use URI::Encode qw(uri_encode uri_decode);
use Getopt::Std;

my %options=();
# -t 4, -d "delimiter" -o "outputfile.csv" -r "us" -l "en-gb" -v -x "exclude.csv"
getopts("t:d:o:r:l:vx:", \%options);
if($options{v}){
	foreach my $opt(keys %options) {
		print "$opt = $options{$opt}\n";
	}
}

sub ConvertCompanyToTicker {
	my @args = @_;
	my $company = uri_encode(shift @args);
	my $region = shift @args || ($options{r} || "us");
	my $lang = shift @args ||  ($options{l} || "en-gb");
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
	print "Live ConvertTickerToStockTicker: '$ticker'\n";
	my $url = "https://query.yahooapis.com/v1/public/yql?q=".
		           "select%20*%20from%20yahoo.finance.quotes%20where%20symbol%20in%20(%22" .$ticker.
			   "%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=";
	my $json = getJson($url);
	if($json) {
		eval {
			my $jObj = decode_json($json);
			1;
			my $queryResult = $jObj->{'query'}{'results'}{'quote'};
			return $queryResult || undef;
		} or do {
		 	print $url; 
			my $e = $@;
			print "$e\n";
			return undef;
		};
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
		next if(!$ticker);
	};

	$all{$ticker} = undef if(!$all{$ticker});
	$company =~ s/ /_/g;
	$resolutionCache{$company} = $ticker;

	$lineCount++;
}

#persist the cache of company to ticker hashes for future lookups...
store(\%resolutionCache,$cacheFileName);

my %output = iterate_as_hash({ workers => ($options{t} || 2) },\&ConvertTickerToStock, \%all);
%all = (%all, %output);
my @columns;

# Write all to CSV as output...
open(my $csv, '>', $options{o} || 'stocks.csv');
foreach my $ticker (sort keys %all) {
	my $delim = $options{d} || ";";
	my $stock = $all{$ticker}; 
	#Get the first stocks values' order as default column order for all following stocks for csv format
	if(!@columns) { 
		@columns = sort keys(%$stock);
		print $csv join($delim, @columns)."\n";
	}
	my @line;
        
	foreach my $key(@columns) {
		my $column = $key;
		my $data = $stock->{$key} || "none";
		push(@line, $data);
	}
	print $csv join($delim ,@line)."\n";
	@line = undef;
}
close($csv);	
unlink $progressCacheFileName


