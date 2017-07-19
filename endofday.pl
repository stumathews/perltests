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
# -t 4, -d "delimiter" -o "outputfile.csv" -r "us" -l "en-gb" -v -x "exclude.csv" -l 5(co limit)
getopts("ht:d:o:r:l:vx:bl:", \%options);
my $verbose = $options{v};
my $colimit = $options{l};
if($verbose) {
	foreach my $opt(keys %options) {
		print "$opt = $options{$opt}\n";
	}
}
if($options{h}){
	print "./endofday.pl -t <numThreads> -d <delimiter> -o <ouputfile> -r <region> -l <language> -x <exclude file> -l <limit> -v\n";
	exit(0);
}

sub ConvertCompanyToTicker {
	my @args = @_;
	my $company = uri_encode(shift @args);
	my $region = shift @args || ($options{r} || "us");
	my $lang = shift @args ||  ($options{l} || "en-gb");
	my $json = getJson("http://d.yimg.com/aq/autoc?query=$company&region=$region&lang=$lang");
	if ($json) {
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
		my $jObj = decode_json($json);
		my $queryResult = $jObj->{'query'}{'results'}{'quote'};
		return $queryResult || undef;
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

#Global store of all tickers and their stock details
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

# read in all the companies and exclude the ones in the exclude file
my @companies = <>;
my $excludeFile = $options{x};

if($excludeFile && -e $excludeFile) {
	print "using exclude file '$excludeFile'\n" if($verbose);
	open (EXCLUDE, "< $excludeFile") or die "Can't open $excludeFile for read: $!";
	my @lines = <EXCLUDE>;
	my %exclude;
	$exclude{$_} = undef foreach (@lines);
	# exclude from companies those that are in exclude file
	@companies = grep {not exists $exclude{$_}} @companies;
	close EXCLUDE or die "Cannot close $excludeFile: $!"; 
}

# process companies
my $lineCount = 0;
foreach my $line(@companies) {
	my $company = $line;
	chomp $company;
	chop $company;
	next if !$company;
	my $ticker;

	# We're going to store company names with space to underscores so we can have one-worded companies in the cache
	$company =~ s/ /_/g;
	$ticker = $resolutionCache{$company};

	# get a ticker	
	if(!$ticker) { 
		$company =~ s/_/ /g;
	    	print "LIVE convertCompanyToTicker Company:'$company': ";
		$ticker = ConvertCompanyToTicker($company);
		print ($ticker || "could not resolved to a ticker symbol.");
		my $addbadTickersToExcludeFile = $options{b};
		if($addbadTickersToExcludeFile && $excludeFile && !$ticker) {
			#exclude bad tickers
			open(my $ex, '>>', $excludeFile) or die "Could not open file '$excludeFile' $!";
			print $ex "$company\n";
			close $ex;
		}
		print "\n";
		next if(!$ticker);
	};

	$all{$ticker} = undef if(!$all{$ticker});

	# Put the multiword comany name in the hash that tracks all the results
	$company =~ s/ /_/g;
	$resolutionCache{$company} = $ticker;

	last if ($colimit && ($lineCount++ == $colimit));
}

#persist the cache of company to ticker hashes for future lookups...
store(\%resolutionCache,$cacheFileName);

my $numThreads = $options{t} || 2; 
my @columns;
my %output = iterate_as_hash({ workers => $numThreads },\&ConvertTickerToStock, \%all);
%all = (%all, %output);

# Write all to CSV as output...
open(my $csv, '>', $options{o} || 'stocks.csv');
foreach my $ticker (sort keys %all) {
	my $delim = $options{d} || ";";
	my $stock = $all{$ticker}; 
	#Get the first stocks values' order as default column order for all following stocks for csv format
	if(!@columns) { 
		@columns = sort keys(%$stock);
		@preferred = qw(Name Currency Ask Open PreviousClose PercentChange PriceBook Change DaysHigh DaysLow EarningsShare);
		my @newColumnsWithout = grep {!/join("|",@preferred)/} @columns;
		my @reOrder = (@preferred, @newColumnsWithout);

		print $csv join($delim, @reOrder)."\n";
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
unlink $progressCacheFileName;

my $end_run = time();
my $start_run = $^T;
my $run_time = $end_run - $start_run;
print "Job took $run_time seconds\n";


