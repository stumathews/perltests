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

my %ticker_data = ();
my %company_tickers;
my %options=();

getopts("abcd:ghil:o:pr:st:mvx:", \%options);

my $verbose = $options{v};
my $colimit = $options{l};
my $cacheFileName = "co2tick.cache";
my $haveTickerCache = -e $cacheFileName;
my $printCache = $options{p};
my $numThreads = $options{t} || 2; 


if($verbose) {
    # print arguments used if verbosed mode used
	foreach my $opt(keys %options) {
		print "$opt = $options{$opt}\n";
	}
}

if($options{h}){
    #print help if asked to
	print "\n";
	print <<EOD;
Usage: perl endofday.pl <options> <company_file>

Options:
 -t <num>    : Threads to use concurrently to get ticker's stock data - default is 2
 -d <delim>  : Delimiter to use in output file eg. ";" (default)
 -o <file>   : Output file to send all stock data to eg. "outputfile.csv" default is stocks_date_time.csv
 -r <region> : Region for yahoo query eg. "us"(default)
 -l <lang>   : Language for yahoo query eg. "en-gb" (default)
 -v          : Verbose messages are shown
 -x <file>   : eXclude certain companies listed in file eg. "exclude.csv" - one company per line like input
 -l          : Length of processing loop i.e end after specified companies are processed (default dont stop until finished)
 -b          : Bad resolutions added to exclusions file (must be used in conjunction with specifing an exclude file eg. with -x)
 -p          : show name to ticker cache (used to prevent re-lookup of ticker symbols for known companies)
 -g          : show saved proGress
 -c          : print all Companies.
 -s          : skip company to ticker resolution - use only known tickers
 -e          : introduce random sleep to confuse spam detectors
 -m          : print cache misses
 -i          : print cache hits
 -a          : print all diagnostics
 
 Examples:  perl endofpday.pl -v companies.csv
            perl endofday.pl -b -x excludefile.csv companies.csv
            perl endofday.pl -d ',' -o 'myoutputfile.csv' companies.csv
            perl endofday.pl -p
 
 Notes: -t > 2 not tested
        if ./endofday.pl is executable, you can pipe in companies to process ie ./endofday.pl | cat companies.csv
EOD
	exit(0);
}

sub encode_name {
    # converts spaces to underscores
	my $name = shift @_;
	$name  =~ s/ /_/g;
	return $name;	
}

sub decode_name {
    #converts underscores to spaces
	my $name = shift @_;
	$name  =~ s/_/ /g;
	return $name;	
}

sub ConvertEncodedCompanyToTicker {    
    # Looks up the company name on the internet to get its corresponding ticker symbol 
    # (which is used later to get its stock details)
	my @args = @_;		
	my $encoded_company = shift @args;	
	my $decoded_company = decode_name($encoded_company);
	my $company_uri =  uri_encode($decoded_company);	
	my $region = shift @args || ($options{r} || "us");
	my $lang = shift @args ||  ($options{l} || "en-gb");
	print "LIVE ConvertEncodedCompanyToTicker : $decoded_company\n" if $options{a};
	my $json = getJson("http://d.yimg.com/aq/autoc?query=$company_uri&region=$region&lang=$lang");	
	if ($json) {
	    my $jObj = decode_json($json);
	    my @queryResult = @{$jObj->{'ResultSet'}{'Result'}};	    
	    my $gotResult = undef;
		for my $var (@queryResult) {  
			$gotResult = 1;
            my $ticker = $var->{symbol};            
            print "company = '$decoded_company' ticker --> $ticker\n";
		    return $ticker;
	    }
		if(!$gotResult){
			print "No ticker symbol could be found for $decoded_company\n";
		}
	}
	return undef;
}

# Look up the tickers stock details on the internet
sub ConvertTickerToStock {

	my @args = @_;
	my $ticker = shift @args;
	my $url = "https://query.yahooapis.com/v1/public/yql?q=".
		           "select%20*%20from%20yahoo.finance.quotes%20where%20symbol%20in%20(%22" .$ticker.
			   "%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callack=";	
	print $url,"\n" if $options{a};
	my $json = getJson($url);
	if($json) {
		my $jObj = decode_json($json);		
		if($jObj && $jObj->{'query'} && $jObj->{'query'}{'results'} && $jObj->{'query'}{'results'}{'quote'}) {		
			my $queryResult = $jObj->{'query'}{'results'}{'quote'};
			my $Name = $queryResult->{'Name'} || "none" ;
			my $Currency = $queryResult->{'Currency'} || "none" ; 
			my $Ask = $queryResult->{'Ask'} || "none" ; 
			my $Open = $queryResult->{'Open'} || "none" ; 
			my $PreviousClose = $queryResult->{'PreviousClose'} || "none" ; 
			my $PercentChange = $queryResult->{'PercentChange'} || "none" ;
			my $PriceBook = $queryResult->{'PriceBook'} || "none" ; 
			my $Change = $queryResult->{'Change'} || "none" ; 
			my $DaysHigh  = $queryResult->{'DaysHigh'} || "none" ;
			my $DaysLow = $queryResult->{'DaysLow'} || "none" ;
			my $EarningsShare = $queryResult->{'EarningsShare'} || "none" ;		
			print sprintf("%36s %5s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s\n",$Name,$Currency,$Ask,$Open,$PreviousClose,$PercentChange,$PriceBook, $Change,$DaysHigh,$DaysLow,$EarningsShare, $ticker);
			print Dumper($queryResult) if $options{a};
			print "type is ", ref($queryResult),"\n" if $options{a};
			return $queryResult
		}
	}  
	return undef;
}


# Send actual request as HTTP/S
sub getJson {
	my @args = @_;
	my $url = shift @args;	
	my $req = HTTP::Request->new(GET => $url);
       $req->header('content-type' => 'application/json');
	my $ua = LWP::UserAgent->new;
	#introduce random sleep.
    sleep rand($options{t}) if $options{e};
    my $resp = $ua->request($req);        
    if ($resp->is_success) { 
		print "Dump decoded_conent:", $resp->decoded_content, "\n" if $options{a};
        return $resp->decoded_content;
    } else {
        print "HTTP GET error code: ", $resp->code, "\n";
        print "HTTP GET error message: ", $resp->message, "\n";
        return undef;
    }
}


if($haveTickerCache) {
	#Read in existing file-Cache of ticker to company names to prevent relookup(expensive)
	%company_tickers = %{ retrieve($cacheFileName) };
	# print the company vs ticker cache is asked
	if($printCache) {
		print "Printing company vs ticker cache...\n";
		my $count = 0;
		my %hits = ();
		my %misses = ();

		while ((my $company, my $ticker) = each(%company_tickers)) {
			$company = decode_name($company);
            if($ticker){
                $hits{$company} = $ticker;
                print "cache entry #",$count++, ": Company: $company Ticker --> ",$ticker,"\n";
            } else {
                $misses{$company} = undef;
                print "cache entry #",$count++, ": Company: $company Ticker --> MISS","\n";
            }
		}
		
		if($options{m})
		{
            print "Cache misses:\n";
            print map { "miss $_\n"} sort keys %misses;
		}
		if($options{i})
		{
            print "Cache hits:\n";
            print map { "hit $_\n"} sort keys %hits;
		}
		print "total hits: ",scalar(keys %hits), ", total misses: ",scalar(keys %misses),"\n";
		exit 0;
	}
}

# read in all the companies 
my @companies = <>;

#remove linefeed and carrige returns
s/\r|\n//g for @companies;

# We like companies without spaces so encode them
@companies = map { encode_name($_)} @companies;


if($options{c}){
    #print companies if asked to, -c
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

# add companies to cache if the cache doesn't have the company loaded from file
foreach my $company (@companies) {
	if(not exists $company_tickers{$company})
	{
		print "Adding new company to cache '$company'\n";
		$company_tickers{$company} = undef;
	}
}

my %company_ticker = (); 
my %company_noticker = ();
while( my( $company, $ticker ) = each %company_tickers ){
    $company_ticker{$company} = $ticker if $ticker; #cache hits
    $company_noticker{$company} = $ticker if !$ticker; #cache misses
}

print "sending in only ", scalar(keys %company_noticker), " companies for resolution\n";
print scalar(keys %company_ticker), " have already been found via cache\n";
print "both combined = ", scalar(keys %company_tickers),"\n";

if(!$options{s}){ #skip name->ticker resolution?
    my %output1 = iterate_as_hash({ workers => $numThreads },\&ConvertEncodedCompanyToTicker, \%company_noticker);
    %company_tickers = (%company_ticker, %output1);
}


print "Finished Pass one : Resolving company names to tickers\n";
print "Saving results in $cacheFileName\n\n";
store(\%company_tickers, $cacheFileName);
    
print Dumper(%company_tickers) if $options{a};

#Set all tickers to look for to undef stock prices ie tbd
while( my($c, $t) = each %company_tickers ){            
	$ticker_data{$t} = undef if $t;	
}

my %output = iterate_as_hash({ workers => $numThreads },\&ConvertTickerToStock, \%ticker_data);
%ticker_data = (%ticker_data, %output);

print Dumper(%ticker_data) if $options{a};

print "Phase 2 Complete: Fetching stock data for tickers\n";
print "Writing all stock data to CSV...\n";

# Write all to CSV as output...
my @now = localtime();
my $timeStamp = sprintf("%04d-%02d-%02d_%02d-%02d-%02d", 
                        $now[5]+1900, $now[4]+1, $now[3],
                        $now[2],      $now[1],   $now[0]);

my @columns;
# Write to output file
open(my $csv, '>', $options{o} || "stocks_$timeStamp.csv");
foreach my $ticker (sort keys %ticker_data) {
	my $delim = $options{d} || ";";
	next if !$ticker_data{$ticker};
	my $stock = $ticker_data{$ticker}; 
	print "### typeof =",ref($stock),Dumper($stock),"\n" if $options{a};
	# Arrange column names
	# Get the first stocks values' order as default column order for all following stocks for csv format
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


my $end_run = time();
my $start_run = $^T;
my $run_time = $end_run - $start_run;
print "Job took $run_time seconds\n";
