=head1 NAME

Requirements-tests for the C<Archive::Unrar::Linux::CLIWrapper>-module.

=cut

use strict;
use warnings;

use Devel::CheckOS qw(os_is);
use Test::More tests => 2;

=head1 TEST CASES

=head2 OPERATING SYSTEM

Expected is the Linux operating system.

=cut

ok(os_is('Linux'), "Underlying operating system should be Linux");

=head2 UNRAR DISTRIBUTION

Checks whether an appropriate version of the unrar command line tool is
installed.

=cut

my $min_version = 1.00;

sub _check_unrar(;\$) {
	my $error_var = shift;
	my @output = split /\n/, `unrar 2>&1`;
	$output[1] =~ /UNRAR (\d\.\d\d) beta 3 freeware/;
	if ($1 < $min_version) {
		$$error_var = 'bad version';
		return 0;
	} elsif ($output[$#output] =~ /unrar: command not found/) {
		$$error_var = 'not installed';
		return 0;
	}
	return 1;
}

my $error;
ok(_check_unrar($error),
		"Unrar 4.0 should be installed" . ($error ? ": $error" : "."));

=head1 TODOs

=over 4

=item * may test whether all used commands and switches of the unrar command
line interface are available

=back

=cut

