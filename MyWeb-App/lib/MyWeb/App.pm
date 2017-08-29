package MyWeb::App;
use Dancer2;

our $VERSION = '0.1';

get '/' => sub {
    template 'index.tt',{ 'title' => "Stuart's Cool website" };
};

get '/consecutiveaddition1' => sub {
	my %addition = ("1+2"=>3, "2+3"=>5, "3+4"=>7, "4+5"=>9, "5+6"=>11, "6+7"=>13, "7+8"=>15,"8+9"=>17, "9+10"=>19);
    template 'addition.tt', { 
							'title' => "Consecutive addition level 1",
							'sums' => \%addition,
	};
};

get '/consecutiveaddition2' => sub {
	my %randomaddition = ("1+2"=>3, "2+3"=>5,"3+4"=>7,"4+5"=>9,"5+6"=>11,"6+7"=>13,"7+8"=>15,"8+9"=>17,"9+10"=>19,
		"10+11"=>21,"11+12"=>23,"12+13"=>27,"13+14"=>27,"14+15"=>29,"15+16"=>31,"16+17"=>33,"17+18"=>35,"18+19"=>37,
		"19+20"=>39,"8+9"=>17 );
    template 'addition.tt', { 
							'title' => "Consecutive addition level 2",
							'sums' => \%randomaddition,
	};
};

get '/hardaddition' => sub {
	my %randomaddition = ( "6+3"=>9, "7+2"=>9, "4+7"=>11,"9+2"=>11, "8+3"=>11, "7+5"=>12, "9+3"=>12,"8+4"=>12, "9+4"=>13,
		"8+5"=>13, "8+6"=>14,"9+5"=>14, "9+7"=>16, "9+6"=>15);
    template 'addition.tt', { 
							'title' => "Random addition",
							'sums' => \%randomaddition,
	};
};

get '/randomaddition/:upto' => sub {
	my %sums = ();
	foreach my $index (1..int(route_parameters->get('upto'))){
		my $term1 = int(rand(100));
		my $term2 = int(rand(100));
		my $string = $term1."+".$term2;
		$sums{$string} = $term1+$term2;
	}
    template 'addition.tt', { 
							'title' => "Random addition",
							'sums' => \%sums,
	};
};

get '/alphabet' => sub {
	my %alphabet = ( "A"=>1, "B"=>2, "C"=>3, "D"=>4, "E"=>5, "F"=>6, "G"=>7, "H"=>8, "I"=>9,
					 "J"=>10,"K"=>11,"L"=>12,"M"=>13,"N"=>14,"O"=>15, "P"=>16,"Q"=>17,"R"=>18,"S"=>19,
		"T"=>20,"U"=>21,"V"=>22,"W"=>23,"X"=>24,"Y"=>25,"Z"=>26);
    template 'alphabet.tt', { 
							'title' => "Alphabet",
							'letters' => \%alphabet,
	};
};
get '/alphabetnumbers' => sub {
	my %alphabet = ( "A"=>1, "B"=>2, "C"=>3, "D"=>4, "E"=>5, "F"=>6, "G"=>7, "H"=>8, "I"=>9,
					 "J"=>10,"K"=>11,"L"=>12,"M"=>13,"N"=>14,"O"=>15, "P"=>16,"Q"=>17,"R"=>18,"S"=>19,
		"T"=>20,"U"=>21,"V"=>22,"W"=>23,"X"=>24,"Y"=>25,"Z"=>26);
    template 'alphabetnumbers.tt', { 
							'title' => "Alphabet",
							'letters' => \%alphabet,
	};
};

get '/months' => sub {
	my %alphabet = ( "JAN"=>1, "FEB"=>2, "MAR"=>3, "AUG"=>4, "MAY"=>5, "JUNE"=>6, "JULY"=>7, "APR"=>8, "SEPT"=>9,"OCT"=>10,"NOV"=>11,"DEC"=>12,"JULY"=>7,"JUNE"=>6,"MAY"=>5,"AUG"=>4,"APR"=>8,"JULY"=>7,
	"MAY"=>5);
    template 'alphabet.tt', { 
							'title' => "Alphabet",
							'letters' => \%alphabet,
	};
};

get '/monthnumbers' => sub {
	my %alphabet = ( "JAN"=>1, "FEB"=>2, "MAR"=>3, "AUG"=>4, "MAY"=>5, "JUNE"=>6, "JULY"=>7, "APR"=>8, "SEPT"=>9,"OCT"=>10,"NOV"=>11,"DEC"=>12,"JULY"=>7,"JUNE"=>6,"MAY"=>5,"AUG"=>4,"APR"=>8,"JULY"=>7,
	"MAY"=>5);
    template 'monthnumbers.tt', { 
							'title' => "Alphabet",
							'letters' => \%alphabet,
	};
};

true;
