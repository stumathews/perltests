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

my $verbose = $options{v};
my $colimit = $options{l};

# print arguments used if verbosed mode used
if($verbose) {
	foreach my $opt(keys %options) {
		print "$opt = $options{$opt}\n";
	}
}

#print help if asked to
if($options{h}){
	print "\n";
	print <<EOD;
Usage: perl endofday.pl <options> <company_file>

Options:
 -t : Threads to use concurrently to get ticker's stock data - default is 2
 -d : Delimiter to use in output file eg. ";" (default)
 -o : Output file to send all stock data to eg. "outputfile.csv" default is stocks_date_time.csv
 -r : Region for yahoo query eg. "us"(default)
 -l : Language for yahoo query eg. "en-gb" (default)
 -v : Verbose messages are shown
 -x : eXclude certain companies listed in file eg. "exclude.csv" - one company per line like input
 -l : Length of processing loop i.e end after specified companies are processed (default dont stop until finished)
 -b : Bad resolutions added to exclusions file (must be used in conjunction with specifing an exclude file eg. with -x)
 -p : show name to ticker cache (used to prevent re-lookup of ticker symbols for known companies)
 -g : show saved proGress
 -c : print all Companies.
 
 Examples:  perl endofpday.pl -v companies.csv
            perl endofday.pl -b -x excludefile.csv companies.csv
            perl endofday.pl -d ',' -o 'myoutputfile.csv' companies.csv
            perl endofday.pl -p
 
 Notes: -t > 2 not tested
        if ./endofday.pl is executable, you can pipe in companies to process ie ./endofday.pl | cat companies.csv
EOD
	exit(0);
}

# converts spaces to underscores
sub encode_name {
	my $name = shift @_;
	$name  =~ s/ /_/g;
	return $name;	
}

#converts underscores to spaces
sub decode_name {
	my $name = shift @_;
	$name  =~ s/_/ /g;
	return $name;	
}

# Looks up the company name on the internet to get its corresponding ticker symbol (which is used later to get its stock details)
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

my $count = 0;
# Look up the tickers stock details on the internet
sub ConvertTickerToStock {
	my @args = @_;
	my $ticker = shift @args;
	my $url = "https://query.yahooapis.com/v1/public/yql?q=".
		           "select%20*%20from%20yahoo.finance.quotes%20where%20symbol%20in%20(%22" .$ticker.
			   "%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=";
	my $total = scalar(keys %all);
	my $end_run = time();
	my $start_run = $^T;
	my $run_time = $end_run - $start_run;
	print "Fetching: [$ticker] ",++$count,"/", $total, "(",sprintf("%1d",($count/$total)*100),"%) Elapsed: $run_time secs. ";
	my $json = getJson($url);
	if($json) {
		my $jObj = decode_json($json);
		my $queryResult = $jObj->{'query'}{'results'}{'quote'};
		# Keep track of our progress so far
		$all{$ticker} = $queryResult || undef;
		# print Huge output?
		print Dumper($queryResult) if $verbose;
		return $all{$ticker};
	}
	return undef;
}

my $total_payload = 0;
# Send actual request as HTTP/S
sub getJson {
	my @args = @_;
	my $url = shift @args;
	my $req = HTTP::Request->new(GET => $url);
       $req->header('content-type' => 'application/json');
	my $ua = LWP::UserAgent->new;
        my $resp = $ua->request($req);
		my $headers =  $resp->headers();
		my $content_size = length($resp->content);
		$total_payload+=$content_size;
		print "Recieved: ",sprintf("%1d",$content_size/1024)," Kb Recieve Total:", sprintf("%1d",($total_payload/1024)/1024), " Mb (",sprintf("%1d",$total_payload/1024),"Kb)\n";

        if ($resp->is_success) {
	    return $resp->decoded_content;
        } else {
            print "HTTP GET error code: ", $resp->code, "\n";
            print "HTTP GET error message: ", $resp->message, "\n";
	    return undef;
        }
}

# name of cache of already resolved ticker names from company names
my $cacheFileName = "co2tick.cache";
# name of progress cache 
my $progressCacheFileName = "progress.cache";

my $haveTickerCache = -e $cacheFileName;
my $haveProgressCache = -e $progressCacheFileName;
# the actuual cache of tickers/names
my %resolutionCache;

my $printCache = $options{p};
if($haveTickerCache) {
	#Read in existing file-Cache of ticker to company names to prevent relookup(expensive)
	%resolutionCache = %{ retrieve($cacheFileName) };
	# print the company vs ticker cache is asked
	if($printCache) {
		print "Printing company vs ticker cache...\n";
		my $count = 0;
		while ((my $company, my $ticker) = each(%resolutionCache)) {
			$company = decode_name($company);
			print "cache entry #",$count++, ": Company: $company Ticker --> ",$ticker,"\n";
		}
		exit 0;
	}
}

my $printProgress = $options{g};
if($haveProgressCache) {
	#Read in any progress we've already made before we start processing
	%all = %{ retrieve($progressCacheFileName) };
	#print the progress cache if asked
	if($printProgress) {
		print "Printing progress cache...\n";
		my $count = 0;
		print Dumper(\%all);		
		exit 0;
	}
}

# Ctrl+C event handler will save any progress if interrupted mid-flow...
$SIG{'INT'} = sub {
	print "Abort!\n";
	print "Saving progress...";	
	store(\%all, $progressCacheFileName);
	print "Done.\n";	
	exit 1;	
};

# read in all the companies 
my @companies = <>;

#print companies if asked to, -c
if($options{c}){
	print @companies;
}

#Exclude companies in the exclude file
my $excludeFile = $options{x};
if($excludeFile && -e $excludeFile) {
	print "Using exclude file '$excludeFile'\n";
	open (EXCLUDE, "< $excludeFile") or die "Can't open $excludeFile for read: $!";
	my @lines = <EXCLUDE>;	
	my %exclude;
	print "There are $#lines excludes\n";
	print "There are $#companies companies BEFORE exclude filter\n";
	# exclude from companies those that are in exclude file	
	my %hash;
	@hash{@lines} = ((undef) x @lines);	
	@companies = grep { not exists $hash{$_} } @companies;
	
	print "There are $#companies companies AFTER exclude filter\n";
	close EXCLUDE or die "Cannot close $excludeFile: $!"; 
}


## 
## Main work begins from this point forward.
## 


# process companies as to convert them to tickers, saving any resolved tickers to cache...
my $lineCount = 0;
foreach my $line(@companies) {
	my $company = $line;
	chomp $company; #forget newlines on the ends of company names
	next if !$company;
	my $ticker;

	# We're going to store company names with spaces to underscores so we can have one-worded companies in the cache for easier comparisons and alter lookups
	$company = encode_name($company);
	# Look up ticker for company in the cache first...
	$ticker = $resolutionCache{$company};

	# got a ticker?
	if(!$ticker) { 
		# Nope, so lets try and fetch one oneline for this company...
		$company = decode_name($company);
		print "LIVE convertCompanyToTicker Company:'$company'\n";
		$ticker = ConvertCompanyToTicker($company);
		print ($ticker || "Could not resolved to a ticker symbol.");
		
		my $addbadTickersToExcludeFile = $options{b};
		if($addbadTickersToExcludeFile && $excludeFile && !$ticker) {
			print "Adding bad company, '$company' to exclude file\n";
			open(my $ex, '>>', $excludeFile) or die "Could not open file '$excludeFile' $!";
			print $ex "$company\n";
			close $ex;
		}
		print "\n";		
		next if(!$ticker);
	}else{
		print "CACHE HIT convertCompanyToTicker Company:'$company'\n";
	}
	
	
	# Make a space for this ticker's results...undef means no stock results for this ticker yet
	$all{$ticker} = undef;

	# Put the multiword company name in the hash that tracks company vs ticker names cache
	$company = encode_name($company);
	$resolutionCache{$company} = $ticker;

	# if asked to, stop process after specified set amount of company have been processed.
	last if ($colimit && ($lineCount++ == $colimit));
}

print "Finished Pass one : Resolving company names to tickers\n";
print "Saving results in $cacheFileName\n\n";
store(\%resolutionCache, $cacheFileName);

# now start the fetching of ticker stock data:
my $numThreads = $options{t} || 2; 
my @columns;

# Process the tickers as to convert them to stock details.
# This is currenly entirly handled by Paralell::Iterator's iterate_as_hash function.
my %output = iterate_as_hash({ workers => $numThreads },\&ConvertTickerToStock, \%all);
%all = (%all, %output);

print "Phase 2 Complete: Fetching stock data for tickers\n";
print "Writing all stock data to CSV...\n";

# Write all to CSV as output...
my @now = localtime();
my $timeStamp = sprintf("%04d-%02d-%02d_%02d-%02d-%02d", 
                        $now[5]+1900, $now[4]+1, $now[3],
                        $now[2],      $now[1],   $now[0]);

# Write to output file
open(my $csv, '>', $options{o} || "stocks_$timeStamp.csv");
foreach my $ticker (sort keys %all) {
	my $delim = $options{d} || ";";
	my $stock = $all{$ticker}; 
	
	# Arrange column names
	#Get the first stocks values' order as default column order for all following stocks for csv format
	if(!@columns) { 
		@columns = sort keys(%$stock);
		# Set the order of the first bunch of columns to my preferred selection
		my @preferred = qw(Name Currency Ask Open PreviousClose PercentChange PriceBook Change DaysHigh DaysLow EarningsShare);
		my @newColumnsWithout = grep {!/join("|",@preferred)/} @columns;
		my @reOrder = (@preferred, @newColumnsWithout);
		@columns = @reOrder;
		print $csv join($delim, @reOrder)."\n";
	}
	
	# prepare a line of CSV data...
	my @line;
	#Get data for each column
	foreach my $key(@columns) {
		my $column = $key;
		my $data = $stock->{$key} || "";
		push(@line, $data);
	}
	print $csv join($delim ,@line)."\n";
	@line = undef;
}
close($csv);	
# We've finished and dont need a progress file anymore. Delete it
print "Cleaning up...\n";
unlink $progressCacheFileName;

my $end_run = time();
my $start_run = $^T;
my $run_time = $end_run - $start_run;
print "Job took $run_time seconds\n";


