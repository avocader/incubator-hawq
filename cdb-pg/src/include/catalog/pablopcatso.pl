#!/usr/bin/perl
#
# $Header$
#
# copyright (c) 2011
# Author: Jeffrey I Cohen
#
#
use POSIX;
use Pod::Usage;
use Getopt::Long;
use Data::Dumper;
use JSON;
use strict;
use warnings;

=head1 NAME

B<pablopcatso.pl> - generate graphs of catalog entries

=head1 SYNOPSIS

B<pablopcatso.pl> [options] <json file> 

Options:

    -help            brief help message
    -man             full documentation
	-direction       direction of graph
	-nocolor         black and white graph
	-nocluster       do not cluster tables from same header file
	-showfiles       if clustered, label each cluster with header file name
	-showcolumns     print column definitions for tables
	-filterunused    filter out unreferenced columns or tables
	-table           only graph the specified tables

=head1 OPTIONS

=over 8

=item B<-help>

    Print a brief help message and exits.

=item B<-man>
    
    Prints the manual page and exits.

=item B<-direction>

   Direction of graph.  Valid entries are:

=over 12

=item LR (default): left to right

=item RL: right to left

=item BT: bottom to top

=item TB: top to bottom

    
=back

=item B<-nocolor>

	Print graph in black and white only if set.

    Colors from www.ColorBrewer.org by Cynthia A. Brewer, 
	Geography, Pennsylvania State University.

=item B<-nocluster>

	Normally, each set of tables from the same parent header 
	file is clustered together (with an invisible boundary) 
	in the graph.  Setting this parameter removes clustering.


=item B<-showfiles>

	If clustering is enabled, label and outline each cluster 
	with the parent filename.

=item B<-showcolumns>

	Print each table as a record node that lists the columns

=item B<-filterunused>

	Filter the graph to only show the tables and columns 
	that shared a primary key/foreign key relationship.

=item B<-table>

Specify a table or set of tables to limit the size of the graph.  To
specify multiple tables, use multiple table arguments, eg:

  -table pg_class -table pg_operator


=back


=head1 DESCRIPTION

Some people try to plot out graphs and find it a hassle --
this does not happen with pablo p catso...

=head1 CAVEATS

	Well the girls would turn the color
	of the avocado when he would drive
	Down their street in his El Dorado

=head1 AUTHORS

Jeffrey I Cohen

Copyright (c) 2011 EMC.  All rights reserved.  

Address bug reports and comments to: jeffrey.cohen@emc.com


=cut

my $glob_id = "";

my $glob_dir;
my $glob_dosubgraph;
my $glob_doclusterfilename;
my $glob_filterunused;
my $glob_nocolumns;
my $glob_docolor;

my $glob_tabs;

my $glob_tmpdir = "/tmp";

my $GV_formats; # graphviz output formats

my %glob_coltab = (set312 => [
                              '#8DD3C7',
                              '#FFFFB3',
                              '#BEBADA',
                              '#FB8072',
                              '#80B1D3',
                              '#FDB462',
                              '#B3DE69',
                              '#FCCDE5',
                              '#D9D9D9',
                              '#BC80BD',
                              '#CCEBC5',
                              '#FFED6F'
                              ],
                   paired12 => [
                                '#a6cee3',
                                '#1f78b4',
                                '#b2df8a',
                                '#33a02c',
                                '#fb9a99',
                                '#e31a1c',
                                '#fdbf6f',
                                '#ff7f00',
                                '#cab2d6',
                                '#6a3d9a',
                                '#ffff99',
                                '#b15928'
                                ],
                   pastel19 => [
                                '#fbb4ae',
                                '#b3cde3',
                                '#ccebc5',
                                '#decbe4',
                                '#fed9a6',
                                '#ffffcc',
                                '#e5d8bd',
                                '#fddaec',
                                '#f2f2f2'
                                ],
                   pastel24 => [
                                '#b3e2cd',
                                '#fdcdac',
                                '#cbd5e8',
                                '#f4cae4',
                                '#e6f5c9',
                                '#fff2ae',
                                '#f1e2cc',
                                '#cccccc'
                                ],
                   set19 => [
                             '#e41a1c',
                             '#377eb8',
                             '#4daf4a',
                             '#984ea3',
                             '#ff7f00',
                             '#ffff33',
                             '#a65628',
                             '#f781bf',
                             '#999999'
                             ],
                   set28 => [
                             '#66c2a5',
                             '#fc8d62',
                             '#8da0cb',
                             '#e78ac3',
                             '#a6d854',
                             '#ffd92f',
                             '#e5c494',
                             '#b3b3b3'
                             ]
                   );


BEGIN {
    my $man				  = 0;
    my $help			  = 0;
	my $dir				  = "LR";
	my $nosubgraph		  = 0;
	my $doclusterfilename = 0;
	my $filterunused	  = 0;
	my $showcolumns		  = 0;
	my $nocolor			  = 0;
	my @tabs;

    $GV_formats = '^(jpg|bmp|ps|pdf|png)$';

    GetOptions(
               'help|?' => \$help, man => \$man, 
		'direction=s',
		'nocluster|nosubgraph' => \$nosubgraph,
		'showfiles' => \$doclusterfilename,
		'filterunused' => \$filterunused,
		'showcols|showcolumns' => \$showcolumns,
		'nocolor' => \$nocolor,
		'table:s' => \@tabs
               )
        or pod2usage(2);

    pod2usage(-msg => $glob_id, -exitstatus => 1) if $help;
    pod2usage(-msg => $glob_id, -exitstatus => 0, -verbose => 2) if $man;

	if ($dir !~ m/^(TB|BT|LR|RL)$/i)
    {
        $glob_dir = "LR";
    }
    else
    {
        $glob_dir = uc($dir);
    }

	$glob_dosubgraph = !($nosubgraph);
	$glob_doclusterfilename = $doclusterfilename;
	$glob_filterunused = $filterunused;
	$glob_nocolumns = !($showcolumns);
	$glob_docolor = !($nocolor);

	if (scalar(@tabs))
	{
		$glob_filterunused = 1;
		$glob_tabs = {};
		for my $t1 (@tabs)
		{
			$glob_tabs->{$t1} = 1;
		}

	}

#    print "loading...\n" ;
}

sub dograph
{
	my ($tabh, $dir) = @_;

	print "digraph g {\n\noverlap=false;rankdir=\"$dir\";\n";

	my $filh = {};

	my $refcols = {};
	my $reftabs = {};
	my $revreftabs = {};

	my @alledges;

	for my $kk (sort (keys (%{$tabh})))
	{
		next if ($kk =~ m/^\_\_/);

		my $vv = $tabh->{$kk};

		if (exists($vv->{filename}))
		{
			$filh->{$vv->{filename}} = []
				unless (exists($filh->{$vv->{filename}}));

			push @{$filh->{$vv->{filename}}}, $kk;
		}

		next unless (exists($vv->{foreign_keys}));

		for my $fkdef (@{$vv->{foreign_keys}})
		{
			my $fk1 = $fkdef->[0];
			my $t1  = $fkdef->[1];
			my $pk1 = $fkdef->[2];

			# save the fk
			$refcols->{$kk} = {} unless (exists($refcols->{$kk}));
			$refcols->{$kk}->{$fk1->[0]} = 1 
				unless (exists($refcols->{$kk}->{$fk1->[0]}));

			# save the pk
			$refcols->{$t1} = {} unless (exists($refcols->{$t1}));
			$refcols->{$t1}->{$pk1->[0]} = 1 
				unless (exists($refcols->{$t1}->{$pk1->[0]}));

			# save the table reference
			$reftabs->{$kk} = {} unless (exists($reftabs->{$kk}));
			$reftabs->{$kk}->{$t1} = 1 
				unless (exists($reftabs->{$kk}->{$t1}));
			$revreftabs->{$t1} = {} unless (exists($revreftabs->{$t1}));
			$revreftabs->{$t1}->{$kk} = 1 
				unless (exists($revreftabs->{$t1}->{$kk}));
		}

	} # end for my kk

#	print Data::Dumper->Dump([$refcols]);

	my $clusternum = 0;

	my $dosubgraph = $glob_dosubgraph;
	my $doclusterfilename = $glob_doclusterfilename;
	my $filterunused = $glob_filterunused;
	my $nocolumns = $glob_nocolumns;
	my $docolor = $glob_docolor;

	my @tablist = qw(
pg_class
pg_type
pg_proc
pg_operator
pg_authid
pg_namespace
pg_tablespace
);

	my $tabhue = {};

	my $tcount = 0;

	if ($docolor)
	{
		for my $t1 (@tablist)
		{
			$tabhue->{$t1} = "color=\"" . 
				$glob_coltab{set28}->[$tcount] . '"';
			$tcount++;
		}
	}

	for my $filnam (sort (keys (%{$filh})))
	{
		my $fildef = $filh->{$filnam};

		$clusternum++;

		if ($dosubgraph)
		{
			print "subgraph cluster_" . "$clusternum { \n ";

			if (!$doclusterfilename)
			{
				print "style=invis; \n";
			}
			else
			{
				print "style=filled;\n color=lightgrey;\n";
				print "node [style=filled,color=white];\n label = \"" . 
				$filnam . "\";\n";
			}
		}

		my %tab_only; # only print these tables if in glob_tab references

		for my $kk (@{$fildef})
		{
			my $vv = $tabh->{$kk};

			my @allcols;

			# check table filtering
			if ($glob_tabs)
			{
				my @checko;

				# find all tables referencing and referenced by this table
				push @checko, keys(%{$reftabs->{$kk}})
					if (exists($reftabs->{$kk}));
				push @checko, keys(%{$revreftabs->{$kk}})
					if (exists($revreftabs->{$kk}));

				push @checko, $kk;

				my $gotone = 0;

				# check for match in table filter
				for my $c1 (@checko)
				{
					if (exists($glob_tabs->{$c1}))
					{
						$gotone = 1;
						$tab_only{$kk} = 1;
						$tab_only{$c1} = 1;
						last;
					}
				}
				next unless ($gotone);
			}


			# put the name of the table as the first label
#			push @allcols, $kk . '\\n\\n';
			push @allcols, $kk;

			if (exists($vv->{with}) && 
				exists($vv->{with}->{oid}) &&
				$vv->{with}->{oid})
			{
				my $colstr = "<oid> oid Oid" . '\l';
				push @allcols, $colstr
					if (!$filterunused ||
						# check if column is a pk or fk
						(exists($refcols->{$kk}) &&
						 exists($refcols->{$kk}->{oid})));
			}

			for my $col (@{$vv->{cols}})
			{
				my $colstr =  "<" . $col->{colname} . ">" . $col->{colname}
				. " " . $col->{sqltype} . '\l';

				push @allcols, $colstr
					if (!$filterunused ||
						(exists($refcols->{$kk}) &&
						 exists($refcols->{$kk}->{$col->{colname}})));
			}

			# check if have any columns to print 
			if (scalar(@allcols) > 1)
			{
				my $colspec;

				$colspec = "";
				$colspec = $tabhue->{$kk} . " style=filled "
					if (exists($tabhue->{$kk}));

				if ($nocolumns)
				{
					$colspec = "[ " . $colspec . " ] "
						if (length($colspec));

					print "\n" . '"' . $kk . '" ' . $colspec .  " ;\n";
 
				}
				else
				{
					print "\n" . '"' . $kk . '" [' . 
#				"\nnodelabel = \"" . $kk . "\";\n" .
						"\nlabel = \"";

					print  join(" | ", @allcols)  . '"' . 
						"\nshape= \"record\"\n  $colspec ];\n";
				}
			} # end scalar allcols
		} # end for my kk fildef

		for my $kk (@{$fildef})
		{
			my $vv = $tabh->{$kk};

			next unless (exists($vv->{foreign_keys}));

			if ($glob_tabs)
			{
				# filter by tablename
				next unless (exists($tab_only{$kk}));
			}

			if ($nocolumns)
			{
				if (exists($reftabs->{$kk}))
				{
					for my $t1 (keys(%{$reftabs->{$kk}}))
					{
						my $colspec;

						if (!exists($tabhue->{$t1}))
						{
							$colspec = "";
						}
						else
						{
							$colspec = "[ " . $tabhue->{$t1} . " ] ";
						}

						push @alledges,  '"' . $kk . '" -> "' . 
							$t1 . '"' . " $colspec ;\n";
					}
				}
				
			}
			else
			{
				for my $fkdef (@{$vv->{foreign_keys}})
				{
					my $fk1 = shift @{$fkdef};
					my $t1  = shift @{$fkdef};
					my $pk1 = shift @{$fkdef};

					my $colspec;
					
					if (!exists($tabhue->{$t1}))
					{
						$colspec = "";
					}
					else
					{
						$colspec = "[ " . $tabhue->{$t1} . " ] ";
					}

					push @alledges, '"' . $kk . '":' . $fk1->[0] . ' -> "' . 
						$t1 . '":' . $pk1->[0] . " $colspec ;\n";
				}
			}
		} # end for my $kk

		if ($dosubgraph)
		{
			print "\n};\n\n" ; # end subgraph
		}
		push @alledges, "\n";

	} # end for filname

	print join("", @alledges);

	print "\n};\n\n" ; # end digraph

}

if (1)
{
	my $whole_file;

	{
        # $$$ $$$ undefine input record separator (\n")
        # and slurp entire file into variable

        local $/;
        undef $/;

		$whole_file = <>;
	}


	my $tabdefh = JSON::from_json($whole_file);

#	print Data::Dumper->Dump([$tabdefh]);

	dograph($tabdefh, $glob_dir);

}

exit();
