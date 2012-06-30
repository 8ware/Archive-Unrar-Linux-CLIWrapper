package Archive::Unrar::Linux::CLIWrapper;

use 5.014002;
use strict;
use warnings;

=head1 NAME

Archive::Unrar::Linux::CLIWrapper - Perl interface to Alexander Roshal's UnRAR
command line tool (Linux distribution)

=head1 SYNOPSIS

  use Archive::Unrar::Linux::CLIWrapper ':all';
  
  # lists the archive's content
  %archive_content = list(
      file => 'path/to/archive.rar',
      password => 'archive's password'
  );
  $item_count = list(...);

  # extracts the archive to the given destination
  @extracted_paths = extract(
      file => 'path/to/archive.rar',
      password => 'archive's password',
      overwrite => 1,
      destination => 'path/to/destination'
  );
  $extracted_count = extract(...);

  # check for errors
  print "Wrong password!" if $UNRAR_ERR == ERRNO_CRC_FAILED;

=head1 DESCRIPTION

This module is simply an interface to the unrar command line tool by Alexander
Roshal. Depending on the invoked subroutine and the giben parameters it
generates a system-call which is then executed in a sub-shell.

B<Note:> This module is not thread-safe.

=head2 EXPORT

None by default. The C<:all>-flag exports the both main-routines, the
error-variable and all error-code constants. The C<:error>-flag exports
only the error-related stuff.

=cut

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	list extract
	$UNRAR_ERR ERRNO_ALL_OK ERRNO_CRC_FAILED ERRNO_CANT_OPEN_FILE
) ], 'error' => [ qw(
	$UNRAR_ERR ERRNO_ALL_OK ERRNO_CRC_FAILED ERRNO_CANT_OPEN_FILE
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our $VERSION = '0.02';


use Carp;

=head2 ERROR-CODES

To evaluate possible failures the variable C<$UNRAR__ERR> should be analyzed.
Therefore the error-constants can be imported. Following constants exist, yet:

=over 4

=item B<ERRNO_ALL_OK> indicates that the extraction was successfully completed

=item B<ERRNO_CRC_FAILED> the file either is corrupt or the password is wrong

=item B<ERRNO_CANT_OPEN_FILE> the specified file couldn't be opened, maybe the
file was not found or the permissions are missing

=back

If the C<$UNRAR_ERR>-variable is not imported, the C<$?>-variable can also be
used.

=cut

our $UNRAR_ERR = 0;

use constant {
	ERRNO_ALL_OK => 0,
	ERRNO_CRC_FAILED => 768,
	ERRNO_CANT_OPEN_FILE => 2560
};


=head2 METHODS

Both methods accept several arguments, which are described in the following.

=over 4

=item * B<file> the path to the archive, which is processed.

=item * B<password> the password of the archive. If not set the password
will not be queried and an error could occur. A wrong password results in
an error, too.

=item * B<destination> the path to the destination, where the archive will
be extracted

=item * B<overwrite> sets the flag whether to overwrite the already
extracted file or not. If set to C<1> automatical override is enabled;
disabled otherwise.

=item * B<fullpath> if set, all files are created with theis full path, so
the directory-structure of the archive is kept.

=back

The arguments C<file> and C<password> are global accepted. Further, the
C<file>-argument is an obligatory argument. If not given, the method dies.

=cut

my %accepted_options = (
	__PACKAGE__.'::list' => [ qw(password) ],
	__PACKAGE__.'::extract' => [ qw(password overwrite) ]
);

my %processors = (
	password => sub { return '-p' . ($_[0] ? $_[0] : '-') },
	overwrite => sub { return '-o' . ($_[0] ? '+' : '-') },
);

#
# processes the options contained in the given configuration and returns
# them as an option-string
#
sub _process_options(%) {
	my %config = @_;
	my $call_sub = (caller(1))[3];
	my @options = @{$accepted_options{$call_sub}};
	my $option_string = "";
	for my $opt (@options) {
		$option_string .= $processors{$opt}->($config{$opt}) . " ";
	}
	return $option_string;
}

#
# generates the system-call and executes it in a sub-shell
#
sub _execute($$$;$) {
	my ($mode, $options, $file, $destination) = @_;
	my $call = "unrar $mode ";
	$call .= '-idcp '; # don't show comment (header) and current process-state
	$call .= $options if defined $options;
	$call .= $file;
	$call .= " $destination" if defined $destination;
	return `$call 2>&1`;
}

=head3 list

Lists the content of the given archive and returns a hash-reference which
indicates the structure of the content of the archive. A directory is
indicated by its name as key and an array-reference as its value. A file
is indicated by its name as key and C<1> as its value. For example:

  %archive = (
      directory => {
          file_1 => 1,
          file_2 => 1
      }
  ); # is equal to 'dir/file_1' and 'dir/file_2'

In scalar context the count of the directly contained items is returned.

=cut

use subs qw(_build_tree _merge_tree);

sub list(%) {
	my %config = @_;
	croak "No file specified" unless exists $config{file};
	my $options = _process_options(%config);
	my $output = _execute('vb -v', $options, $config{file});
	$UNRAR_ERR = $?;
	return wantarray ? () : 0 if $UNRAR_ERR;
	my %archive;
	for (split /\n/, $output) {
		my @path_parts = split m|/|;
		my $root = shift @path_parts;
		my $tree = _build_tree(@path_parts);
		unless (defined $archive{$root}) {
			$archive{$root} = $tree;
		} elsif(ref $tree eq 'HASH') {
			_merge_tree($archive{$root}, $tree);
		}
	}
	return wantarray ? %archive : scalar keys %archive;
}

#
# Builds a tree in a recursive way.
#
sub _build_tree(@) {
	return 1 unless @_;
	return { (shift) => _build_tree(@_) };
}

#
# Merges two (hash-)trees.
#
sub _merge_tree($$) {
	my ($original, $new) = @_;
	return if $new == 1;
	for (keys %{$new}) {
		unless (defined $original->{$_}) {
			$original->{$_} = $new->{$_};
		} elsif (ref $original->{$_} eq 'HASH') {
			_merge_tree($original->{$_}, $new->{$_});
		}
	}
}

=head3 extract

Extracts the given archive and returns a list with all extracted files
(full path) or an empty list if nothing was extracted or something gone
wrong. In scalar context the count of extracted files is returned.

The following arguments are recognized in addition to the global ones:
C<destination>, C<overwrite>, C<fullpath>

=cut

sub extract(%) {
	my %config = @_;
	croak "No file specified" unless exists $config{file};
	my $mode = $config{fullpath} ? 'x' : 'e';
	my $options = _process_options(%config);
	my $destination = $config{destination};
	my $output = _execute($mode, $options, $config{file}, $destination);
	$UNRAR_ERR = $?;
	return wantarray ? () : 0 if $UNRAR_ERR;
	my @extracted;
	for (split /\n/, $output) {
		next unless /^Extracting\s+(\S.+\S)\s+OK\s+$/;
		push @extracted, $1;
	}
	return wantarray ? @extracted : scalar @extracted;
}


1;
__END__

=head1 DEPEDENCIES

Only the linux-distribution of "unrar" have to be installed on a linux-OS.
Maybe other Unix (or even non-Unix) operating systems have the same command
line interface for unrar as Linux. In such a case, adjust the requirements-test
for yourself and write a mail, so I can fix that.

=head1 TODOs

=over 4

=item * provide callbacks, which are invoked in case of error (?)

=item * handle return- and error-value if the specified file is not an archive

=item * provide module-flags which en-/disable option-flags statically, such
as C<fullpath> or C<override>

=item * provide flag which enables deletion of directories or empty files in
case of CRC-fails.

=back

=head1 SEE ALSO

Homepage of the UnRAR-CLI - http://www.rarlab.com

=head1 AUTHOR

8ware, E<lt>8wared@googlemail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by 8ware

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut

