use Person;
use PoliceOfficer;
my $person = Person->new("a","b");

print "the constant is ".Person->GetConstant()."\n"; # Class variable access (shared between all Persons)
print "the first param is ".$person->GetParam1()."\n"; #instance variable access(specific to instance of class)

my $policeOfficer = PoliceOfficer->new("c","d");
print "the first param of police officer is ".$policeOfficer->GetParam1()."\n";
print "the object for police oficer is of type ", ref $policeOfficer,"\n";
$policeOfficer->setParam1("one");
$policeOfficer->setParam3("three");

print "policeOfficer officer param 1 is ", $policeOfficer->GetParam1(), "\n";
print "policeOfficer param 3 is ", $policeOfficer->GetParam3(), "\n";
print "Get person Constant constant via inheritance is ", $policeOfficer->GetConstant(), "\n";
print "PoliceOfficer constant is ", $policeOfficer->GetPoliceConstant(), "\n";
