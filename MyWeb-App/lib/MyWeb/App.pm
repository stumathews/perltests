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

true;
