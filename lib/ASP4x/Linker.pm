
package ASP4x::Linker;

use strict;
use warnings 'all';
use Carp 'confess';
use ASP4x::Linker::Widget;
use ASP4::ConfigLoader;

our $VERSION = '0.001';


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
  
  my @parts = ( );
  no warnings 'uninitialized';
  my ($uri) = split /\?/, $s->base_href;
  
  my $context = ASP4::HTTPContext->current;
  my $server = $context->server;
  my %vars = %{ $context->request->Form };
  
  if( my $route = eval { $s->_router->route_for( $s->base_href, $ENV{REQUEST_METHOD} ) } )
  {
    map {
      delete($vars{$_});
    } @{$route->{captures}};
  }# end if()
  
  
  foreach my $w ( $s->widgets )
  {
    foreach( $w->attrs )
    {
      my $key = $server->URLEncode( $w->name . '.' . $_ );
      my $val;
      if( defined( $val = $args->{ $w->name }->{ $_ } ) )
      {
        $vars{ $key } = $val
      }
      elsif( defined( $val = $w->$_ ) )
      {
        $vars{ $key } = $val;
      }# end if()
    }# end foreach()
  }# end foreach()
  
  my $final_querystring = join '&', map { $server->URLEncode($_) . '=' . $server->URLEncode($vars{$_}) } sort keys %vars;
  
  return $final_querystring ? join '?', ( $uri, $final_querystring ) : $uri;
}# end uri()


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
  
  $linker->reset();

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

=head1 PUBLIC READ-ONLY PROPERTIES

=head2 base_href

Returns the C<base_href> value in use for the linker object.

=head2 widgets

Returns an array of L<ASP4x::Widget> objects assigned to the linker.

=head1 PUBLIC METHODS

=head2 add_widget( name => $str, attrs => \@attrNames )

Adds a "widget" to

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

=head2 reset( )

Resets all widgets to their original values from the original request.

=head1 SEE ALSO

L<ASP4>, L<ASP4x::Router>, L<Router::Generic>

=head1 AUTHOR

John Drago <jdrago_999@yahoo.com>

=head1 LICENSE

This software is B<Free> software and may be used and redistributed under the same
terms as Perl itself.

=cut

