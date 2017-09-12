package Person;

# Constructor, by convetion called new()
sub new {

	#first parameter to constructor is the name of its class used to call the new() function
	# normally this is called via Person->new which is a class method and thus the first param of all class
	# methods is silently the name of the class followed by any oprands passed additionally to constructor
	# ie class name would be Dog of invoked as Dog->new or Person if invoked as Person->new
	my $class = shift;
	print "Class of person constructor is ", $class, "\n";

	#anonymous hash reference
	my $self = {}; 

	# Data members (internal)
	$self->{"param1"} = shift;
	$self->{"param2"} = shift;
	print "param1 is $self->{'param1'}\n";
	print "param2 is $self->{'param2'}\n";

	# For constructor inheritance, return the reference as the class the constructor was called on.
	# eg. $self will be turned into a reference to a class of type $class, namely og type Person as above Person->new [person used]
	bless($self, $class);
	return $self;
}

# Destructor
sub DESTROY {

}

# Typical class method - no use of underlying object reference - can only be called as Person->GetConstant not personInst->GetConstant
sub GetConstant {
	shift;
	return "9000000";
}

# instance method can access itself using first param which represents the underlying object
sub GetParam1 {
	my $self = shift;
	return $self->{"param1"};
}

# Must always return true for a module
return 1;
