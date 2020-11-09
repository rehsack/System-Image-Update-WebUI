package Update::UI::Backend;

use strict;
use warnings;

use parent 'Exporter';

use Update::Status ();

use File::Basename qw(basename);
use File::Find::Rule ();
use File::Slurper qw(read_text);
use Unix::Statgrab qw(get_process_stats);

our @EXPORT_OK = qw(get_installed_software get_sysupdate_status set_sysupdate_status get_sysupdate_config set_sysupdate_config);

use experimental 'switch';

sub get_installed_software
{
    my $installed_sw = {};
    -d $ENV{RECORD_INSTALLED_DIR} or return $installed_sw;
    my @found_sw = File::Find::Rule->file()->in($ENV{RECORD_INSTALLED_DIR});
    foreach my $f (@found_sw)
    {
        my $v = read_text($f);
        chomp $v;
        my $k = basename($f);
        $installed_sw->{$k} = $v;
    }

    return $installed_sw;
}

sub _get_us_status
{
    my $us = shift;

    my $status = "idle";
    $us->has_recent_update    and $status = "available";
    $us->status eq "download" and $status = "downloading";
    $us->status eq "prove"    and $status = "downloading" and $us->prove;
    $us->has_verified_update  and $status = "proved";
    my $proc_list = get_process_stats();
    grep { /flash-device/ } map { $proc_list->process_name($_) } (0 .. $proc_list->entries() - 1) and $status = "applying";

    return $status;
}

sub get_sysupdate_status
{
    Update::Status->is_running or return "n/a";

    my $us = eval { Update::Status->new(); };
    unless ($us)
    {
        printf STDERR "set_sysupdate_status: error initializing Update::Status: '%s'\n", $@;
        return "Update::Status initialization failed: '$@'";
    }

    return _get_us_status($us);
}

my %set_on_action = (
    Scan     => "scan",
    Download => "download",
    Install  => "apply",
);

sub set_sysupdate_status
{
    my $cfg = shift;
    unless ($cfg->{action})
    {
        printf STDERR "set_sysupdate_status: Missing parameter 'action'\n";
        return;
    }

    my $us = eval { Update::Status->new(); };
    unless ($us)
    {
        printf STDERR "set_sysupdate_status: error initializing Update::Status: '%s'\n", $@;
        return;
    }

    my $status = _get_us_status($us);

    given ($cfg->{action})
    {
        when ("Scan")
        {
            if ($us->ready)
            {
                $us->status("scan");
            }
            else
            {
                printf STDERR "set_sysupdate_status: Can't scan - service isn't ready\n";
                return;
            }
        }
        when ("Download")
        {
            if ($us->ready and $us->has_recent_update and $status eq "available")
            {
                $us->status("download");
            }
            else
            {
                printf STDERR "set_sysupdate_status: Can't download - no recent update available\n";
                return;
            }
        }
        when ("Apply")
        {
            if ($us->ready and $status eq "proved")
            {
                $us->status("apply");
            }
            else
            {
                printf STDERR "set_sysupdate_status: Can't apply - no verified update available\n";
                return;
            }
        }
        default { }
    }

    $us->save_config_and_restart;

    return;
}

sub get_sysupdate_config
{
    my $us = eval { Update::Status->new(); };
    $us or return {error => "Update::Status initialization failed: '$@'"};

    my %cfg = (
        host              => $us->update_server,
        path              => $us->update_path,
        manifest_basename => $us->update_manifest_basename,
        ($us->has_http_user   and $us->http_user ne $us->computed_http_cred   ? (username => $us->http_user)   : ()),
        ($us->has_http_passwd and $us->http_passwd ne $us->computed_http_cred ? (password => $us->http_passwd) : ()),
    );

    return \%cfg;
}

sub set_sysupdate_config
{
    my $cfg = shift;

    my $us = eval { Update::Status->new(); };
    $us or return "error: '$@'";

    $cfg->{host} ne $us->update_server                         and $us->update_server($cfg->{host});
    $cfg->{path} ne $us->update_path                           and $us->update_path($cfg->{path});
    $cfg->{manifest_basename} ne $us->update_manifest_basename and $us->update_manifest_basename($cfg->{manifest_basename});
    defined $cfg->{username} and $cfg->{username} ne $us->http_user   and $us->http_user($cfg->{username});
    defined $cfg->{password} and $cfg->{password} ne $us->http_passwd and $us->http_passwd($cfg->{password});

    $us->save_config_and_restart;

    return;
}

1;
