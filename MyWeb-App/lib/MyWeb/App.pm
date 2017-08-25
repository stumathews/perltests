package MyWeb::App;
use Dancer2;

our $VERSION = '0.1';

get '/' => sub {
    template 'index.tt',{ 'title' => "Stuart's Cool website" };
};

get '/simpleaddition' => sub {
	my %addition = (
		"1+2"=>3, "2+3"=>5, "3+4"=>7, "4+5"=>9, "5+6"=>11, "6+7"=>13, "7+8"=>15,"8+9"=>17		
		);
    template 'simpleaddition.tt', { 
							'title' => "Simple addition",
							'sums' => \%addition,
	};
};

get '/randomaddition' => sub {
	my %randomaddition = (
		"1+2"=>3,
		"2+3"=>5,
		"3+4"=>7,
		"4+5"=>9,
		"5+6"=>11,
		"6+7"=>13,
		"7+8"=>15,
		"8+9"=>17,
		"9+10"=>19,
		"10+11"=>21,		
		"11+12"=>23,
		"12+13"=>27,
		"13+14"=>27,
		"14+15"=>29,
		"15+16"=>31,
		"16+17"=>33,
		"17+18"=>35,
		"18+19"=>37,
		"19+20"=>39,					
		"8+9"=>17
		);
    template 'simpleaddition.tt', { 
							'title' => "Random addition",
							'sums' => \%randomaddition,
	};
};

get '/hardaddition' => sub {
	my %randomaddition = (
		"6+3"=>9,
		"7+2"=>9,
		"4+7"=>11,
		"9+2"=>11,
		"8+3"=>11,
		"7+5"=>12,
		"9+3"=>12,
		"8+4"=>12,
		"9+4"=>13,
		"8+5"=>13,		
		"8+6"=>14,
		"9+5"=>14,
		"9+7"=>16,
		"9+6"=>15		
		);
    template 'simpleaddition.tt', { 
							'title' => "Random addition",
							'sums' => \%randomaddition,
	};
};

true;
