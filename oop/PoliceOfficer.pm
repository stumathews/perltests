package PoliceOfficer;

use Person;

# Declare that this package/class IS A Person
@ISA = qw(Person);

my $POLICE_CONSTANT = 10000;

sub new {
	# effectvely make a new Person and then bless it as a PoliceOfficer object(self)
	my $self = Person->new(@_[1 .. $#_]);
	bless($self);
	return $self;
}

# * inherits GetParam1()

# * as GetConstant() is a class variable its accessible through PoliceOfficer->GetConstant();


# new specialized PoliceOfficer instance methods
sub setParam1 {
	my $self = shift;
	$self->{"param1"} = shift;
}

sub setParam3 {
	my $self = shift;
	$self->{"param3"} = shift;

}
sub GetParam3 {
	return (shift)->{"param3"};
}

# new Police Officer class method(becase it doesnt; use get a underlying $self via first param to function as its called from a Class
sub GetPoliceConstant
{
	return $POLICE_CONSTANT;
}



return 1;
