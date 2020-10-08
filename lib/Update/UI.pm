package Update::UI;
use Dancer2;

our $VERSION = '0.1';

get '/' => sub {
    template 'index' => { 'title' => 'Updater UI - Status', 'sysupdt_software' => { "system-image" => "1.0.0-r0" }, 'sysupdt_status' => 'avail' };
};

get '/config' => sub {
    template 'config' => { 'title' => 'Updater UI - Configuration' };
};

true;
