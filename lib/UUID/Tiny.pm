package UUID::Tiny;

use 5.006;
use warnings;
use strict;
use Carp;
use Digest::MD5;
#use Digest::SHA1;
use MIME::Base64;
use Time::HiRes;
use POSIX;

#
# Do some preparation ...
#
my $sha_api;

BEGIN {
    # Check for availability of SHA-1 ...
    $sha_api = eval 'use Digest::SHA; 1';
    $sha_api = eval 'use Digest::SHA1; 2' unless $sha_api;
    $sha_api = eval 'use Digest::SHA::PurePerl; 3' unless $sha_api;
    $sha_api = 0 unless $sha_api;
}


=head1 NAME

UUID::Tiny - Pure Perl UUID Support With Functional Interface

=head1 VERSION

Version 1.01_05

=cut

our $VERSION = '1.01_05';


=head1 SYNOPSIS

Create version 1, 3, 4 and 5 UUIDs:

    use UUID::Tiny;

    my $v1_mc_UUID         = create_UUID();
    my $v3_md5_UUID        = create_UUID(UUID_V3, $str);
    my $v3_md5_UUID        = create_UUID(UUID_V3, UUID_NS_DNS, 'caugustin.de');
    my $v4_rand_UUID       = create_UUID(UUID_V4);
    my $v5_sha1_UUID       = create_UUID(UUID_V5, $str);
    my $v5_with_NS_UUID    = create_UUID(UUID_V5, UUID_NS_DNS, 'caugustin.de');

    my $v1_mc_UUID_string  = create_UUID_as_string(UUID_V1);
    my $v3_md5_UUID_string = UUID_to_string($v3_md5_UUID);

    if ( version_of_UUID($v1_mc_UUID) == 1   ) { ... };
    if ( version_of_UUID($v5_sha1_UUID) == 5 ) { ... };
    if ( is_UUID_string($v1_mc_UUID_string)  ) { ... };
    if ( equal_UUIDs($uuid1, $uuid2)         ) { ... };

    my $uuid_time    = time_of_UUID($v1_mc_UUID);
    my $uuid_clk_seq = clk_seq_of_UUID($v1_mc_UUID);

=cut


=head1 DESCRIPTION

UUID::Tiny is a lightweight, low dependency Pure Perl module for UUID
creation and testing. This module provides the creation of version 1 time
based UUIDs (using random multicast MAC addresses), version 3 MD5 based UUIDs,
version 4 random UUIDs, and version 5 SHA-1 based UUIDs.

No fancy OO interface, no plethora of different UUID representation formats
and transformations - just string and binary. Conversion, test and time
functions equally accept UUIDs and UUID strings, so don't bother to convert
UUIDs for them!

All constants and public functions are exported by default, because if you
didn't need/want them, you wouldn't use this module ...

UUID::Tiny deliberately uses a minimal functional interface for UUID creation
(and conversion/testing), because in this case OO looks like overkill to me
and makes the creation and use of UUIDs unnecessarily complicated.

If you need raw performance for UUID creation, or the real MAC address in
version 1 UUIDs, or an OO interface, and if you can afford module compilation
and installation on the target system, then better look at other CPAN UUID
modules like L<Data::UUID>.

This module should be thread save, because the (necessary) global variables
are locked in the functions that access them. (Not tested.)

=cut


=head1 DEPENDENCIES

This module should run from Perl 5.6 up and uses mostly standard (5.8 core)
modules for its job. No compilation or installation required. These are the
modules UUID::Tiny depends on:

    Carp
    Digest::MD5   Perl 5.8 core
    Digest::SHA1
    MIME::Base64  Perl 5.8 core
    Time::HiRes   Perl 5.8 core
    POSIX         Perl 5.8 core

=cut


=head1 ATTENTION! NEW STANDARD INTERFACE (IN PREPARATION FOR V2.00)

After some debate I'm convinced that it is more Perlish (and far easier to
write) to use all-lowercase function names - without exceptions. And that it
is more polite to export symbols only on demand.

While the 1.0x versions will continue to export the old, "legacy" interface on
default, the future standard interface is available using the C<:std> tag on
import from version 1.02 on:

    use UUID::Tiny ':std';
    my $md5_uuid = create_uuid(UUID_MD5, $str);

In preparation for the upcoming version 2.00 of UUID::Tiny you should use the
C<:legacy> tag if you want to stay with the version 1.0x interface:

    use UUID::Tiny ':legacy';
    my $md5_uuid = create_UUID(UUID_V3, $str);

=cut

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT;
our @EXPORT_OK;
our %EXPORT_TAGS = (
     std =>         [qw(
                        UUID_NIL
                        UUID_NS_DNS UUID_NS_URL UUID_NS_OID UUID_NS_X500
                        UUID_V1 UUID_TIME
                        UUID_V3 UUID_MD5
                        UUID_V4 UUID_RANDOM
                        UUID_V5 UUID_SHA1
                        UUID_SHA1_AVAIL
                        create_uuid create_uuid_as_string
                        is_uuid_string
                        uuid_to_string string_to_uuid
                        version_of_uuid time_of_uuid clk_seq_of_uuid
                        equal_uuids
                    )],
    legacy =>       [qw(
                        UUID_NIL
                        UUID_NS_DNS UUID_NS_URL UUID_NS_OID UUID_NS_X500
                        UUID_V1
                        UUID_V3
                        UUID_V4
                        UUID_V5
                        UUID_SHA1_AVAIL
                        create_UUID create_UUID_as_string
                        is_UUID_string
                        UUID_to_string string_to_UUID
                        version_of_UUID time_of_UUID clk_seq_of_UUID
                        equal_UUIDs
                    )],
);

Exporter::export_tags('legacy');
Exporter::export_ok_tags('std');


=head1 CONSTANTS

=cut

=over 4

=item B<NIL UUID>

This module provides the NIL UUID (shown with its string representation):

    UUID_NIL: '00000000-0000-0000-0000-000000000000'

=cut

use constant UUID_NIL => "\x00" x 16;


=item B<Pre-defined Namespace UUIDs>

This module provides the common pre-defined namespace UUIDs (shown with their
string representation):

    UUID_NS_DNS:  '6ba7b810-9dad-11d1-80b4-00c04fd430c8'
    UUID_NS_URL:  '6ba7b811-9dad-11d1-80b4-00c04fd430c8'
    UUID_NS_OID:  '6ba7b812-9dad-11d1-80b4-00c04fd430c8'
    UUID_NS_X500: '6ba7b814-9dad-11d1-80b4-00c04fd430c8'

=cut

use constant UUID_NS_DNS  =>
    "\x6b\xa7\xb8\x10\x9d\xad\x11\xd1\x80\xb4\x00\xc0\x4f\xd4\x30\xc8";
use constant UUID_NS_URL  =>
    "\x6b\xa7\xb8\x11\x9d\xad\x11\xd1\x80\xb4\x00\xc0\x4f\xd4\x30\xc8";
use constant UUID_NS_OID  =>
    "\x6b\xa7\xb8\x12\x9d\xad\x11\xd1\x80\xb4\x00\xc0\x4f\xd4\x30\xc8";
use constant UUID_NS_X500 =>
    "\x6b\xa7\xb8\x14\x9d\xad\x11\xd1\x80\xb4\x00\xc0\x4f\xd4\x30\xc8";


=item B<UUID versions>

This module provides the UUID version numbers as constants:

    UUID_V1
    UUID_V3
    UUID_V4
    UUID_V5

With C<use UUID::Tiny ':std';> you get additional, "speaking" constants:

    UUID_TIME
    UUID_MD5
    UUID_RANDOM
    UUID_SHA1

=cut

use constant UUID_V1 => 1; use constant UUID_TIME   => 1;
use constant UUID_V3 => 3; use constant UUID_MD5    => 3;
use constant UUID_V4 => 4; use constant UUID_RANDOM => 4;
use constant UUID_V5 => 5; use constant UUID_SHA1   => 5;


=item B<UUID_SHA1_AVAIL>

    my $uuid = create_UUID( UUID_SHA1_AVAIL? UUID_V5 : UUID_V3, $str );

This function returns a positive value if a module to create SHA-1 digests
could be loaded, 0 otherwise.

UUID::Tiny (since version 1.02) tries to load
Digest::SHA (1), Digest::SHA1 (2) or Digest::SHA::PurePerl (3), but does not
die if none of them is found. Instead C<create_UUID()> and
C<create_UUID_as_string()> die when trying to create an SHA-1 based UUID
without an appropriate module available.

=cut

sub UUID_SHA1_AVAIL {
    return $sha_api;
}


=back

=cut


=head1 FUNCTIONS

All public functions are exported by default (they should not collide with
other functions).

C<create_UUID()> creates standard binary UUIDs in network byte order
(MSB first), C<create_UUID_as_string()> creates the standard string
represantion of UUIDs.

All query and test functions (except C<is_UUID_string>) accept both
representations.

=over 4

=cut



=item B<create_UUID()>, B<create_uuid()> (:std)

    my $v1_mc_UUID   = create_UUID();
    my $v1_mc_UUID   = create_UUID(UUID_V1);
    my $v3_md5_UUID  = create_UUID(UUID_V3, $ns_uuid, $name_or_filehandle);
    my $v3_md5_UUID  = create_UUID(UUID_V3, $name_or_filehandle);
    my $v4_rand_UUID = create_UUID(UUID_V4);
    my $v5_sha1_UUID = create_UUID(UUID_V5, $ns_uuid $name_or_filehandle);
    my $v5_sha1_UUID = create_UUID(UUID_V5, $name_or_filehandle);

Creates a binary UUID in network byte order (MSB first). For v3 and v5 UUIDs a
C<SCALAR> (normally a string), C<GLOB> ("classic" file handle) or C<IO> object
(i.e. C<IO::File>) can be used; files have to be opened for reading.

I found no hint if and how UUIDs should be created from file content. It seems
to be undefined, but it is useful - so I would suggest to use UUID_NIL as the
namespace UUID, because no "real name" is used; UUID_NIL is used by default if
a namespace UUID is missing (only 2 arguments are used).

=cut

sub create_uuid {
    use bytes;
    my ($v, $arg2, $arg3) = (shift || UUID_V1, shift, shift);
    my $uuid    = UUID_NIL;
    my $ns_uuid = string_to_uuid(defined $arg3 ? $arg2 : UUID_NIL);
    my $name    = defined $arg3 ? $arg3 : $arg2;

    if ($v == UUID_V1) {
        # Create time and clock sequence ...
        my $timestamp = Time::HiRes::time();
        my $clk_seq   = _get_clk_seq($timestamp);

        # hi = time mod (1000000 / 0x100000000)
        my $hi = floor($timestamp / 65536.0 / 512 * 78125);
        $timestamp -= $hi * 512.0 * 65536 / 78125;
        my $low = floor($timestamp * 10000000.0 + 0.5);

        # MAGIC offset: 01B2-1DD2-13814000
        if ($low < 0xec7ec000) {
            $low += 0x13814000;
        }
        else {
            $low -= 0xec7ec000;
            $hi ++;
        }

        if ($hi < 0x0e4de22e) {
            $hi += 0x01b21dd2;
        }
        else {
            $hi -= 0x0e4de22e;  # wrap around
        }

        # Set time in UUID ...
        substr $uuid, 0, 4, pack('N', $low);                 # set time low
        substr $uuid, 4, 2, pack('n', $hi & 0xffff);         # set time mid
        substr $uuid, 6, 2, pack('n', ($hi >> 16) & 0x0fff); # set time high

        # Set clock sequence in UUID ...
        substr $uuid, 8, 2, pack('n', $clk_seq);

        # Set random node in UUID ...
        substr $uuid, 10, 6, _random_node_id();

        # Set version 1 in UUID ...
        substr $uuid, 6, 1, chr(ord(substr($uuid, 6, 1)) & 0x0f | 0x10);
    }
    elsif ($v == UUID_V3 || $v == UUID_V5) {
        # Create digest in UUID ...
        my $d = $v == UUID_V3 ? Digest::MD5->new()
              : $sha_api == 1 ? Digest::SHA->new(1)
              : $sha_api == 2 ? Digest::SHA1->new()
              : $sha_api == 3 ? Digest::SHA::PurePerl->new(1)
              : croak __PACKAGE__
                    . '::create_uuid(): No SHA-1 implementation available! '
                    . 'Please install Digest::SHA1, Digest::SHA or '
                    . 'Digest::SHA::PurePerl to use SHA-1 based UUIDs.'
              ;
        $d->reset();
        $d->add($ns_uuid);
        if (my $ref = ref $name) {
            croak __PACKAGE__
                . '::create_uuid(): Name for v3 or v5 UUID'
                . ' has to be SCALAR, GLOB or IO object!'
                    unless $ref =~ m/^(?:GLOB|IO::)/;
            $d->addfile($name);
        }
        else {
            croak __PACKAGE__
                . '::create_uuid(): Name for v3 or v5 UUID is not defined!'
                    unless defined $name;
            $d->add($name);
        }
        $uuid = substr($d->digest(), 0, 16); # Use only first 16 Bytes

        # Set version in UUID ...
        substr $uuid, 6, 1, chr(ord(substr($uuid, 6, 1))
            & 0x0f | ($v == UUID_V3 ? 0x30 : 0x50));
    }
    elsif ($v == UUID_V4) {
        # Create random value in UUID ...
        $uuid = '';
        for (1 .. 4) {
            $uuid .= pack 'I', _rand_32bit();
        }

        # Set version in UUID ...
        substr $uuid, 6, 1, chr(ord(substr($uuid, 6, 1)) & 0x0f | 0x40);
    }
    else {
        croak __PACKAGE__ . "::create_uuid(): Invalid UUID version '$v'!";
    }

    # Set variant 2 in UUID ...
    substr $uuid, 8, 1, chr(ord(substr $uuid, 8, 1) & 0x3f | 0x80);

    return $uuid;
}

*create_UUID = \&create_uuid;


=item B<create_UUID_as_string()>, B<create_uuid_as_string()> (:std)

Similar to C<create_UUID>, but creates a UUID string.

=cut

sub create_uuid_as_string {
    return uuid_to_string(create_uuid(@_));
}

*create_UUID_as_string = \&create_uuid_as_string;


=item B<is_UUID_string()>, B<is_uuid_string()> (:std)

    my $bool = is_UUID_string($str);

=cut

my $IS_UUID_STRING = qr/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/is;
my $IS_UUID_HEX    = qr/^[0-9a-f]{32}$/is;
my $IS_UUID_Base64 = qr/^[+\/0-9A-Za-z]{22}==$/s;

sub is_uuid_string {
    local $_ = shift;
    return m/$IS_UUID_STRING/;
}

*is_UUID_string = \&is_uuid_string;


=item B<UUID_to_string()>, B<uuid_to_string()> (:std)

    my $uuid_str = UUID_to_string($uuid);

This function returns C<$uuid> unchanged if it is a UUID string already.

=cut

sub uuid_to_string {
    my $uuid = shift;
    use bytes;
    return $uuid
        if $uuid =~ m/$IS_UUID_STRING/;
    croak __PACKAGE__ . "::uuid_to_string(): Invalid UUID!"
        unless length $uuid == 16;
    return  join q{-},
            map { unpack 'H*', $_ }
            map { substr $uuid, 0, $_, q{} }
            ( 4, 2, 2, 2, 6 );
}

*UUID_to_string = \&uuid_to_string;


=item B<string_to_UUID()>, B<string_to_uuid()> (:std)

    my $uuid = string_to_UUID($uuid_str);

This function returns C<$uuid_str> unchanged if it is a UUID already.

In addition to the standard UUID string representation and its URN forms
(starting with C<urn:uuid:> or C<uuid:>), this function accepts 32 digit hex
strings, variants with different positions of C<-> and Base64 encoded UUIDs.

Throws an exception if string can't be interpreted as a UUID.

If you want to make shure to have a "pure" standard UUID representation, check
with C<is_UUID_string>!

=cut

sub string_to_uuid {
    local $_ = shift;
    use bytes;
    return $_ if length $_ == 16;
    return decode_base64($_) if m/$IS_UUID_Base64/;
    my $str = $_;
    s/^(?:urn:)?(?:uuid:)?//io;
    tr/-//d;
    return pack 'H*', $_ if m/$IS_UUID_HEX/;
    croak __PACKAGE__ . "::string_to_uuid(): '$str' is no UUID string!";
}

*string_to_UUID = \&string_to_uuid;


=item B<version_of_UUID()>, B<version_of_uuid()> (:std)

    my $version = version_of_UUID($uuid);

This function accepts binary and string UUIDs.

=cut

sub version_of_uuid {
    my $uuid = shift;
    use bytes;
    $uuid = string_to_uuid($uuid);
    return (ord(substr($uuid, 6, 1)) & 0xf0) >> 4;
}

*version_of_UUID = \&version_of_uuid;


=item B<time_of_UUID()>, B<time_of_uuid()> (:std)

    my $uuid_time = time_of_UUID($uuid);

This function accepts UUIDs and UUID strings. Returns the time as a floating
point value, so use C<int()> to get a C<time()> compatible value.

Returns C<undef> if the UUID is not version 1.

=cut

sub time_of_uuid {
    local $_ = shift;
    use bytes;
    $_ = string_to_uuid($_);
    return unless version_of_uuid($_) == 1;
    
    my $low = unpack 'N', substr($_, 0, 4);
    my $mid = unpack 'n', substr($_, 4, 2);
    my $high = unpack('n', substr($_, 6, 2)) & 0x0fff;

    my $hi = $mid | $high << 16;

    # MAGIC offset: 01B2-1DD2-13814000
    if ($low >= 0x13814000) {
        $low -= 0x13814000;
    }
    else {
        $low += 0xec7ec000;
        $hi --;
    }

    if ($hi >= 0x01b21dd2) {
        $hi -= 0x01b21dd2;
    }
    else {
        $hi += 0x0e4de22e;  # wrap around
    }

    $low /= 10000000.0;
    $hi  /= 78125.0 / 512 / 65536;  # / 1000000 * 0x10000000

    return $hi + $low;
}

*time_of_UUID = \&time_of_uuid;


=item B<clk_seq_of_UUID()>, B<clk_seq_of_uuid()> (:std)

    my $uuid_clk_seq = clk_seq_of_UUID($uuid);

This function accepts UUIDs and UUID strings. Returns the clock sequence for a
version 1 UUID. Returns C<undef> if UUID is not version 1.

=cut

sub clk_seq_of_uuid {
    local $_ = shift;
    use bytes;
    $_ = string_to_uuid($_);
    return unless version_of_uuid($_) == 1;

    my $r = unpack 'n', substr($_, 8, 2);
    my $v = $r >> 13;
    my $w = ($v >= 6) ? 3 # 11x
          : ($v >= 4) ? 2 # 10-
          :             1 # 0--
          ;
    $w = 16 - $w;

    return $r & ((1 << $w) - 1);
}

*clk_seq_of_UUID = \&clk_seq_of_uuid;


=item B<equal_UUIDs()>, B<equal_uuids()> (:std)

    my $bool = equal_UUIDs($uuid1, $uuid2);

Returns true if the provided UUIDs are equal. Accepts UUIDs and UUID strings
(can be mixed).

=cut

sub equal_uuids {
    my ($u1, $u2) = @_;
    return unless defined $u1 && defined $u2;
    return string_to_uuid($u1) eq string_to_uuid($u2);
}

*equal_UUIDs = \&equal_uuids;


#
# Private functions ...
#

my $last_timestamp;
my $clk_seq;

sub _get_clk_seq {
    my $ts = shift;
    lock $last_timestamp;
    lock $clk_seq;

    $clk_seq = _generate_clk_seq() if !defined $clk_seq;

    if (!defined $last_timestamp || $ts <= $last_timestamp) {
        $clk_seq = ($clk_seq + 1) % 65536;
    }
    $last_timestamp = $ts;

    return $clk_seq & 0x03ff;
}

sub _generate_clk_seq {
    my $self = shift;

    my @data;
    push @data, q{}  . $$;
    push @data, q{:} . Time::HiRes::time();

    return _digest_as_16bit(@data);
}

sub _random_node_id {
    my $self = shift;

    my $r1 = _rand_32bit();
    my $r2 = _rand_32bit();

    my $hi = ($r1 >> 8) ^ ($r2 & 0xff);
    my $lo = ($r2 >> 8) ^ ($r1 & 0xff);

    $hi |= 0x80;

    my $id  = substr pack('V', $hi), 0, 3;
       $id .= substr pack('V', $lo), 0, 3;

    return $id;
}

# Seed rand only once per module load ...
#
my $seed;

sub _seed_rand {
    lock $seed;

    return if defined $seed;

    my @r;
    push @r, q{}  . Time::HiRes::time();
    push @r, q{:} . $$;
    push @r, join(q{:}, POSIX::uname());
    $seed = _digest_as_32bit(@r);

    srand($seed);

    return;
}

_seed_rand();

sub _rand_32bit {
    my $v1 = int(rand(65536)) % 65536;
    my $v2 = int(rand(65536)) % 65536;
    return ($v1 << 16) | $v2;
}

sub _fold_into_octets {
    use bytes;
    my ($num_octets, $s) = @_;

    my $x = "\x0" x $num_octets;

    while (length $s > 0) {
        my $n = q{};
        while (length $x > 0) {
            my $c = ord(substr $x, -1, 1, q{}) ^ ord(substr $s, -1, 1, q{});
            $n = chr($c) . $n;
            last if length $s <= 0;
        }
        $n = $x . $n;

        $x = $n;
    }

    return $x;
}

sub _digest_as_octets {
    my $num_octets = shift;

    my $d = Digest::MD5->new();
    $d->add($_) for @_;

    return _fold_into_octets($num_octets, $d->digest);
}

sub _digest_as_32bit {
    return unpack 'N', _digest_as_octets(4, @_);
}

sub _digest_as_16bit {
    return unpack 'n', _digest_as_octets(2, @_);
}

=back

=cut


=head1 DISCUSSION

=over

=item B<Why version 1 only with random multi-cast MAC addresses?>

The random multi-cast MAC address gives privacy, and getting the real MAC
address with Perl is really dirty (and slow);

=item B<Should version 3 or version 5 be used?>

Using SHA-1 reduces the probabillity of collisions and provides a better
"randomness" of the resulting UUID compared to MD5. Version 5 is recommended
in RFC 4122 if backward compatibility is not an issue.

Using MD5 (version 3) has a better performance. This could be important with
creating UUIDs from file content rather than names.

=back


=head1 UUID DEFINITION

See RFC 4122 (L<http://www.ietf.org/rfc/rfc4122.txt>) for technical details on
UUIDs.


=head1 AUTHOR

Much of this code is borrowed from UUID::Generator by ITO Nobuaki
E<lt>banb@cpan.orgE<gt>. But that module is announced to be marked as
"deprecated" in the future and it is much too complicated for my liking.

So I decided to reduce it to the necessary parts and to re-implement those
parts with a functional interface ...

Christian Augustin, C<< <mail at caugustin.de> >>


=head1 BUGS

Please report any bugs or feature requests to C<bug-uuid-tiny at rt.cpan.org>,
or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=UUID-Tiny>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc UUID::Tiny

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=UUID-Tiny>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/UUID-Tiny>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/UUID-Tiny>

=item * Search CPAN

L<http://search.cpan.org/dist/UUID-Tiny/>

=back


=head1 ACKNOWLEDGEMENTS

Kudos to ITO Nobuaki E<lt>banb@cpan.orgE<gt> for his UUID::Generator::PurePerl
module! My work is based on his code, and without it I would've been lost with
all those incomprehensible RFC texts and C codes ...

Thanks to Jesse Vincent for his feedback and tips.


=head1 COPYRIGHT & LICENSE

Copyright 2009 Christian Augustin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of UUID::Tiny
