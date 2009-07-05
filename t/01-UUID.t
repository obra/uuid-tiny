#!perl -T

use strict;
use warnings;
use Test::More 'no_plan';
use Carp;
use IO::File;
use MIME::Base64;

use UUID::Tiny;

#
# Pre-defined UUIDs ...
#
ok( equal_UUIDs(UUID_NIL,     '00000000-0000-0000-0000-000000000000'), 'NIL'  );
ok( equal_UUIDs(UUID_NS_DNS,  '6ba7b810-9dad-11d1-80b4-00c04fd430c8'), 'DNS'  );
ok( equal_UUIDs(UUID_NS_URL,  '6ba7b811-9dad-11d1-80b4-00c04fd430c8'), 'URL'  );
ok( equal_UUIDs(UUID_NS_OID,  '6ba7b812-9dad-11d1-80b4-00c04fd430c8'), 'OID'  );
ok( equal_UUIDs(UUID_NS_X500, '6ba7b814-9dad-11d1-80b4-00c04fd430c8'), 'X500' );

#
# is_UUID_string() ...
#
ok( is_UUID_string(UUID_to_string(UUID_NIL)), 'is_UUID_string($UUID_NIL)' );
ok( is_UUID_string(UUID_to_string(UUID_NS_URL)),
    'is_UUID_string() with URL UUID'
);
ok( 
    !is_UUID_string('6ba7b810-9dad-11d1-80b4-00c04fd430'),
    'is_UUID_string() with truncated UUID-string'
);

#
# UUID_to_string() and string_to_UUID() ...
#
is(
    UUID_to_string(UUID_NIL),
    '00000000-0000-0000-0000-000000000000',
    'UUID_to_string(UUID_NIL)',
);
is(
    UUID_to_string(UUID_NS_DNS),
    '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
    'UUID_to_string(UUID_NS_DNS)',
);
is(
    UUID_to_string(UUID_to_string(UUID_NS_URL)),
    UUID_to_string(UUID_NS_URL),
    'UUID_to_string with UUID string returns UUID string'
);
is(
    string_to_UUID(UUID_NS_OID),
    UUID_NS_OID,
    'string_to_UUID of UUID return UUID'
);

my $hex_UUID = UUID_to_string(UUID_NS_URL);
$hex_UUID =~ tr/-//;
is(
    string_to_UUID($hex_UUID),
    UUID_NS_URL,
    'string_to_UUID of hex string'
);

my $base64_UUID = encode_base64(UUID_NS_URL);
is(
    string_to_UUID($base64_UUID),
    UUID_NS_URL,
    'string_to_UUID of Base64 string'
);

is(
    string_to_UUID( 'urn:uuid:' . UUID_to_string(UUID_NS_DNS) ),
    UUID_NS_DNS,
    'string_to_UUID with URN string representation'
);

is(
    string_to_UUID( 'uuid:' . UUID_to_string(UUID_NS_DNS) ),
    UUID_NS_DNS,
    'string_to_UUID with shortened URN string representation'
);

is(
    string_to_UUID( 'URN:UUID:' . uc(UUID_to_string(UUID_NS_DNS)) ),
    UUID_NS_DNS,
    'string_to_UUID with all-uppercase URN string representation'
);

eval{ string_to_UUID( 'This is nonsense!' ) };
like( $@, qr/is no UUID string/, 'string_to_UUID with invalid string' );


#
# Create v3 UUIDs ...
#
is(
    create_UUID_as_string( UUID_V3, UUID_NS_DNS, 'python.org' ),
    '6fa459ea-ee8a-3ca4-894e-db77e160355e',
    'v3 UUID with DNS und python.org'
);
is(
    create_UUID_as_string( UUID_V3, UUID_NS_DNS, 'www.doughellmann.com' ),
    'bcd02e22-68f0-3046-a512-327cca9def8f',
    'v3 UUID test with www.doughellmann.com and DNS Namespace UUID'
);

my $test_data = do {
    local $/;
    open my $fh, '<', 't/data/test.jpg';
    <$fh>;
};

my $fh;
open $fh, '<', 't/data/test.jpg' or croak "Open failed!";
is(
    create_UUID_as_string( UUID_V3, $fh ),
    create_UUID_as_string( UUID_V3, $test_data ),
    'V3 UUID from GLOB'
);
undef $fh;

$fh = new IO::File 't/data/test.jpg' or croak 'IO::File failed.';
is(
    create_UUID_as_string( UUID_V3, $fh ),
    create_UUID_as_string( UUID_V3, $test_data ),
    'V3 UUID from IO::File'
);
undef $fh;

#
# Create v5 UUIDs ...
#
is(
    create_UUID_as_string( UUID_V5, UUID_NS_DNS, 'python.org' ),
    '886313e1-3b8a-5372-9b90-0c9aee199e5d',
    'v5 UUID with DNS und python.org'
);
is(
    create_UUID_as_string( UUID_V5, UUID_NS_DNS, 'www.doughellmann.com' ),
    'e3329b12-30b7-57c4-8117-c2cd34a87ce9',
    'v5 UUID test with www.doughellmann.com and DNS Namespace UUID'
);

open $fh, '<', 't/data/test.jpg' or croak "Open failed!";
is(
    create_UUID_as_string( UUID_V5, $fh ),
    create_UUID_as_string( UUID_V5, $test_data ),
    'V3 UUID from GLOB'
);
undef $fh;

$fh = new IO::File 't/data/test.jpg' or croak 'IO::File failed.';
is(
    create_UUID_as_string( UUID_V5, $fh ),
    create_UUID_as_string( UUID_V5, $test_data ),
    'V3 UUID from IO::File'
);
undef $fh;

is(
    create_UUID(UUID_V5, 'Ein Test-String.'),
    create_UUID(UUID_V5, UUID_NIL, 'Ein Test-String.'),
    'create_UUID without NS UUID'
);


#
# is_v1_UUID() and is_v5_UUID() ...
#
ok( version_of_UUID(UUID_NS_URL) == 1, 'is_v1_UUID with UUID' );
ok(
    version_of_UUID(string_to_UUID(UUID_NS_URL)) == 1,
    'is_v1_UUID with UUID string'
);
ok(
    version_of_UUID(
        string_to_UUID('e3329b12-30b7-57c4-8117-c2cd34a87ce9')) == 5,
    'is_v5_UUID with UUID'
);
ok(
    version_of_UUID('e3329b12-30b7-57c4-8117-c2cd34a87ce9') == 5,
    'is_v5_UUID with UUID string'
);

#
# Generate v1mc UUIDs ...
#
my $now = time();
my $v1_UUID = create_UUID();
ok( version_of_UUID($v1_UUID) == 1, 'create_UUID creates v1 UUID' );

# Check time_of_UUID() ...
my $uuid_time = int(time_of_UUID($v1_UUID));
ok( ($uuid_time == $now) || ($uuid_time == $now + 1), 'check time of UUID' );
is( time_of_UUID(UUID_NIL), undef, 'time_of_UUID($UUID_NIL) is undef' );
is(
    time_of_UUID($v1_UUID),
    time_of_UUID(UUID_to_string($v1_UUID)),
    'time_of_UUID with UUID and UUID string'
);

# Check clk_seq_of_UUID() ...
ok( defined clk_seq_of_UUID($v1_UUID), 'clk_seq_of_UUID works as expected' );
ok( !defined clk_seq_of_UUID(UUID_NIL), 'clk_seq_of_UUID of UUID NIL undef');
is(
    clk_seq_of_UUID($v1_UUID),
    clk_seq_of_UUID(UUID_to_string($v1_UUID)),
    'clk_seq_of_UUID with UUID and UUID string'
);

# Check equal_UUIDs() ...
ok( equal_UUIDs($v1_UUID, UUID_to_string($v1_UUID)), 'equal_UUIDs()' );
ok( !equal_UUIDs(UUID_to_string($v1_UUID), UUID_NS_URL), '!equal_UUIDs()' );

# Check if time advances as expected ...
sleep 1;
ok( $now < time_of_UUID(create_UUID()), 'check if time advances ...');

# Check for uniqueness of consecutive UUIDs ...
my %uuid;
my $prev_uuid;
for (my $i = 0; $i < 10000; $i++) {
    my $act_uuid = create_UUID();
    if (!exists $uuid{$act_uuid}) {
        $uuid{$act_uuid} = 1;
        if (defined $prev_uuid) {
            ok(
                (
                    (time_of_UUID($prev_uuid) < time_of_UUID($act_uuid))
                        && (clk_seq_of_UUID($prev_uuid)
                            == clk_seq_of_UUID($act_uuid))
                ) || (
                    (time_of_UUID($prev_uuid) >= time_of_UUID($act_uuid))
                        && (clk_seq_of_UUID($prev_uuid)
                            != clk_seq_of_UUID($act_uuid))
                ),
                'time advances or clk_seq is different'
            );
        }
        $prev_uuid = $act_uuid;
    }
    else {
        fail('Consecutive v1 UUIDs are not unique!');
    }
}


#
# Generate v4 UUIDs ...
#
my $v4_UUID = create_UUID(UUID_V4);
ok( version_of_UUID($v4_UUID) == 4, 'create_UUID creates v4 UUID' );

# Check for uniqueness of random UUIDs ...
my $not_unique = 0;
for (my $i = 0; $i < 100000; $i++) {
    my $act_uuid = create_UUID(UUID_V4);
    if (!exists $uuid{$act_uuid}) {
        $uuid{$act_uuid} = 1;
    }
    else {
        $not_unique = 1;
        last;
    }
}

ok( !$not_unique, '100.000 V4 UUIDs are unique!' ); 


