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

#Global store of all tickers and their stock details
my %all;
my %options=();
getopts("ht:d:o:r:l:vx:bpgc", \%options);
# -t 4, -d "delimiter" -o "outputfile.csv" -r "us" -l "en-gb" -v -x "exclude.csv" -l 5(co limit)
# -b : add bad resolutions to explcusions file (must be with -x)
# -p show cache
# -g show progress
# -c print companies

my $verbose = $options{v};
my $colimit = $options{l};

# print arguments used
if($verbose) {
	foreach my $opt(keys %options) {
		print "$opt = $options{$opt}\n";
	}
}

#print help
if($options{h}){
	print "./endofday.pl -t <numThreads> -d <delimiter> -o <ouputfile> -r <region> -l <language> -x <exclude file> -l <limit> -v\n";
	exit(0);
}

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
		$all{$ticker} = $queryResult || undef;
		# print Huge output?
		print Dumper($queryResult);
		return $all{$ticker};
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

#Read in Cache of ticker to company names to prevent relookup(expensive)
my $cacheFileName = "co2tick.cache";
my $progressCacheFileName = "progress.cache";
my $haveTickerCache = -e $cacheFileName;
my $haveProgressCache = -e $progressCacheFileName;
my %resolutionCache;

my $printCache = $options{p};
if($haveTickerCache) {
	%resolutionCache = %{ retrieve($cacheFileName) };
	# print the company vs ticker cache is asked
	if($printCache) {
		print "Printing company vs ticker cache...e\n";
		my $count = 0;
		while ((my $company, my $ticker) = each(%resolutionCache)) {
			$company = decode_name($company);
			print "cache hit #",$count++, ": Company: $company Ticker -->",$ticker,"\n";
		}
		exit 0;
	}
}
my $printProgress = $options{g};
if($haveProgressCache) {
	%all = %{ retrieve($progressCacheFileName) };
	#print the progress cache if asked
	if($printProgress) {
	print "Printing progress cache...\n";
		my $count = 0;
		print Dumper(\%all);
		
		exit 0;
	}
}

$SIG{'INT'} = sub {
	if($options{v}){
		print "Saving progress...\n";
	}
	store(\%all, $progressCacheFileName);
	exit 1;
	
};

# read in all the companies 
my @companies = <>;
my $excludeFile = $options{x};

#print companies if asked
if($options{c}){
	print @companies;
	print "END"
}

#and exclude the ones in the exclude file
if($excludeFile && -e $excludeFile) {
	print "using exclude file '$excludeFile'\n" if($verbose);
	open (EXCLUDE, "< $excludeFile") or die "Can't open $excludeFile for read: $!";
	my @lines = <EXCLUDE>;	
	my %exclude;
	print "There are $#lines excludes\n" if $options{v};
	print "There are $#companies companies before exclude filter\n" if $options{v};
	# exclude from companies those that are in exclude file	
	 my %hash;
	@hash{@lines} = ((undef) x @lines);	
	@companies = grep { not exists $hash{$_} } @companies;
	
	print "There are $#companies companies After exclude filter\n" if $options{v};	
	close EXCLUDE or die "Cannot close $excludeFile: $!"; 
}

# process companies as to convert themto tickers...
my $lineCount = 0;
foreach my $line(@companies) {
	my $company = $line;
	chomp $company; #forget newlines
	next if !$company;
	my $ticker;

	# We're going to store company names with space to underscores so we can have one-worded companies in the cache
	$company = encode_name($company);
	$ticker = $resolutionCache{$company};

	# get a ticker	
	if(!$ticker) { 
		$company = decode_name($company);
		print "LIVE convertCompanyToTicker Company:'$company'\n";
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
	print "CACHE convertCompanyToTicker Company:'$company'\n";
	# Make a space for this ticker's results...which we dont have yet...
	$all{$ticker} = undef;

	# Put the multiword company name in the hash that tracks all the results
	$company = encode_name($company);
	$resolutionCache{$company} = $ticker;

	# Stop process after a set mount if asked to
	last if ($colimit && ($lineCount++ == $colimit));
}

#persist the cache of company to ticker hashes for future lookups...
store(\%resolutionCache,$cacheFileName);

my $numThreads = $options{t} || 2; 
my @columns;

# Process the tickers as to convert them to stock details.
my %output = iterate_as_hash({ workers => $numThreads },\&ConvertTickerToStock, \%all);
%all = (%all, %output);

# Write all to CSV as output...
my @now = localtime();
my $timeStamp = sprintf("%04d%02d%02d%02d%02d%02d", 
                        $now[5]+1900, $now[4]+1, $now[3],
                        $now[2],      $now[1],   $now[0]);
open(my $csv, '>', $options{o} || "stocks_$timeStamp.csv");
foreach my $ticker (sort keys %all) {
	my $delim = $options{d} || ";";
	my $stock = $all{$ticker}; 
	
	#Get the first stocks values' order as default column order for all following stocks for csv format
	if(!@columns) { 
		@columns = sort keys(%$stock);
		my @preferred = qw(Name Currency Ask Open PreviousClose PercentChange PriceBook Change DaysHigh DaysLow EarningsShare);
		my @newColumnsWithout = grep {!/join("|",@preferred)/} @columns;
		my @reOrder = (@preferred, @newColumnsWithout);
		@columns = @reOrder;
		print $csv join($delim, @reOrder)."\n";
	}
	my @line;
        
	foreach my $key(@columns) {
		my $column = $key;
		my $data = $stock->{$key} || "";
		push(@line, $data);
	}
	print $csv join($delim ,@line)."\n";
	@line = undef;
}
close($csv);	
# We've finished and dont need a progress file anymore.
unlink $progressCacheFileName;

my $end_run = time();
my $start_run = $^T;
my $run_time = $end_run - $start_run;
print "Job took $run_time seconds\n";


