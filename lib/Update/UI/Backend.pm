package Update::UI::Backend;

use strict;
use warnings;

use parent 'Exporter';

use Update::Status ();

use File::Basename qw(basename);
use File::Find::Rule ();
use File::Slurper qw(read_text);
use Unix::Statgrab qw(get_process_stats);

our @EXPORT_OK = qw(get_installed_software get_sysupdate_status);

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
    $us or return "error: '$@'";

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

1;
