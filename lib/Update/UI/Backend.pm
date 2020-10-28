package Update::UI::Backend;

use strict;
use warnings;

use parent 'Exporter';

use Update::Status ();

use File::Basename qw(basename);
use File::Find::Rule ();
use File::Slurper qw(read_text);
use Unix::Statgrab qw(get_process_stats);

our @EXPORT_OK = qw(get_installed_software get_sysupdate_status get_sysupdate_config set_sysupdate_config);

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

sub get_sysupdate_status
{
    Update::Status->is_running or return "n/a";

    my $us = eval { Update::Status->new(); };
    $us or return "Update::Status initialization failed: '$@'";

    my $status = "idle";
    $us->has_recent_update and $status = "available";
    $us->status eq "prove" and $status = "downloading";
    $us->has_recent_update
      and -f $us->download_image
      and $us->download_sums->{size} == stat($us->download_image)->size
      and $status = "proved";
    my $proc_list = get_process_stats();
    grep { /flash-device/ } map { $proc_list->process_name($_) } (0 .. $proc_list->entries() - 1) and $status = "applying";

    return $status;
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
