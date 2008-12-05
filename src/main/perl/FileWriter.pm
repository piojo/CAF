# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
#
#
# CAF::Process class
# Written by Luis Fernando Muñoz Mejías <mejias@delta.ft.uam.es>

package CAF::FileWriter;

use strict;
use warnings;
use LC::Check;
use IO::String;

our @ISA = qw (IO::String);

=pod

=head1 NAME

CAF::FileWriter - Class for securely writing to files in CAF
applications.

=head1 SYNOPSIS

Normal use:

    use CAF::FileWriter;
    my $fh = CAF::FileWriter->open ("my/path");
    print $fh "My text";
    $fh->close();

Aborting changes:

    use CAF::FileWriter;
    my $fh = CAF::FileWriter->open ("my/path");
    print $fh, "My text";
    $fh->cancel();
    $fh->close();

=head1 DESCRIPTION

This class should be used whenever a file is to be opened for writing.

If the file already exists and the printed contents are the same as
the contents present on disk, the actual file won't be modified. This
way, timestamps will be kept.

It also provides a secure way of opening files, avoiding symlink
attacks.

In case of errors, changes can be cancelled, and nothing will happen
to disk.

Finally, the file names to be handled will be logged at the verbose
level.

=head2 Gory details

This is just a wrapper class for C<LC::Check::file>

=head2 Public methods

=over

=item new

Returns a new object. It accepts the file name as its first argument,
and the next hash as additional options:

=over

=item C<log>

The log object. If not supplied, no logging will be performed.

=item C<owner>

UID for the file.

=item C<group>

File's GID.

=item C<mode>

File's permissions.

=item C<backup>

Path for the backup file, if this one has to be re-written.

=back

=cut

sub new
{
    my ($class, $path, %opts) = @_;

    my $self = IO::String->new();

    *$self->{filename} = $path;
    *$self->{LOG} = $opts{log} if exists ($opts{log});
    *$self->{LOG}->verbose ("Opening file $path") if exists (*$self->{LOG});
    *$self->{options}->{mode} = $opts{mode} if exists ($opts{mode});
    *$self->{options}->{owner} = $opts{owner} if exists ($opts{owner});
    *$self->{options}->{group} = $opts{group} if exists ($opts{group});
    *$self->{options}->{backup} = $opts{backup} if exists ($opts{backup});
    *$self->{save} = 1;
    return bless ($self, $class);
}

=item open

Synonimous of new.

=cut

sub open
{
    return new (@_);
}

=item close

Closes the file. If it has not been saved and it has not been
cancelled, it checks its contents and perhaps re-writes it, in a
secure way (not following symlinks, etc).

=cut

sub close
{
    my $self = shift;
    my ($str, $ret);

    if (*$self->{save}) {
	*$self->{save} = 0;
	$str = *$self->{buf};
	*$self->{options}->{contents} = $$str;
	$ret = LC::Check::file (*$self->{filename}, %{*$self->{options}});
	*$self->{LOG}->verbose ("File ", *$self->{filename}, " was",
				$ret?" ":" not ", "modified")
	    if *$self->{LOG};
    }
    $self->SUPER::close();
    return $ret;
}

=item cancel

Marks the printed contents as invalid. The existing file will not be
altered.

=cut

sub cancel
{
    my $self = shift;
    if (*$self->{LOG}) {
	*$self->{LOG}->verbose ("Not saving file ", *$self->{filename});
    }
    *$self->{save} = 0;
}

=back

=head2 Private methods

=over

=item DESTROY

Class destructor. Closes the file, perhaps saving it to disk.

=back

=cut


sub DESTROY
{
    my $self = shift;
    $self->close();
    $self->SUPER::DESTROY();
}

1;

__END__

=pod

=head1 EXAMPLES

=head2 Opening /etc/sudoers

This a part of what I<ncm-sudo> should do, if it used this module:

    my $fh = CAF::FileWriter->open ("/etc/sudoers", mode => 0440,
                                    log => $self);
    print $fh "User_Alias\t$_\n" foreach @{$aliases->{USER_ALIASES()}};
    print $fh "Runas_Alias\t$_\n" foreach @{$aliases->{RUNAS_ALIASES()}};
    ...
    $fh->close();

Which is actually simpler and safer than current code.

=head2 Specifying owner and group

Owner and group are set at the time of creating the object:

    my $fh = CAF::FileWriter->open ("/some/file",
                                    owner => 100
                                    group => 200);
    print $fh "Hello, world!\n";
    # I don't like what I did, just drop the changes:
    $fh->cancel();
    $fh->close();

=head2 Changing the default filehandle

If you don't want C<STDOUT> as your default filehandle, you can just
C<select> a C<CAF::FileWriter> object:

    my $fh = CAF::FileWriter->open ("/some/file",
                                    owner => 100,
                                    group => 200);
    select ($fh);
    print "Hello, world!\n";
    $fh->close();
    select (STDOUT);

=head2 Using here-documents

You can use them, as always:

    my $fh = CAF::FileWriter->open ("/some/file");
    print $fh <<EOF
    Hello, World!
    EOF
    $fh->close();

=head2 Closing when destroying

If you forget to explictly close the C<CAF::FileWriter> object, it
will be closed automatically when it is destroyed:

    my $fh = CAF::FileWriter->open ("/some/file");
    print $fh "Hello, world!\n";
    undef $fh;

=head1 SEE ALSO

This package inherits from L<IO::String(3pm)>. Check its man page to
do powerful things with the already printed contents.

=cut