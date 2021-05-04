package Perl::Critic::Policy::TryTiny::RequireCatch;
use strict;
use warnings;
use utf8;

# ABSTRACT: Always include a "catch" block when using "try"

use Readonly;
use Perl::Critic::Utils qw( :severities :classification :ppi );

use base 'Perl::Critic::Policy';

Readonly::Scalar my $DESC => "Try::Tiny \"try\" invoked without a corresponding \"catch\" block";
Readonly::Scalar my $EXPL => "Try::Tiny's \"try\" without a \"catch\" block will swallow exceptions. Use an empty block if this is intended.";

sub supported_parameters {
    return ();
}

sub default_severity {
    return $SEVERITY_HIGH;
}

sub default_themes {
    return qw(bugs);
}

sub prepare_to_scan_document {
    my $self = shift;
    my $document = shift;

    return $document->find_any(sub {
        my $element = $_[1];
        return 0 if ! $element->isa('PPI::Statement::Include');
        my @children = grep { $_->significant } $element->children;
        if ($children[1] && $children[1]->isa('PPI::Token::Word') && $children[1] eq 'Try::Tiny') {
            return 1;
        }
        return 0;
    });
}

sub applies_to {
    return 'PPI::Token::Word';
}

sub violates {
    my ($self, $elem, undef) = @_;

    return if $elem->content ne 'try';
    return if ! is_function_call($elem) && !($] >= 5.033007 && is_perl_bareword($elem));

    my $try_block = $elem->snext_sibling() or return;
    my $sib = $try_block->snext_sibling();
    if (!$sib || $sib->content ne 'catch') {
        return $self->violation($DESC, $EXPL, $elem);
    }
    return;
}

1;

=head1 DESCRIPTION

Programmers from other programming languages may assume that the following code
does not swallow exceptions:

    use Try::Tiny;
    try {
        # ...
    }
    finally {
        # ...
    };

However, Try::Tiny's implementation always swallows exceptions unless a catch
block has been specified.

The programmer should always include a catch block. The block may be empty, to
indicate that exceptions are deliberately ignored.

    use Try::Tiny;
    try {
        # ...
    }
    catch {
        # ...
    }
    finally {
        # ...
    };

This policy assumes that L<Try::Tiny> is being used, and it doesn't run if it
can't find it being imported.

=head1 CONFIGURATION

This Policy is not configurable except for the standard options.

=cut
