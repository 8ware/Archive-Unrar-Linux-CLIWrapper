=head1 NAME

Test-suite for the C<Archive::Unrar::Linux::CLIWrapper>-module.

=cut

use strict;
use warnings;

use Test::More tests => 12;
BEGIN { use_ok('Archive::Unrar::Linux::CLIWrapper', ':all') };

use File::Path;

=head1 TEST CASES

=head2 TEST DATA

Given are two rar-archives: one with and the other without password
protection.

=cut

use subs 'clear';

my ($test_directory) = $0 =~ m|(.*)/|;
my $test_archive = "$test_directory/test-rar_+pass.rar";
my %test_content = (
	directory_1 => {
		file_1 => 1,
		file_2 => 1,
	},
	directory_2 => {
		directory_3 => {
			file_4 => 1
		},
		file_3 => 1
	},
	file_0 => 1
);
my @test_content = (
	"$test_directory/directory_1/file_1",
	"$test_directory/directory_1/file_2",
	"$test_directory/directory_2/directory_3/file_4",
	"$test_directory/directory_2/file_3",
	"$test_directory/file_0"
);

=head2 CONTENT LISTING

=over 4

=item [list-context] file-/directory-tree of archive's content is returned

=item [scalar-context] number of files/directories in the first level of
the archive is returned

=item dispensable options are silently ignored, e.g. overwrite

=back

=cut

my %content = list(file => $test_archive, overwrite => 1);
is_deeply(\%content, \%test_content,
		"[list] should return correct content-hash in list-context");
my $item_count = list(file => $test_archive, overwrite => 1);
is($item_count, 3, "[list] should return correct item-count in scalar-context");

=head2 CONTENT EXTRACTION

=over 4

=item [list-context] extraction should return list of extracted files (fullpath) and the
files must exist

=item [scalar-context] count of extracted items must be returned

=back

=cut

my @extracted = extract(file => $test_archive, password => 'test',
		destination => $test_directory, overwrite => 1, fullpath => 1);
is_deeply(\@extracted,  \@test_content,
		"[extract] should return extracted file in list-context"); 
ok(-f, "[extract] extracted file ($_) should exist") for @extracted;
clear();
my $extracted_count = extract(file => $test_archive, password => 'test',
		destination => $test_directory, overwrite => 1, fullpath => 1);
is($extracted_count, 5,
		"[extract] the count of extracted files is returned in scalar-context");
clear();

=head2 ERROR HANDLING

=over 4

=item C<$UNRAR_ERR> must be set in case of error

=item wrong password should result in C<ERRNO_CRC_FAILED>

=back

=cut

$extracted_count = extract(file => $test_archive, password => 'fail');
is($extracted_count, 0, "[extract] returned list should be empty on failure");
is($UNRAR_ERR, ERRNO_CRC_FAILED,
			"[extract] error-variable should be valued with " . ERRNO_CRC_FAILED);


#
# Removes all unpacked files and directories.
#
sub clear() {
	rmtree(["$test_directory/directory_1", "$test_directory/directory_2"]);
	unlink "$test_directory/file_0";
}

