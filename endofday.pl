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
my %all = ();

# the actuual cache of tickers/names
my %company_tickers;

my %options=();
getopts("ht:d:o:r:l:vx:bpgcsmi", \%options);

my $verbose = $options{v};
my $colimit = $options{l};
my $cacheFileName = "co2tick.cache";
my $haveTickerCache = -e $cacheFileName;
my $printCache = $options{p};
my $numThreads = $options{t} || 2; 

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
 -s : skip company to ticker resolution - use only known tickers
 -e : introduce random sleep to confuse spam detectors
 -m : print cache misses
 -i - print cache hits
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
sub ConvertEncodedCompanyToTicker {    
	my @args = @_;		
	my $encoded_company = shift @args;	
	my $decoded_company = decode_name($encoded_company);
	my $company_uri =  uri_encode($decoded_company);	
	my $region = shift @args || ($options{r} || "us");
	my $lang = shift @args ||  ($options{l} || "en-gb");
	#print "LIVE ConvertEncodedCompanyToTicker : $decoded_company\n";
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
			print "No data received for $decoded_company\n";
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
			   "%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=";	
	#print $url,"\n" if $verbose;	
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
			##print Dumper($queryResult) if $verbose;
			#print "type is ", ref($queryResult),"\n";
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
		#print "Dump decoded_conent:", $resp->decoded_content, "\n";
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

# add companies to cache if the cache doesn't have the company loaded from file
foreach my $company (@companies) {
	if(not exists $company_tickers{$company})
	{
		print "Adding new company to cache '$company'\n";
		$company_tickers{$company} = undef;
	}
}

my %defined = ();
my %undefined = ();
while( my( $company, $ticker ) = each %company_tickers ){
    $defined{$company} = $ticker if $ticker; #cache hits
    $undefined{$company} = $ticker if !$ticker; #cache misses
}

print "sending in only ", scalar(keys %undefined), " companies for resolution\n";
print scalar(keys %defined), " have already been found via cache\n";
print "both combined = ", scalar(keys %company_tickers),"\n";
if(!$options{s}){
    #Pass one: Get all known company tickers and update the company_tickers value as ticker symbol
    my %output1 = iterate_as_hash({ workers => $numThreads },\&ConvertEncodedCompanyToTicker, \%undefined);
    %company_tickers = (%defined, %output1);
}


print "Finished Pass one : Resolving company names to tickers\n";
print "Saving results in $cacheFileName\n\n";
store(\%company_tickers, $cacheFileName);
    
	#print Dumper(%company_tickers); exit 1;

while( my($c, $t) = each %company_tickers ){            
	$all{$t} = undef if $t;	
}


#Pass 2: Process the tickers as to convert them to stock details.
my %output = iterate_as_hash({ workers => $numThreads },\&ConvertTickerToStock, \%all);
%all = (%all, %output);

print Dumper(%all);


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
foreach my $ticker (sort keys %all) {
	my $delim = $options{d} || ";";
	next if !$all{$ticker};
	my $stock = $all{$ticker}; 
	print "### typeof =",ref($stock),Dumper($stock),"\n";
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


my $end_run = time();
my $start_run = $^T;
my $run_time = $end_run - $start_run;
print "Job took $run_time seconds\n";
