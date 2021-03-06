package App::Sqitch::GUI::Config;

# ABSTRACT: A Sqitch::Config Extension

use 5.010;
use utf8;
use Moo;
use MooX::HandlesVia;
use App::Sqitch::GUI::Types qw(
    Dir
    Str
    Maybe
    HashRef
);
use Path::Class qw(dir file);
use File::ShareDir qw(dist_dir);
use Try::Tiny;
use List::Util qw(first);
use Locale::TextDomain 1.20 qw(App-Sqitch-GUI);
use App::Sqitch::X qw(hurl);

extends 'App::Sqitch::Config';

has 'default_project_name' => (
    is      => 'rw',
    isa     => Maybe[Str],
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->get(key => 'core.project');
    }
);

has 'default_project_path' => (
    is      => 'rw',
    isa     => Maybe[Dir],
    lazy    => 1,
    default => sub {
        my $self    = shift;
        my $default = $self->default_project_name;
        return $default
            ? dir $self->get( key => "project.${default}.path" )
            : undef;
    }
);

has 'current_project_path' => (
    is       => 'rw',
    isa      => Dir,
    required => 0,
);

sub local_file {
    my $self = shift;
    return $self->current_project_path
        ? file( $self->current_project_path, $self->confname )
        : undef;
};

has '_conf_projects_list' => (
    is      => 'ro',
    isa     => Maybe[HashRef],
    lazy    => 1,
    default => sub {
        shift->get_regexp( key => qr/^project[.][^.]+[.]path$/ );
    }
);

has 'project_list' => (
    is          => 'ro',
    handles_via => 'Hash',
    lazy        => 1,
    builder     => '_build_project_list',
    handles     => {
        get_project => 'get',
        has_project => 'count',
        projects    => 'kv',
    },
);

sub _build_project_list {
    my $self = shift;
    my $project_list = {};
    while ( my ( $key, $path ) = each( %{ $self->_conf_projects_list } ) ) {
        my ($name) = $key =~ m{^project[.](.+)[.]path$};
        $project_list->{$name} = dir $path;
    }
    return $project_list;
}

has 'engine_list' => (
    handles_via => 'Hash',
    is          => 'ro',
    required    => 1,
    lazy        => 1,
    default     => sub {
        {   unknown  => 'Unknown',
            pg       => 'PostgreSQL',
            mysql    => 'MySQL',
            sqlite   => 'SQLite',
            oracle   => 'Oracle',
            firebird => 'Firebird',
        };
    },
    handles => {
        get_engine_name => 'get',
    },
);

sub get_engine_from_name {
    my ($self, $engine) = @_;
    my %engines = reverse %{ $self->engine_list };
    return $engines{$engine};
}

#-- Not used, yet:

# sub has_repo_name {
#     my ($self, $name) = @_;
#     hurl 'Wrong arguments passed to has_repo_name()'
#         unless $name;
#     return 1 if first { $name eq $_ } keys %{$self->project_list};
#     return 0;
# }

# sub has_repo_path {
#     my ($self, $path) = @_;
#     hurl 'Wrong arguments passed to has_repo_path()' unless $path;
#     return 1 if first { $path->stringify eq $_ } values %{$self->project_list};
#     return 0;
# }

sub reload {
    my ( $self, $path ) = @_;
    hurl 'Wrong arguments passed to reload()' unless $path and -d $path;
    my $file = file $path, $self->confname;
    hurl reload =>
      __x( 'The configuration file "{file}" does not exist!', file => $file )
      unless $file and -f $file;
    try { $self->load_file($file) }
    catch {
        hurl reload => __x(
            'The configuration file "{file}" could not be (re)loaded: {err}',
            file => $file,
            err  => $_,
        );
    };
    $self->current_project_path( dir $path);
    return;
}

sub project_list_cnt {
    my $self = shift;
    return scalar keys %{ $self->project_list };
}

has 'sharedir' => (
    is      => 'ro',
    isa     => Dir,
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $path;
        try {
            $path = dist_dir('App-Sqitch-GUI');
        }
        catch {
            $path = 'share';
        };
        return dir $path;
    },
);

has 'icon_path' => (
    is      => 'ro',
    isa     => Dir,
    default => sub {
        my $self = shift;
        return dir( $self->sharedir, 'etc', 'icons' );
    },
);

=pod

Additions to the user configuration file C<sqitch.conf>:

[core]
    engine = pg
    project = flipr
[project "flipr"]
    path = /home/user/sqitch/flipr
[project "widgets"]
    path = /home/user/sqitch/widgets

The list of project names and paths and a default project name.

=cut

1;
