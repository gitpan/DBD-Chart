#23456789012345678901234567890123456789012345678901234567890123456789012345
#
# DBD::Chart::Plot -- Plotting engine for DBD::Chart
#
#	Copyright (C) 2001 by Dean Arnold <darnold@presicient.net>
#
#   You may distribute under the terms of the Artistic License, 
#	as specified in the Perl README file.
#
#	Change History:
#
#	0.52	2001-Dec-14		D. Arnold
#		fix for ymax in 2d bars
#
#	0.51	2001-Dec-01		D. Arnold
#		Support multicolor barcharts
#		Support 3D piecharts
#
#	0.50	2001-Oct-14		 D. Arnold
#		Add barchart, piechart engine
#		Add iconic barcharts, pointshapes
#		Add 3D, 3 axis barcharts
#		Add HTML imagemap generation
#		Increase axis label text length
#
#	0.43	2001-Oct-11		 P. Scott
#		Allow a 'gif' (or any future format supported by
#		GD::Image) format to be called in plot().
#
#	0.42	2001-Sep-29		Dean Arnold
#		- fixed xVertAxis handling for candlestick and symbolic domains
#
#	0.30	Jun 1, 2001		Dean Arnold
#		- fixed Y-axis tick problem when no grid used
#
#	0.20	Mar 10, 2001	Dean Arnold
#		- added logrithmic graphs
#		- added area graphs
#		- added image overlays
#
#	0.10	Feb 20, 2001	Dean Arnold
#		- Coded.
#
require 5.6.0;
package DBD::Chart::Plot;

$DBD::Chart::Plot::VERSION = '0.52';

use GD;
use strict;
#
#	list of valid colors
#
my @clrlist = qw(
	white lgray	gray dgray black lblue blue dblue gold lyellow	
	yellow	dyellow	lgreen	green dgreen lred red dred lpurple	
	purple dpurple lorange orange pink dpink marine	cyan	
	lbrown dbrown );
#
#	RGB of valid colors
#
my %colors = (
	white	=> [255,255,255], 
	lgray	=> [191,191,191], 
	gray	=> [127,127,127],
	dgray	=> [63,63,63],
	black	=> [0,0,0],
	lblue	=> [0,0,255], 
	blue	=> [0,0,191],
	dblue	=> [0,0,127], 
	gold	=> [255,215,0],
	lyellow	=> [255,255,0], 
	yellow	=> [191,191,0], 
	dyellow	=> [127,127,0],
	lgreen	=> [0,255,0], 
	green	=> [0,191,0], 
	dgreen	=> [0,127,0],
	lred	=> [255,0,0], 
	red		=> [191,0,0],
	dred	=> [127,0,0],
	lpurple	=> [255,0,255], 
	purple	=> [191,0,191],
	dpurple	=> [127,0,127],
	lorange	=> [255,183,0], 
	orange	=> [255,127,0],
	pink	=> [255,183,193], 
	dpink	=> [255,105,180],
	marine	=> [127,127,255], 
	cyan	=> [0,255,255],
	lbrown	=> [210,180,140], 
	dbrown	=> [165,42,42],
	transparent => [1,1,1]
);
#
#	pointshapes
#
my %shapes = (
'fillsquare', 1,
'opensquare', 2,
'horizcross', 3,
'diagcross', 4,
'filldiamond', 5,
'opendiamond', 6,
'fillcircle', 7,
'opencircle', 8,
'icon', 9);
#
#	logarithmic steps for axis scaling
#
my @logsteps = (0, log(2)/log(10), log(3)/log(10), log(4)/log(10), 
	log(5)/log(10), 1.0);
#
#	index of vertex pts for 3-D barchart
#	polygonal visible faces
#
my @polyverts = ( 
[ 1*2, 2*2,	3*2, 4*2 ],	# top face
[ 0*2, 1*2, 4*2, 5*2 ],	# front face
[ 4*2, 3*2, 6*2, 5*2 ]	# side face
);
#
# indices of 3-D projection vertices
#	mapped to line segments
#
my @vert2lines = (
1*2, 4*2, 	# top front l-r
0*2, 1*2,	# left front b-t
0*2, 5*2,	# bottom front l-r
4*2, 5*2,	# right front b-t
1*2, 2*2,	# top left f-r
2*2, 3*2,	# top rear l-r
3*2, 4*2,   # right top r-f
3*2, 6*2,   # right rear t-b
5*2, 6*2,   # right bottom r-f
);

#
#	indices of 3-D projection of axes planes
#
my @axesverts = (
	0*2, 1*2,	# left wall
	1*2, 3*2,
	3*2, 2*2,
	2*2, 0*2,
		
# rear wall
	3*2, 6*2,	# trl to trr
	6*2, 5*2,	# trr to brr
	5*2, 1*2,	# brr to brl

# floor		
	9*2, 10*2,	# brr to brl
	10*2, 7*2,	# brl to brf
	
	9*2, 8*2,	# brr to brf
	7*2, 8*2,	# blf to brf
);
#
#	font sizes
#
my ($sfw,$sfh) = (gdSmallFont->width, gdSmallFont->height);
my ($tfw,$tfh) = (gdTinyFont->width, gdTinyFont->height);

my %valid_attr = qw(
	width 1
	height 1
	genMap 1
	mapType 1
	mapURL 1
	mapScript 1
	horizMargin 1
	vertMargin 1
	xAxisLabel 1
	yAxisLabel 1
	zAxisLabel 1
	xLog 1
	yLog 1
	zLog 1
	title 1
	signature 1
	legend 1
	showValues 1
	horizGrid 1
	vertGrid 1
	xAxisVert 1
	keepOrigin 1
	bgColor 1
	threed 1
	icons 1
	symDomain 1
	timeDomain 1
	gridColor 1
	textColor 1
	font 1
	logo 1
);
my @lines = ( 
[ 0*2, 4*2,	5*2, 1*2 ],	# top face
[ 0*2, 1*2, 3*2, 2*2 ],	# front face
[ 1*2, 5*2, 7*2, 3*2 ]	# side face
);
#
#	URI escape map
#
my %escapes = ();
for (0..255) {
    $escapes{chr($_)} = sprintf("%%%02X", $_);
}

sub new {
    my $class = shift;
    my $obj = {};
    bless $obj, $class;
    $obj->init (@_);

    return $obj;
}
#
#	Plot object members:
#
#	img - GD::Image object
#	width - image width in pixels
#	height - image height in pixels
#	signature - signature string
#	genMap - 1 => generate HTML imagemap
#	horizMargin - image horizontal margins in pixels
#	vertMargin - image vertical margins in pixels
#	data - data points to be plotted
#	props - graph properties
#	plotCnt - number of plots in graph
#	xl, xh, yl, yh, zl, zh - min/max of each axis
#	xscale, yscale, zscale - scaling factors for assoc. axis
#	horizEdge, vertEdge - horizontal/vertical edge location
#	horizStep, vertStep - horizontal/vertical pixel increment
#	haveScale - calculated min/max is valid
#	xAxisLabel, yAxisLabel, zAxisLabel - label for assoc. axis
#	title - title string
#	xLog, yLog, zLog - 1 => assoc axis is logarithmic
#	errmsg - last error msg
#	keepOrigin - force (0,0[,0]) into graph
#	imgMap - HTML imagemap text
#	symDomain - 1 => domain is symbolic
#	timeDomain - 1 => domain is temporal
#	icon - name of icon image file for iconic barcharts
#	logo - name of background logo image file
#
sub init {
	my ($obj, $w, $h) = @_;

	$w = 400 unless $w;
	$h = 300 unless $h;
	my $img = new GD::Image($w, $h);
	
	my $white = $img->colorAllocate(@{$colors{white}});
	my $black = $img->colorAllocate(@{$colors{black}}); 

	$obj->{width} = $w;
	$obj->{height} = $h;
	$obj->{img} = $img;

# imagemap attributes
  	$obj->{genMap} = undef;	# name of map
  	$obj->{imgMap} = '';		# contains resulting map text
  	$obj->{mapType} = 'HTML';	# default HTML
  	$obj->{mapURL} = '';		# base URL for hotspots
  	$obj->{mapScript} = '';	# base script call for hotspots
  		
# image margins
	$obj->{horizMargin} = 50;
	$obj->{vertMargin} = 70;

# create an empty array for point arrays and properties
	$obj->{data} = [ ];
	$obj->{props} = [ ];
	$obj->{plotCnt} = 0;

# used for pt2pxl()
	$obj->{xl} = undef;
	$obj->{xh} = undef;
	$obj->{yl} = undef;
	$obj->{yh} = undef;
	$obj->{zl} = undef;
	$obj->{zh} = undef;
	$obj->{xscale} = 0;
	$obj->{yscale} = 0;
	$obj->{zscale} = 0;
	$obj->{horizEdge} = 0;
	$obj->{vertEdge} = 0;
	$obj->{horizStep} = 0;
	$obj->{vertStep} = 0;
	$obj->{Xcard} = 0;		# cardinality of 3-axis barcharts
	$obj->{Zcard} = 0;
	$obj->{plotWidth} = 0;	# true plot width; height; depth
	$obj->{plotHeight} = 0;
	$obj->{plotDepth} = 0;
	$obj->{brushWidth} = 0; # width of bars or candlesticks
	$obj->{brushDepth} = 0;
	$obj->{rangeSum} = 0;	# running total for piecharts
	$obj->{haveScale} = 0;	# 1} = last calculated min & max still valid

# axis label strings
	$obj->{xAxisLabel} = '';
	$obj->{yAxisLabel} = '';
	$obj->{zAxisLabel} = '';

	$obj->{xLog} = 0;		# 1 => log10 scaling
	$obj->{yLog} = 0;
	$obj->{zLog} = 0;

	$obj->{title} = '';
	$obj->{signature} = '';
	$obj->{legend} = 0; 	# 1 => render legend
	$obj->{showValues} = 0; # 1 => print datapoint values
	$obj->{horizGrid} = 0;	# 1 => print y-axis gridlines
	$obj->{vertGrid} = 0;	# 1 => print x-axis gridlines
	$obj->{xAxisVert} = 0;	# 1 => print x-axis label vertically
	$obj->{errmsg} = '';	# error result of last operation
	$obj->{keepOrigin} = 0; # 1 => force origin into graph
	$obj->{threed} = 0;		# 1 => use 3-D effect
	$obj->{logo} = undef;
		
	$obj->{icons} = [ ];	# array of icon filenames
		
	$obj->{symDomain} = 0;	# 1 => use symbolic domain
	$obj->{timeDomain} = undef; # defines format of temporal domain labels

#  allocate some oft used colors
	$obj->{white} = $white;
	$obj->{black} = $black; 
	$obj->{transparent} = $img->colorAllocate(@{$colors{'transparent'}});

#	for now these aren't used, but someday we'll let them be configured
	$obj->{bgColor} = $white; # background color
	$obj->{gridColor} = $black;
	$obj->{textColor} = $black;
	$obj->{font} = 'gd';

# set image basic properties
	$img->transparent($obj->{transparent});
	$img->interlaced('true');
	$img->rectangle( 0, 0, $w-1, $h-1, $obj->{black});
}

#
#	compare function for numeric sort
#
sub numerically { $a <=> $b }

sub setCandlePoints {
	my ($obj, $xary, @ranges) = @_;
	my $props = pop @ranges;
	my ($xmin, $ymin, $xmax, $ymax) = 
		($obj->{xl}, $obj->{yl}, $obj->{xh}, $obj->{yh});

	my $num_ranges = @ranges;
	$obj->{errmsg} = 'Missing a min or max range array.', return undef
		if ($num_ranges != 2);

	my $baseary = ($obj->{data}) ? $obj->{data}->[0] : undef;
	$obj->{errmsg} = 'Domain does not match prior domain.', return undef
		if ($baseary && ((3 * scalar @$xary) != scalar @$baseary));

	foreach my $yary (@ranges) {
		$obj->{errmsg} = 'Unbalanced dataset.',
		return undef
			if ($#$xary != $#$yary);
	}

	my @ary = ();
	my $yaryl = $ranges[0];
	my $yaryh = $ranges[1];
	my $i = 0;
	for ($i = 0; $i <= $#$xary; $i++) {
#
#	eliminate undefined data points
#
		next unless defined($$xary[$i]);
#
#	domains must match
#
		$obj->{errmsg} = 'Domain value ' . $$xary[$i] .
			' does not match previous dataset.', 
		return undef
			if ($baseary && ($$xary[$i] ne $$baseary[$i*3]));
#
#	store datapts as 
#	($xval[0], [ ylow[0], yhi[0] ],...$xval[M], [ ylow[M], yhi[M] ])
#
		my ($yl, $yh) = (0, 0);
		push(@ary, $$xary[$i]);
		
		push(@ary, undef, undef),
		next 
			unless (defined($$yaryl[$i]) && defined($$yaryh[$i]));

		$obj->{errmsg} = 'Non-numeric range value ' . $$yaryl[$i] . '.',
		return undef
			unless ($$yaryl[$i]=~/^[+-]?\.?\d+\.?\d*([Ee][+-]?\d+)?$/);

		$obj->{errmsg} = 'Non-numeric range value ' . $$yaryh[$i] . '.',
		return undef
			unless ($$yaryh[$i]=~/^[+-]?\.?\d+\.?\d*([Ee][+-]?\d+)?$/);
		
		$obj->{errmsg} = 'Range min value greater than range max value.',
		return undef
			if ($$yaryl[$i] > $$yaryh[$i]);
			
		$obj->{errmsg} = 
			'Negative value supplied for logarithmic axis.',
		return undef
			if ($obj->{yLog} && (($$yaryl[$i] <= 0) || 
					($$yaryh[$i] <= 0)));

		$yl = ($obj->{yLog} ? log($$yaryl[$i])/log(10) : $$yaryl[$i]);
		$yh = ($obj->{yLog} ? log($$yaryh[$i])/log(10) : $$yaryh[$i]);
		$ymin = $yl unless (defined($ymin) && ($ymin <= $yl));
		$ymax = $yh unless (defined($ymax) && ($ymax >= $yh));
		push(@ary, $yl, $yh);
	} # end for
# record the dataset; use stack to support future multi-graph images
	push(@{$obj->{data}}, \@ary);
	push(@{$obj->{props}}, $props);
#
#	set min/max range values here, and the width of the sticks
#
	$obj->{xl} = 1;
	$obj->{xh} = $i;
	$obj->{yl} = $ymin;
	$obj->{yh} = $ymax;
	$obj->{brushWidth} = 2;
	$obj->{haveScale} = 0; # invalidate any prior min-max calculations
	return 1;
}

sub set3DBarPoints {
	my ($obj, $xary, $yary, $zary, $props) = @_;
	my ($ymin, $ymax) = ($obj->{yl}, $obj->{yh});
#
#	verify:
#		2 range sets if 3-axis
#		each rangeset has same number of elements as domain
#
	my $hasZaxis = ($obj->{zAxisLabel});
	
	$obj->{errmsg} = '3-axis chart requires 2 ranges.', 
	return undef
		if ($hasZaxis && (! $props));

	$props = $zary, $zary = undef
		unless $hasZaxis;

	my @zs = ();
	my %zhash = ();
	my %xhash = ();
	my @xs = ();
	my ($xval, $zval) = (0,1);
	my $i = 0;
	if ($hasZaxis) {

		$obj->{errmsg} = 'Unbalanced dataset.',
		return undef
			if (($#$xary != $#$yary) || ($#$xary != $#$zary));
#
#	collect distinct Z and X values, and correlate them
#	with the assoc. Y value via hashes
#
		for ($i = 0; $i <= $#$zary; $i++) {
			$zval = $$zary[$i];
			push(@zs, $zval),
			$zhash{$zval} = { }
				unless $zhash{$zval};
			$zhash{$zval}->{$$xary[$i]} = $$yary[$i];
		}
		for ($i = 0; $i <= $#$xary; $i++) {
			$xval = $$xary[$i];
			next if $xhash{$xval};
			push(@xs, $xval);
			$xhash{$xval} = 1;
		}
	}
	else {
		$obj->{errmsg} = 'Unbalanced dataset.',
		return undef
			if ($#$xary != $#$yary);
#
#	synthesize Z axis values so we can process same as true 3 axis
#
		push(@zs, 1);
		$zhash{1} = { };
		for ($i = 0; $i <= $#$xary; $i++) {
			$zhash{1}->{$$xary[$i]} = $$yary[$i];
		}
		for ($i = 0; $i <= $#$xary; $i++) {
			$xval = $$xary[$i];
			next if $xhash{$xval};
			push(@xs, $xval);
			$xhash{$xval} = 1;
		}
	}
	$obj->{zValues} = \@zs;
	$obj->{xValues} = \@xs;
#
#	sort datapoints in order Z from back to front,
#		X from left to right
#	(i.e., GROUP BY Z, X ORDER BY Z DESCENDING, X ASCENDING)
#	the order of appearance in the input arrays determines
#	what "front, back, left, and right" mean
#
#	Since X and Z are always symbolic, we generate numeric pseudo values
#	for them based on order of appearance in the input arrays
#
	my $zCard = scalar @zs;	# go from last Z value forward
	my $xCard = scalar @xs;
	my ($znum, $xnum, $y) = (0,0,0);
	my @ary = ();
	for (my $z = $zCard; $z > 0; $z--) {
		foreach my $x (1..$xCard) {
			$y = $zhash{$zs[$z-1]}->{$xs[$x-1]};
#
#	data is stored in output array as (X, Ymin, Ymax, Z, ...)
#
			$obj->{errmsg} = "Non-numeric range value $y.",
			return undef
				unless ($y=~/^[+-]?\.?\d\d*(\.\d*)?([Ee][+-]?\d+)?$/);
		
			$obj->{errmsg} = 
				'Negative value supplied for logarithmic axis.',
			return undef
				if (($obj->{yLog}) && ($y <= 0));

			$y = log($y)/log(10) if ($obj->{yLog});
			$ymin = $y unless (defined($ymin) && ($ymin <= $y));
			$ymax = $y unless (defined($ymax) && ($ymax >= $y));
			push(@ary, $x, ($y >= 0) ? 0 : $y, ($y < 0) ? 0 : $y, $z);
		}
	}
# record the dataset; use stack to support future multi-graph images
	push(@{$obj->{data}}, \@ary);
	push(@{$obj->{props}}, $props);
	$obj->{xl} = 1;
	$obj->{xh} = $xCard;
	$obj->{yl} = $ymin;
	$obj->{yh} = $ymax;
	$obj->{zl} = 1;
	$obj->{zh} = $zCard;
	$obj->{Xcard} = $xCard;
	$obj->{Zcard} = $zCard;
	$obj->{haveScale} = 0;	# invalidate prior min-max calculations

	return 1;
}

#
#	2-Axis barchart
#
sub set2DBarPoints {
	my ($obj, $xary, $yary, $props) = @_;

	my $baseary = ($obj->{data}) ? $obj->{data}->[0] : undef;
	$obj->{errmsg} = 'Domain does not match prior domain.', 
	return undef
		if ($baseary && ((3 * scalar @$xary) != scalar @$baseary));

	$obj->{errmsg} = 'Unbalanced dataset.',
	return undef
		if ($#$xary != $#$yary);

	my ($x, $y) = (0,0);
	my @ary = ();
	my ($i, $ymin, $ymax);
	$ymin = $obj->{yl}, $ymax = $obj->{yh}
		if $baseary;

	for ($i = 0; $i <= $#$xary; $i++) {
#
#	eliminate undefined data points
#
		next unless defined($$xary[$i]);
#
#	domains must match
#
		$x = $$xary[$i];
		$y = $$yary[$i];
		$obj->{errmsg} = 'Domain value ' . $x . 
			' does not match previous dataset.', 
		return undef
			if ($baseary && ($x ne $$baseary[$i*3]));
#
#	store datapts as same as candlesticks w/ pseudo min (or max)
#	($xval[0], 0, yval[0])
#
		push(@ary, $x);
		push(@ary, undef),
		next 
			unless defined($y);

		$obj->{errmsg} = "Non-numeric range value $y.";
		return undef
			unless ($y =~ /^[+-]?\.?\d+\.?\d*([Ee][+-]?\d+)?$/);
		
		$obj->{errmsg} =
			'Negative value supplied for logarithmic axis.',
		return undef
			if (($obj->{yLog}) && ($y <= 0));

		$y = $obj->{yLog} ? log($y)/log(10) : $y;
		$ymin = $y unless (defined($ymin) && ($ymin <= $y));
		$ymax = $y unless (defined($ymax) && ($ymax >= $y));
		push(@ary, ($y >= 0) ? 0 : $y, ($y < 0) ? 0 : $y);
	}
# record the dataset; use stack to support future multi-graph images
	push(@{$obj->{data}}, \@ary);
	push(@{$obj->{props}}, $props);
	
	$obj->{xl} = 1;
	$obj->{xh} = $i;
	$obj->{yl} = $ymin;
	$obj->{yh} = $ymax;
	$obj->{haveScale} = 0;	# invalidate any prior min-max calculations

}

sub setPiePoints {
	my ($obj, $xary, $yary, $props) = @_;
		
	my @ary = ();
	$obj->{errmsg} = 'Unbalanced dataset.',
	return undef
		if ($#$xary != $#$yary);
	
	my $xtotal = 0;
	for (my $i = 0; $i <= $#$xary; $i++) {
		$obj->{errmsg} = 
			'Negative range values not permitted for piecharts.',
		return undef
			if ($$yary[$i] < 0);

		push(@ary, $$xary[$i], $$yary[$i]);
		$xtotal += $$yary[$i];
	}
	push(@{$obj->{data}}, \@ary);
	push(@{$obj->{props}}, $props);
	$obj->{rangeSum} = $xtotal;
	$obj->{haveScale} = 0; # invalidate any prior min-max calculations
	return 1;
}

sub setBoxPoints {
	my ($obj, $xary, $props) = @_;
	my @ary = sort numerically @$xary;
	my ($xl, $xh) = ($obj->{xl}, $obj->{xh});
	push(@{$obj->{data}}, \@ary);
	push(@{$obj->{props}}, $props);
	$obj->{xl} = $ary[0] 
		unless (defined($xl) && ($ary[0] > $xl));
	$obj->{xh} = $ary[$#ary] 
		unless (defined($xh) && ($ary[$#ary] < $xh));
#
#	create dummy Y bounds
#
	$obj->{yl} = 1;
	$obj->{yh} = 100 * (scalar(@{$obj->{data}}));

	$obj->{numRanges} = 0;
	$obj->{haveScale} = 0; # invalidate any prior min-max calculations
	return 1;
}
#
#	variable arglist:
#
#	for line/point/area graphs, 2-axis barcharts:
#		setPoints($plotobj, \@xarray, \@yarray1, $props)
#	for 3-axis barcharts, surfacemaps:
#		setPoints($plotobj, \@xarray, \@yarray, \@zarray, $props)
#	for candlesticks, barcharts:
#		setPoints($plotobj, \@xarray, \@ylow, \@yhigh, $props)
#	for piecharts:
#		setPoints($plotobj, \@xarray, \@yarray, $props)
#	for box&whisker:
#		setPoints($plotobj, \@xarray, $props)
#	for Gantt:
#		setPoints($plotobj, \@tasks, \@assigned, \@dependents, \@start,
#			\@end, \@status, \@comment, $props)
#
#	NOTE: graph type properties must be set prior to setting graph points
#	Each domain/rangeset must be separately defined with its properties
#	(e.g., a barchart with N domains requires N setPoints calls)
#
sub setPoints {
	my ($obj, $xary, @ranges) = @_;
	my $props = pop @ranges;

	return $obj->setCandlePoints($xary, @ranges, $props)
		if ($props=~/\bcandle\b/);

	return $obj->set3DBarPoints($xary, @ranges, $props)
		if (($props=~/\bbar\b/) && ($obj->{zAxisLabel} || $obj->{threed}));

	return $obj->set2DBarPoints($xary, @ranges, $props)
		if ($props=~/\bbar\b/);

	return $obj->setPiePoints($xary, @ranges, $props)
		if ($props=~/\bpie\b/);

	return $obj->setBoxPoints($xary, @ranges, $props)
		if ($props=~/\bbox\b/);
#
#	must be line/point/area, verify ranges have same num of elements
#	as domain
#
	my $yary = $ranges[0];

	$obj->{errmsg} = 'Unbalanced dataset.',
	return undef
		if ($#$xary != $#$yary);

	my @ary = ();
	my %xhash = ();
	my $i;
	my ($x, $y) = (0,0);
	my ($xmin, $xmax, $ymin, $ymax) = 
		($obj->{xl}, $obj->{xh}, $obj->{yl}, $obj->{yh});
	for ($i = 0; $i <= $#$xary; $i++) {
#
#	eliminate undefined data points
#
		next unless (defined($$xary[$i]) && defined($$yary[$i]));
		
		$x = $$xary[$i];
		$obj->{errmsg} = "Non-numeric domain value $x.",
		return undef
			unless ($obj->{symDomain} ||
				($x=~/^[+-]?\.?\d+\.?\d*([Ee][+-]?\d+)?$/));

		$y = $$yary[$i];
		$obj->{errmsg} = "Non-numeric range value $y.",
		return undef
			if ($y!~/^[+-]?\.?\d+\.?\d*([Ee][+-]?\d+)?$/);
		
		$obj->{errmsg} = 'Negative value supplied for logarithmic axis.',
		return undef
			unless (
				($obj->{symDomain} || (! $obj->{xLog}) || ($x > 0)) &&
				((! $obj->{yLog}) || ($y > 0)));

		$y = $obj->{yLog} ? log($y)/log(10) : $y;
		$ymin = $y unless (defined($ymin) && ($ymin <= $y));
		$ymax = $y unless (defined($ymax) && ($ymax >= $y));

		push(@ary, $x, $y), next
			if ($obj->{symDomain});

		$xhash{$x} = $y;
	}
#
#	make sure domain values are in ascending order
#
	if (! $obj->{symDomain}) {
		my @xsorted = sort numerically keys(%xhash);

		foreach $i (@xsorted) {
#
#	if either xLog or yLog is defined, apply to appropriate dataset now
#
			$x = $obj->{xLog} ? log($i)/log(10) : $i;
			$xmin = $x unless (defined($xmin) && ($xmin <= $x));
			$xmax = $x unless (defined($xmax) && ($xmax >= $x));
			push(@ary, $x, $xhash{$i});
		}
	}
	else {
		$xmin = 0;
		$xmax = $i;
	}
# record the dataset
	push(@{$obj->{data}}, \@ary);
	push(@{$obj->{props}}, ($props ? $props : 'nopoints'));
	$obj->{yl} = $ymin;
	$obj->{yh} = $ymax;
	$obj->{xl} = $xmin;
	$obj->{xh} = $xmax;
	$obj->{haveScale} = 0;	# invalidate any prior min-max calculations

	return 1;
}

sub error {
  my $obj = shift;
  return $obj->{errmsg};
}

sub setOptions {
	my ($obj, %hash) = @_;

	foreach (keys (%hash)) {
#
#	we need a lot more error checking here!!!
#
		$obj->{errmsg} = "Unrecognized attribute $_.",
		return undef
			unless ($valid_attr{$_});
		
		if ($_=~/^(bg|grid|text)Color$/) {
			$obj->{errmsg} = "Unrecognized color $hash{$_} for $_.",
			return undef
				unless $colors{$hash{$_}};
			my $color = $hash{$_};
#
#	if its a predefined color, reuse it
#	else allocate it
#
			$obj->{$color} = $obj->{img}->colorAllocate(@{$colors{$color}})
				unless $obj->{$color};
			$obj->{$_} = $obj->{$color};
			next;
		}
		$obj->{$_} = $hash{$_};
	}
	return 1;
}

sub plot {
	my ($obj, $format) = @_;
	$format = lc $format;
#
#	first fill with bg color
#
	my $color;
	$obj->{img}->fill(1, 1, $obj->{bgColor} );
#
#	then add any defined logo
	$obj->addLogo if $obj->{logo};

	$obj->{numRanges} = scalar @{$obj->{data}};
	my $rc = 1;
	
	my $props = $obj->{props}->[0];

	$obj->{symDomain} = 1
		if ($props=~/\b(candle|bar)\b/i);

	$rc = $obj->computeScales()
		unless ($obj->{haveScale} || ($props=~/\bpie\b/i));
	return undef unless $rc;
	
	$obj->drawTitle if $obj->{title}; # vert offset may be increased
	$obj->drawSignature if $obj->{signature};

	return (($obj->plotPie) ? 
		(($format) && $obj->{img}->$format) : undef)
		if ($props=~/\bpie\b/i);

	return (($obj->plot3DAxes && $obj->plot3DBars) ? 
		(($format) && $obj->{img}->$format) : undef)
		if (($props=~/\bbar\b/i) && ($obj->{zAxisLabel} || $obj->{threed}));

	return (($obj->plotAxes && $obj->plot2DBars) ? 
		(($format) && $obj->{img}->$format) : undef)
		if ($props=~/\bbar\b/i);

	return (($obj->plotBoxAxes && $obj->plotBox) ? 
		(($format) && $obj->{img}->$format) : undef)
		if ($props=~/\bbox\b/i);
	
	return (($obj->plotAxes && $obj->plotCandles) ? 
		(($format) && $obj->{img}->$format) : undef)
		if ($props=~/\bcandle\b/i);
#
#	must be line/point/area graph
#
	return ($obj->plotAxes && $obj->plotData) ? 
		(($format) && $obj->{img}->$format) : undef;
}

sub getMap {
	my ($obj) = @_;
	my $mapname = $obj->{genMap};

	return "\$$mapname = [\n" . $obj->{imgMap} . " ];"
		if (uc $obj->{mapType} eq 'PERL');

	return 	"<MAP NAME=\"$mapname\">" . 
		$obj->{imgMap} . "\n</MAP>\n";
}

# 
# sets xscale, yscale, and edge values used in pt2pxl
#	also adjusts min or max of barcharts to clip away origin
#
sub computeScales {
	my $obj = shift;
	my ($xl, $yl, $zl, $xh, $yh, $zh) = 
		($obj->{xl}, $obj->{yl}, $obj->{zl}, $obj->{xh}, $obj->{yh}, 
			$obj->{zh});
	my $i;
	my $props = $obj->{props}->[0];

# if no data, set arbitrary bounds
	($xl, $yl, $zl, $xh, $yh, $zh) = (0,0,0,1,0,1) and return
		if (! @{$obj->{data}});
#
#	if keepOrigin, make sure (0,0) is included
#	(but only if not in logarithmic mode)
#
	if ($obj->{keepOrigin}) {
		if ((! $obj->{xLog}) && (! $obj->{symDomain})) {
			$xl = 0 if ($xl > 0);
			$xh = 0 if ($xh < 0);
		}
		if (! $obj->{yLog}) {
			$yl = 0 if ($yl > 0);
			$yh = 0 if ($yh < 0);
		}
#
#	doesn't apply to Z axis (yet)
#
	}
	
# set axis ranges for widest/tallest/deepest dataset
	$obj->computeRanges($xl, $xh, $yl, $yh, $zl, $zh);
	$obj->{yl} = 0 if (($props=~/\bbar\b/i) && ($yl == 0));
	($xl, $xh, $yl, $yh, $zl, $zh) = 
		($obj->{xl}, $obj->{xh}, $obj->{yl}, $obj->{yh}, 
			$obj->{zl}, $obj->{zh});

	if (($props=~/\bbar\b/) && ($yl > 0) && (! $obj->{keepOrigin})) {
#
#	adjust mins to clip away from origin
#
		my $incr = ($obj->{zAxisLabel}) ? 4 : 3;
		foreach my $data (@{$obj->{data}}) {
			for ($i = 1; $i <= $#$data; $i+=$incr) {
				$$data[$i] = $yl;
			}
		}
	}
#
#	heuristically adjust image margins to fit labels
#
	my ($botmargin, $topmargin) = (40, 40);
	$botmargin += (3 * $tfh) if ($obj->{legend});
#
#	compute space needed for X axis labels
#
	my $maxlen = 0;
	my ($tl, $th);
	if ($obj->{symDomain}) {
		my $ary = $obj->{zAxisLabel} ? $obj->{xValues} : $obj->{data}->[0];
		my $incr = ($props=~/\b(bar|candle)\b/i) ?
			(($obj->{zAxisLabel}) ? 1 : 3) : 2;
		for (my $i = 0; $i < $#$ary; $i+=$incr) {
			$maxlen = length($$ary[$i]) 
				if (length($$ary[$i]) > $maxlen);
		}
	}
	else {
		($tl, $th) = ($obj->{xLog}) ? (10**$xl, 10**$xh) : ($xl, $xh);
		$maxlen = (length($th) > length($tl)) ? length($th) : length($tl);
	}
	$maxlen = 25 if ($maxlen > 25);
	$maxlen = 7 if ($maxlen < 7);
	$botmargin += (($sfw * $maxlen) + 10);
#
#	compute space needed for Y axis labels
#
	my ($rtmargin, $ltmargin) = (40, 20);
	($tl, $th) = ($obj->{yLog}) ? (10**$yl, 10**$yh) : ($yl, $yh);
	$maxlen = (length($th) > length($tl)) ? length($th) : length($tl);
	$maxlen = 25 if ($maxlen > 25);
	$maxlen = 7 if ($maxlen < 7);
	$ltmargin += (($sfw * $maxlen) + 10);
#
#	compute space needed for Z axis labels
#
	if ($obj->{zAxisLabel}) {
		my $ary = $obj->{zValues};
		for (my $i = 0; $i <= $#$ary; $i++) {
			$maxlen = length($$ary[$i])
				if (length($$ary[$i]) > $maxlen);
		}
		$maxlen = 25 if ($maxlen > 25);
		$maxlen = 7 if ($maxlen < 7);
		$rtmargin += ($sfw * $maxlen);
	}
#
# calculate axis scales 
	if ($obj->{zAxisLabel} || $obj->{threed}) {
		my $tht = $obj->{height} - $topmargin - $botmargin;
		my $twd = $obj->{width} - $ltmargin - $rtmargin;
#
#	compute ratio of Z values to X values
#	to adjust percent of plot area reserved for
#	depth. Max is 40%, min is 10%
#
		my $xzratio = 
			$obj->{Zcard}/($obj->{Xcard}*(scalar @{$obj->{data}}));
#		$xzratio = 0.1 if ($xzratio < 0.1);
#
#	compute actual height as adjusted height x (1 - depth ratio)
#	actual depth is based on 30 deg. rotation of adjusted
#	width x depth ratio
#	actual width is adjust width - the 30 deg. rotation effect
#
		$obj->{plotWidth} = int($twd / ($xzratio*sin(3.1415926/6) + 1));
		$obj->{plotDepth} = int(($twd - $obj->{plotWidth})/sin(3.1415926/6));
		$obj->{plotHeight} = int($tht - ($obj->{plotDepth}*cos(3.1415926/6)));
		$obj->{xscale} = $obj->{plotWidth}/($xh - $xl);
		$obj->{yscale} = $obj->{plotHeight}/($yh - $yl);
		$obj->{zscale} = $obj->{plotDepth}/($zh - $zl);
	}
	else {
#	keep true width/height for future reference
		$obj->{xscale} = ($obj->{width} - $ltmargin - $rtmargin)/($xh - $xl);
		$obj->{yscale} = ($obj->{height} - $topmargin - $botmargin)/($yh - $yl);
		$obj->{plotWidth} = $obj->{width} - $ltmargin - $rtmargin;
		$obj->{plotHeight} = $obj->{height} - $topmargin - $botmargin;
	}

	$obj->{horizEdge} = $ltmargin;
	$obj->{vertEdge} = $obj->{height} - $botmargin;
#
#	compute spacing info for bar/candles
#
	return undef
		if (($props=~/\b(bar|candle)\b/i) && 
			(! $obj->{zAxisLabel}) &&
			(! $obj->computeSpacing(lc $1)));
	
	$obj->{haveScale} = 1;
}

# computes the axis ranges for the input (min,max) tuple
# also computes axis step size for ticks
sub computeRanges {
 	my ($obj, $xl, $xh, $yl, $yh, $zl, $zh) = @_;
 	my ($tmp, $om) = (0,0);
 	my @sign = ();

	($obj->{horizStep}, $obj->{vertStep}, $obj->{depthStep}) = (1,1,1),
	($obj->{xl}, $obj->{xh}, $obj->{yl}, $obj->{yh}, $obj->{zl}, $obj->{zh}) = 
		(0,1,0,1, 0,1)
		if (($xl == $xh) || ($yl == $yh) || 
			(defined($zl) && ($zl == $zh)) );
		
	foreach ($xl, $xh, $yl, $yh, $zl, $zh) {
		push @sign, (($_ < 0) ? -1 : (! $_) ? 0 : 1)
			if defined($_);
	}
#
#	tick increment/value algorithm:
#	z = (log(max - min))/log(10);
#	y = z - int(z);
#	scale = (y < 0.4) ? 10 ** (int(z) - 1) :
#		((y >= 0.87) ? 10 ** int(z)) : 5 * ( 10 ** (int(z) - 1));
#	num_of_ticks = int((max - min)/scale) + 2;
#	step_pixels = int(image_width/num_of_ticks)
#
	my ($xr, $xd);
	$xr = (log($xh - $xl))/log(10),
	$xd = $xr - int($xr)
		unless ($obj->{symDomain});
	$obj->{horizStep} = ($obj->{symDomain}) ? 1 : ($xd < 0.4) ? (10 ** (int($xr) - 1)) :
		(($xd >= 0.87) ? (10 ** int($xr)) : (5 * (10 ** (int($xr) - 1))));

	$yh = $yl * 2 if ($yh == $yl);
	$xr = (log($yh - $yl))/log(10);
	$xd = $xr - int($xr);
	$obj->{vertStep} = ($xd < 0.4) ? (10 ** (int($xr) - 1)) :
		(($xd >= 0.87) ? (10 ** int($xr)) : (5 * (10 ** (int($xr) - 1))));

	if ($obj->{zAxisLabel} || $obj->{threed}) {
		$xr = (log($zh - $zl))/log(10),
		$xd = $xr - int($xr)
			unless $obj->{symDomain};
		$obj->{depthStep} = ($obj->{symDomain}) ? 1 : 
			($xd < 0.4) ? (10 ** (int($xr) - 1)) :
			(($xd >= 0.87) ? (10 ** int($xr)) : (5 * (10 ** (int($xr) - 1))));
	}
	my ($xm, $ym, $zm) = ($obj->{horizStep}, $obj->{vertStep}, 
		$obj->{depthStep});

	($zl, $zh) = (0.5, 1.5) if ($obj->{symDomain} && defined($zl) && ($zl == $zh));
	($xl, $xh) = (0.5, 1.5) if ($obj->{symDomain} && ($xl == $xh));
# fudge a little in case limit equals min or max
	$obj->{zl} = ((! $zm) ? 0 : $zm * (int(($zl-0.00001*$sign[4])/$zm) + $sign[4] - 1)),
	$obj->{zh} = ((! $zm) ? 0 : $zm * (int(($zh-0.00001*$sign[5])/$zm) + $sign[5] + 1))
		if defined($zl);
	$obj->{xl} = (! $xm) ? 0 : $xm * (int(($xl-0.00001*$sign[0])/$xm) + $sign[0] - 1);
	$obj->{xh} = (! $xm) ? 0 : $xm * (int(($xh-0.00001*$sign[1])/$xm) + $sign[1] + 1);
	$obj->{yl} = (! $ym) ? 0 : $ym * (int(($yl-0.00001*$sign[2])/$ym) + $sign[2] - 1);
	$obj->{yh} = (! $ym) ? 0 : $ym * (int(($yh-0.00001*$sign[3])/$ym) + $sign[3] + 1);
	return 1;
}
#
#	compute bar spacing
#
sub computeSpacing {
	my ($obj, $type) = @_;
#
#	candlestick, use fixed bar width and adjust spacers
#
	$obj->{brushWidth} = 2,
	return 1
		if ($type eq 'candle');
#
#	compute number of domain values
#
	my $domains = ($obj->{Xcard}) ? 1 :
		(scalar @{$obj->{data}->[0]})/3;
	my $bars = ($obj->{Xcard}) ? $obj->{Xcard} : (scalar @{$obj->{data}});
	my $spacer = 10;
	my $width = $obj->{plotWidth};
	my $pxlsperdom = int($width/($domains+1)) - $spacer;

	$obj->{errmsg} = 'Insufficient width for number of domain values.',
	return undef
		if ($pxlsperdom < 2);
#
#	compute width of each bar from number of bars per domain value
#
	my $pxlsperbar = int($pxlsperdom/$bars);

	$obj->{errmsg} = 'Insufficient width for number of ranges or values.',
	return undef
		if ($pxlsperbar < 2);

	$obj->{brushWidth} = $pxlsperbar;
	return 1;
}

sub plot2DBars {
	my $obj = shift;
	my ($i, $k, $ary, $px, $py, $pyt, $pyb);
	my ($color, $prop, $s, $colorcnt);
	my @barcolors = ();
	my @brushes = ();
	my @props = ();
	my $legend = $obj->{legend};
	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, $obj->{yl}, 
		$obj->{yh});
	my ($brush, $ci, $t);
	my ($useicon, $marker, $boff);
	my $img = $obj->{img};
	
 	for ($k = 0; $k < scalar(@{$obj->{data}}); $k++) {
		$color = 'black';

		$ary = $obj->{data}->[$k];
		$t = $obj->{props}->[$k];
		$t=~s/\s+/ /g;
		$t = lc $t;
		@props = split (' ', $t);
		foreach $prop (@props) {
			$color = $prop,
			push (@barcolors, $prop), next
				if ($colors{$prop});
#
#	if its iconic, load the icon image
#
			$marker = $obj->{icons}->[$k]
				if (($prop eq 'icon') && $obj->{icons} && 
					$obj->{icons}->[$k]);
		}
#
#	allocate each color we're using
		$colorcnt = 0;
		foreach $color (@barcolors) {
			$colorcnt++;
			$obj->{$color} = $obj->{img}->colorAllocate(@{$colors{$color}})
				unless $obj->{$color};
#
#	generate brushes to draw bars
#
			$brush = new GD::Image($obj->{brushWidth}, 1),
			$ci = $brush->colorAllocate(@{$colors{$color}}),
			$brush->filledRectangle(0,0,$obj->{brushWidth},0,$ci),
			push(@brushes, $brush)
				unless $marker;
		}

		$marker = $obj->getIcon($marker, 1)
			if ($marker);
#
#	render legend if requested
#	(a bit confusing here for multicolor single range charts?)
#
		$obj->drawLegend($k, $color, $marker, $$legend[$k])
			if (($legend) && ($$legend[$k]));

		my $bars  = scalar @{$obj->{data}};
#
#	compute the center data point, then
#	adjust horizontal location based on brush width
#	and data set number
#
		$boff = int($obj->{brushWidth}/2),
		my $ttlw = int($bars * $boff);
		my $xoffset = ($k * $obj->{brushWidth}) - $ttlw 
			+ $boff;

		for (my $i = 0, my $j = 0; $i <= $#$ary; $i += 3) {

# get top and bottom points
			($px, $pyb) = $obj->pt2pxl ( ($i/3)+1, $$ary[$i+1] );
			($px, $pyt) = $obj->pt2pxl ( ($i/3)+1, $$ary[$i+2] );
			$px += $xoffset;
				
# draw line between top and bottom
			$j = 0 if ($j == $colorcnt);
			$img->setBrush($brushes[$j++]),
			$img->line($px, $pyb, $px, $pyt, gdBrushed)
				unless $marker;
#
#	unless its iconic
#
			$obj->drawIcons($marker, $px, $pyb, $pyt)
				if $marker;

# update imagemap if requested
			$obj->updateImagemap('RECT', $$ary[$i+2], $k, $$ary[$i], 
				$$ary[$i+2], undef, $px-$boff, $pyt, $px+$boff, $pyb)
				if $obj->{genMap};
#
#	draw vertical values for bars
#	NOTE: if max length of values is less than bar width,
#	draw horizontally!!!
#
			$img->stringUp(gdTinyFont, $px-int($sfw/2), $pyt-4, 
				(($obj->{yLog}) ? 10**($$ary[$i+2]) : 
					$$ary[$i+2]), $obj->{textColor})
				if $obj->{showValues};
		}
	}
	return 1;
}

sub plotCandles {
	my $obj = shift;
	my ($k, $ary, $px, $py, $pyt, $pyb);
	my ($color, $img, $prop, $s);
	my @props = ();
	my $legend = $obj->{legend};
	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, $obj->{yl}, 
		$obj->{yh});
	my ($marker, $markw, $markh, $yoff, $wdelta, $hdelta);

	$img = $obj->{img};	

 	for ($k = 0; $k < scalar(@{$obj->{data}}); $k++) {
		$color = 'black';
		$marker = undef;

		$ary = $obj->{data}->[$k];
		my $t = $obj->{props}->[$k];
		$t=~s/\s+/ /g;
		$t = lc $t;
		@props = split (' ', $t);
		foreach $prop (@props) {
			$color = $prop, next
				if ($colors{$prop});
#
#	generate pointshape if requested
#
			$marker = $prop,
			next
				if (($shapes{$prop}) && ($prop ne 'icon'));
#
#	if its iconic, load the icon image
#
			$marker = $obj->{icons}->[$k],
			next
				if (($prop eq 'icon') && $obj->{icons} && 
					$obj->{icons}->[$k]);


			$marker = 'fillcircle',
			next
				if ((! $marker) && ($prop eq 'points'));
					
			$marker = undef, next 
				if ($prop eq 'nopoints');
		}
		$obj->{$color} = $obj->{img}->colorAllocate(@{$colors{$color}})
			unless $obj->{$color};
		
		if ($marker) {
			$marker = ($shapes{$marker}) ? $obj->make_marker($marker, $color) :
				$obj->getIcon($marker);
			return undef unless $marker;
			($markw, $markh) = $marker->getBounds();
			$wdelta = $markw>>1;
			$hdelta = $markh>>1;
		}

		$yoff = ($marker) ? $markh : 2;
#
#	render legend if requested
#
		$obj->drawLegend($k, $color, $marker, $$legend[$k])
			if ($legend && $$legend[$k]);
#
#	generate brush to draw sticks/bars
#
		my $brush = new GD::Image($obj->{brushWidth}, 1);
		my $ci = $brush->colorAllocate(@{$colors{$color}});
		$brush->filledRectangle(0,0,$obj->{brushWidth},0,$ci);
				# wide line
		$img->setBrush($brush);

		my $bars  = scalar @{$obj->{data}};
#
#	compute the center data point, then
#	adjust horizontal location based on brush width
#	and data set number
#
		my $ttlw = int(($bars * $obj->{brushWidth})/2);
		my $xoffset = ($k * $obj->{brushWidth}) - $ttlw 
			+ int($obj->{brushWidth}/2);
		for (my $i = 0; $i <= $#$ary; $i += 3) {

# get top and bottom points
			($px, $pyb) = $obj->pt2pxl ( ($i/3)+1, $$ary[$i+1] );
			($px, $pyt) = $obj->pt2pxl ( ($i/3)+1, $$ary[$i+2] );
			$px += $xoffset;
				
# draw line between top and bottom
			$img->line($px, $pyb, $px, $pyt, gdBrushed);
				
# draw pointshape if requested: use marker w&h!!!
			$img->copy($marker, $px-$wdelta, $pyb-$hdelta, 0, 0, 
				$markw-1, $markh-1),
			$img->copy($marker, $px-$wdelta, $pyt-$hdelta, 0, 0, 
				$markw-1, $markh-1)
				if ($marker);

# update imagemap if requested
			$obj->updateImagemap('CIRCLE', $$ary[$i+2], $k, $$ary[$i], 
				$$ary[$i+2], undef, $px, $pyt, 4),
			$obj->updateImagemap('CIRCLE', $$ary[$i+1], $k, $$ary[$i], 
				$$ary[$i+1], undef, $px, $pyb, 4)
				if ($obj->{genMap});
				
# draw top/bottom values if requested
			if ($obj->{showValues}) {
				$img->string(gdTinyFont,$px-10,$pyb, 
					(($obj->{yLog}) ? 10**($$ary[$i+1]) : 
						$$ary[$i+1]), $obj->{textColor}),
				$img->string(gdTinyFont,$px-10,$pyt-$yoff,
					(($obj->{yLog}) ? 10**($$ary[$i+2]) : 
						$$ary[$i+2]), $obj->{textColor})
			}	# end for each stick
		}
	}
	return 1;
}

sub computeMedian {
	my ($ary, $lo, $hi) = @_;
	my $size = $hi - $lo +1;
	my $midi = $size>>1;
	$midi-- unless ($size & 1);
	$midi += $lo;
	return ($size & 1) ? $$ary[$midi] : (($$ary[$midi] + $$ary[$midi+1])/2);
}

sub computeBox {
	my ($obj, $k) = @_;
	my ($median, $uq, $lq, $lex, $uex, $midpt, $iqr, $val);
	
	my $ary = $obj->{data}->[$k];
	my $size = $#$ary;
#
#	compute median
	$median = computeMedian($ary, 0, $size);
#
#	compute quartiles
	$midpt = ($size)>>1;
	$midpt-- unless ($size & 1);
	$lq = computeMedian($ary, 0, $midpt);
	$midpt += ($size & 1) ? 1 : 2;
	$uq = computeMedian($ary, $midpt, $size);
#
#	compute extremes within 1.5 IQR of median
	$iqr = $uq - $lq;
	$lex = $lq - ($iqr*1.5);
	$uex = $uq + ($iqr*1.5);
	$lex = $$ary[0] if ($lex < $$ary[0]);
	$uex = $$ary[$#$ary] if ($uex > $$ary[$#$ary]);
	
	return ($median, $lq, $uq, $lex, $uex);
}

sub plotBox {
	my $obj = shift;

	my $legend = $obj->{legend};
	
	for (my $k = 0; $k <= $#{$obj->{data}}; $k++) {
#
#	compute median, quartiles, and extremes
#
		my ($median, $lq, $uq, $lex, $uex) = $obj->computeBox($k);

		my $yoff = 100 * $k;
		my $ary = $obj->{data}->[$k];
		my @props = split(' ', $obj->{props}->[$k]);
		my $color = 'black';
		my ($val, $xoff);
		foreach $val (@props) {
			$color = $val
				if ($colors{$val});
		}
		$obj->{$color} = $obj->{img}->colorAllocate(@{$colors{$color}})
			unless $obj->{$color};
			
		$obj->drawLegend($k, $color, undef, $$legend[$k])
			if (($legend) && ($$legend[$k]));
#
#	draw the box
		my ($p1x, $p1y) = $obj->pt2pxl($lq, $yoff+50);
		my ($p2x, $p2y) = $obj->pt2pxl($uq, $yoff+10);
		my $img = $obj->{img};

		$img->rectangle($p1x, $p1y, $p2x, $p2y, $obj->{$color});
		$img->rectangle($p1x+1, $p1y+1, $p2x-1, $p2y-1, $obj->{$color});

		$xoff = int(length($lq) * $tfw/2),
		$img->string(gdTinyFont,$p1x-$xoff,$p1y-$tfh, $lq, $obj->{textColor}),
		$xoff = int(length($uq) * $tfw/2),
		$img->string(gdTinyFont,$p2x-$xoff,$p1y-$tfh, $uq, $obj->{textColor})
			if ($obj->{showValues});
	
		$obj->updateImagemap('RECT', "$median\[$lq..$uq\]", 0, $median, $lq, $uq, $p1x, $p1y, $p2x, $p2y)
			if ($obj->{genMap});
#
#	draw median line
		($p1x, $p1y) = $obj->pt2pxl($median, $yoff+55);
		($p2x, $p2y) = $obj->pt2pxl($median, $yoff+5);
		$img->line($p1x, $p1y, $p2x, $p2y, $obj->{$color});

		$xoff = int(length($median) * $tfw/2),
		$img->string(gdTinyFont,$p1x-$xoff,$p1y-$tfh, $median, $obj->{textColor})
			if ($obj->{showValues});
#
#	draw whiskers
		($p1x, $p1y) = $obj->pt2pxl($lex, $yoff+30);
		($p2x, $p2y) = $obj->pt2pxl($lq, $yoff+30);
		$img->line($p1x, $p1y, $p2x, $p2y, $obj->{$color});

		$xoff = int(length($lex) * $tfw/2),
		$img->string(gdTinyFont,$p1x-$xoff,$p1y-$tfh, $lex, $obj->{textColor})
			if ($obj->{showValues});
		$obj->updateImagemap('CIRCLE', $lex, 0, $lex, undef, undef, $p1x, $p1y, 4)
			if ($obj->{genMap});

		($p1x, $p1y) = $obj->pt2pxl($uq, $yoff+30);
		($p2x, $p2y) = $obj->pt2pxl($uex, $yoff+30);
		$img->line($p1x, $p1y, $p2x, $p2y, $obj->{$color});

		$xoff = int(length($uex) * $tfw/2),
		$img->string(gdTinyFont,$p2x-$xoff,$p2y-$tfh, $uex, $obj->{textColor})
			if ($obj->{showValues});
		$obj->updateImagemap('CIRCLE', $uex, 0, $uex, undef, undef, $p2x, $p2y, 4)
			if ($obj->{genMap});
#
#	plot outliers; we won't show values here
#
		my $marker = $obj->make_marker('filldiamond', $color);
		foreach $val (@$ary) {
			last if ($val >= $lex);
			($p1x, $p1y) = $obj->pt2pxl($val, $yoff+30);
			$img->copy($marker, $p1x-4, $p1y-4, 0, 0, 9, 9);
		}
		for (my $i = $#$ary; ($i > 0) && ($uex < $$ary[$i]); $i--) {
			($p1x, $p1y) = $obj->pt2pxl($$ary[$i], $yoff+30);
			$img->copy($marker, $p1x-4, $p1y-4, 0, 0, 9, 9);
		}
	}	# end for each plot
	return 1;
}

sub plotBoxAxes {
	my $obj = shift;
	my ($p1x, $p1y, $p2x, $p2y);
	my $img = $obj->{img};
	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, 
		$obj->{yl}, $obj->{yh});

	my $yaxpt = ((! $obj->{yLog}) && ($yl < 0) && ($yh > 0)) ? 0 : $yl;
	my $xaxpt = ((! $obj->{xLog}) && ($xl < 0) && ($xh > 0)) ? 0 : $xl;
#
#	X axis
	($p1x, $p1y) = $obj->pt2pxl($xl, $yaxpt);
	($p2x, $p2y) = $obj->pt2pxl($xh, $yaxpt);
	$img->line($p1x, $p1y, $p2x, $p2y, $obj->{gridColor});
#
#	draw X axis label
	my ($len, $xStart);
	($p2x, $p2y) = $obj->pt2pxl($xh, $yl),
	$len = $sfw * length($obj->{xAxisLabel}),
	$xStart = ($p2x+$len/2 > $obj->{width}-10)
		? ($obj->{width}-10-$len) : ($p2x-$len/2),
	$img->string(gdSmallFont, $xStart, $p2y+ int(4*$sfh/3), 
		$obj->{xAxisLabel}, $obj->{textColor})
		if ($obj->{xAxisLabel});
#
# draw ticks and labels
# 
	my ($i,$px,$py);
#
#	for LOG(X):
#
	my $powk;
	if ($obj->{xLog}) {
		$i = $xl;
		my $n = 0;
		my $k = $i;
		while ($i < $xh) {
			$k = $i + $logsteps[$n++];

			($px,$py) = $obj->pt2pxl($k, 
				((($obj->{yLog}) || 
				($obj->{vertGrid}) || ($yl > 0) || ($yh < 0)) ? $yl : 0));
			($p1x, $p1y) = ($obj->{vertGrid}) ? 
				$obj->pt2pxl($k, $yh) : ($px, $py+2);
			$py -= 2 if (! $obj->{vertGrid});
			$img->line($px, $py, $px, $p1y, $obj->{gridColor});
			$py += 2 if (! $obj->{vertGrid});

			$powk = 10**$k,
			$img->stringUp(gdSmallFont, $px-$sfh/2, 
				$py+length($powk)*$sfw, $powk, $obj->{textColor})
				if ($n == 1);

			($n, $i)  = (0 , $k )
				if ($n == scalar(@logsteps));
		}
	}
	else {
	    my $step = $obj->{horizStep}; 
    
		for ($i = $xl; $i <= $xh; $i += $step ) {
			($px,$py) = $obj->pt2pxl($i, 
				((($obj->{yLog}) || 
				($obj->{vertGrid}) || ($yl > 0) || ($yh < 0)) ? $yl : 0));
			($p1x, $p1y) = ($obj->{vertGrid}) ? 
				$obj->pt2pxl($i, $yh) : ($px, $py+2);
			$py -= 2 if (! $obj->{vertGrid});
			$img->line($px, $py, $px, $p1y, $obj->{gridColor});
			$py += 2 if (! $obj->{vertGrid});

			$img->stringUp(gdSmallFont, $px-($sfh>>1), 
				$py+2+length($i)*$sfw, $i, $obj->{textColor}), next
				if ($obj->{xAxisVert});

			$img->string(gdSmallFont, $px-length($i)*($sfw>>1), 
				$py+($sfh>>1), $i, $obj->{textColor});
		}
	}
	return 1;
}

# draws all the datasets in $obj->{data}
sub plotData {
	my $obj = shift;
	my ($i, $k, $ary, $px, $py, $prevpx, $prevpy, $pyt, $pyb);
	my ($color, $line, $img, $prop, $s, $voff);
	my @props = ();
	my $legend = $obj->{legend};
	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, $obj->{yl}, 
		$obj->{yh});
# legend is left justified underneath
	my ($p2x, $p2y) = $obj->pt2pxl ($xl, $yl);
	my ($marker, $markw, $markh, $yoff, $wdelta, $hdelta);

	$img = $obj->{img};	
	
 	for ($k = 0; $k < scalar(@{$obj->{data}}); $k++) {
		$color = 'black';
		$marker = undef;
		$line = 'line';

		$ary = $obj->{data}->[$k];
		my $t = $obj->{props}->[$k];
		$t=~s/\s+/ /g;
		$t = lc $t;
		@props = split (' ', $t);
		foreach $prop (@props) {
			$color = $prop, next
				if ($colors{$prop});

			$marker = $prop,
			next
				if ($shapes{$prop} && ($prop ne 'icon'));
#
#	if its iconic, load the icon image
#
			$marker = $obj->{icons}->[$k],
			next
				if (($prop eq 'icon') && $obj->{icons} && 
					$obj->{icons}->[$k]);

			$marker = 'fillcircle',
			next
				if ((! $marker) && ($prop eq 'points'));
					
			$marker = undef, next 
				if ($prop eq 'nopoints');

			$line = $prop
				if ($prop=~/^(line|noline|fill)$/);
		}
		$obj->{$color} = $obj->{img}->colorAllocate(@{$colors{$color}})
			unless $obj->{$color};
		
		if ($marker) {
			$marker = ($shapes{$marker}) ? $obj->make_marker($marker, $color) :
				$obj->getIcon($marker);
			return undef unless $marker;
			($markw, $markh) = $marker->getBounds();
			$wdelta = $markw>>1;
			$hdelta = $markh>>1;
		}
		my $yoff = ($marker) ? $markh : 2;
#
#	render legend if requested
#
		$obj->drawLegend($k, $color, $marker, $$legend[$k])
			if ($legend && $$legend[$k]);
#
#	line/point/area charts
#
# draw the first point 
		($px, $py) = $obj->pt2pxl((($obj->{symDomain}) ? 0 : $$ary[0]),
			$$ary[1] );

		$img->copy($marker, $px-$wdelta, $py-$hdelta, 0, 0, $markw-1, 
			$markh-1)
			if ($marker);

		$s = ($obj->{symDomain}) ? 
			(($obj->{yLog}) ? 10**($$ary[1]) : $$ary[1]) : 
			'(' . (($obj->{xLog}) ? 10**($$ary[0]) : $$ary[0]) . ',' . 
			(($obj->{yLog}) ? 10**($$ary[1]) : $$ary[1]) . ')'
			if (($obj->{genMap}) || ($obj->{showValues}));
			
		$obj->updateImagemap('CIRCLE', $s, $k, $$ary[0], $$ary[1], undef, 
			$px, $py, 4)
			if ($obj->{genMap});

		$voff = (length($s) * $tfw)>>1,
		$img->string(gdTinyFont,$px-$voff,$py-$yoff, $s, $obj->{textColor})
			if ($obj->{showValues});
#
#	we need to heuristically sort data sets to optimize the view of 
#	overlapping areagraphs...for now the user will need to be smart 
#	about the order of registering the datasets
#
		$obj->fill_region($obj->{$color}, $ary)
			if ($line eq 'fill');

		($prevpx, $prevpy) = ($px, $py);

# draw the rest of the points and lines 
		for ($i=2; $i < @$ary; $i+=2) {

# get next point
			($px, $py) = $obj->pt2pxl((($obj->{symDomain}) ?
				$i>>1 : $$ary[$i]), $$ary[$i+1] );

# draw point, maybe
			$img->copy($marker, $px-$wdelta, $py-$hdelta, 0, 0, $markw, 
				$markh)
				if ($marker);

			$s = ($obj->{symDomain}) ? 
				(($obj->{yLog}) ? 10**($$ary[$i+1]) : $$ary[$i+1]) : 
				'(' . (($obj->{xLog}) ? 10**($$ary[$i]) : $$ary[$i]) . ',' . 
				(($obj->{yLog}) ? 10**($$ary[$i+1]) : $$ary[$i+1]) . ')';
			
			$obj->updateImagemap('CIRCLE', $s, $k, $$ary[$i], $$ary[$i+1], 
				undef, $px, $py, 4)
				if ($obj->{genMap});

			$voff = (length($s) * $tfw)>>1,
			$img->string(gdTinyFont,$px-$voff,$py-$yoff, $s, $obj->{textColor})
				if ($obj->{showValues});

# draw line from previous point, maybe
			$img->line($prevpx, $prevpy, $px, $py, $obj->{$color})
				if ($line eq 'line');
			($prevpx, $prevpy) = ($px, $py);
		}
	}
	return 1;
}

sub drawLegend {
	my ($obj, $k, $color, $shape, $text) = @_;
#
#	add the dataset to the legend using current color
#	and shape (if any)
#
	$shape = $obj->make_marker('fillsquare', $color)
		unless $shape;

	my $legend_wd = (int($k/3) * 85) + 10;
	my $legend_maxht = $obj->{height} - 40;

	my $legend_ht = $obj->{height} - 40 - 20 - (2 * $tfh) + 
		(($k%3) * (3*$tfh/2));

	my $img = $obj->{img};
	my $legend = $obj->{legend};
	$img->string (gdTinyFont, $legend_wd + 25, $legend_ht,
		$$legend[$k], $obj->{$color});

	$img->line($legend_wd, $legend_ht+4, $legend_wd+20, 
		$legend_ht+4, $obj->{$color});

	my ($w, $h);
	($w, $h) = $shape->getBounds(),
	$img->copy($shape, $legend_wd+5, $legend_ht, 0, 0, $w-1, $w-1)
		if ($shape);
}

# compute pixel coordinates from datapoint
sub pt2pxl {
	my ($obj, $x, $y, $z) = @_;

	return (
		int($obj->{horizEdge} + ($x - $obj->{xl}) * $obj->{xscale}),
		int($obj->{vertEdge} - ($y - $obj->{yl}) * $obj->{yscale})
	 ) unless defined($z);
#
#	translate x,y,z into x,y
#
	my $tx = ($x - $obj->{xl}) * $obj->{xscale};
	my $ty = ($y - $obj->{yl}) * $obj->{yscale};
	my $tz = ($z - $obj->{zl}) * $obj->{zscale};
	my $xoff = $obj->{horizEdge};
	my $yoff = $obj->{height} - $obj->{vertEdge};
	return
		$xoff + int($tx + ($tz * 0.433)),
		$obj->{vertEdge} - int($ty + ($tz * 0.25));
}
# draw the axes, labels, title, grid/ticks and tick labels

sub plotAxes {
	my $obj = shift;
	my ($p1x, $p1y, $p2x, $p2y);
	my $img = $obj->{img};
	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, 
		$obj->{yl}, $obj->{yh});

	my $yaxpt = ((! $obj->{yLog}) && ($yl < 0) && ($yh > 0)) ? 0 : $yl;
	my $xaxpt = ((! $obj->{xLog}) && ($xl < 0) && ($xh > 0)) ? 0 : $xl;
	my $props = $obj->{props}->[0];
	$xaxpt = $xl if ($obj->{symDomain});
	
	if ($obj->{vertGrid} || $obj->{horizGrid}) {
#
#	gridded, create a rectangle
#
		($p1x, $p1y) = $obj->pt2pxl ($xl, $yl);
		($p2x, $p2y) = $obj->pt2pxl ($xh, $yh);

  		$img->rectangle( $p1x, $p1y, $p2x, $p2y, $obj->{gridColor});
#
#	hilight the (0,0) axes, if available
#
#	draw X-axis
		($p1x, $p1y) = $obj->pt2pxl($xl, $yaxpt);
		($p2x, $p2y) = $obj->pt2pxl($xh, $yaxpt);
		$img->filledRectangle($p1x, $p1y-1,$p2x, $p2y-1,$obj->{gridColor}); # wide line
#	draw Y-axis
		($p1x, $p1y) = $obj->pt2pxl($xaxpt, $yl);
		($p2x, $p2y) = $obj->pt2pxl($xaxpt, $yh);
		$img->filledRectangle($p1x-1, $p2y,$p2x+1, $p1y,$obj->{gridColor}); # wide line
  	}
  	else {
#
#	X axis
		($p1x, $p1y) = $obj->pt2pxl($xl, $yaxpt);
		($p2x, $p2y) = $obj->pt2pxl($xh, $yaxpt);
		$img->line($p1x, $p1y, $p2x, $p2y, $obj->{gridColor});
#
#	draw at bottom if yl < 0
		($p1x, $p1y) = $obj->pt2pxl($xl, $yl),
		($p2x, $p2y) = $obj->pt2pxl($xh, $yl),
		$img->line($p1x, $p1y, $p2x, $p2y, $obj->{gridColor})
			if ($yl < 0);
	}
#
#	draw X axis label
	my ($len, $xStart);
	($p2x, $p2y) = $obj->pt2pxl($xh, (
		$obj->{vertGrid} || $obj->{horizGrid}) ? $yl : $yaxpt),
	$len = $sfw * length($obj->{xAxisLabel}),
	$xStart = ($p2x+$len/2 > $obj->{width}-10)
		? ($obj->{width}-10-$len) : ($p2x-$len/2),
	$img->string(gdSmallFont, $xStart, $p2y+ int(4*$sfh/3), 
		$obj->{xAxisLabel}, $obj->{textColor})
		if ($obj->{xAxisLabel});

# Y axis
	($p1x, $p1y) = $obj->pt2pxl($xaxpt, $yl);
	($p2x, $p2y) = $obj->pt2pxl((($obj->{vertGrid}) ? $xl : $xaxpt), $yh);
	
	$img->line($p1x, $p1y, $p2x, $p2y, $obj->{gridColor})
		if ((! $obj->{'vertGrid'}) && (! $obj->{horizGrid}));

	$xStart = $p2x - length($obj->{yAxisLabel}) * ($sfw >> 1),
	$img->string(gdSmallFont, ($xStart>10 ? $xStart : 10), 
		$p2y - 3*($sfh>>1), $obj->{yAxisLabel},  $obj->{textColor})
		if ($obj->{yAxisLabel});
#
# draw ticks and labels
# 
	my ($i,$px,$py, $step, $j, $txt);
# 
# horizontal
#
#	for LOG(X):
#
	my $powk;
	if ($obj->{xLog}) {
		$i = $xl;
		my $n = 0;
		my $k = $i;
		while ($i < $xh) {
			$k = $i + $logsteps[$n++];

			($px,$py) = $obj->pt2pxl($k, $yl);
#				((($obj->{yLog}) || 
#				($obj->{vertGrid}) || ($yl > 0) || ($yh < 0)) ? $yl : 0));
			($p1x, $p1y) = ($obj->{vertGrid}) ? 
				$obj->pt2pxl($k, $yh) : ($px, $py+2);
			$py -= 2 unless $obj->{vertGrid};
			$img->line($px, $py, $px, $p1y, $obj->{gridColor});
			$py += 2 unless $obj->{vertGrid};

			$powk = 10**$k,
			$img->stringUp(gdSmallFont, $px-$sfh/2, 
				$py+length($powk)*$sfw, $powk, $obj->{textColor})
				if ($n == 1);

			($n, $i)  = (0 , $k )
				if ($n == scalar(@logsteps));
		}
	}
	elsif ($obj->{symDomain}) {
#
# symbolic domain
#
		my $ary = $obj->{data}->[0];
    
    	my $prevx = 0;
    	my $incr = ($props=~/\b(bar|candle)\b/i) ? 3 : 2;
    	my $offset = ($props=~/\b(bar|candle)\b/i) ? 0 : 1;
		for ($i = ($props=~/\b(bar|candle)\b/i) ? 1 : 0, $j = 0; 
			$i < $xh-$offset; $i++, $j += $incr ) {
			($px,$py) = $obj->pt2pxl($i, $yl);
#				((($obj->{yLog}) || 
#				($obj->{vertGrid}) || ($yl > 0) || ($yh < 0)) ? $yl : 0));
			($p1x, $p1y) = ($obj->{vertGrid}) ? 
				$obj->pt2pxl($i, $yh) : ($px, $py+2);
			$py -= 2 unless $obj->{vertGrid};
			$img->line($px, $py, $px, $p1y, $obj->{gridColor});
			$py += 2 unless $obj->{vertGrid};
			next unless defined($$ary[$j]);
#
#	truncate long labels
#
			$txt = $$ary[$j];
			$txt = substr($txt, 0, 22) . '...' 
				if (length($txt) > 25);

			if (defined($obj->{xAxisVert}) && ($obj->{xAxisVert} == 0)) {
#
#	skip the label if it would overlap
#
				next if (((length($txt)+1) * $sfw) > ($px - $prevx));
				$prevx = $px;

				$img->string(gdSmallFont, $px-length($txt)*($sfw>>1), 
					$py+($sfh>>1), $txt, $obj->{textColor});
			}
			else {
#
#	skip the label if it would overlap
#
				next if (($sfh+1) > ($px - $prevx));
				$prevx = $px;

				$img->stringUp(gdSmallFont, $px-($sfh>>1), 
					$py+2+length($txt)*$sfw, $txt, $obj->{textColor})
			}
		}
	}
	else {
	    $step = $obj->{horizStep}; 
    
		for ($i = $xl; $i <= $xh; $i += $step ) {
			($px,$py) = $obj->pt2pxl($i, $yl);
#				((($obj->{yLog}) || 
#				($obj->{vertGrid}) || ($yl > 0) || ($yh < 0)) ? $yl : 0));
			($p1x, $p1y) = ($obj->{vertGrid}) ? 
				$obj->pt2pxl($i, $yh) : ($px, $py+2);
			$py -= 2 if (! $obj->{vertGrid});
			$img->line($px, $py, $px, $p1y, $obj->{gridColor});
			$py += 2 if (! $obj->{vertGrid});

			$img->stringUp(gdSmallFont, $px-($sfh>>1), 
				$py+2+length($i)*$sfw, $i, $obj->{textColor})
				if ($obj->{xAxisVert});

			$img->string(gdSmallFont, $px-length($i)*($sfw>>1), 
				$py+($sfh>>1), $i, $obj->{textColor})
				unless ($obj->{xAxisVert});
		}
	}
#
# vertical
#
#	for LOG(Y):
#
	if ($obj->{yLog}) {
		$i = $yl;
		my $n = 0;
		my $k = $i;
		while ($i < $yh) {
			$k = $i + $logsteps[$n++];
			($px,$py) = $obj->pt2pxl(
				((($obj->{xLog}) || ($obj->{horizGrid})) ? 
				$xl : $xaxpt), $k);
			($p1x, $p1y) = ($obj->{horizGrid}) ? 
				$obj->pt2pxl($xh, $k) : ($px+2, $py);
			$px -=2 if (! $obj->{horizGrid});
			$img->line($px, $py, $p1x, $py, $obj->{gridColor});
			$px +=2 if (! $obj->{horizGrid});
			if ($n == 1) {
				my $powk = 10**$k;
				$img->string(gdSmallFont, $px-5-length($powk)*$sfw, 
					$py-($sfh>>1), $powk, $obj->{textColor});
			}
			
			($n, $i)  = (0 , $k )
				if ($n == scalar(@logsteps));
		}
		return 1;
	}

	$step = $obj->{vertStep};
#
#	if y tick step < (2 * sfh), skip every other label
#
	($px,$py) = $obj->pt2pxl((($obj->{horizGrid}) ? $xl : $xaxpt), $yl);
	($p1x,$p1y) = $obj->pt2pxl((($obj->{horizGrid}) ? $xl : $xaxpt), 
		$yl+$step);
	my $skip = ($p1y - $py < ($sfh<<1)) ? 1 : 0;

	for ($i=$yl, $j = 0; $i <= $yh; $i+=$step, $j++ ) {
		($px,$py) = $obj->pt2pxl((($obj->{horizGrid}) ? $xl : $xaxpt), $i);
		($p1x, $p1y) = ($obj->{horizGrid}) ? 
			$obj->pt2pxl($xh, $i) : ($px+2, $py);
		$px -=2 if (! $obj->{horizGrid});
		$img->line($px, $py, $p1x, $py, $obj->{gridColor});
		$px +=2 if (! $obj->{horizGrid});

		next if (($skip) && ($j&1));
		$img->string(gdSmallFont, $px-5-length($i)*$sfw, $py-($sfh>>1), 
			$i, $obj->{textColor});
	}
	return 1;
}

sub drawTitle {
	my ($obj) = @_;
	my ($w,$h) = (gdMediumBoldFont->width, gdMediumBoldFont->height);

# centered below chart
	my ($px,$py) = ($obj->{width}/2, $obj->{height} - 40);

	($px,$py) = ($px - length ($obj->{title}) * $w/2, $py+$h/2);
	$obj->{img}->string (gdMediumBoldFont, $px, $py, 
		$obj->{title}, $obj->{textColor}); 
}

sub drawSignature {
	my ($obj) = @_;
	my $fw = ($tfw * length($obj->{signature})) + 5;
# in lower right corner
	my ($px,$py) = ($obj->{width} - $fw, $obj->{height} - ($tfh * 2));

	$obj->{img}->string (gdTinyFont, $px, $py, 
		$obj->{signature}, $obj->{textColor}); 
}

sub fill_region
{
	my ($obj, $ci, $ary) = @_;
	my $img = $obj->{img};

	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, 
		$obj->{yl}, $obj->{yh});
	my($x, $y);
	
	# Create a new polygon
	my $poly = GD::Polygon->new();

	my @bottom;

	$xl = 0 if $obj->{symDomain};
	my ($xbot, $ybot) = $obj->pt2pxl($xl, (($yl >= 0) ? $yl : 0));
	
	# Add the data points
	for (my $i = 0; $i < @$ary; $i += 2)
	{
		next unless defined($$ary[$i]);

		($x, $y) = $obj->pt2pxl(
			$obj->{symDomain} ? $i>>1 : $$ary[$i], 
			$$ary[$i+1]);
		$poly->addPt($x, $y);
		push @bottom, [$x, $ybot];
	}

	foreach my $bottom (reverse @bottom)
	{
		$poly->addPt($bottom->[0], $bottom->[1]);
	}

	# Draw a filled and a line polygon
	$img->filledPolygon($poly, $ci);
	$img->polygon($poly, $ci);

	1;
}

sub make_marker {
	my ($obj, $mtype, $mclr) = @_;

	my $brush = new GD::Image(9,9);
	my $white = $brush->colorAllocate(255, 255, 255);
	my $clr = $brush->colorAllocate(@{$colors{$mclr}});
	$brush->transparent($white);
	$mtype = $shapes{$mtype};

# square, filled	
	$brush->filledRectangle(0,0,6,6,$clr),
	return $brush
		if ($mtype == 1);

# Square, open
	$brush->rectangle( 0, 0, 6, 6, $clr ),
	return $brush
		if ($mtype == 2);

# Cross, horizontal
	$brush->line( 0, 4, 8, 4, $clr ),
	$brush->line( 4, 0, 4, 8, $clr ),
	return $brush
		if ($mtype == 3);

# Cross, diagonal
	$brush->line( 0, 0, 8, 8, $clr ),
	$brush->line( 8, 0, 0, 8, $clr ),
	return $brush
		if ($mtype == 4);

# Diamond, filled
	$brush->line( 0, 4, 4, 8, $clr ),
	$brush->line( 4, 8, 8, 4, $clr ),
	$brush->line( 8, 4, 4, 0, $clr ),
	$brush->line( 4, 0, 0, 4, $clr ),
	$brush->fillToBorder( 4, 4, $clr, $clr ),
	return $brush
		if ($mtype == 5);

# Diamond, open
	$brush->line( 0, 4, 4, 8, $clr ),
	$brush->line( 4, 8, 8, 4, $clr ),
	$brush->line( 8, 4, 4, 0, $clr ),
	$brush->line( 4, 0, 0, 4, $clr ),
	return $brush
		if ($mtype == 6);

# Circle, filled
	$brush->arc( 4, 4, 8 , 8, 0, 360, $clr ),
	$brush->fillToBorder( 4, 4, $clr, $clr ),
	return $brush,
		if ($mtype == 7);

# must be Circle, open
	$brush->arc( 4, 4, 8, 8, 0, 360, $clr );
	return $brush;
}

sub getIcon {
	my ($obj, $icon, $isbar) = @_;
	my $pat = GD::Image->can('newFromGif') ? 
		'png|jpe?g|gif' : 'png|jpe?g';

	$obj->{errmsg} = 
	'Unrecognized icon file format. File qualifier must be .png, .jpg, ' . 
		(GD::Image->can('newFromGif') ? '.jpeg, or .gif.' : 'or .jpeg.'),
	return undef
		unless ($icon=~/\.($pat)$/i);

	$obj->{errmsg} = "Unable to open icon file $icon.",
	return undef
		unless open(ICON, "<$icon");

	my $iconimg = ($icon=~/\.png$/i) ? GD::Image->newFromPng(*ICON) :
	  ($icon=~/\.gif$/i) ? GD::Image->newFromGif(*ICON) :
	    GD::Image->newFromJpeg(*ICON);
	close(ICON);
	$obj->{errmsg} = "GD cannot read icon file $icon\.",
	return undef
		unless $iconimg;

	my ($iconw, $iconh) = $iconimg->getBounds();
	$obj->{errmsg} = "Icon image $icon too wide for chart image.",
	return undef
		if (($isbar && ($iconw > $obj->{brushWidth})) ||
			($iconw > $obj->{plotWidth}));
		
	$obj->{errmsg} = "Icon image $icon too tall for chart image.",
	return undef
		if ($iconh > $obj->{plotHeight});
	return $iconimg;
}

sub drawIcons {
	my ($obj, $iconimg, $px, $pyb, $pyt) = @_;
#
#	force the icon into the defined image area
#
	my ($iconw, $iconh) = $iconimg->getBounds();
	my $img = $obj->{img};
	my $remy = $pyb;
	$px -= int($iconw/2);

	while ($remy > $pyt) {	
		my $srcY = ($iconh > ($remy - $pyt)) ? 
			($iconh - ($remy - $pyt)) : 0;
		my $h = ($iconh > ($remy - $pyt)) ? $remy - $pyt : $iconh;
		$remy -= $h;
		$img->copy($iconimg, $px, $remy, 0, $srcY, $iconw, $h);
	}
	1;
}

sub plot3DAxes {
	my ($obj) = @_;
	my $img = $obj->{img};
	my ($xl, $xh, $yl, $yh, $zl, $zh) = 
		($obj->{xl}, $obj->{xh}, $obj->{yl}, $obj->{yh}, $obj->{zl}, $obj->{zh});

	my $numRanges = scalar @{$obj->{data}};
	my ($xoff, $zcard) = ($obj->{zAxisLabel}) ? 
		(1.0, $obj->{Zcard}) : (0.9, 1);
	my $xbarw = $xoff/$numRanges;
	my $zbarw = ($obj->{zh} - $obj->{zl})/($zcard*2);

	$zl -= (0.8);
	$zh += $zbarw;
	my $yc = ($yl < 0) ? 0 : $yl;
	my @v = (
		$xl, $yl, $zl,	# bottom front left
		$xl, $yl, $zh,	# bottom rear left
		$xl, $yh, $zl,	# top front left
		$xl, $yh, $zh,	# top rear left
		$xh, $yl, $zl,	# bottom front right
		$xh, $yl, $zh,	# bottom rear right
		$xh, $yh, $zh,	# top rear right
#
#	in case floor is above bottom of graph
		$xl, $yc, $zl,	# bottom front left
		$xh, $yc, $zl,	# bottom front right
		$xh, $yc, $zh,	# bottom rear right
		$xl, $yc, $zh	# bottom rear left
	);

	my @xlatverts = ();
#
#	generate vertices of cabinet projection
#
	my ($i, $j);
	for ($i = 0; $i <= $#v; $i+=3) {
		push(@xlatverts, $obj->pt2pxl($v[$i], $v[$i+1], $v[$i+2]));
	}
#
#	draw left and rear wall, and floor
#
	for ($i = 0; $i <= $#axesverts; $i+=2) {
		$img->line($xlatverts[$axesverts[$i]],
			$xlatverts[$axesverts[$i]+1],
			$xlatverts[$axesverts[$i+1]],
			$xlatverts[$axesverts[$i+1]+1], $obj->{gridColor});
	}
#
#	draw grid lines if requested
#
	my ($gx, $gy, $hx, $hy);
	if ($obj->{horizGrid}) {
		for ($i = $obj->{yl}; $i < $obj->{yh}; $i += $obj->{vertStep}) {
			($gx, $gy) = $obj->pt2pxl($xl, $i, $zl);
			($hx, $hy) = $obj->pt2pxl($xl, $i, $zh),
			$img->line($gx, $gy, $hx, $hy, $obj->{gridColor}),
			($gx, $gy) = $obj->pt2pxl($xh, $i, $zh),
			$img->line($gx, $gy, $hx, $hy, $obj->{gridColor}),
		}
	}
# need these later to redraw floor and tick labels
	$obj->{xlatVerts} = \@xlatverts;
	1;
}

sub plot3DTicks {
#
#	draw axis tick values
#
	my ($obj) = @_;
	my $img = $obj->{img};
	my ($xl, $xh, $yl, $yh, $zl, $zh) = 
		($obj->{xl}, $obj->{xh}, $obj->{yl}, $obj->{yh}, $obj->{zl}, $obj->{zh});

	my $numRanges = scalar @{$obj->{data}};
	my ($xoff, $zcard) = ($obj->{zAxisLabel}) ? 
		(1.0, $obj->{Zcard}) : (0.9, 1);

	my $xbarw = $xoff/$numRanges;
	my $zbarw = ($obj->{zh} - $obj->{zl})/($zcard*2);
	my $data = $obj->{data}->[0];
	$zl -= (0.8);
	$zh += $zbarw;
	my $yc = ($yl < 0) ? 0 : $yl;
	my $i;
	my $xlatverts = $obj->{xlatVerts};

	my $text = '';
	my ($gx, $gy, $hx, $hy);
	if ($obj->{zAxisLabel}) {
		my $zs = $obj->{zValues};
		for ($i = 0; $i <= $#$zs; $i++) {
			($gx, $gy) = $obj->pt2pxl($xh, $yc, $i+1+0.8);
			$text = $$zs[$i];
			$text = substr($text, 0, 22) . '...' if (length($text) > 25);
			$img->string(gdSmallFont, $gx, $gy, $text, $obj->{textColor});
		}
	}
	my $xs = $obj->{xValues};
	for ($i = 0; $i <= $#$xs; $i++) {
		($gx, $gy) = $obj->pt2pxl($i+(($yl >= 0) ? 1 : 0.5), $yl, ($yl >= 0) ? $zl : $zh);
		$text = $$xs[$i];
		$text = substr($text, 0, 22) . '...' if (length($text) > 25);
		$gy += (length($text) * $sfw) + 5;
		$img->stringUp(gdSmallFont, $gx, $gy, $text, $obj->{textColor});
	}
	for ($i = $obj->{yl}; $i < $obj->{yh}; $i += $obj->{vertStep}) {
		($gx, $gy) = $obj->pt2pxl($xl, $i, $zl);
		$text = $i;
		$text = substr($text, 0, 22) . '...' if (length($text) > 25);
		$gx -= ((length($text) * $sfw) + 5);
		$img->string(gdSmallFont, $gx, $gy-($sfw>>1), $text, $obj->{textColor});
	}
#
#	redraw the floor in case we had negative values
	for ($i = 18; $i <= $#axesverts; $i+=2) {
		$img->line($$xlatverts[$axesverts[$i]],
			$$xlatverts[$axesverts[$i]+1],
			$$xlatverts[$axesverts[$i+1]],
			$$xlatverts[$axesverts[$i+1]+1], $obj->{gridColor});
	}

	1;
}

sub plot3DBars {
	my ($obj) = @_;
	
	my $img = $obj->{img};
	my $numRanges = scalar @{$obj->{data}};
	my ($xoff, $zcard) = ($obj->{zAxisLabel}) ? 
		(1.0, $obj->{Zcard}) : (0.9, 1);
	my $xbarw = $xoff/$numRanges;
	my $zbarw = ($obj->{zh} - $obj->{zl})/($zcard*2);
	my ($xvals, $zvals) = ($obj->{xValues}, $obj->{zValues});
	my @fronts = ();
	my @tops = ();
	my @sides = ();
	my $legend = $obj->{legend};
	for (my $k = 0; $k < $numRanges ; $k++) {
		my $color = 'black';
		my $ary = $obj->{data}->[$k];
#
#	extract properties
#
		my $t = $obj->{props}->[$k];
		$t=~s/\s+/ /g;
		$t = lc $t;
		my @props = split (' ', $t);
		foreach my $prop (@props) {
#
#	generate light, medium, and dark version for front,
#	top, and side faces
#
			$color = $prop,
			push(@tops, $img->colorAllocate(@{$colors{$prop}})),
			push(@fronts, $img->colorAllocate(int($colors{$prop}->[0] * 0.8), 
				int($colors{$prop}->[1] * 0.8), int($colors{$prop}->[2] * 0.8))),
			push(@sides, $img->colorAllocate(int($colors{$prop}->[0] * 0.6), 
				int($colors{$prop}->[1] * 0.6), int($colors{$prop}->[2] * 0.6)))
				if ($colors{$prop});

		}
		$obj->{$color} = $tops[$#tops];
		$obj->drawLegend($k, $color, undef, $$legend[$k])
			if (($legend) && ($$legend[$k]));
	}
#
#	draw each bar
	my $numPts = $#{$obj->{data}->[0]};
	my $ary;
	for (my $i = 0, my $j = 0; $i <= $numPts; $i+=4) {
		if ($numRanges == 1) {
#
#	to support multicolor single ranges
			$ary = $obj->{data}->[0];
			$obj->drawCube($$ary[$i], $$ary[$i+1], $$ary[$i+2], $$ary[$i+3],
				0, $fronts[$j], $tops[$j], $sides[$j], 
				$xoff, $xbarw, $zbarw, $$xvals[$$ary[$i]-1], $$zvals[$$ary[$i+3]-1]);
			$j++;
			$j = 0 if ($j > $#fronts);
			next;
		}
		for (my $k = 0; $k < $numRanges; $k++) {
			$ary = $obj->{data}->[$k];
			$obj->drawCube($$ary[$i], $$ary[$i+1], $$ary[$i+2], $$ary[$i+3],
				$k, $fronts[$k], $tops[$k], $sides[$k], 
				$xoff, $xbarw, $zbarw, $$xvals[$$ary[$i]-1], $$zvals[$$ary[$i+3]-1]);
		}
	}
#
#	need to redraw floor and ticks
	$obj->plot3DTicks;
	return 1;
}

sub computeSides {
	my ($x, $xoff, $barw, $k) = @_;
	
	return ($x - ($xoff/2) + ($k * $barw), 
		$x - ($xoff/2) + (($k+1) * $barw));
}

sub drawCube {
	my ($obj, $x, $yl, $yh, $z, $k, $front, $top, $side, 
		$xoff, $xbarw, $zbarw, $xval, $zval) = @_;
	my ($xl, $xr) = computeSides($x, $xoff, $xbarw, $k);
	$z++;
#
#	generate value coordinates of visible vertices
	my @v = (
		$xl, $yl, $z - $zbarw,	# left bottom front
		$xl, $yh, $z - $zbarw,	# left top front
		$xl, $yh, $z + $zbarw,	# left top rear
		$xr, $yh, $z + $zbarw,	# right top rear
		$xr, $yh, $z - $zbarw,	# right top front
		$xr, $yl, $z - $zbarw,	# right bottom front
		$xr, $yl, $z + $zbarw	# right bottom rear
	);
	
	my @xlatverts = ();
	my $img = $obj->{img};
	my ($i, $j);
#
#	translate value vertices to pixel coordinate using
#	cabinet projection
	for ($i = 0; $i < 21; $i+=3) {
		push(@xlatverts, $obj->pt2pxl($v[$i], $v[$i+1], $v[$i+2]));
	}
	my @faces = ($top, $front, $side);
#
#	render faces as filled polygons to obscure any prior cubes
#
	for ($i = 0; $i < 3; $i++) {
		my $poly = new GD::Polygon;
		my $ary = $polyverts[$i];
		for ($j = 0; $j < 4; $j++) {
			$poly->addPt($xlatverts[$$ary[$j]],$xlatverts[$$ary[$j]+1]);
		}
		$img->filledPolygon($poly, $faces[$i]);
	}
	for ($i = 0; $i < 18; $i+=2) {
		$img->line($xlatverts[$vert2lines[$i]], 
			$xlatverts[$vert2lines[$i]+1],
			$xlatverts[$vert2lines[$i+1]],
			$xlatverts[$vert2lines[$i+1]+1], $obj->{black});
	}
#
#	generate image map for top face only
#
	my $y = ($yh > 0) ? $yh : $yl;
	if ($obj->{genMap}) {
		my $text = ($zval) ? "($xval, $y, $zval)" : "($xval, $y)";
		my $ary = $polyverts[0];
		my @ptsary = ();
		for ($i = 0; $i < 4; $i++) {
			push(@ptsary, $xlatverts[$$ary[$i]], $xlatverts[$$ary[$i]+1]);
		}
		$obj->updateImagemap('POLY', $text, 0, $xval, $y, $zval, @ptsary);
	}
#
#	render the top text label
#
	my $mx = ($xr + $xl)/2;
	my ($px, $py) = $obj->pt2pxl($mx, $yh, $z - $zbarw);
	$img->stringUp(gdTinyFont, $px, $py-10, $y, $obj->{textColor});
	1;
}

sub abs { my $x = shift; return ($x < 0) ? -1*$x : $x; }

sub plotPie {
	my ($obj) = @_;
	my $ary = $obj->{data}->[0];
#
#	extract properties
#
	my @colormap = ();
	my $t = $obj->{props}->[0];
	$t=~s/\s+/ /g;
	$t = lc $t;
	my @props = split (' ', $t);
	my $img = $obj->{img};
	foreach my $prop (@props) {
		push(@colormap, $img->colorAllocate(@{$colors{$prop}}))
			if ($colors{$prop});
	}
#
#	render each wedge, in clockwise order, starting from 12 o'clock
#
	my $i = 0;
#
#	compute sum of wedge values
#	and max length of wedge labels
#
	my $total = 0;
	my $arc = 0;
	my $maxlen = 0;
	my $len = 0;
	for ($i = 0; $i <= $#$ary; $i+=2) { 
		$total += $$ary[$i+1]; 
		$len = length($$ary[$i]) + 6;
		$len = 25 if ($len > 25);
		$maxlen = $len if ($len > $maxlen);
	}
	$maxlen++;
	$maxlen *= $tfw;
	$obj->{errmsg} = 'Insufficient image size for graph.',
	return undef
		if ($maxlen * 2 > ($obj->{width} * 0.5));
#
#	compute center coords and radius of pie
#
	my $xc = int($obj->{width}/2);
	my $yc = int(($obj->{height}/2) - 30);
	my $hr = $xc - $maxlen - 10;
	my $vr = $obj->{threed} ? int($hr * tan(30 * (3.1415926/180))) : $hr;
	my $piefactor = $obj->{threed} ? cotan(30 * (3.1415926/180)) : 1;

	$vr = $yc - 10, $hr = $vr
		unless ($obj->{threed} || ($yc - 10 > $vr));
	$vr = $yc - 10, $hr = int($vr/tan(30))
		if ($obj->{threed} && ($vr > $yc - 10));

	$img->arc($xc, $yc, $hr*2, $vr*2, 0, 360, $obj->{black});
	$img->arc($xc, $yc+20, $hr*2, $vr*2, 0, 180, $obj->{black}),
	$img->line($xc-$hr, $yc, $xc-$hr, $yc+20, $obj->{black}),
	$img->line($xc+$hr, $yc, $xc+$hr, $yc+20, $obj->{black})
		if $obj->{threed};

#	$img->line($xc, $yc, $xc, $yc - $radius, $obj->{black});
#
#	now draw each wedge
#
	my $w = 0;
	my $j = 0;
	for ($i = 0, $j = 0; $i <= $#$ary; $i+=2, $j++) { 
		$w = $$ary[$i+1];
		my $color = $colormap[$j%(scalar @colormap)];
		$arc = $obj->drawWedge($arc, $color, $xc, 
			$yc, $vr, $hr, $w/$total, $$ary[$i], $w, $piefactor);
	}
	return 1;
}

sub drawWedge {
	my ($obj, $arc, $color, $xc, $yc, $vr, $hr, $pct, $text, $val, $piefactor) = @_;
	my $img = $obj->{img};
#
#	locate coords at 80% of radius that bisects the wedge;
#	we'll use this to fill the color and apply the text
#
	my ($x, $y, $fx, $fy);
#
#	if imagemap, generate 10 degree coordinates up 
#	to the arc of the wedge
#
	if ($obj->{genMap}) {
		my $tarc = 0;

		my @ptsary = ($xc, $yc);
		while ($tarc <= (2 * 3.1415926 * $pct)) {
			($x, $y) = computeCoords($xc, $yc, $vr, $hr, 
				$arc + $tarc, $piefactor);
			push(@ptsary, $x, $y);
			last if ((2 * 3.1415926 * $pct) - $tarc < (2 * 3.1415926/36));
			$tarc += (2 * 3.1415926/36);
				
		}
		if ($tarc < (2 * 3.1415926 * $pct)) {
			($x, $y) = computeCoords($xc, $yc, $vr, $hr, 
				$arc + (2 * 3.1415926 * $pct), $piefactor);
			push(@ptsary, $x, $y);
		}
		$obj->updateImagemap('POLY', 
			"$val(" . (int($pct * 1000)/10) . '%)', 0, $text, $val, 
			int(10000*$pct)/100, @ptsary);
	}
	my $start = $arc;
	my $bisect = $arc + ($pct * 3.1415926);
	$arc += (2 * 3.1415926 * $pct); 
	my $visible = ($obj->{threed} &&
		(($start < 3.1415926/2) || ($start >= (1.5 * 3.1415926)) ||
		($arc < 3.1415926/2) || ($arc >= (1.5 * 3.1415926))));
	$start = (($arc < 3.1415926/2) || ($arc >= (1.5 * 3.1415926))) ?
			$arc : $start;

#	print "Plotting $text with $pct % angle $arc\n";
	($x, $y) = computeCoords($xc, $yc, $vr, $hr, $arc, $piefactor);
	($fx, $fy) = computeCoords($xc, $yc, $vr * 0.6, $hr* 0.6, $bisect, $piefactor);
	$img->line($xc, $yc, $x, $y, $obj->{black});
	$img->fill($fx, $fy, $color);
#
#	draw front face line if visible
	if ($visible) {
		$img->line($x, $y, $x, $y+20, $obj->{black})
			if ($start == $arc);
		($fx, $fy) = computeCoords($xc, $yc+10, $vr, $hr, $start, $piefactor);
		$fx += ($start == $arc) ? 2 : -2;
		$img->fill($fx, $fy, $color);
	}
#
#	render text
#
	if ($text) {
		my ($gx, $gy) = computeCoords($xc, $yc, $vr, $hr, $bisect, $piefactor);
		$gy -= $sfh if (($bisect > 3.1415926/2) && ($bisect <= 3.1415926));

		$gy += 20 if ($obj->{threed} && 
			(($bisect < 3.1415926/2) || ($bisect >= (1.5 * 3.1415926))));
		$gx -= ((length($text)+1) * $sfw) 
			if (($gx < $xc) && ($bisect > 3.1415926/4));
		$gx += $sfw if ($gx > $xc);
		$gx -= (length($text) * $sfw/2) 
			if (($gx == $xc) || ($bisect <= 3.1415926/4));

		$img->string(gdSmallFont, $gx, $gy, $text, $obj->{textColor});
	}
	return $arc;
}

sub computeCoords {
	my ($xc, $yc, $vr, $hr, $arc, $piefactor) = @_;

	return (
		int($xc + $piefactor * $vr * cos($arc + (3.1415926/2))), 
		int($yc + $piefactor * ($vr/$hr) * $vr * sin($arc+ (3.1415926/2)))
	);
}

sub tan {
	my ($angle) = @_;
	
	return (sin($angle)/cos($angle));
}

sub cotan {
	my ($angle) = @_;
	
	return (cos($angle)/sin($angle));
}

sub updateImagemap {
	my ($obj, $shape, $alt, $plotNum, $x, $y, $z, @pts) = @_;
	$y = '' unless defined($y);
	$z = '' unless defined($z);
#
#	do different for Perl map
#
	return $obj->updatePerlImagemap($plotNum, $x, $y, $z, $shape, @pts)
		if (uc $obj->{mapType} eq 'PERL');
#
#	render image map element:
#	hotspot is an 8 pixel diameter circle centered on datapoint for
#	lines, points, areas, and candlesticks.
#	the user can provide both a URL to be invoked, and/or a 
#	script function to be locally executed, when the hotspot is clicked.
#	Special variable names $PLOTNUM, $X, $Y, $Z can be specified
#	anywhere in the URL/script string to be interpolated to the
#	the equivalent input values
#
	$shape = uc $shape;
	$x =~ s/([^;\/?:@&=+\$,A-Za-z0-9\-_.!~*'()])/$escapes{$1}/g;
	$y =~ s/([^;\/?:@&=+\$,A-Za-z0-9\-_.!~*'()])/$escapes{$1}/g;
	$z =~ s/([^;\/?:@&=+\$,A-Za-z0-9\-_.!~*'()])/$escapes{$1}/g;
	my $imgmap = $obj->{imgMap};
#
#	interpolate special variables
#
	my $imgURL = $obj->{mapURL};
	$imgURL=~s/:PLOTNUM\b/$plotNum/g,
	$imgURL=~s/:X\b/$x/g,
	$imgURL=~s/:Y\b/$y/g,
	$imgURL=~s/:Z\b/$z/g
		if ($imgURL);
#
#	interpolate special variables
#
	my $imgScript = $obj->{mapScript};
	$imgScript=~s/:PLOTNUM\b/$plotNum/g,
	$imgScript=~s/:X\b/$x/g,
	$imgScript=~s/:Y\b/$y/g,
	$imgScript=~s/:Z\b/$z/g
		if ($imgScript);

	$imgmap .= "\n<AREA ALT=\"$alt\" " .
		(($obj->{mapURL}) ? " HREF=\"$imgURL\" " : ' NOHREF ');
	$imgmap .= " $imgScript "
		if ($imgScript);

	$imgmap .= " SHAPE=$shape COORDS=\"" . join(',', @pts) . '">';
	$obj->{imgMap} = $imgmap;
	return 1;
}

sub updatePerlImagemap {
	my ($obj, $plotNum, $x, $y, $z, $shape, @pts) = @_;
#
#	render image map element:
#	hotspot is an 8 pixel diameter circle centered on datapoint for
#	lines, points, areas, and candlesticks.
#
	my $imgmap = $obj->{imgMap};
	$imgmap .= ",\n" unless ($imgmap eq '');
	$imgmap .= 
"\{
	plotnum => $plotNum,
	X => '$x',
	Y => '$y',
	Z => '$z',
	shape => '$shape',
	coordinates => [ " . join(',', @pts) . "]
}";
	$obj->{imgMap} = $imgmap;
	return 1;
}

sub formatTime {
	my ($obj, $timeval) = @_;
	my $fmt = $obj->{timeDomain};
	if ($fmt=~/^(YY)?YY[-\.\/]MM(M)?[-\.\/]DD( HH:MM:SS)?$/) {
		ctime($timeval);
	}

	my ($hrs, $mins, $secs);
	$hrs = int($timeval/3600),
	$mins = int(($timeval - ($hrs * 3600))/60),
	$secs = $timeval%60,
	return "$hrs:$mins:$secs"
		if ($fmt eq 'HH:MM:SS');

	$obj->{errmsg} = "Unrecognized time domain format $fmt.";
	return undef;
}

sub addLogo {
	my ($obj) = @_;
	my $pat = GD::Image->can('newFromGif') ? 'png|jpe?g|gif' : 'png|jpe?g';
	my ($logo, $imgw, $imgh) = ($obj->{logo}, $obj->{width}, $obj->{height});
	my $img = $obj->{img};

	$obj->{errmsg} = 
	'Unrecognized logo file format. File qualifier must be .png, .jpg, ' .
		(GD::Image->can('newFromGif') ? '.jpeg, or .gif.' :	'or .jpeg.'),
	return undef
		unless ($logo=~/\.($pat)$/i);

	$obj->{errmsg} = 'Unable to open logo file.',
	return undef
		unless open(LOGO, "<$logo");

	my $logoimg = ($logo=~/\.png$/i) ? GD::Image->newFromPng(*LOGO) :
	  ($logo=~/\.gif$/i) ? GD::Image->newFromGif(*LOGO) :
	    GD::Image->newFromJpeg(*LOGO);
	close(LOGO);
	
	$obj->{errmsg} = 'GD cannot read logo file.',
	return undef
		unless $logoimg;

	my ($logow, $logoh) = $logoimg->getBounds();
#
#	force the logo into the defined image area
#
	my $srcX = ($logow > $imgw) ? ($logow - $imgw)>>1 : 0;
	my $srcY = ($logoh > $imgh) ? ($logoh - $imgh)>>1 : 0;
	my $dstX = ($logow > $imgw) ? 0 : ($imgw - $logow)>>1;
	my $dstY = ($logoh > $imgh) ? 0 : ($imgh - $logoh)>>1;
	my $h = ($logoh > $imgh) ? $imgh : $logoh;
	my $w = ($logow > $imgw) ? $imgw : $logow;
	$img->copy($logoimg, $dstX, $dstY, $srcX, $srcY, $w-1, $h-1);
	return 1;
}
 1;
__END__

=head1 NAME

DBD::Chart::Plot - Graph/chart Plotting engine for DBD::Chart

=head1 SYNOPSIS

    use DBD::Chart::Plot; 
    
    my $img = DBD::Chart::Plot->new(); 
    my $anotherImg = DBD::Chart::Plot->new($image_width, $image_height); 
    
    $img->setPoints(\@xdataset, \@ydataset, 'blue line nopoints');
    
    $img->setOptions (
        horizMargin => 75,
        vertMargin => 100,
        title => 'My Graph Title',
        xAxisLabel => 'my X label',
        yAxisLabel => 'my Y label' );
    
    print $img->plot;

=head1 DESCRIPTION

B<DBD::Chart::Plot> creates images of line and scatter graphs for
two dimensional data. Unlike GD::Graph, the input data sets
do not need to be uniformly distributed in the domain (X-axis).

B<DBD::Chart::Plot> supports the following:

=over 4

=item - multiple data set plots

=item - line graphs, areagraphs, scatter graphs, linegraphs w/ points, 
	candlestick graphs, barcharts (2-D, 3-D, and 3-axis), piecharts,
	and box & whisker charts (aka boxcharts)

=item - optional iconic barcharts or datapoints

=item - a wide selection of colors, and point shapes

=item - optional horizontal and/or vertical gridlines

=item - optional legend

=item - auto-sizing of axes based in input dataset ranges

=item - automatic sorting of numeric input datasets to assure 
	proper order of plotting

=item - optional symbolic (i.e., non-numeric) domain values

=item - optional X, Y, and Z axis labels

=item - optional X and/or Y logarithmic scaling

=item - optional title

=item - optional adjustment of horizontal and vertical margins

=item - optional HTML or Perl imagemap generation


=back

=head1 PREREQUISITES

=over 4

=item B<GD.pm> module minimum version 1.26 (available on B<CPAN>)

GD.pm requires additional libraries:

=item libgd

=item libpng

=item zlib

=head1 USAGE

=head2 Create an image object: new()

    use DBD::Chart::Plot; 

    my $img = DBD::Chart::Plot->new; 
    my $img = DBD::Chart::Plot->new ( $image_width, $image_height ); 
    my $anotherImg = new DBD::Chart::Plot; 

Creates an empty image. If image size is not specified, 
the default is 400 x 300 pixels. 

=head2 Graph-wide options: setOptions()


    $img->setOptions (_title => 'My Graph Title',
        xAxisLabel => 'my X label',
        yAxisLabel => 'my Y label',
        xLog => 0,
        yLog => 0,
        horizMargin => $numHorPixels,
        vertMargin => $numvertPixels,
        horizGrid => 1,
        vertGrid => 1,
        showValues => 1,
        legend => \@plotnames,
        genMap => 'a_valid_HTML_anchor_name',
        mapURL => 'http://some.website.com/cgi-bin/cgi.pl',
        icon => [ 'redstar.png', 'bluestar.png' ]
        symDomain => 0
     );

As many (or few) of the options may be specified as desired.

=item width, height

The width and height of the image in pixels. Default is 400 and 300,
respectively.

=item genMap, mapType, mapURL, mapScript

COntrol generation of imagemaps. When genMap is set to a legal HTML
anchor name, an image map of the specified type is created for the image.
The default type is 'HTML' if no mapType is specified. Legal types are
'HTML' and 'PERL'.

If mapType is 'PERL', then Perl script compatible text is generated
representing an array ref of hashrefs containing the following
attributes:

plotnum => the plot number to which this hashref applies (to support
multi-range graphs), starting at zero.

x => the domain value for the plot element

y => the range value for the plot element

z => the Z axis value for 3-axis bar charts, if any

shape => the shape of the hotspot area of the plot element, same
as for HTML: 'RECT', 'CIRCLE', 'POLY'

coordinates => an arrayref of the (x,y) pixel coordinates of the hotspot
area to be mapped; for CIRCLE shape, its (x-center, y-center, radius),
for RECT, its (upper-left corner x, upper-left corner y, 
lower-right corner x, lower-right corner y), and for POLY its the
set of vertices (x,y)'s.

If the mapType is 'HTML', then either the mapURL or mapScript (or both)
can be specified. mapURL specifies a legal URL string, e.g., 
'http://www.mysite.com/cgi-bin/plotproc.pl?plotnum=:PLOTNUM&X=:X&Y=:Y',
which will be added to the AREA tags generated for each mapped plot element.
mapScript specifies any legal HTML scripting tag, e.g.,
'ONCLICK="alert('Got X=:X, Y=:Y')"' to be added to each generated AREA tag.

For both mapURL and mapScript, special variables :PLOTNUM, :X, :Y, :Z
can be specified which are replaced by the following values when the
imagemap is generated.

Refer to the IMAGEMAP description at www.presicient.com/dbdchart#imagemap
for details.

=item horizMargin, vertMargin

Sets the number of pixels around the actual plot area.

=item xAxisLabel, yAxisLabel, zAxisLabel

Sets the label strings for each axis.

=item xLog, yLog

When set to a non-zero value, causes the associated axis to be
rendered in log10 format. Z axis plots are currently only
symbolic, so no zLog is supported.

=item title

Sets a title string to be rendered at the bottom center of the image
in bold text.

=item signature

Sets a string to be rendered in tiny font at the lower right corner of the
image, e.g., 'Copyright(C) 2001, Presicient Corp.'.

=item legend

Set to an array ref of domain names to be displayed in a legend
for the various plots.
The legend is displayed below the chart, left justified and placed
above the chart title string.
The legend for each plot is
printed in the same color as the plot. If a point shape or icon has been specified
for a plot, then the point shape is printed with the label; otherwise, a small
line segment is printed with the label. Due to space limitations, 
the number of datasets plotted should be limited to 8 or less.

=item showValues

When set to a non-zero value, causes the data points for each
plotted element to be displayed next to hte plot point.

=item horizGrid, vertGrid

Causes grid lines to be drawn completely across the plot area.

=item xAxisVert

When set to a non-zero value, causes the X axis tick labels to be rendered 
vertically.

=item keepOrigin

When set to a non-zero value, forces the (0,0) data point into the
graph. Normally, DBD::Chart::Plot will heuristically clip away from the
origin is the plot never crosses the origin.

=item bgColor

Sets the background color of the image. Default is white.

=item threed

When set to a non-zero value for barcharts, causes the bars to be
rendered in a 3-D effect.

=item icons

Set to an arrayref of image filenames. The images will be used
to plot iconic barcharts or individual plot points, if the
'icon' shape is specified in the property string supplied
to the setPoints() function (defined below). The array must
match 1-to-1 with the number of plots in the image; icons
and predefined point shapes can be mixed in the same image
by setting the icon arrayref entry to undef for plots using
predefined shapes in the properties string.

=item symDomain

When set to a non-zero value, causes the domain to be treated
as discrete symbolic values which are evenly distributed over
the X-axis. Numeric domains are plotted as scaled values
in the image.

=item timeDomain - NOT YET SUPPORTED

When set to a valid format string, the domain data points
are treated as associated temporal values (e.g., date,  time,
timestamp, interval). The values supplied by setPoints will
be strings of the specified format (e.g., 'YYYY-MM-DD'), but
will be converted to numeric time values for purposes of
plotting, so the domain is treated as continuous numeric
data, rather than discrete symbolic.

=item gridColor

Sets the color of the axis lines and ticks. Default is black.

=item textColor

Sets the color used to render text in the image. Default is black.

=item font - NOT YET SUPPORTED

Sets the font used to render text in the image. Default is
default GD fonts (gdMedium, gdSmall, etc.).

=item logo

Specifies the name of an image file to be drawn into the
background of the image. The logo image is centered in the
plot image, and will be clipped if the logo size exceeds
the defined width or height of the plot image.

By default, the graph will be centered within the image, with 50
pixel margin around the graph border. You can obtain more space for 
titles or labels by increasing the image size or increasing the
margin values.


=head2 Establish data points: setPoints()

    $img->setPoints(\@xdata, \@ydata);
    $img->setPoints(\@xdata, \@ydata, 'blue line');
    $img->setPoints(\@xdata, \@ymindata, \@ymaxdata, 'blue points');
    $img->setPoints(\@xdata, \@ydata, \@zdata, 'blue bar zaxis');

Copies the input array values for later plotting.
May be called repeatedly to establish multiple plots in a single graph.
Returns a positive integer on success and C<undef> on failure. 
The global graph properties should be set (via setOptions())
prior to setting the data points.
The error() method can be used to retrieve an error message.
X-axis values may be non-numeric, in which case the set of domain values
is uniformly distributed along the X-axis. Numeric X-axis data will be
properly scaled, including logarithmic scaling is requested.

If two sets of range data (ymindata and ymaxdata in the example above)
are supplied, and the properties string does not specify a 3-axis barchart,
a candlestick graph is rendered, in which case the domain
data is assumed non-numeric and is uniformly distributed, the first range
data array is used as the bottom value, and the second range data array
is used as the top value of each candlestick. Pointshapes may be specified,
in which case the top and bottom of each stick will be capped with the
specified pointshape. The range axis may be logarithmically scaled. 
If value display is requested, the range value of both the top and bottom 
of each stick will be printed above and below the stick, respectively.

B<Plot properties:> Properties of each dataset plot can be set
with an optional string as the third argument. Properties are separated
by spaces. The following properties may be set on a per-plot basis
(defaults in capitals):

    COLOR     CHARTSTYLE  USE POINTS?   POINTSHAPE 
    -----     ---------  -----------   ----------
	BLACK       LINE        POINTS     FILLCIRCLE
	white      noline      nopoints    opencircle
	lgray       fill                   fillsquare  
	gray        bar                    opensquare
	dgray       pie                    filldiamond
	lblue       box                    opendiamond
	blue       zaxis                   horizcross
	dblue                              diagcross
	gold                               icon
	lyellow	
	yellow
	dyellow
	lgreen
	green
	dgreen
	lred
	red
	dred
	lpurple	
	purple
	dpurple
	lorange
	orange
	pink
	dpink
	marine
	cyan	
	lbrown
	dbrown

E.g., if you want a red scatter plot (red dots
but no lines) with filled diamonds, you could specify

    $p->setPoints (\@xdata, \@ydata, 'Points Noline Red filldiamond');
    
Specifying icon for the pointshape requires setting the
icon object attribute to a list of compatible image filenames
(as an arrayref, see below). In that case, the icon images
are displayed centered on the associated plotpoints. For 2-D 
barcharts, a stack of the icon is used to display the bars,
including a proportionally clipped icon image to cap the bar
if needed.


=head2 Draw the image: plot() 

     $img->plot();

Draws the image and returns it as a string.
To save the image to a file:

    open (WR,'>plot.png') or die ("Failed to write file: $!");
    binmode WR;            # for DOSish platforms
    print WR $img->plot();
    close WR;

To return the graph to a browser via HTTP:

    print "Content-type: image/png\n\n";
    print  $img->plot();

The range of values on each axis is automatically
computed to optimize the data placement in the largest possible
area of the image. As a result, the origin (0, 0) axes 
may be omitted if none of the datasets do not cross them at any point. 
Instead, the axes will be drawn on the left and bottom borders
using the value ranges that appropriately fit the dataset(s).

=head2 Fetch the imagemap: getMap() 

     $img->getMap();

Returns the imagemap for the chart. 
If no mapType was set, or if mapType was set to HTML.
the returned value is a valid <MAP...><AREA...></MAP> HTML string.
If mapType was set to 'Perl', a Perl-compatible arrayref
declaration string is returned.

The resulting imagemap will be applied as follows:

=item 2 axis 2-D Barcharts

Each bar is mapped individually.

=item Piecharts

Each wedge is mapped. The CGI parameter values are used slightly
differently than described above:

X=<wedge-label>&Y=<wedge-value>&Z=<wedge-percent>

=item 3-D Barcharts (either 2 or 3 axis)

The top face of each bar is mapped. The Z CGI parameter will be
empty for 2 axis barcharts.


=item Line, point, area graphs

A 4 pixel diameter circle around each datapoint is mapped.

=item Candlestick graphs

A 4 pixel diameter circle around both the top and bottom datapoints
of each stick are mapped.


=item Boxcharts

The area of the box is mapped, and 4-pixel diameter circles
are mapped at the end of each extreme whisker.


=head1 BUGS AND TO DO

=item programmable fonts

=item temporal domain and ranges

=item symbolic ranges for scatter graphs

=item surfacemaps

=item SVG support

=head1 AUTHOR

Copyright (c) 2001 by Presicient Corporation. (darnold@presicient.com)

You may distribute this module under the terms of the Artistic License, 
as specified in the Perl README file.

=head1 SEE ALSO

GD, DBD::Chart. (All available on CPAN).
