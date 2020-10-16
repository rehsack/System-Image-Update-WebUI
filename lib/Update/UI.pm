package Update::UI;

use strict;
use warnings;

use Dancer2;
use Update::UI::Backend qw(get_installed_software get_sysupdate_status);

our $VERSION = '0.001';

get '/' => sub {
    template 'index' => {
        'title'            => 'Updater UI - Status',
        'sysupdt_software' => get_installed_software,
        'sysupdt_status'   => get_sysupdate_status,
    };
};

get '/config' => sub {
    template 'config' => {'title' => 'Updater UI - Configuration'};
};

true;
