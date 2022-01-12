#!/usr/bin/perl
#
# This generates the daily guide slices.
#
# Copyright 2003 Dennis J. Boylan, dennis@lan.com
# released under the GNU GPL v2
#
# $Id: mkguideslices.pl,v 1.28 2004/05/30 19:31:51 ether Exp $
#

my($version) = "0.5";

use strict;
use Config::IniFiles 2.37;
use Date::Calc qw(Date_to_Days Add_Delta_Days Today);
use Getopt::Long;

sub date_calc (;$) {
    my($days) = @_;
    my($year,$month,$day,$epoch,$today,$diff);
    ($year,$month,$day) = Today();
    $epoch = Date_to_Days(1970,01,01);
    if (defined($days)) {
        ($year,$month,$day) = Add_Delta_Days($year,$month,$day,$days);
    }
    $today = Date_to_Days($year,$month,$day);
    $diff = $today-$epoch;
    return $diff;
}

MAIN:
{
    my($start) = time();
    my($cfg) = new Config::IniFiles(-file=>'tivo.conf',-nocase=>1);
    my($days) = $cfg->val("slices","days",7);
    my($dir) = $cfg->val("slices","directory");
    my($offset) = $cfg->val("slices","offset",0);
    my($grabber) = $cfg->val("slices","country","na");
    my($debug) = $cfg->val("debug","guide","none");
    my($verbose) = $cfg->val("config","verbose","1,2,3,4,5,6");
    my($path) = $cfg->val("slices","path");
    my($gdir) = $cfg->val("slices","guidedir");
    my($fillholes) = $cfg->val("slices","fillholes",0);
    my($useextractinfo) = $cfg->val("slices","useextractinfo",1);
    my($usesort) = $cfg->val("slices","usesort",1);
    my($usegrep) = $cfg->val("slices","usegrep",1);
    my($imdb) = $cfg->val("slices","useimdb",0);
    my($opt,@files,$i);
    my($quiet) = 0;
    my($stages) = "all";

    $path .= "/" if $path;

    # Get command-line options: these override tivo.conf.
    GetOptions('quiet' => \$quiet,
               'offset=s' => \$offset,
               'days=s' => \$days,
               'stages=s' => \$stages);
    $verbose = "none" if $quiet;

    my($cdat) = `date +%Y%m%d`; chomp $cdat;
    my($tdat) = date_calc();
    print "Today is $cdat ($tdat).\n";

    # This is the start date
    my($sdat) = date_calc($offset);

    # Determine whether days should increase and offset decrease,
    # to fill some earlier holes in the guide data.  We back up one
    # more day than you'd think would be necessary, so as to cover up
    # the 5-8 hour data hole that the last data grab left.
    if ($fillholes and 
        $cfg->val("slices","guidetype","xmltv") eq "parsexml")
    {
        # work backwards from the "start" date ($sdat)
        # and look for shows/ dirs (stop at "yesterday")
        until ($sdat == $tdat-1 or -d "$gdir/shows/${sdat}")
        {
            $days++;
            $offset--;
            $sdat--;
        }
    }

    print "Processing $days days, with offset $offset.\n";

    my($f) = "a";
    # Part 1: tv_grab
    if ($stages eq "all" or $stages =~ /1/)
    {
        print "Starting tv_grab_$grabber.\n\n";

        $opt = "--offset $offset" if $offset;
        $opt .= " --quiet" if ($verbose eq "none" or $verbose !~ /1/);
        system("${path}tv_grab_$grabber $opt --days $days --output $dir/$f$cdat.xml");
        unless (-e "$dir/$f$cdat.xml" and -s "$dir/$f$cdat.xml") {
            print STDERR "tv_grab_$grabber failure: no output\n";
            exit(1);
        }
    }

    # Part 2: tv_extractinfo_en
    if ($useextractinfo and ($stages eq "all" or $stages =~ /2/))
    {
        $opt = "";
        if ($verbose eq "none" or $verbose !~ /2/) {
            $opt = "2>/dev/null";
        } else {
            print "\nStarting tv_extractinfo_en.\n";
        }
        system("${path}tv_extractinfo_en --output $dir/b$cdat.xml $dir/$f$cdat.xml $opt");
        push @files,"$dir/$f$cdat.xml" if ($debug eq "none" || $debug !~ /2/);
	$f = "b";
        unless (-e "$dir/$f$cdat.xml" and -s "$dir/$f$cdat.xml") {
            print STDERR "tv_extractinfo_en failure: no output\n";
            exit(1);
        }
    }

    # Part 3: tv_sort
    if ($usesort and ($stages eq "all" or $stages =~ /3/))
    {
        $opt = "";
        if ($verbose eq "none" or $verbose !~ /3/) {
            $opt = "2>/dev/null";
        } else {
            print "\nStarting tv_sort.\n";
        }
        system("${path}tv_sort --output $dir/c$cdat.xml $dir/$f$cdat.xml $opt");
        push @files,"$dir/$f$cdat.xml" if ($debug eq "none" || $debug !~ /3/);
	$f = "c";
        unless (-e "$dir/$f$cdat.xml" and -s "$dir/$f$cdat.xml") {
            print STDERR "tv_sort failure: no output\n";
            exit(1);
        }
    }

    # Part 4: tv_grep
    if ($usegrep and ($stages eq "all" or $stages =~ /4/))
    {
        $opt = "";
        if ($verbose eq "none" or $verbose !~ /4/) {
            $opt = "2>/dev/null";
        } else {
            print "\nStarting tv_grep.\n";
        }
        system("${path}tv_grep --output $dir/d$cdat.xml --stop . $dir/$f$cdat.xml $opt");
        push @files,"$dir/$f$cdat.xml" if ($debug eq "none" || $debug !~ /4/);
	$f = "d";
        unless (-e "$dir/$f$cdat.xml" and -s "$dir/$f$cdat.xml") {
            print STDERR "tv_grep failure: no output\n";
            exit(1);
        }
    }

    # Part 5 (optional): tv_imdb
    if ($useimdb and ($stages eq "all" or $stages =~ /5/))
    {
        $opt = "";
        if ($verbose eq "none" or $verbose !~ /5/) {
            $opt = "--quiet";
        } else {
            print "\nStarting tv_imdb.\n";
        }
        my($imdbdir) = $cfg->val("slices","imdbdir");
        system("${path}tv_imdb --imdbdir $imdbdir --movies-only $opt --output $dir/e$cdat.xml $dir/$f$cdat.xml");
        push @files,"$dir/$f$cdat.xml" if ($debug eq "none" || $debug !~ /5/);
        $f = "e";
        unless (-e "$dir/$f$cdat.xml" and -s "$dir/$f$cdat.xml") {
            print STDERR "tv_imdb failure: no output\n";
            exit(1);
        }
    }

    # This is actually 1 day beyond the last day grabbed
    my($edat) = date_calc($days + $offset);

    # Part 6,7: xmltv or parsexml method
    if ($stages eq "all" or $stages =~ /[67]/)
    {
        print "\nNow generating slices for $days days (with offset $offset).\n";
        my($type) = $cfg->val("slices","guidetype","xmltv");
        if ($type eq "xmltv") {
            if ($stages eq "all" or $stages =~ /6/)
            {
                $opt = "";
                $opt = "2>/dev/null" if ($verbose eq "none" or $verbose !~ /6/);
                system("cd $gdir;./xmltv2tivo $dir/$f$cdat.xml >$dir/e$cdat.txt $opt");
                push @files,"$dir/$f$cdat.xml" if ($debug eq "none" || $debug !~ /6/);
                unless (-e "$dir/e$cdat.txt" and -s "$dir/e$cdat.txt") {
                    print STDERR "xmltv2tivo failure: no output\n";
                    exit(1);
                }
            }
            if ($stages eq "all" or $stages =~ /7/)
            {
                system("cd $gdir;./writeguide <$dir/e$cdat.txt >$cdat.slice");
                push @files,"$dir/e$cdat.txt" if ($debug eq "none" || $debug !~ /7/);
            }
        } elsif ($type eq "parsexml") {
            if ($stages eq "all" or $stages =~ /6/)
            {
                $opt = "";
                $opt = "--quiet" if ($verbose eq "none" or $verbose !~ /6/);
                print "Running parsexmlguide.\n";
                system("cd $gdir;./parsexmlguide.pl $opt -f $dir/$f$cdat.xml");
                push @files,"$dir/$f$cdat.xml" if ($debug eq "none" || $debug !~ /6/);
                print "\n";
            }

            if ($stages eq "all" or $stages =~ /7/)
            {
                # Determine whether fetching some days failed (will skip those)
                until($edat == $sdat or -d "$gdir/shows/" . ($edat-1)) {
                    print "Day " . ($edat-1) . " grab failed; skipping.\n";
                    $days--;
                    $edat--;
                }

                if ($days == 0)
                {
                    for $i (@files) { unlink($i); }
                    print "\nFailed to fetch any data. Done in ",
                        time() - $start, " seconds.\n";
                    exit(0);
                }

                print "Generating a $days day slice starting at $sdat.\n";
                $days--;
                if ($days > 0) {
                    system("cd $gdir;./mkslice $sdat+$days >$cdat.slice");
                } else {
                    system("cd $gdir;./mkslice $sdat >$cdat.slice");
                }
                $days++;
            }
        } else {
            print STDERR "$type not currently supported\n";
            exit(1);
        }
    }

    unless ($stages eq "all" or $stages =~ /7/)
    {
        for $i (@files) { unlink($i); }

        print "\nDone partial slice generation in ",
            time() - $start, " seconds.\n";
        exit(0);
    }

    unless (-e "$gdir/$cdat.slice" and -s "$gdir/$cdat.slice") {
        print STDERR "slice failure: no output\n";
        exit(1);
    }
    my($gzip) = $cfg->val("slices","usegzip",0);
    my($suffix) = ".slice";
    if ($gzip)
    {
        system("gzip --best $gdir/$cdat$suffix");
        $suffix .= ".gz";
        unless (-e "$gdir/$cdat$suffix" and -s "$gdir/$cdat$suffix") {
            print STDERR "gzip failure: no output\n";
            exit(1);
        }
    }
    my($sdir) = $cfg->val("config","slicedir");
    my($head) = $cfg->val("slices","headend");
    system("mv $gdir/$cdat$suffix $sdir/$head"."_$sdat-$edat$suffix");
    unless (-e "$sdir/$head"."_$sdat-$edat$suffix" and
            -s "$sdir/$head"."_$sdat-$edat$suffix") {
        print STDERR "mv failure: no output\n";
        exit(1);
    }
    my($group) = $cfg->val("slices","group");
    if (defined($group)) {
        system("chgrp $group $sdir/$head"."_$sdat-$edat$suffix");
    }
    for $i (@files) {
        unlink($i);
    }

    print "\nDone in ", time() - $start, " seconds.\n";
}
