
package ASP4x::Linker::Widget;

use strict;
use warnings 'all';
use Carp 'confess';


sub new
{
  my ($class, %args) = @_;
  
  foreach(qw( name ))
  {
    confess "Required param '$_' was not provided"
      unless $args{$_};
  }# end foreach()
  
  my $context = ASP4::HTTPContext->current;
  my $form = $context->request->Form;
  $args{attrs} ||= [ ];
  
  $args{vars} = {
    map { $_ => $form->{"$args{name}.$_"} }
      @{$args{attrs}}
  };
  $args{original_vars} = {
    map { $_ => $form->{"$args{name}.$_"} }
      @{$args{attrs}}
  };
  
  return bless \%args, $class;
}# end new()


sub attrs { sort @{ shift->{attrs} } }
sub name { shift->{name} }


sub vars
{
  my $s = shift;
  
  return $s->{vars};
}# end filters()


sub reset
{
  my $s = shift;
  
  %{ $s->{vars} } = %{ $s->{original_vars} };
}# end reset()


# Getter/setter for variables:
sub AUTOLOAD
{
  my $s = shift;
  our $AUTOLOAD;
  
  my ($name) = $AUTOLOAD =~ m{([^:]+)$};
  
  confess "Unknown attribute '$name' for widget '$s->{name}'"
    unless exists( $s->{vars}->{$name} );
  
  @_ ? $s->{vars}->{$name} = shift : $s->{vars}->{$name};
}# end AUTOLOAD()


sub DESTROY { my $s = shift; undef(%$s); }

1;# return true:

