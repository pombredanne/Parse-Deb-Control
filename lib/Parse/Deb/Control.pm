package Parse::Deb::Control;

=head1 NAME

Parse::Deb::Control - parse and manipulate F<debian/control> in a controlable way

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use warnings;
use strict;

our $VERSION = '0.01';

use base 'Class::Accessor::Fast';

use File::Slurp qw(read_file write_file);
use Storable 'dclone';

=head1 PROPERTIES

=cut

__PACKAGE__->mk_accessors(qw{
    filename
    _control_src
    content
    structure
});

=head1 METHODS

=head2 new()

Object constructor.

=cut

sub new {
    my $class = shift;
    my $src   = shift;
    my $self  = $class->SUPER::new({});
    
    return $self
        if not $src;
    
    # assume it's file handle if it can getline method
    $self->_control_src($src)
        if eval { $src->can('getline') };

    # assume it's string if there are new lines
    $self->_control_src(IO::String->new($src))
        if ($src =~ m/\n/xms);

    # otherwise open file for reading
    open my $io, '<', $src or die 'failed to open "'.$src.'" - '.$!;
    $self->_control_src($io);

    return $self;
}

sub content {
    my $self = shift;
    my $content = $self->{'content'};

    return $content
        if defined $content;
    
    my @structure   = ();
    my @content     = ();
    my $last_value  = undef;
    my $last_para   = undef;
    my $control_txt = '';
    
    my $line_number = 0;
    my $control_src = $self->_control_src;
    while (my $line = <$control_src>) {
        $line_number++;
        $control_txt .= $line;
        
        # if the line is epmty it's the end of control paragraph
        if ($line =~ /^\s*$/) {
            $last_value = undef;
            push @structure, $line;
            if ($last_para) {
                push @content, $last_para;
                $last_para = undef;
            }
            next;
        }
        
        # line starting with white space
        if ($line =~ /^\s/) {
            die 'not previous value to append "'.$line.'" to (line '.$line_number.')'
                if not defined $last_value;
            ${$last_value} .= $line;
            next;
        }
        
        # other should be key/value lines
        if ($line =~ /^([^:]+):(.*$)/xms) {
            my ($key, $value) = ($1, $2);
            push @structure, $key;
            $last_para->{$key} = $value;
            $last_value = \($last_para->{$key});
            next;
        }
        
        die 'unrecognized format "'.$line.'" (line '.$line_number.')';
    }
    push @content, $last_para;
    
    $self->{'content'} = \@content;
    $self->structure(\@structure);

    die 'control reconstruction failed, send your "control" file attached to bug report :)'
        if $control_txt ne $self->control;
    
    return \@content;
}

sub control {
    my $self = shift;
    
    my $control_txt = '';
    my @content     = @{dclone($self->{'content'})};
    my %cur_para    = %{shift @content};
    foreach my $structure_key (@{$self->structure}) {
        if ($structure_key =~ /^\s*$/) {
            # loop throug new keys and add them
            foreach my $key (sort keys %cur_para) {
                $control_txt .= $key.':'.$cur_para{$key};
            }
            
            # add the space
            $control_txt .= $structure_key;
            
            # get next paragraph
            %cur_para    = %{shift @content};
        }
        
        my $value = delete $cur_para{$structure_key};
        $control_txt .= $structure_key.':'.$value
            if $value;
    }
    # loop throug new keys and add them
    foreach my $key (sort keys %cur_para) {
        $control_txt .= $key.':'.$cur_para{$key};
    }
    
    return $control_txt;
}

1;


__END__

=head1 AUTHOR

Jozef Kutej, C<< <jkutej at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-parse-deb-control at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Parse-Deb-Control>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Parse::Deb::Control


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Parse-Deb-Control>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Parse-Deb-Control>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Parse-Deb-Control>

=item * Search CPAN

L<http://search.cpan.org/dist/Parse-Deb-Control>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Jozef Kutej, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Parse::Deb::Control