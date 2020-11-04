package Update::UI;

use strict;
use warnings;
use v5.24;

use Dancer2;
use Update::UI::Backend (qw(get_installed_software), qw(get_sysupdate_status set_sysupdate_status),
    qw(get_sysupdate_config set_sysupdate_config));

our $VERSION = '0.001';

my %sysupdt_actions = (
    "idle" => {
        action  => "Scan",
        enabled => 1
    },
    "available" => {
        action  => "Download",
        enabled => 1
    },
    "downloading" => {
        action  => "Be patient",
        enabled => 0
    },
    "proved" => {
        action  => "Apply",
        enabled => 1
    },
    "applying" => {
        action  => "Be patient",
        enabled => 0
    },
);
my %sysupdt_error_action = (
    action  => "Scan",
    enabled => 1
);

get '/' => sub {
    my $sysupdt_status = get_sysupdate_status;
    my $sysupdt_action = $sysupdt_actions{$sysupdt_status};
    $sysupdt_action //= \%sysupdt_error_action;
    template 'index' => {
        'title'   => 'Updater UI - Status',
        'refresh' => {
            timeout => 20,
            url     => '/'
        },
        'sysupdt_software' => get_installed_software,
        'sysupdt_status'   => $sysupdt_status,
        'sysupdt_action'   => $sysupdt_action,
    };
};

post '/apply/status' => sub {
    my $action = body_parameters->get('action');

    set_sysupdate_status({action => $action});

    redirect '/';
};

get '/config' => sub {
    template 'config' => {
        'title'   => 'Updater UI - Configuration',
        'refresh' => {
            timeout => 20,
            url     => '/config'
        },
        'sysupdt_config' => get_sysupdate_config
    };
};

post '/apply/config' => sub {
    my %cfg = (
        host              => body_parameters->get('host'),
        path              => body_parameters->get('path'),
        manifest_basename => body_parameters->get('manifest_basename'),
        username          => body_parameters->get('username'),
        password          => body_parameters->get('password'),
    );

    set_sysupdate_config(\%cfg);

    redirect '/config';
};

true;
