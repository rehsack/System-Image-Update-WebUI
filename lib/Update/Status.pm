package Update::Status;

use strict;
use warnings;

use File::stat;
use Unix::Statgrab qw(get_process_stats);

use Moo;
use namespace::clean;

extends "System::Image::Update";

# use sysimg_update config, not hp2sm - for this class
sub _build_config_prefix { "sysimg-update" }

# avoid automatic actions taken in wrong context
sub _trigger_recent_update { }

# XXX for debugging purposes we might want a singleton here ...
sub _trigger_log_adapter { }

around BUILDARGS => sub {
    my $next   = shift;
    my $self   = shift;
    my $params = $self->$next(@_);
    exists $params->{status} and delete $params->{status};
    $params;
};

around collect_savable_config => sub {
    my $next                   = shift;
    my $self                   = shift;
    my $collect_savable_config = $self->$next(@_);
    $self->has_status and $collect_savable_config->{status} = $self->status;
    $collect_savable_config;
};

sub is_running
{
    -f "/tmp/sysimg-update.once"     or return;
    -d $ENV{SYSTEM_IMAGE_UPDATE_DIR} or return;
    -w $ENV{SYSTEM_IMAGE_UPDATE_DIR} or return;
    `s6-svstat /etc/s6/service/system-image-update` =~ m/up\s\(pid\s(\d+)\)/;
}

has ready => (
    is      => "lazy",
    builder => 1,
);

sub _build_ready
{
    my $self = shift;
    my ($pid) = ($self->is_running);
    $pid or return 0;

    my $proc_list = get_process_stats();
    my ($sysimg_update) = (grep { $proc_list->pid($_) == $pid } (0 .. $proc_list->entries() - 1));
    $sysimg_update                                                                  or return 0;
    -f $self->savable_configfile                                                    or return 0;
    $proc_list->start_time($sysimg_update) < stat($self->savable_configfile)->mtime or return 0;
    1;
}

sub save_config_and_restart
{
    my $self = shift;
    $self->save_config;
    system("s6-svc -t /etc/s6/service/system-image-update");
}

1;
