package Thread::Benchmark::Size;

# Make sure we have version info for this module
# Make sure we do everything by the book from now on

our $VERSION : unique = '0.01';
use strict;

# Satisfy -require-

1;

#---------------------------------------------------------------------------
#  IN: 1 class (ignored)
#      2..N parameter hash

sub import {

# Lose the class
# Obtain the parameters

    shift;
    my %param = @_;

# Obtain the number of times that we should execute
# Remove that parameter from the hash (just to make sure)
# Return now unless there is something to do

    my $times = $param{'times'} || '';
    delete( $param{'times'} );
    return unless keys %param;

# Initialize the test scripts

    _ramthread(); _ramthread1();

# For all of the pieces of code to check
#  Create the file or die
#  Write the code there
#  Close the handle or die

    while (my($file,$code) = each %param) {
        open( my $handle,'>',$file ) or die "Could not write $file: $!\n";
        print $handle $code;
        close( $handle ) or die "Could not close $file: $!\n";
    }

# Execute the test script
# Remove the test scripts from the face of the earth

    system( "$^X -w ramthread $times ".join( ' ',sort keys %param ) );
    unlink( qw(ramthread ramthread1),keys %param );
} #import

#---------------------------------------------------------------------------

# internal subroutines

#---------------------------------------------------------------------------

sub _ramthread {

# Attempt to create the main test script
# Write out the script

    open( my $out,'>','ramthread' ) or die "Could not initialize script: $!\n";
    print $out <<'RAMTHREAD';
# ramthread - test more than one piece of code
# - first parameter (optional): number of repetitions (default: 5)
# - other parameters: filenames with source code to test
#
my $times = ($ARGV[0] || '') =~ m#^(\d+)$# ? shift : 5;

my %code;
my %temp;
$/ = undef;
print STDERR "Performing each test $times times\n" if $times > 1;

foreach my $file (@ARGV) {
    print STDERR "$file ";
    open( my $code,'<',$file ) or die "Could not read $file: $!\n";
    $code{$file} = <$code>;
    close( $code );             # don't care whether successful

    foreach my $i (1..$times) {
        printf STDERR '%2d',$i;
        open( my $out,"$^X -w ramthread1 $file |" )
         or die "Could not test $file: $!\n";
        push( @{$temp{$file}},<$out> );
        close( $out ) or die "Could not close pipe for $file: $!\n";
        print STDERR "\b\b";
    }
    print STDERR "\n";
}

# normalize results of multiple runs of the same code approach

my %threads;
my %result;
while (my($file,$list) = each %temp) {
    my %t;
    foreach my $single (@{$list}) {
        foreach (split( "\n",$single )) {
	    s#^\s+##;
            my ($t,$ram) = split( m#\s+# );
            $t{$t} += $ram;
            $threads{$t} = 1;
        }
    }
    $t{$_} /= $times foreach keys %t;
    $result{$file} = \%t;
}

# print out the result summary

printf( "  #%9s%9s%9s%9s%9s%9s%9s%9s\n",@ARGV,'','','','','','','','' );
foreach my $t (sort {$a <=> $b} keys %threads) {
    printf '%3d',$t;
    foreach my $file (@ARGV) {
        printf '%9d',$result{$file}->{$t};
    }
    print "\n";
}

print "\n";
my $line = "==================================================================";
foreach (@ARGV) {
    my $header = $line;
    substr( $header,4,length($_)+2 ) = " $_ ";
    print <<EOD;
$header
$code{$_}
EOD
}
print "$line\n";
RAMTHREAD
} #_ramthread

#---------------------------------------------------------------------------

sub _ramthread1 {

# Attempt to create the sub test script
# Write out the script

    open( my $out,'>','ramthread1' ) or die "Could not initialize script: $!\n";
    print $out <<'RAMTHREAD1';
# ramthread1 - test a single piece of code for a varying number of threads.
#
# Source to be checked is specified as filename.
# Output memory sizes to STDOUT so that they can be compared.  Fields are:
#  1 number of threads
#  2 absolute size in Kb (as reported by ps)
#  3 relative size in Kb (size of process with 0 threads substracted)
#  4 size increase per thread in bytes (from the base size)

my %size;

my $file = shift or die "No filename specified\n";
open( my $in,'<',$file ) or die "Could not read source from $file: $!\n";
my $code = join( '',<$in> );
close( $in );

my $testfile = '_test_ramthread';
foreach my $threads (0,1,2,5,10,20,50,100) {
    printf STDERR '%4d',$threads;
    open( my $script,'>',$testfile ) or die "Could not open $testfile: $!\n";

# create the external script to be executed
    print $script <<EOD;
\$| = 1;               # make sure everything gets sent immediately
print "\$\$\\n";       # make sure parent knows the pid

use threads ();

$code                  # whatever was received from STDIN

for (\$i=0; \$i< $threads ; \$i++) {
  threads->new( sub {print "started\\n"; sleep( 86400 )} );
}
print "done\\n";
<>;                    # make sure it waits until killed
EOD

    close( $script ) or die "Could not close $testfile: $!\n";

    open( my $out,"$^X -w $testfile |" ) or die "Could not run $testfile: $!\n";
    chomp( my $pid = <$out> );
    my $started = 0;
    my $done = 0;
    while (<$out>) {
        $done++ if m#^done#;
        $started++ if m#^started#;
        last if $done and $started == $threads;
    }

# this may need tweaking on non-Linux systems
    my $size = 0;
    while (!$size and kill 0,$pid) {
        open( my $ps,"ps --no-heading -o rss $pid |" )
         or die "Could not ps: $!\n";
        chomp( $size = <$ps> || '' );
        close( $ps );       # don't care whether successful
    }
    $size{$threads} = $size;

    kill 9,$pid;        # not interested in cleanup, just speed
    close( $out );      # don't care whether successful
    unlink( $testfile );
    print STDERR "\b\b\b\b";
}

# print the report
my $base = $size{0};
my $diff;
foreach my $threads (sort {$a <=> $b} keys %size) {
    printf( "%3d %6d %6d %9d\n",
     $threads,
     $size{$threads},
     $diff = $size{$threads}-$base,
     $threads ? (1024 * $diff) / $threads : 0,
     );
}
RAMTHREAD1
} #_ramthread1

#---------------------------------------------------------------------------

=head1 NAME

Thread::Benchmark::Size - report size of threads for different code approaches

=head1 SYNOPSIS

  use Thread::Benchmark::Size times => 5, noexport => <<'E1', export => <<'E2';
  use threads::shared ();
  E1
  use threads::shared;
  E2

=head1 DESCRIPTION

                  *** A note of CAUTION ***

 This module only functions on Perl versions 5.8.0 and later.
 And then only when threads are enabled with -Dusethreads.  It
 is of no use with any version of Perl before 5.8.0 or without
 threads enabled.

                  *************************

The Thread::Benchmark::Size module allows you to check the effects of
different approaches to coding threaded application on the amount of RAM used.
One or more approaches can be checked at a time, each tested 5 times by
default.  Testing is done for 0, 1, 2, 5, 10, 20, 50 and 100 threads.  The
final report is sent to STDOUT.

This is an example report:

   #  shared0  shared1  shared2  shared3                                    
   0     2296     2304     2336     2340
   1     2824     2804     2852     2856
   2     3238     3208     3264     3280
   5     4428     4416     4492     4516
  10     6406     6412     6540     6588
  20    10378    10414    10636    10714
  50    22264    22404    22906    23098
 100    42090    42388    43348    43736
 
 ==== shared0 =====================================================
 use threads::shared ();
 
 ==== shared1 =====================================================
 use threads::shared;
 
 ==== shared2 =====================================================
 use threads::shared ();
 
 my $shared : shared;
 lock( $shared );
 threads::shared::cond_signal( $shared );
 
 ==== shared3 =====================================================
 use threads::shared;
 
 my $shared : shared;
 lock( $shared );
 cond_signal( $shared );
 
 ==================================================================

The sizes given are the numbers that were obtained from the system for the
size of the process.  This is usually in Kbytes but could be anything,
depending on how the information about the memory usage is obtained.

=head1 SUBROUTINES

There are no subroutines to call: all values need to be specified with the
C<use> command.

=head1 WHAT IT DOES

This module started life as just a number of scripts.  In order to facilitate
distribution I decided to bundle them together into this module.  So, what
does happen exactly when you execute this module?

=over 2

=item create ramthread

This is the main script that does the testing.  It collects the data that is
written out to STDOUT by ramthread1.

=item create ramthread1

This is the script that gets called for each seperate test.  It creates a
special test-script "_test_ramthread" for each test and each number of threads
to be checked (to avoid artefacts from previous runs in the same interpreter),
then measures the size of memory for each number of threads running
simultaneously and writes out the result to STDOUT.

=item create files for each piece of code

For several (historical) reasons, a seperate file is created for each piece of
code given.  These files are used by ramthread1 to measure the amount of memory
used.  The identification of the code is used as the filename, so be sure that
this will not overwrite stuff you might need later.

=item run ramthread

The ramthread script is then run with the appropriate parameters.  The output
is sent to STDERR (progress indication) and STDOUT (final report).

=item remove all files that were created

Then all of the files (including the ramthread and ramthread1 script) are
removed, so that no files are left behind.

=back

All files are created in the current directory.  This may not be the best
place, but it was the easiest thing to code.

=head1 HOW TO MEASURE SIZE?

Currently the size of the process is measured by doing a:

  ps --no-heading -o rss $pid

However, this may not be as portable as I would like.  If you would like to
use Thread::Benchmark::Size on your system and the above doesn't work, please
send me a string for your system that writes out the size of the given process
to STDOUT and the condition that should be used to determine that that string
should be used instead of the above default.

=head1 AUTHOR

Elizabeth Mattijsen, <liz@dijkmat.nl>.

Please report bugs to <perlbugs@dijkmat.nl>.

=head1 COPYRIGHT

Copyright (c) 2002 Elizabeth Mattijsen <liz@dijkmat.nl>. All rights
reserved.  This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Benchmark>.

=cut
