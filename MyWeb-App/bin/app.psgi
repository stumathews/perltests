#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";


# use this block if you don't need middleware, and only have a single target Dancer app to run here
use MyWeb::App;

MyWeb::App->to_app;

use Plack::Builder;

builder {
    enable 'Deflater';
    MyWeb::App->to_app;
}



=begin comment
# use this block if you want to include middleware such as Plack::Middleware::Deflater

use MyWeb::App;
use Plack::Builder;

builder {
    enable 'Deflater';
    MyWeb::App->to_app;
}

=end comment

=cut

=begin comment
# use this block if you want to include middleware such as Plack::Middleware::Deflater

use MyWeb::App;
use MyWeb::App_admin;

builder {
    mount '/'      => MyWeb::App->to_app;
    mount '/admin'      => MyWeb::App_admin->to_app;
}

=end comment

=cut

