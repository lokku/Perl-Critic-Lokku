package Perl::Critic::Policy::TryTiny::ProhibitExitingSubroutine;
use strict;
use warnings;
use utf8;

# ABSTRACT: Ban next/last/return in Try::Tiny blocks

use Readonly;
use Perl::Critic::Utils qw( :severities :classification :ppi );

use base 'Perl::Critic::Policy';

Readonly::Scalar my $DESC => "Using next/last/redo/return in a Try::Tiny block is ambiguous";
Readonly::Scalar my $EXPL => "Using next/last/redo without a label or using return in a Try::Tiny block is ambiguous, did you intend to exit out of the try/catch/finally block or the surrounding block?";

sub supported_parameters {
    return ();
}

sub default_severity {
    return $SEVERITY_HIGH;
}

sub default_themes {
    return qw(bugs);
}

sub applies_to {
    return 'PPI::Token::Word';
}

sub violates {
    my ($self, $elem, undef) = @_;

    return if $elem->content ne 'try';
    return if ! is_function_call($elem);

    my @blocks_to_check;

    if (my $try_block = $elem->snext_sibling()) {
        if ($try_block->isa('PPI::Structure::Block')) {
            push @blocks_to_check, $try_block;
        }
        my $sib = $try_block->snext_sibling();
        if ($sib and $sib->content eq 'catch' and my $catch_block = $sib->snext_sibling()) {
            if ($catch_block->isa('PPI::Structure::Block')) {
                push @blocks_to_check, $catch_block;
            }
            $sib = $catch_block->snext_sibling();
        }
        if ($sib and $sib->content eq 'finally' and my $finally_block = $sib->snext_sibling()) {
            if (finally_block->isa('PPI::Structure::Block')) {
                push @blocks_to_check, $finally_block;
            }
        }
    }

    for my $block_to_check (@blocks_to_check) {
        my $violation = $self->_check_block($block_to_check);
        if (defined($violation)) {
            return $violation;
        }
    }
    return;
}

sub _check_block {
    my $self = shift;
    my $block = shift;

    for my $word (@{ $block->find('PPI::Token::Word') || [] }) {
        if ($word eq 'return') {
            return $self->violation($DESC, $EXPL, $word);
        }

        my $sib = $word->snext_sibling;

        if ($word eq 'next' || $word eq 'redo' || $word eq 'last') {
            if (! $sib || ! _is_label($sib)) {
                return $self->violation($DESC, $EXPL, $word);
            }
        }
    }
    return;
}

sub _is_label {
    my $element = shift;

    if ($element eq 'if' || $element eq 'unless') {
        return 0;
    }

    return $element =~ /^[_a-z]+$/i ? 1 : 0;
}

1;

=head1 DESCRIPTION

Take this code:

    use Try::Tiny;

    for my $item (@array) {
        try {
            next if $item == 2;
            # other code
        }
        catch {
            warn $_;
        };
        # other code
    }

The next statement will not go to the next iteration of the for-loop, rather,
it will exit the try block, emitting a warning if warnings are enabled.

This is probably not what the developer had intended, so this policy prohibits it.

One way to fix this is to use labels:

    use Try::Tiny;

    ITEM:
    for my $item (@array) {
        try {
            if ($item == 2) {
                no warnings 'exiting';
                next ITEM;
            }
            # other code
        }
        catch {
            warn $_;
        };
        # other code
    }

=head1 CONFIGURATION

This Policy is not configurable except for the standard options.

=head1 KNOWN BUGS

This policy assumes that L<Try::Tiny> is being used, and doesn't check for
whether an alternative like L<TryCatch> is being used.

=cut
