package Update::UI;

use strict;
use warnings;

use Dancer2;
use Update::UI::Backend qw(get_installed_software get_sysupdate_status get_sysupdate_config set_sysupdate_config);

our $VERSION = '0.001';

get '/' => sub {
    template 'index' => {
        'title'            => 'Updater UI - Status',
        'sysupdt_software' => get_installed_software,
        'sysupdt_status'   => get_sysupdate_status,
    };
};

get '/config' => sub {
    template 'config' => {
        'title'          => 'Updater UI - Configuration',
        'sysupdt_config' => get_sysupdate_config
    };
};

use Data::Dumper;

post '/apply/config' => sub {
    my %cfg = (
        host              => body_parameters->get('host'),
        path              => body_parameters->get('path'),
        manifest_basename => body_parameters->get('manifest_basename'),
        username          => body_parameters->get('username'),
        password          => body_parameters->get('password'),
    );

    set_sysupdate_config(\%cfg);

    template 'config' => {
        'title'          => 'Updater UI - Configuration (Saved)',
        'sysupdt_config' => get_sysupdate_config
    };
};

true;
