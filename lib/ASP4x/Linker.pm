
package ASP4x::Linker;

use strict;
use warnings 'all';
use Carp 'confess';
use ASP4x::Linker::Widget;
use ASP4::ConfigLoader;

our $VERSION = '0.003';


sub new
{
  my ($class, %args) = @_;
  
  $args{base_href} ||= $ENV{REQUEST_URI};
  confess "No 'base_href' argument provided and can't discover it from \$ENV{REQUEST_URI}!"
    unless $args{base_href};
  
  $args{widgets} = [ ];
  
  return bless \%args, $class;
}# end new()


# Public read-only properties:
sub base_href { shift->{base_href} }
sub _router { eval { ASP4::ConfigLoader->load->web->router } }
sub widgets { @{ shift->{widgets} } }


sub add_widget
{
  my ($s, %args) = @_;
  
  my $widget = ASP4x::Linker::Widget->new( %args );
  
  confess "Another widget with the name '@{[ $widget->name ]}' already exists."
    if grep { $_->name eq $widget->name } $s->widgets;
  
  push @{ $s->{widgets} }, $widget;
  $widget;
}# end add_widget()


sub widget
{
  my ($s, $name) = @_;
  
  my ($widget) = grep { $_->name eq $name } $s->widgets
    or return;
  
  return $widget;
}# end widget()


sub reset
{
  map { $_->reset } shift->widgets;
}# end reset()


sub uri
{
  my ($s, $args) = @_;
  
  my $vars = $s->vars( $args );
  
  no warnings 'uninitialized';
  my ($uri) = split /\?/, $s->base_href;
  my $context = ASP4::HTTPContext->current;
  my $server = $context->server;
  my $final_querystring = join '&', map { $server->URLEncode($_) . '=' . $server->URLEncode($vars->{$_}) }
                                      grep { defined($vars->{$_}) }
                                        sort keys %$vars;
  
  return $final_querystring ? join '?', ( $uri, $final_querystring ) : $uri;
}# end uri()


sub hidden_fields
{
  my ($s, $args) = @_;
  
  my $vars = $s->vars( $args, 1 );
  
  no warnings 'uninitialized';
  my ($uri) = split /\?/, $s->base_href;
  my $context = ASP4::HTTPContext->current;
  my $server = $context->server;

  my @inputs = map {qq(<input type="hidden" name="@{[ $server->URLEncode( $_ ) ]}" value="@{[ $server->URLEncode( $vars->{$_} ) ]}" />)}
                 keys %$vars;
  return join "\n", @inputs;
}# end hidden_fields()


sub vars
{
  my ($s, $args) = @_;
  
  my @parts = ( );
  no warnings 'uninitialized';
  my ($uri) = split /\?/, $s->base_href;
  
  my $context = ASP4::HTTPContext->current;
  my $server = $context->server;
  my %vars = %{ $context->request->Form };
  
  if( $context->config->web->can('router') )
  {
    if( my $route = eval { $s->_router->route_for( $s->base_href, $ENV{REQUEST_METHOD} ) } )
    {
      map {
        delete($vars{$_});
      } @{$route->{captures}};
    }# end if()
  }# end if()
  
  foreach my $w ( $s->widgets )
  {
    foreach( $w->attrs )
    {
      my $key = $server->URLEncode( $w->name . '.' . $_ );
      my $val;
      if( exists( $args->{ $w->name } ) && exists( $args->{ $w->name }->{ $_ } ) )
      {
        $vars{ $key } = $args->{ $w->name }->{ $_ };
      }
      else
      {
        $vars{ $key } = $w->get( $_ );
      }# end if()
    }# end foreach()
  }# end foreach()
  
  # Also add any non-ref values that were passed in as $args:
  map { $vars{$_} = $args->{$_} }
    grep { ! ref($args->{$_}) }
      sort keys %$args;
  
  my $res = \%vars;
  $s->reset();
  return $res;
}# end _prepare_vars()


sub DESTROY { my $s = shift; undef(%$s); }

1;

=pod

=head1 NAME

ASP4x::Linker - In-page persistence of widget-specific variables.

=head1 SYNOPSIS

(Within /some-page.asp)

  use ASP4x::Linker;

  my $linker = ASP4x::Linker->new();
  
  $linker->add_widget(
    name  => "albums",
    attrs => [qw/ page_number page_size sort_field sort_dir /]
  );
  
  $linker->add_widget(
    name  => "genres",
    attrs => [qw/ page_number page_size sort_field sort_dir /]
  );
  
  $linker->add_widget(
    name  => "artists",
    attrs => [qw/ page_number page_size sort_field sort_dir /]
  );

...later, on the same page...

  For more info click <a href="<%= $linker->uri() %>">Here</a>.

Then:

  $linker->widget('albums')->page_number(4);
  
  <a href="<%= $linker->uri() %>">Page 4</a>  # /some-page.asp?albums.page_number=4

Or

  my $url = $linker->uri({
    albums => { page_number => 4 }
  });
  # /some-page.asp?albums.page_number=4

Or

  my $url = $linker->uri({
    albums  => { page_number => 4 },
    genres  => {
      page_number => 1,
      page_size   => 20,
      sort_col    => 'name',
      sort_dir    => 'desc'
    }
  });
  
  # /some-page.asp?albums.page_number=4&genres.page_number=1&genres.page_size=20&genres.sort_col=name&genres.sort_dir=desc

Or

  my $url = $linker->uri({foo => 'bar'});
  
  # /some-page.asp?foo=bar

=head1 DESCRIPTION

C<ASP4x::Linker> aims to solve the age-old problem of:

B<How do I change one widget on the page without losing my settings for all the other widgets on the page?>

OK - say you have one data grid on your web page that allows paging and sorting.  You can move forward and backward between
pages, change the sorting - life's great.  B<THEN> your boss says:

  We need to have two of those on the same page.  One for Albums and one for Genres.

Now you have 2 options.

=over 4

B<Option 1>: If a user pages "Albums" to page 4, then pages "Genres" to page 2, you forget that "Albums" was on page 4.

B<Option 2>: Use ASP4x::Linker.  Register 2 "widgets" (albums and genres) and let the linker know that they both have C<page_number>, C<page_size>, C<sort_col> and C<sort_dir> attributes.
When the user makes paging or sorting changes in Albums, the stuff for Genres will persist between requests without any extra effort.

=back

=head1 CONSTRUCTOR

=head2 new( [ base_href => $ENV{REQUEST_URI} ] )

Returns a new C<ASP4x::Linker> object using the supplied C<base_href> value as the "starting point"
for all links that will be generated.

If no C<base_href> is provided, the value of C<$ENV{REQUEST_URI}> will be used instead.

=head1 PUBLIC READ-ONLY PROPERTIES

=head2 base_href

Returns the C<base_href> value in use for the linker object.

=head2 widgets

Returns an array of L<ASP4x::Linker::Widget> objects assigned to the linker.

=head1 PUBLIC METHODS

=head2 add_widget( name => $str, attrs => \@attrNames )

Adds a "widget" to the widgets collection.

=head2 widget( $name )

Returns an individual L<ASP4x::Linker::Widget> object by that name.

Returns undef if no widget by that name is found.

=head2 uri( [$properties] )

Returns the uri for all widgets based on the intersect of:

=over 4

=item * The incoming form data from the original request

=item * Individually-set values for each widget in the collection.

=item * Any properties provided as an argument to C<uri()>.

=back

=head2 hidden_fields( [$properties] )

Returns a string of XHTML hidden input fields (<input type="hidden" name="$name" value="$value" />).

Useful if your persistence logic involves repeated form submissions rather than hyperlinks.

The C<$properties> argument is the same as in the C<uri()> method.

=head2 vars( [$properties] )

Returns a hashref representing the intersect of all widgets' names and attributes.

Supposing you setup your linker like this:

  my $linker = ASP4x::Linker->new();
  
  $linker->add_widget(
    name  => 'albums',
    attrs => [qw( page sort )]
  );
  
  $linker->add_widget(
    name  => 'artists',
    attrs => [qw( page sort )]
  );

After calling C<vars()> you'd get:

  $VAR1 = {
    'albums.page'  => undef,
    'albums.sort'  => undef,
    'artists.page' => undef,
    'artists.sort' => undef,
  };

If you did this:

  $linker->vars({
    albums  => {page => 2},
    artists => {sort => 'desc'}
  });

Then you'd get this instead:

  $VAR1 = {
    'albums.page'  => 2,
    'albums.sort'  => undef,
    'artists.page' => undef,
    'artists.sort' => 'desc',
  };

You could also do this:

  $linker->widget('albums')->page( 10 );
  $linker->widget('artists')->sort( 'desc' );
  $linker->vars();

And you would get the same thing:

  $VAR1 = {
    'albums.page'  => 2,
    'albums.sort'  => undef,
    'artists.page' => undef,
    'artists.sort' => 'desc',
  };

=head2 reset( )

Resets all widgets to their original values from the original request (as specified in the C<base_href> value used by C<new()>).

=head1 SEE ALSO

L<ASP4>, L<ASP4x::Router>, L<Router::Generic>

=head1 AUTHOR

John Drago <jdrago_999@yahoo.com>

=head1 LICENSE

This software is B<Free> software and may be used and redistributed under the same
terms as Perl itself.

=cut

