require 5.008;
use threads (); # just to force breakage if threads are not available
use ExtUtils::MakeMaker;

WriteMakefile (
 NAME		=> "Thread::Benchmark::Size",
 ($[ >= 5.005) ?
 (AUTHOR	=> 'Elizabeth Mattijsen (liz@dijkmat.nl)',
  ABSTRACT	=> 'report size of threads for different code approaches') : (),
 VERSION	=> '0.02',
 PREREQ_PM	=> {
		    Benchmark::Thread::Size => 0
                   },
);
