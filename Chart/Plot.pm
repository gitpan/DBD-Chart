#23456789012345678901234567890123456789012345678901234567890123456789012345
#
# DBD::Chart::Plot -- Plotting engine for DBD::Chart
#
#	Copyright (C) 2001,2002 by Dean Arnold <darnold@presicient.com>
#
#   You may distribute under the terms of the Artistic License, 
#	as specified in the Perl README file.
#
#	Change History:
#
#	0.63	2002-May-16		D. Arnold
#		fix for Gantt chart date axis alignment
#
#	0.61	2002-Feb-07		D. Arnold
#		fix for :PLOTNUM imagemap variable in Gantt chart
#		fix for undef range values
#		added 'dot' point shape (contributed by Andrea Spinelli)
#		fix for temporal alignment
#		fix for tick labels overwriting axis labels
#
#	0.60	2002-Jan-12		D. Arnold
#		support temporal datatypes
#		support histograms
#		support composite images
#		support user defined colors
#		scale boxchart vertical offsets
#		support Gantt charts
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

$DBD::Chart::Plot::VERSION = '0.63';

use GD;
use Time::Local;
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
'icon', 9,
'dot', 10);
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
	timeRange 1
);
my @lines = ( 
[ 0*2, 4*2,	5*2, 1*2 ],	# top face
[ 0*2, 1*2, 3*2, 2*2 ],	# front face
[ 1*2, 5*2, 7*2, 3*2 ]	# side face
);

my %month = ( 'JAN', 0, 'FEB', 1, 'MAR', 2, 'APR', 3, 'MAY', 4, 'JUN', 5, 
'JUL', 6, 'AUG', 7, 'SEP', 8, 'OCT', 9, 'NOV', 10, 'DEC', 11);
my @monthmap = qw( JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC );
#
#	URI escape map
#
my %escapes = ();
for (0..255) {
    $escapes{chr($_)} = sprintf("%%%02X", $_);
}

use constant LINE => 1;
use constant POINT => 2;
use constant AREA => 4;
use constant BOX => 8;
use constant PIE => 16;
use constant HISTO => 32;
use constant BAR => 64;
use constant CANDLE => 128;
use constant GANTT => 256;

my %typemap = ( 'BAR', BAR, 'HISTO', HISTO, 'FILL', AREA, 
	'CANDLE', CANDLE, 'BOX', BOX, 'GANTT', GANTT);

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
#	icon - name of icon image file for iconic barcharts/points
#	logo - name of background logo image file
#
sub init {
	my ($obj, $w, $h, $colormap) = @_;

	$w = 400 unless $w;
	$h = 300 unless $h;
	my $img = new GD::Image($w, $h);
#
#	if a colormap supplied, copy it into our color list
#
	if ($colormap) {
		foreach my $color (keys(%$colormap)) {
			$colors{lc $color} = $$colormap{$color};
		}
	}
	
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
	$obj->{plotTypes} = 0;

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
	$obj->{haveScale} = 0;	# 1 = last calculated min & max still valid
	$obj->{domainValues} = { };	# map of domain values for bar/histo/candle/sym domains
	$obj->{boxCount} = 0;	# num of boxcharts in plot
	$obj->{barCount} = 0;	# num of barchart/histos in plot
	$obj->{xMaxLen} = 0;	# max length of symbolic X value
	$obj->{yMaxLen} = 0;	# max length of temporal Y value
	$obj->{zMaxLen} = 0;	# max length of symbolic Z value

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
	$obj->{timeRange} = undef; # defines format of temporal range labels

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

sub convert_temporal {
	my ($value, $format) = @_;
#
#	use Perl funcs to compute seconds from date
	my $t;
	$t = timegm(0, 0, 0, $3, $2 - 1, $1),
	$t -= ($t%86400), #	timelocal isn't behaving quite right
	return $t
		if (($format eq 'YYYY-MM-DD') &&
			($value=~/^(\d+)[\-\.\/](\d+)[\-\.\/](\d+)$/));

	$t = timegm(0, 0, 0, $3, $month{uc $2}, $1),
	$t -= ($t%86400), #	timelocal isn't behaving quite right
	return $t
		if (($format eq 'YYYY-MM-DD') &&
			($value=~/^(\d+)[\-\.\/](\w+)[\-\.\/](\d+)$/) &&
			defined($month{uc $2}));

	return timegm($6, $5, $4, $3, $2 - 1, $1) + ($7 ? $7 : 0)
		if (($format eq 'YYYY-MM-DD HH:MM:SS') &&
			($value=~/^(\d+)[\-\.\/](\d+)[\-\.\/](\d+)\s+(\d+):(\d+):(\d+)(\.\d+)?$/));

	return timegm($6, $5, $4, $3, $month{uc $2}, $1) + ($7 ? $7 : 0)
		if (($format eq 'YYYY-MM-DD HH:MM:SS') &&
			($value=~/^(\d+)[\-\.\/](\w+)[\-\.\/](\d+)\s+(\d+):(\d+):(\d+)(\.\d+)?$/) &&
			(defined($month{uc $2})));

	return (($1 ? (($1 eq '-') ? -1 : 1) : 1) * (($3 ? ($3 * 3600) : 0) + ($5 ? ($5 * 60) : 0) + 
		$6 + ($7 ? $7 : 0)))
		if ((($format eq '+HH:MM:SS') || ($format eq 'HH:MM:SS')) && 
			($value=~/^([\-\+])?((\d+):)?((\d+):)?(\d+)(\.\d+)?$/));

	return undef; # for completeness, shouldn't get here
}
#
#	restore the readable datetime form from 
#	the input numeric value
sub restore_temporal {
	my ($value, $format) = @_;

	my ($sign, $subsec, $sec, $min, $hour, $mday, $mon, $yr, $wday, $yday, $isdst);
	$sign = ($value < 0);
	$value = abs($value);
	if (($format eq '+HH:MM:SS') || ($format eq 'HH:MM:SS')) {
		$hour = int($value/3600);
		$min = int(($value%3600)/60);
		$sec = int($value%60);
		$hour = "0$hour" if ($hour < 10);
		$min = "0$min" if ($min < 10);
		$sec = "0$sec" if ($sec < 10);
		$subsec = int(($value - int($value)) * 100);
		return ($sign ? '-' : '') . "$hour:$min:$sec" . 
			($subsec ? ".$subsec" : '');
	}

	($sec, $min, $hour, $mday, $mon, $yr, $wday, $yday, $isdst) = gmtime($value);
	$yr += 1900;
	$mon++;
	$mon = "0$mon" if ($mon < 10);
	$min = "0$min" if ($min < 10);
	$sec = "0$sec" if ($sec < 10);
	$mday = "0$mday" if ($mday < 10);
	
	return "$yr\-$mon\-$mday"
		if ($format eq 'YYYY-MM-DD');

	$mon = $monthmap[$mon-1],
	return "$yr\-$mon\-$mday"
		if ($format eq 'YYYY-MMM-DD');

	return "$yr\-$mon\-$mday $hour:$min:$sec"
		if ($format eq 'YYYY-MM-DD HH:MM:SS');

	$mon = $monthmap[$mon-1],
	return "$yr\-$mon\-$mday $hour:$min:$sec"
		if ($format eq 'YYYY-MMM-DD HH:MM:SS');

	return undef; # for completeness, shouldn't get here
}

sub setCandlePoints {
	my ($obj, $xary, @ranges) = @_;
	my $props = pop @ranges;
	my $num_ranges = @ranges;
	$obj->{errmsg} = 'Missing a min or max range array.', return undef
		unless ($num_ranges == 2);
#
#	validate environment
#
	$obj->{errmsg} = 'Candle not compatible with 3-D plots.', return undef
		if ($obj->{threed} || $obj->{zAxis});

	$obj->{errmsg} = 'Incompatible plot types.', return undef
		if ($obj->{plotTypes} & (HISTO|BOX|PIE|GANTT));
#
#	require prior line/point/areas to explicitly decclare domain type
	$obj->{errmsg} = 'Incompatible plot domain types.', return undef
		if (($obj->{plotTypes} & (LINE|POINT|AREA)) && (! $obj->{symDomain}));

	$obj->{symDomain} = 1;
	$obj->{plotTypes} |= CANDLE;
#
#	now translate/validate datapoints
	my ($x, $yaryl, $yaryh,$i, $yl, $yh);
	$yaryl = $ranges[0];
	$yaryh = $ranges[1];

	$obj->{errmsg} = 'Unbalanced dataset.',
	return undef
		if (($#$xary != $#$yaryl) || ($#$xary != $#$yaryh));
		
	my ($ymin, $ymax) = ($obj->{yl}, $obj->{yh});
	$ymin = 1E38 unless defined($ymin);
	$ymax = -1E38 unless defined($ymax);
#
# record/merge the dataset
	my $domVals = $obj->{domainValues};
	my @data = ();
	my $idx = 0;
	for (my $i = 0; $i <= $#$xary; $i++) {
		next unless (defined($$xary[$i]) && 
			defined($$yaryl[$i]) && defined($$yaryh[$i]));

		($x, $yl, $yh) = ($$xary[$i], $$yaryl[$i], $$yaryh[$i]);
		$x = convert_temporal($x, $obj->{timeDomain}) if $obj->{timeDomain}; 
		$yl = convert_temporal($yl, $obj->{timeRange}),
		$yh = convert_temporal($yh, $obj->{timeRange})
			if $obj->{timeRange};
#
#	validate the range values
		$obj->{errmsg} = 'Non-numeric range value ' . $yl . '.',
		return undef
			unless ($obj->{timeRange} || 
				($yl=~/^[+-]?\d+\.?\d*([Ee][+-]?\d+)?$/));

		$obj->{errmsg} = 'Non-numeric range value ' . $yh . '.',
		return undef
			unless ($obj->{timeRange} || 
				($yh=~/^[+-]?\d+\.?\d*([Ee][+-]?\d+)?$/));

		$obj->{errmsg} = 'Invalid value supplied for logarithmic axis.',
		return undef
			if ($obj->{yLog} && (($yl <= 0) || ($yh <= 0)));

		$domVals->{$x} = defined($domVals) ? scalar(keys(%$domVals)) : 0
			unless ($domVals->{$x});
#
#	force data into array in same order as any prior definition
		$idx = $domVals->{$x} * 3;
		$data[$idx++] = $x;
		$data[$idx++] = $obj->{yLog} ? log($$yaryl[$i])/log(10) : $$yaryl[$i];
		$data[$idx] = $obj->{yLog} ? log($$yaryh[$i])/log(10) : $$yaryh[$i];

		$obj->{xMaxLen} = length($x) 
			unless ($obj->{xMaxLen} && ($obj->{xMaxLen} >= length($x)));
		
		$ymin = $$yaryl[$i] unless (defined($ymin) && ($$yaryl[$i] >= $ymin));
		$ymax = $$yaryh[$i] unless (defined($ymin) && ($$yaryh[$i] <= $ymax));
	}
	push(@{$obj->{data}}, \@data);
	push(@{$obj->{props}}, $props);
#
#	set width of the sticks
#
	$obj->{brushWidth} = 2;
	$obj->{yl} = $ymin;
	$obj->{yh} = $ymax;
	$obj->{xl} = 1;
	$obj->{xh} = scalar(keys(%$domVals));
	$obj->{haveScale} = 0; # invalidate any prior min-max calculations
	return 1;
}

sub set3DBarPoints {
	my ($obj, $xary, $yary, $zary, $props, $type) = @_;
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

	$type = $props,
	$props = $zary, 
	$zary = undef
		unless $hasZaxis;

	my @zs = ();
	my %zhash = ();
	my %xhash = ();
	my @xs = ();
	my @xvals = @$xary;
	my ($xval, $zval) = (0,1);
	my $i = 0;
	my $maxlen = 0;
#
#	collect all X's and convert if needed
	for ($i = 0; $i <= $#xvals; $i++) {
		$xvals[$i] = convert_temporal($xvals[$i], $obj->{timeDomain})
			if $obj->{timeDomain};
		next if $xhash{$xvals[$i]};
		push(@xs, $xvals[$i]);
		$xhash{$xvals[$i]} = 1;
		$maxlen = length($xvals[$i]) if (length($xvals[$i]) > $maxlen);
	}
	$obj->{xMaxLen} = $maxlen;

	if ($hasZaxis) {
#
#	only 1 3-axis dataset permitted
		$obj->{errmsg} = 'Incompatible plot types.', return undef
			if $obj->{plotTypes};

		$obj->{errmsg} = 'Unbalanced dataset.',
		return undef
			if (($#$xary != $#$yary) || ($#$xary != $#$zary));
#
#	collect distinct Z and X values, and correlate them
#	with the assoc. Y value via hashes
#
		$maxlen = 0;
		for ($i = 0; $i <= $#$zary; $i++) {
			$zval = $$zary[$i];
			push(@zs, $zval),
			$zhash{$zval} = { }
				unless $zhash{$zval};
			$zhash{$zval}->{$xvals[$i]} = $$yary[$i];
			$maxlen = length($zval) if (length($zval) > $maxlen);
		}
		$obj->{zMaxLen} = $maxlen;
	}
	else {
		$obj->{errmsg} = 'Incompatible plot types.', return undef
			unless (($obj->{plotTypes} == 0) || ($obj->{plotTypes} & $type));

		$obj->{errmsg} = 'Unbalanced dataset.',
		return undef
			if ($#$xary != $#$yary);
#
#	synthesize Z axis values so we can process same as true 3 axis
#
		push(@zs, 1);
		$zhash{1} = { };
		for ($i = 0; $i <= $#$xary; $i++) {
			$zhash{1}->{$xvals[$i]} = $$yary[$i];
		}
		$obj->{zMaxLen} = 0;
	}
	
	@xs = sort numerically @xs
		if $obj->{timeDomain};

	$obj->{plotTypes} |= $type;
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
			$y = convert_temporal($y, $obj->{timeRange}) 
				if $obj->{timeRange};

			$obj->{errmsg} = "Non-numeric range value $y.",
			return undef
				unless ($obj->{timeRange} || 
					($y=~/^[+-]?\.?\d\d*(\.\d*)?([Ee][+-]?\d+)?$/));
		
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
# record the dataset; use stack to support multi-graph images
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
	$obj->{barCount}++;
	$obj->{symDomain} = 0;	# to avoid a later sort
	return 1;
}

#
#	2-Axis barchart
#
sub set2DBarPoints {
	my ($obj, $xary, $yary, $props, $type) = @_;

	$obj->{errmsg} = 'Unbalanced dataset.',
	return undef
		if ($#$xary != $#$yary);
#
#	validate environment
#
	$obj->{errmsg} = 'Incompatible plot types.', return undef
		if ((($type == HISTO) && $obj->{plotTypes} && ($obj->{plotTypes}^HISTO)) ||
			(($type != HISTO) && ($obj->{plotTypes} & HISTO)));

	$obj->{errmsg} = 'Incompatible plot domain types.', return undef
		if (($obj->{plotTypes} & (BOX|PIE|GANTT)) ||
			(($obj->{plotTypes} & (LINE|POINT|AREA)) && (! $obj->{symDomain})));

	$obj->{symDomain} = 1;
	$obj->{plotTypes} |= $type;

	my ($x, $y, $ylo, $yhi) = (0,0,0,0);
	my $ty = 0;
	my ($ymin, $ymax) = ($obj->{yl}, $obj->{yh});
	$ymin = 1E38 unless $ymin;
	$ymax = -1E38 unless $ymax;
#
# record/merge the dataset
	my $domVals = $obj->{domainValues};
	my @data = ();
	my $idx = 0;
	my $i;
	for ($i = 0; $i <= $#$xary; $i++) {
#
#	eliminate undefined data points
#
		next unless defined($$xary[$i]);
		$x = $$xary[$i];
		$y = $$yary[$i];

		$x = convert_temporal($x, $obj->{timeDomain}) if $obj->{timeDomain};

		$domVals->{$x} = defined($domVals) ? scalar(keys(%$domVals)) : 0
			unless defined($domVals->{$x});
		
		if (defined($y)) {
		$y = convert_temporal($y, $obj->{timeRange}) if $obj->{timeRange};
#
#	validate the range values
		$obj->{errmsg} = 'Non-numeric range value ' . $y . '.',
		return undef
			unless ($y=~/^[+-]?\.?\d+\.?\d*([Ee][+-]?\d+)?$/);
		
		$obj->{errmsg} = 
			'Invalid value supplied for logarithmic axis.',
		return undef
			if ($obj->{yLog} && ($y <= 0));
#
#	store datapts same as candlesticks w/ pseudo min (or max)
#	($xval[0], 0, yval[0]); use temp to test in case its logarithmic
#	since merge does the actual datapoint log conversion
#
		$ty = $obj->{yLog} ? log($y)/log(10) : $y;
		$ylo = ($ty >= 0) ? 0 : $y;
		$yhi = ($ty < 0) ? 0 : $y;
#
#	force data into array in same order as any prior definition
		$idx = $domVals->{$x} * 3;
		$data[$idx++] = $x;
		$data[$idx++] = $ylo;
		$data[$idx] = $yhi;
		$obj->{xMaxLen} = length($x) 
			unless ($obj->{xMaxLen} && ($obj->{xMaxLen} >= length($x)));
		$ymin = $ylo if ($ylo < $ymin);
		$ymax = $yhi if ($yhi > $ymax);
		}
	}
	push(@{$obj->{data}}, \@data);
	push(@{$obj->{props}}, $props);
	push(@{$obj->{bars}}, $#{$obj->{props}});
	$obj->{yl} = $ymin;
	$obj->{yh} = $ymax;
	$obj->{xl} = 1;
	$obj->{xh} = scalar(keys(%$domVals));
	
	$obj->{haveScale} = 0;	# invalidate any prior min-max calculations
	$obj->{barCount}++;
	return 1;
}

sub setPiePoints {
	my ($obj, $xary, $yary, $props) = @_;
		
	my @ary = ();

	$obj->{errmsg} = 'Incompatible plot types.', return undef
		if $obj->{plotTypes};

	$obj->{errmsg} = 'Unbalanced dataset.',
	return undef
		if ($#$xary != $#$yary);
	
	my $xtotal = 0;
	my ($i, $y);
	for ($i = 0; $i <= $#$xary; $i++) {
		next unless (defined($$xary[$i]) && defined($$yary[$i]));
		$y = $$yary[$i];
		$y = convert_temporal($y, $obj->{timeRange}) if $obj->{timeRange};

		$obj->{errmsg} = 'Non-numeric range value ' . $y . '.',
		return undef
			unless ($obj->{timeRange} || 
				($y=~/^[+-]?\.?\d+\.?\d*([Ee][+-]?\d+)?$/));

		$obj->{errmsg} = 
			'Negative range values not permitted for piecharts.',
		return undef
			if ($$yary[$i] < 0);

		$xtotal += $y;
		push(@ary, $$xary[$i], $y);
	}
	$obj->{plotTypes} |= PIE;
	push(@{$obj->{data}}, \@ary);
	push(@{$obj->{props}}, $props);
	$obj->{rangeSum} = $xtotal;
	$obj->{haveScale} = 0; # invalidate any prior min-max calculations
	return 1;
}

sub setBoxPoints {
	my ($obj, $xary, $props) = @_;

	$obj->{errmsg} = 'Incompatible plot types.', return undef
		if ($obj->{plotTypes} & (PIE|HISTO|BAR|CANDLE|GANTT));
		
	$obj->{errmsg} = 'Boxchart not compatible with 3-D plot types.', return undef
		if ($obj->{threed} || $obj->{zAxis});
		
	$obj->{errmsg} = 'Boxchart not compatible with symbolic domains.', return undef
		if $obj->{symDomain};
		
	my @data = ();
	foreach my $x (@$xary) {
		
		next unless defined($x);
		$x = convert_temporal($x, $obj->{timeDomain}) if $obj->{timeDomain};
		$obj->{errmsg} = 'Non-numeric value ' . $x . '.',
		return undef
			unless ($x=~/^[+-]?\d+\.?\d*([Ee][+-]?\d+)?$/);
		push(@data, $x);
	}
	@data = sort numerically @data;
	$obj->{xl} = $data[0] 
		unless (defined($obj->{xl}) && ($data[0] >= $obj->{xl}));
	$obj->{xh} = $data[$#data] 
		unless (defined($obj->{xh}) && ($data[$#data] <= $obj->{xh}));
	push(@{$obj->{data}}, \@data);
	push(@{$obj->{props}}, $props);
	$obj->{boxCount}++;
	$obj->{plotTypes} |= BOX;
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
#		setPoints($plotobj, \@tasks, \@start,\@end, \@assigned, \@pctcomplete,
#		\@depend1, [\@dependent2...], $props)
#
#	NOTE: graph type properties must be set prior to setting graph points
#	Each domain/rangeset must be separately defined with its properties
#	(e.g., a barchart with N domains requires N setPoints calls)
#
sub setPoints {
	my ($obj, $xary, @ranges) = @_;
	my $props = pop @ranges;

	return $obj->setCandlePoints($xary, @ranges, $props)
		if ($props=~/\bcandle\b/i);

	return $obj->set3DBarPoints($xary, @ranges, $props, $typemap{uc $1})
		if (($props=~/\b(bar|histo)\b/i) && 
			($obj->{zAxisLabel} || $obj->{threed}));

	return $obj->set2DBarPoints($xary, @ranges, $props, $typemap{uc $1})
		if ($props=~/\b(bar|histo)\b/i);

	return $obj->setPiePoints($xary, @ranges, $props)
		if ($props=~/\bpie\b/i);

	return $obj->setBoxPoints($xary, @ranges, $props)
		if ($props=~/\bbox\b/i);

	return $obj->setGanttPoints($xary, @ranges, $props)
		if ($props=~/\bgantt\b/i);
#
#	must be line/point/area, verify ranges have same num of elements
#	as domain
#
	my $yary = $ranges[0];

	$obj->{errmsg} = 'Unbalanced dataset.',
	return undef
		if ($#$xary != $#$yary);

	$obj->{errmsg} = 'Incompatible plot types.', return undef
		if ($obj->{plotTypes} & (PIE|HISTO|GANTT));
		
	$obj->{errmsg} = 
		'Line/point/area graph not compatible with 3-D plot types.', return undef
		if ($obj->{threed} || $obj->{zAxis});

	my $i;
	my ($x, $y) = (0,0);
	my ($xmin, $xmax, $ymin, $ymax) = 
		($obj->{xl}, $obj->{xh}, $obj->{yl}, $obj->{yh});
	my $is_symbolic = $obj->{symDomain};
	$xmin = $is_symbolic ? 1 : 1E38 unless defined($xmin);
	$xmax = $is_symbolic ? $#$xary + 1 : -1E38 unless defined($xmax);
	$ymin = 1E38 unless defined($ymin);
	$ymax = -1E38 unless defined($ymax);
#
# record/merge the dataset
	my $domVals = $obj->{domainValues};
	my @data = ();
	my $idx = 0;
	my @xs = ();
	my @ys = ();
#
#	sort numeric/temporal domain into asc. order
#
	my %xhash = ();
	my $needsort = 0;
	for ($i = 0; $i <= $#$xary; $i++) {
#
#	eliminate undefined data points
#
		$x = $$xary[$i];
		next unless defined($x);
		
		$x = convert_temporal($x, $obj->{timeDomain}) if $obj->{timeDomain};

		$obj->{errmsg} = "Non-numeric domain value $x.",
		return undef
			unless ($is_symbolic ||
				($x=~/^[+-]?\.?\d+\.?\d*([Ee][+-]?\d+)?$/));

		$obj->{errmsg} = "Invalid value for logarithmic axis.",
		return undef
			unless ($is_symbolic || (! $obj->{xLog}) ||	($x > 0));

		$obj->{xMaxLen} = length($x) 
			if ($is_symbolic && ((! $obj->{xMaxLen}) || (length($x) > $obj->{xMaxLen})));
		push(@xs, $x),
		$xhash{$x} = $#xs,
		next
			if $is_symbolic;

		$x = log($x)/log(10) if $obj->{xLog};
		$needsort = 1 if (($#xs >= 0) && ($xs[$#xs] > $x));
		push @xs, $x;
		$xhash{$x} = $#xs;
	}
#
#	optimize for presorted domains
	@ys = @$yary 
		unless $needsort;

	if ($needsort) {
		@xs = sort numerically @xs ;

		foreach $x (@xs) {
			push @ys, $$yary[$xhash{$x}];
		}
	}
#
#	first and last domain values are smallest and biggest now
	$xmin = $xs[0] unless ($is_symbolic || ($xs[0] >= $xmin));
	$xmax = $xs[$#xs] unless ($is_symbolic || ($xs[$#xs] <= $xmax));
	$xmax = 1 + $#xs  if ($is_symbolic && ($#xs >= $xmax));

	for ($i = 0; $i <= $#xs; $i++) {
		($x, $y) = ($xs[$i], $ys[$i]); # maybe shift instead ?
		next unless (defined($x) && defined($y));
		
		$y = convert_temporal($y, $obj->{timeRange}) if $obj->{timeRange};
#
#	validate the range values
		$obj->{errmsg} = 'Non-numeric range value ' . $y . '.',
		return undef
			unless ($y=~/^[+-]?\.?\d+\.?\d*([Ee][+-]?\d+)?$/);
		
		$obj->{errmsg} = 
			'Invalid value supplied for logarithmic axis.',
		return undef
			if ($obj->{yLog} && ($y <= 0));

		$y = log($y)/log(10) if $obj->{yLog};
		$ymin = $y if ($y < $ymin);
		$ymax = $y if ($y > $ymax);
		
		push(@data, $x, $y), next
			unless $obj->{symDomain};
#
#	symbolic domain is mapped according to prior order (if any)
		$domVals->{$x} = defined($domVals) ? scalar(keys(%$domVals)) : 0
			unless defined($domVals->{$x});
		$idx = $domVals->{$x} * 2;
		$data[$idx++] = $x;
		$data[$idx++] = $y;
	}
	push(@{$obj->{data}}, \@data);
	$props .= ' line' unless ($props=~/\bnoline|line|fill\b/i);
	$props=~s/\bnoline\b/line/i if ($props=~/\bfill\b/i);
#	$props .= ' nopoints' 
#		unless (($props=~/\b(no)?points\b/i) || ($props!~/\bline\b/i));
	push(@{$obj->{props}}, $props);
	$obj->{haveScale} = 0;	# invalidate any prior min-max calculations
	$obj->{plotTypes} |= ($props=~/\bfill\b/i) ? AREA : 
		($props=~/\bline\b/i) ? LINE : POINT;
	($obj->{xl}, $obj->{xh}, $obj->{yl}, $obj->{yh}) = 
		($xmin, $xmax, $ymin, $ymax);
	return 1;
}
#
#	wait until plot time to sort domain for bars/histos/candles
#
sub sortData {
	my ($obj) = @_;
#
#	make sure domain values are in ascending order
#
	my $xhash = $obj->{domainValues};
	my @xsorted = ();
	if ($obj->{timeDomain}) {
		@xsorted = sort numerically keys(%$xhash);
	}
	else {
		foreach my $x (keys(%$xhash)) {
			$xsorted[$$xhash{$x}] = $x;
		}
	}
	$obj->{domain} = \@xsorted;
	$obj->{xh} = scalar @xsorted;
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
	
	$obj->{errmsg} = 'No plots defined.' unless $obj->{plotTypes};
#
#	first fill with bg color
#
	my $color;
	$obj->{img}->fill(1, 1, $obj->{bgColor} );
#
#	then add any defined logo
	$obj->addLogo if $obj->{logo};

	$obj->drawTitle if $obj->{title}; # vert offset may be increased
	$obj->drawSignature if $obj->{signature};

#	$obj->{numRanges} = scalar @{$obj->{data}};
	my $rc = 1;
#
#	sort the domain values if temporal domain
#
	$obj->sortData if $obj->{symDomain};

	my $plottypes = $obj->{plotTypes};
	my $props = $obj->{props};
	my $prop;
#
#	if its boxchart only, then establish dummy yl, yh
	($obj->{yl}, $obj->{yh}) = (1, 100) if ($plottypes == BOX);
#
#	get scale of all included plots
#
	$rc = $obj->computeScales()
		unless ($obj->{haveScale} || ($plottypes == PIE));
	return undef unless $rc;
#
#	if boxchart included, distribute the range values among the
#	plots
	$obj->{boxHeight} = int($obj->{plotHeight}/($obj->{boxCount}+1))
		if $obj->{boxCount};
#
#	pies are always solo, get em out of the way...
	$rc = $obj->plotPie,
	return ($rc ? (($format) && $obj->{img}->$format) : undef)
		if ($plottypes == PIE);
#
#	plot axes based on plot type
#
	$rc = ($plottypes == BOX) ? $obj->plotBoxAxes :
		($plottypes & (HISTO|GANTT)) ? $obj->plotHistoAxes :
		$obj->plotAxes;
	return undef unless $rc;
#
#	now we can plot each dataset
#
	my @proptypes = ();
	foreach $prop (@{$obj->{props}}) {
		push(@proptypes, $typemap{uc $1}), next 
			if ($prop=~/\b(candle|fill|box|bar|histo|gantt)\b/i);
		push(@proptypes, POINT),next if ($prop=~/\bnoline\b/i);
		push(@proptypes, LINE);
	}
	my $plotcnt = $#{$obj->{props}} + 1;
#
#	hueristically render plots in "best" visible order
#
	if ($obj->{zAxisLabel} || $obj->{threed}) {
		return undef	# since 3-D only compatible with 3-D 
			if (! $obj->plot3DBars);

		$obj->plot3DTicks;
		return (($format) && $obj->{img}->$format);
	}

	return undef	# since histo only compatible with histo
		if (($plottypes & HISTO) && (! $obj->plot2DBars(HISTO, \@proptypes)));

	return undef	# since Gantt only compatible with Gantt
		if (($plottypes & GANTT) && (! $obj->plotGantt));

	return undef 
		if (($plottypes & AREA) && (! $obj->plotAll(AREA,\@proptypes)));
		
	return undef
		if (($plottypes & BAR) && (! $obj->plot2DBars(BAR, \@proptypes)));

	return undef
		if (($plottypes & CANDLE) && (! $obj->plotCandles(\@proptypes)));

	return undef
		if (($plottypes & BOX) && (! $obj->plotBox(\@proptypes)));

	return undef 
		if (($plottypes & LINE) && (! $obj->plotAll(LINE,\@proptypes)));
		
	return undef 
		if (($plottypes & POINT) && (! $obj->plotAll(POINT,\@proptypes)));
#
#	now render it in the requested format
#
	return (($format) && $obj->{img}->$format);
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
#
#	if keepOrigin, make sure (0,0) is included
#	(but only if not in logarithmic mode)
#
	if ($obj->{keepOrigin}) {
		unless ($obj->{xLog} || $obj->{symDomain}) {
			$xl = 0 if ($xl > 0);
			$xh = 0 if ($xh < 0);
		}
		unless ($obj->{yLog}) {
			$yl = 0 if ($yl > 0);
			$yh = 0 if ($yh < 0);
		}
#
#	doesn't apply to Z axis (yet)
#
	}
	
	my $plottypes = $obj->{plotTypes};
# set axis ranges for widest/tallest/deepest dataset
	$obj->computeRanges($xl, $xh, $yl, $yh, $zl, $zh);
	$obj->{yl} = 0 if (($plottypes & (BAR|HISTO|CANDLE)) && ($yl == 0));
	($xl, $xh, $yl, $yh, $zl, $zh) = 
		($obj->{xl}, $obj->{xh}, $obj->{yl}, $obj->{yh}, 
			$obj->{zl}, $obj->{zh});

	if (($plottypes & (BAR|HISTO)) && ($yl > 0) 
		&& (! $obj->{keepOrigin})) {
#
#	adjust mins to clip away from origin
#
		my $incr = ($obj->{zAxisLabel} || $obj->{threed}) ? 4 : 3;
		for ($i = 0; $i <= $#{$obj->{props}}; $i++) {
			next unless ($obj->{props}->[$i]=~/\b(bar|histo)\b/i);
			my $datastack = $obj->{data}->[$i];
			for (my $j = 1; $j <= $#$datastack; $j += $incr) {
				$$datastack[$j] = $yl;
			}
		}
	}
#
#	heuristically adjust image margins to fit labels
#
	my ($botmargin, $topmargin, $ltmargin, $rtmargin) = (40, 40, 0, 5*$sfw);
	$botmargin += (3 * $tfh) if $obj->{legend};
#
#	compute space needed for X axis labels
#
	my $maxlen = 0;
	my ($tl, $th) = (0, 0);
	($tl, $th) = ($obj->{xLog}) ? (10**$xl, 10**$xh) : ($xl, $xh)
		unless $obj->{symDomain};
	$maxlen = $obj->{symDomain} ? $obj->{xMaxLen} : 
		$obj->{timeDomain} ? length($obj->{timeDomain}) :
		(length($th) > length($tl)) ? length($th) : length($tl);
	$maxlen = 25 if ($maxlen > 25);
	$maxlen = 7 if ($maxlen < 7);
	$botmargin += (($sfw * $maxlen) + 10) unless ($plottypes & (HISTO|GANTT));
	$ltmargin = (($sfw * $maxlen) + 20) if ($plottypes & (HISTO|GANTT));
#
#	compute space needed for Y axis labels
#
	($tl, $th) = ($obj->{yLog}) ? (10**$yl, 10**$yh) : ($yl, $yh);
	$maxlen = $obj->{timeRange} ? length($obj->{timeRange}) :
		(length($th) > length($tl)) ? length($th) : length($tl);
	$maxlen = 25 if ($maxlen > 25);
	$maxlen = 7 if ($maxlen < 7);
	$botmargin += (($sfw * $maxlen) + 10) if ($plottypes & (HISTO|GANTT));
	$ltmargin = (($sfw * $maxlen) + 20) unless ($plottypes & (HISTO|GANTT));
#
#	compute space needed for Z axis labels
#
	if ($obj->{zAxisLabel}) {
		$maxlen = $obj->{zMaxLen};
		$maxlen = 25 if ($maxlen > 25);
		$maxlen = 7 if ($maxlen < 7);
		$rtmargin = ($sfw * $maxlen) + 10;
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
		$obj->{plotWidth} = int($twd / ($xzratio*sin(3.1415926/6) + 1)),
		$obj->{plotDepth} = int(($twd - $obj->{plotWidth})/sin(3.1415926/6)),
#		$obj->{plotHeight} = int($tht - ($obj->{plotDepth}*cos(3.1415926/6))),
		$obj->{plotHeight} = int($tht - ($obj->{plotDepth}*cos(3.1415926/3))),
		$obj->{xscale} = $obj->{plotWidth}/($xh - $xl),
		$obj->{yscale} = $obj->{plotHeight}/($yh - $yl),
		$obj->{zscale} = $obj->{plotDepth}/($zh - $zl)
			unless ($plottypes & (HISTO|GANTT));

		$obj->{plotHeight} = int($tht / ($xzratio*cos(3.1415926/6) + 1)),
		$obj->{plotDepth} = int(($tht - $obj->{plotHeight})/cos(3.1415926/6)),
		$obj->{plotWidth} = int($twd - ($obj->{plotDepth}*sin(3.1415926/6))),
		$obj->{yscale} = $obj->{plotWidth}/($yh - $yl),
		$obj->{xscale} = $obj->{plotHeight}/($xh - $xl),
		$obj->{zscale} = $obj->{plotDepth}/($zh - $zl)
			if ($plottypes & (HISTO|GANTT));
	}
	else {
#	keep true width/height for future reference
		$obj->{xscale} = ($obj->{width} - $ltmargin - $rtmargin)/($xh - $xl),
		$obj->{yscale} = ($obj->{height} - $topmargin - $botmargin)/($yh - $yl),
		$obj->{plotWidth} = $obj->{width} - $ltmargin - $rtmargin,
		$obj->{plotHeight} = $obj->{height} - $topmargin - $botmargin
			unless ($plottypes & (HISTO|GANTT));

		$obj->{yscale} = ($obj->{width} - $ltmargin - $rtmargin)/($yh - $yl),
		$obj->{xscale} = ($obj->{height} - $topmargin - $botmargin)/($xh - $xl),
		$obj->{plotWidth} = $obj->{width} - $ltmargin - $rtmargin,
		$obj->{plotHeight} = $obj->{height} - $topmargin - $botmargin
			if ($plottypes & (HISTO|GANTT));
	}

	$obj->{horizEdge} = $ltmargin;
	$obj->{vertEdge} = $obj->{height} - $botmargin;
#
#	compute spacing info for bar/candles
#
	return undef
		if (($plottypes & (BAR|HISTO)) && 
			(! $obj->{zAxisLabel}) &&
			(! $obj->computeSpacing($plottypes)));
	
	$obj->{haveScale} = 1;
	return 1;
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
	my ($xr, $xd, $xs);
	$xl = int($xl) - ($xl < 0 ? 1 : 0),
	$xh = int($xh) + 1
		if ($obj->{xLog});
	$xr = (log($xh - $xl))/log(10),
	$xd = $xr - int($xr)
		unless $obj->{symDomain};
	$obj->{horizStep} = $obj->{symDomain} ? 1 : 
		($xd < 0.4) ? (10 ** (int($xr) - 1)) :
		(($xd >= 0.87) ? (10 ** int($xr)) : (5 * (10 ** (int($xr) - 1))));
#
#	align time domain steps on 12:00 AM (zero hour) of a day
#
	$obj->{horizStep} += (86400 - $obj->{horizStep}%86400)
		if ((! $obj->{symDomain}) && $obj->{timeDomain} && 
			($obj->{timeDomain}=~/^YYYY/i) && 
			($obj->{horizStep}%86400 != 0));
	
	$yh = $yl * 2 if ($yh == $yl);
	$yl = int($yl) - ($yl < 0 ? 1 : 0),
	$yh = int($yh) + 1
		if ($obj->{yLog});
	$xr = (log($yh - $yl))/log(10);
	$xd = $xr - int($xr);
	$obj->{vertStep} = ($xd < 0.4) ? (10 ** (int($xr) - 1)) :
		(($xd >= 0.87) ? (10 ** int($xr)) : (5 * (10 ** (int($xr) - 1))));

#
#	align time range steps on 12:00 AM (zero hour) of a day
#	if histo/gantt
#
	$obj->{vertStep} += (86400 - $obj->{vertStep}%86400)
		if (($obj->{plotTypes} & (HISTO|GANTT)) && 
			$obj->{timeRange} && 
			($obj->{timeRange}=~/^YYYY/i) && 
			($obj->{vertStep}%86400 != 0));
#
#	histos switch things
	$xs = $obj->{horizStep}, 
	$obj->{horizStep} = $obj->{vertStep}, 
	$obj->{vertStep} = $xs
		if ($obj->{plotTypes} & (HISTO|GANTT));

	if (($obj->{zAxisLabel} || $obj->{threed}) && ($zh != $zl)) {
		$xr = (log($zh - $zl))/log(10),
		$xd = $xr - int($xr)
			unless $obj->{symDomain};
		$obj->{depthStep} = $obj->{symDomain} ? 1 : 
			($xd < 0.4) ? (10 ** (int($xr) - 1)) :
			(($xd >= 0.87) ? (10 ** int($xr)) : (5 * (10 ** (int($xr) - 1))));
	}
	my ($xm, $ym, $zm) = ($obj->{plotTypes} & (HISTO|GANTT)) ?
		($obj->{vertStep}, $obj->{horizStep}, $obj->{depthStep}) :
		($obj->{horizStep}, $obj->{vertStep}, $obj->{depthStep});

	($zl, $zh) = (0.5, 1.5) if ($obj->{symDomain} && defined($zl) && ($zl == $zh));
	($xl, $xh) = (0.5, 1.5) if ($obj->{symDomain} && ($xl == $xh));
# fudge a little in case limit equals min or max
	$obj->{zl} = ((! $zm) ? 0 : $zm * (int(($zl-0.00001*$sign[4])/$zm) + $sign[4] - 1)),
	$obj->{zh} = ((! $zm) ? 0 : $zm * (int(($zh-0.00001*$sign[5])/$zm) + $sign[5] + 1))
		if defined($zl);
	$obj->{xl} = (! $xm) ? 0 : $xm * (int(($xl-0.00001*$sign[0])/$xm) + $sign[0] - 1);
	$obj->{xh} = (! $xm) ? 0 : $xm * (int(($xh-0.00001*$sign[1])/$xm) + $sign[1] + 1);
#
#	day align here too
	$obj->{xl} = $obj->{xl} - ($obj->{xl}%86400),
	$obj->{xh} += (86400 - ($obj->{xh}%86400)),
		if ((! $obj->{symDomain}) && 
			$obj->{timeDomain} && ($obj->{timeDomain}=~/^YYYY/i));

	$obj->{yl} = ($obj->{yLog}) ? $yl : (! $ym) ? 0 : $ym * (int(($yl-0.00001*$sign[2])/$ym) + $sign[2] - 1);
	$obj->{yh} = ($obj->{yLog}) ? $yh : (! $ym) ? 0 : $ym * (int(($yh-0.00001*$sign[3])/$ym) + $sign[3] + 1);
#
#	day align here too
	$obj->{yl} = $obj->{yl} - ($obj->{yl}%86400),
	$obj->{yh} += (86400 - ($obj->{yh}%86400)),
		if ($obj->{timeRange} && ($obj->{timeRange}=~/^YYYY/i));
	return 1;
}
#
#	compute bar spacing
#
sub computeSpacing {
	my ($obj, $type) = @_;
#
#	compute number of domain values
#
	my $domains = 0;
	$domains = ($obj->{Xcard}) ? 1 : scalar(@{$obj->{domain}});

	my $bars = $obj->{barCount};
	$bars = $obj->{Xcard} if ($obj->{Xcard});
	my $spacer = 10;
	my $width = ($type & HISTO) ? $obj->{plotHeight} : $obj->{plotWidth};
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
	my ($obj, $type, $typeary) = @_;
	my ($i, $j, $k, $x, $n, $ary, $pxl, $pxr, $py, $pyt, $pyb);
	my ($color, $prop, $s, $colorcnt);
	my @barcolors = ();
	my @brushes = ();
	my @props = ();
	my $legend = $obj->{legend};
	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, $obj->{yl}, 
		$obj->{yh});
	my ($brush, $ci, $t);
	my ($useicon, $marker);
	my $img = $obj->{img};
	my $plottypes = $obj->{plotTypes};
	my @tary = ();
	my $bars = $obj->{barCount};
	my $boff = int($obj->{brushWidth}/2);
	my $ttlw = int($bars * $boff);
	my $domain = $obj->{domain};
	my $xhash = $obj->{domainValues};
#
#	get indexes of all same type
	for ($i = 0; $i <= $#$typeary; $i++) {
		push(@tary, $i)
			if ($$typeary[$i] == $type);
	}

	for ($n = 0; $n <= $#tary; $n++) {
		@barcolors = ();
		@brushes = ();
		$marker = undef;
		$color = 'black';
		$k = $tary[$n];
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
		my ($bw, $bh, $bbasew, $bbaseh) = ($plottypes & HISTO) ?
			(1, $obj->{brushWidth}, 0, $obj->{brushWidth}) :
			($obj->{brushWidth}, 1, $obj->{brushWidth}, 0);
		foreach $color (@barcolors) {
			$colorcnt++;
			$obj->{$color} = $obj->{img}->colorAllocate(@{$colors{$color}})
				unless $obj->{$color};
#
#	generate brushes to draw bars
#
			$brush = new GD::Image($bw, $bh),
			$ci = $brush->colorAllocate(@{$colors{$color}}),
			$brush->filledRectangle(0,0,$bbasew, $bbaseh,$ci),
			push(@brushes, $brush)
				unless $marker;
		}

		$marker = $obj->getIcon($marker, 1)
			if ($marker);
#
#	render legend if requested
#	(a bit confusing here for multicolor single range charts?)
		$obj->drawLegend($k, $color, $marker, $$legend[$k])
			if (($legend) && ($$legend[$k]));

#
#	heuristically determine whether to print Y values vert or horiz.
		my $yorient = (length($yl) > length($yh)) ? length($yl) : length($yh);
		$yorient *= $tfw;
#
#	compute the center data point, then
#	adjust horizontal location based on brush width
#	and data set number
#
		my $xoffset = ($n * $obj->{brushWidth}) - $ttlw 
			+ $boff;
		for ($x = 0, $j = 0; $x <= $#$domain; $x++) {
			$i = $$xhash{$$domain[$x]} * 3;	# get actual index for the current point
			next unless defined($$ary[$i+1]);

# get top and bottom (left/right) points
			($pxl, $pyb) = $obj->pt2pxl ( $x+1, $$ary[$i+1] );
			($pxr, $pyt) = $obj->pt2pxl ( $x+1, $$ary[$i+2] );
#
#	adjust for bar location
			$pxl += $xoffset,
			$pxr += $xoffset
				unless ($plottypes & HISTO);
			$pyb += $xoffset,
			$pyt += $xoffset
				if ($plottypes & HISTO);
				
# draw line between top and bottom(left and right)
			$j = 0 if ($j == $colorcnt);
			$img->setBrush($brushes[$j++]),
			$img->line($pxl, $pyb, $pxr, $pyt, gdBrushed)
				unless $marker;
#
#	unless its iconic
#
			$obj->drawIcons($marker, $pxl, $pyb, $pxr, $pyt)
				if $marker;
#
#	optimization
			next unless ($obj->{genMap} || $obj->{showValues});
#
#	convert range/domain values for printing
			my $prtY = ($$ary[$i+1]) ? $$ary[$i+1] : $$ary[$i+2];
			$prtY = 10**($$prtY) if ($obj->{yLog});
			my $prtX = $$ary[$i];
			$prtY = restore_temporal($prtY, $obj->{timeRange}) 
				if $obj->{timeRange};
			$prtX = restore_temporal($prtX, $obj->{timeDomain}) 
				if $obj->{timeDomain};
#
# update imagemap if requested
			$obj->updateImagemap('RECT', $prtY, $k, $prtX, 
				$prtY, undef, $pxl-$boff, $pyt, $pxl+$boff, $pyb)
				if (($plottypes & BAR) && $obj->{genMap});

			$obj->updateImagemap('RECT', $prtY, $k, $prtX, 
				$prtY, undef, $pxl, $pyt-$boff, $pxr, $pyt+$boff)
				if (($plottypes & HISTO) && $obj->{genMap});
#
#	draw vertical values for bars
			$img->stringUp(gdTinyFont, $pxl-int($tfw/2), $pyt-4, 
				$prtY, $obj->{textColor}), next
				if (($plottypes & BAR) && $obj->{showValues} && 
					($obj->{yLog} || ($yorient >= $obj->{brushWidth})));
#
#	unless they'll fit horiz.
			$img->string(gdTinyFont, $pxl-int(length($prtY) * $tfw/2), $pyt-$tfh - 4, 
				$prtY, $obj->{textColor}), next
				if (($plottypes & BAR) && $obj->{showValues} && 
					($yorient < $obj->{brushWidth}));

			$img->string(gdTinyFont, $pxr+int($sfw/2), $pyt-4, 
				$prtY, $obj->{textColor})
				if (($plottypes & HISTO) && $obj->{showValues});
		}
	}
	return 1;
}

sub plotCandles {
	my ($obj, $typeary) = @_;
	my ($ary, $px, $py, $pyt, $pyb);
	my ($color, $img, $prop, $s);
	my @props = ();
	my $legend = $obj->{legend};
	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, $obj->{yl}, 
		$obj->{yh});
	my ($marker, $markw, $markh, $yoff, $wdelta, $hdelta);
	my ($i, $j, $k, $n, $x);
	my @tary = ();

	for ($i = 0; $i <= $#$typeary; $i++) {
		next unless ($$typeary[$i] == CANDLE);
		push @tary, $i;
	}

	$img = $obj->{img};	

#
#	compute the center data point, then
#	adjust horizontal location based on brush width
#	and data set number
#
	my $bars  = scalar @{$obj->{data}};
	my $ttlw = int(($bars * $obj->{brushWidth})/2);
	my $domain = $obj->{domain};
	my $xhash = $obj->{domainValues};

	for ($n = 0; $n <= $#tary; $n++) {
		$color = 'black';
		$marker = undef;
		$k = $tary[$n];
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
			$marker = ($shapes{$marker}) ? 
				$obj->make_marker($marker, $color) :
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
		$img->setBrush($brush);

		my $xoffset = ($n * $obj->{brushWidth}) - $ttlw 
			+ int($obj->{brushWidth}/2);

		for ($x = 0; $x <= $#$domain; $x++) {
			$i = $$xhash{$$domain[$x]} * 3;
			next unless defined($$ary[$i+1]);

# get top and bottom points
			($px, $pyb) = $obj->pt2pxl ( $x+1, $$ary[$i+1] );
			($px, $pyt) = $obj->pt2pxl ( $x+1, $$ary[$i+2] );
			$px += $xoffset;
				
# draw line between top and bottom
			$img->line($px, $pyb, $px, $pyt, gdBrushed);
				
# draw pointshape if requested
			$img->copy($marker, $px-$wdelta, $pyb-$hdelta, 0, 0, 
				$markw-1, $markh-1),
			$img->copy($marker, $px-$wdelta, $pyt-$hdelta, 0, 0, 
				$markw-1, $markh-1)
				if ($marker);
#
#	optimization
			next unless ($obj->{genMap} || $obj->{showValues});
#
#	convert range/domain values for printing
			my $prtYH = $obj->{yLog} ? 10**($$ary[$i+2]) : $$ary[$i+2];
			my $prtYL = $obj->{yLog} ? 10**($$ary[$i+1]) : $$ary[$i+1];
			my $prtX = $$ary[$i];
			$prtYH = restore_temporal($prtYH, $obj->{timeRange}),
			$prtYL = restore_temporal($prtYL, $obj->{timeRange}) 
				if $obj->{timeRange};
			$prtX = restore_temporal($prtX, $obj->{timeDomain}) 
				if $obj->{timeDomain};

# update imagemap if requested
			$obj->updateImagemap('CIRCLE', $prtYH, $k, $prtX, 
				$prtYH, undef, $px, $pyt, 4),
			$obj->updateImagemap('CIRCLE', $prtYL, $k, $prtX,
				$prtYL, undef, $px, $pyb, 4)
				if ($obj->{genMap});
				
# draw top/bottom values if requested
			$img->string(gdTinyFont,$px-(length($prtYL) * ($tfw>>1)),$pyb+4, 
				$prtYL, $obj->{textColor}),
			$img->string(gdTinyFont,$px-(length($prtYH) * ($tfw>>1)),$pyt-$yoff-4, 
				$prtYH, $obj->{textColor})
				if ($obj->{showValues});
		}	# end for each stick
	} # end for each candle graph
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
	my ($obj, $typeary) = @_;

	my $legend = $obj->{legend};
	my ($i, $j, $k, $n, $x);
	my @tary = ();

	for ($i = 0; $i <= $#$typeary; $i++) {
		next unless ($$typeary[$i] == BOX);
		push @tary, $i;
	}
#
#	compute the height of each box based range max and min
	my $boxht = ($obj->{yh} - $obj->{yl})/($i+1);

	for ($n = 0; $n <= $#tary; $n++) {
		$k = $tary[$n];

		my $ary = $obj->{data}->[$k];
		my $t = lc $obj->{props}->[$k];
		$t=~s/\s+/ /g;
		my @props = split(' ', $t);
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
#	compute median, quartiles, and extremes
#
		my ($median, $lq, $uq, $lex, $uex) = $obj->computeBox($k);
#
#	compute box bounds
		my $ytop = $obj->{yl} + ($boxht * ($n + 1));
		my $ybot = $ytop - $boxht;
		my $dumy = ($ytop + $ybot)/2;
		my $py = 0;
#
#	draw the box
		my ($p1x, $p1y) = $obj->pt2pxl($lq, $ytop);
		my ($p2x, $p2y) = $obj->pt2pxl($uq, $ybot);
		my $yoff = (($n+1) * (15 + $tfh));
		$p1y -= $yoff;
		$p2y -= $yoff;
		my $img = $obj->{img};
#
#	double up the box border
		$img->rectangle($p1x, $p1y, $p2x, $p2y, $obj->{$color});
		$img->rectangle($p1x+1, $p1y+1, $p2x-1, $p2y-1, $obj->{$color});

		my ($tmed, $tlex, $tuex) = ($median, $lex, $uex);
		$tmed = restore_temporal($tmed, $obj->{timeDomain}),
		$lq = restore_temporal($lq, $obj->{timeDomain}),
		$uq = restore_temporal($uq, $obj->{timeDomain}) ,
		$tlex = restore_temporal($tlex, $obj->{timeDomain}),
		$tuex = restore_temporal($tuex, $obj->{timeDomain}) 
			if ($obj->{timeDomain} && ($obj->{genMap} || $obj->{showValues}));

		$xoff = int(length($lq) * $tfw/2),
		$img->string(gdTinyFont,$p1x-$xoff,$p1y-$tfh, $lq, $obj->{textColor}),
		$xoff = int(length($uq) * $tfw/2),
		$img->string(gdTinyFont,$p2x-$xoff,$p1y-$tfh, $uq, $obj->{textColor})
			if ($obj->{showValues});
	
		$obj->updateImagemap('RECT', "$tmed\[$lq..$uq\]", 0, $tmed, 
			$lq, $uq, $p1x, $p1y, $p2x, $p2y)
			if ($obj->{genMap});
#
#	draw median line
		($p1x, $py) = $obj->pt2pxl($median, $dumy);
		$p1y -= 5;
		$p2y += 5;
		$img->line($p1x, $p1y, $p1x, $p2y, $obj->{$color});

		$xoff = int(length($median) * $tfw/2),
		$img->string(gdTinyFont,$p1x-$xoff,$p1y-$tfh, $tmed, 
			$obj->{textColor})
			if ($obj->{showValues});
#
#	draw whiskers
		($p1x, $p1y) = $obj->pt2pxl($lex, $dumy);
		($p2x, $py) = $obj->pt2pxl($lq, $dumy);
		$p1y -= $yoff;
		$img->line($p1x, $p1y, $p2x, $p1y, $obj->{$color});

		$tmed = restore_temporal($tmed, $obj->{timeDomain}),
		$lq = restore_temporal($lq, $obj->{timeDomain}),
		$uq = restore_temporal($uq, $obj->{timeDomain}) 
			if ($obj->{timeDomain} && ($obj->{genMap} || $obj->{showValues}));

		$xoff = int(length($lex) * $tfw/2),
		$img->string(gdTinyFont,$p1x-$xoff,$p1y-$tfh, $tlex,
			$obj->{textColor})
			if ($obj->{showValues});
		$obj->updateImagemap('CIRCLE', $tlex, 0, $tlex, undef, undef, 
			$p1x, $p1y, 4)
			if ($obj->{genMap});

		($p1x, $p1y) = $obj->pt2pxl($uq, $dumy);
		($p2x, $py) = $obj->pt2pxl($uex, $dumy);
		$p1y -= $yoff;
		$img->line($p1x, $p1y, $p2x, $p1y, $obj->{$color});

		$xoff = int(length($uex) * $tfw/2),

		$img->string(gdTinyFont,$p2x-$xoff,$p1y-$tfh, $tuex, 
			$obj->{textColor})
			if ($obj->{showValues});
		$obj->updateImagemap('CIRCLE', $tuex, 0, $tuex, undef, undef, 
			$p2x, $p1y, 4)
			if ($obj->{genMap});
#
#	plot outliers; we won't show values here
#	NOTE: we should us pointshape provided by props!!!
#
		my $marker = $obj->make_marker('filldiamond', $color);
		foreach $val (@$ary) {
			last if ($val >= $lex);
			($p1x, $p1y) = $obj->pt2pxl($val, $dumy);
			$p1y -= $yoff;
			$img->copy($marker, $p1x-4, $p1y-4, 0, 0, 9, 9);
		}
		for (my $i = $#$ary; ($i > 0) && ($uex < $$ary[$i]); $i--) {
			($p1x, $p1y) = $obj->pt2pxl($$ary[$i], $dumy);
			$p1y -= $yoff;
			$img->copy($marker, $p1x-4, $p1y-4, 0, 0, 9, 9);
		}
	}	# end for each box plot
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

			($px,$py) = $obj->pt2pxl($k, $yl);
			($p1x, $p1y) = ($obj->{vertGrid}) ? 
				$obj->pt2pxl($k, $yh) : ($px, $py+2);
			$img->line($px, ($obj->{vertGrid} ? $py : $py-2), 
				$px, $p1y, $obj->{gridColor});

			$powk = ($obj->{timeDomain}) ? 
				restore_temporal(10**$k, $obj->{timeDomain}) : 10**$k,
			$img->stringUp(gdSmallFont, $px-$sfh/2, 
				$py+length($powk)*$sfw, $powk, $obj->{textColor})
				if (($n == 1) && ($px+$sfh < $xStart));

			($n, $i)  = (0, $k)
				if ($n > $#logsteps);
		}
		return 1;
	}

    my $step = $obj->{horizStep}; 
   	my $prtX;
	for ($i = $xl; $i <= $xh; $i += $step ) {
		($px,$py) = $obj->pt2pxl($i, 
			((($obj->{yLog}) || 
			($obj->{vertGrid}) || ($yl > 0) || ($yh < 0)) ? $yl : 0));
		($p1x, $p1y) = ($obj->{vertGrid}) ? 
			$obj->pt2pxl($i, $yh) : ($px, $py+2);
		$img->line($px, ($obj->{vertGrid} ? $py : $py-2), $px, $p1y, $obj->{gridColor});

		next if ($obj->{xAxisVert} && ($px+$sfh >= $xStart));
		$prtX = $obj->{timeDomain} ? restore_temporal($i, $obj->{timeDomain}) : $i;
		$img->stringUp(gdSmallFont, $px-($sfh>>1), 
			$py+2+length($prtX)*$sfw, $prtX, $obj->{textColor}), next
			if ($obj->{xAxisVert});

		$img->string(gdSmallFont, $px-length($prtX)*($sfw>>1), 
			$py+($sfh>>1), $prtX, $obj->{textColor});
	}
	return 1;
}

sub plotAll {
	my ($obj, $type, $typeary) = @_;
	my ($i, $n, $k);
	my @tary = ();
	
	for ($i = 0; $i <= $#$typeary; $i++) {
		push(@tary, $i) 
			if ($$typeary[$i] == $type);
	}

	for ($n = 0; $n <= $#tary; $n++) {
		return undef unless $obj->plotData($tary[$n]);
	}
	return 1;
}

# draws the specified dataset in $obj->{data}
sub plotData {
	my ($obj, $k) = @_;
	my ($i, $n, $ary, $px, $py, $prevpx, $prevpy, $pyt, $pyb);
	my ($color, $line, $img, $prop, $s, $voff);
	my @props = ();
# legend is left justified underneath
	my $legend = $obj->{legend};
	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, $obj->{yl}, 
		$obj->{yh});
	my ($marker, $markw, $markh, $yoff, $wdelta, $hdelta);
	$img = $obj->{img};	
	
	
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
	$yoff = ($marker) ? $markh : 2;
#
#	render legend if requested
#
	$obj->drawLegend($k, $color, $marker, $$legend[$k])
		if ($legend && $$legend[$k]);
#
#	line/point/area charts
#
#	we need to heuristically sort data sets to optimize the view of 
#	overlapping areagraphs...for now the user will need to be smart 
#	about the order of registering the datasets
#
	$obj->fill_region($obj->{$color}, $ary)
		if ($line eq 'fill');

	($prevpx, $prevpy) = (0,0);
	my ($prtX, $prtY);

# draw the rest of the points and lines 
	my $domain = $obj->{symDomain} ? $obj->{domain} : $ary;
	my $xhash = $obj->{symDomain} ? $obj->{domainValues} : undef;
	my $domsize = $obj->{symDomain} ? $#$domain : $#$ary;
	my $x;
	my $incr = $obj->{symDomain} ? 1 : 2;
	my $xd;
	for ($x = 0; $x <= $domsize; $x += $incr) {
		$xd = $$xhash{$$domain[$x]} if $obj->{symDomain};
		$i = $obj->{symDomain} ? $xd * 2: $x;
		next unless defined($$ary[$i+1]);

# get next point
		($px, $py) = $obj->pt2pxl(($obj->{symDomain} ? $xd+1 : $$ary[$i]),
			$$ary[$i+1] );

# draw point, maybe
		$img->copy($marker, $px-$wdelta, $py-$hdelta, 0, 0, $markw, 
			$markh)
			if ($marker);

		if ($obj->{genMap} || $obj->{showValues}) {
			($prtX, $prtY) = ($$ary[$i], $$ary[$i+1]);
			$prtY = 10**$prtY if $obj->{yLog};
			$prtX = 10**$prtX if $obj->{xLog};
			$prtY = restore_temporal($prtY, $obj->{timeRange}) if $obj->{timeRange};
			$prtX = restore_temporal($prtX, $obj->{timeDomain}) if $obj->{timeDomain};
			$s = $obj->{symDomain} ? $prtY : "($prtX,$prtY)";
		}
			
		$obj->updateImagemap('CIRCLE', $s, $k, $prtX, $prtY,
			undef, $px, $py, 4)
			if ($obj->{genMap});

		$voff = (length($s) * $tfw)>>1,
		$img->string(gdTinyFont,$px-$voff,$py-$yoff, $s, $obj->{textColor})
			if ($obj->{showValues});

# draw line from previous point, maybe
		$img->line($prevpx, $prevpy, $px, $py, $obj->{$color})
			if (($line eq 'line') && $i);
		($prevpx, $prevpy) = ($px, $py);
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

	my $legend_wd = (int($k/3) * 85) + $obj->{horizEdge};
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
	my $plottype = $obj->{plotTypes} & (HISTO|GANTT);

	return (
		int($obj->{horizEdge} + ($x - $obj->{xl}) * $obj->{xscale}),
		int($obj->{vertEdge} - ($y - $obj->{yl}) * $obj->{yscale})
	 ) unless (defined($z) || $plottype);
#
#	histo version
	return (
		int($obj->{horizEdge} + ($y - $obj->{yl}) * $obj->{yscale}),
		int($obj->{vertEdge} - ($x - $obj->{xl}) * $obj->{xscale})
	 ) unless defined($z);
#
#	translate x,y,z into x,y
#
	my $tx = ($x - $obj->{xl}) * $obj->{xscale};
	my $ty = ($y - $obj->{yl}) * $obj->{yscale};
	my $tz = ($z - $obj->{zl}) * $obj->{zscale};

	return
		$obj->{horizEdge} + int($tx + ($tz * 0.433)),
		$obj->{vertEdge} - int($ty + ($tz * 0.25))
		unless $plottype;
#
#	histo version
	return
		$obj->{horizEdge} + int($ty + ($tz * 0.433)),
		$obj->{vertEdge} - int($tx + ($tz * 0.25));
}
# draw the axes, labels, title, grid/ticks and tick labels

sub plotAxes {
	my $obj = shift;
	return $obj->plot3DAxes
		if ($obj->{zAxisLabel} || $obj->{threed});

	my ($p1x, $p1y, $p2x, $p2y);
	my $img = $obj->{img};
	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, 
		$obj->{yl}, $obj->{yh});

	my $yaxpt = ((! $obj->{yLog}) && ($yl < 0) && ($yh > 0)) ? 0 : $yl;
	my $xaxpt = ((! $obj->{xLog}) && ($xl < 0) && ($xh > 0)) ? 0 : $xl;
	my $plottypes = $obj->{plotTypes};
	
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
	my ($len, $xStart, $xStart2);
	($p2x, $p2y) = $obj->pt2pxl($xh, $yl);
#		$obj->{vertGrid} || $obj->{horizGrid}) ? $yl : $yaxpt),
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

	$xStart2 = $p2x - length($obj->{yAxisLabel}) * ($sfw >> 1),
	$img->string(gdSmallFont, ($xStart2 > 10 ? $xStart2 : 10), 
		$p2y - 3*($sfh>>1), $obj->{yAxisLabel},  $obj->{textColor})
		if ($obj->{yAxisLabel});
#
# draw ticks and labels
# 
	my ($i,$px,$py, $step, $j, $txt);
   	my $prevx = 0;
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
			($p1x, $p1y) = ($obj->{vertGrid}) ? 
				$obj->pt2pxl($k, $yh) : ($px, $py+2);
			$img->line($px, ($obj->{vertGrid} ? $py : $py-2), 
				$px, $p1y, $obj->{gridColor});
#
#	don't draw tick labels if we're overwriting the axis label
#
			$powk = ($obj->{timeDomain}) ? 
				restore_temporal(10**$k, $obj->{timeDomain}) : 10**$k,
			$img->stringUp(gdSmallFont, $px-$sfh/2, 
				$py+length($powk)*$sfw, $powk, $obj->{textColor})
				if (($n == 1) && ($px+$sfh < $xStart));

			($n, $i)  = (0 , $k)
				if ($n > $#logsteps);
		}
	}
	elsif ($obj->{symDomain}) {
#
# symbolic domain
#
		my $ary = $obj->{domain};
    
		for ($i = 1, $j = 0; $i < $xh; $i++, $j++ ) {
			($px,$py) = $obj->pt2pxl($i, $yl);
			($p1x, $p1y) = ($obj->{vertGrid}) ? 
				$obj->pt2pxl($i, $yh) : ($px, $py+2);
			$img->line($px, ($obj->{vertGrid} ? $py : $py-2), 
				$px, $p1y, $obj->{gridColor});
#
#	skip the label if it would overlap
#
			next if ($obj->{xAxisVert} && ($sfh+1 > ($px - $prevx)));
#
#	truncate long labels
#
			$txt = ($obj->{timeDomain}) ? 
				restore_temporal($$ary[$j], $obj->{timeDomain}) : $$ary[$j];
			$txt = substr($txt, 0, 22) . '...' 
				if (length($txt) > 25);

			if ($obj->{xAxisVert}) {
				$prevx = $px;
				next if ($px+$sfh >= $xStart);
				$img->stringUp(gdSmallFont, $px-($sfh>>1), 
					$py+2+length($txt)*$sfw, $txt, $obj->{textColor});
				next;
			}

			next if (((length($txt)+1) * $sfw) > ($px - $prevx));
			$prevx = $px;

			$img->string(gdSmallFont, $px-length($txt)*($sfw>>1), 
				$py+($sfh>>1), $txt, $obj->{textColor});
		}
	}
	else {
	    $step = $obj->{horizStep}; 
		for ($i = $xl; $i <= $xh; $i += $step ) {
			($px,$py) = $obj->pt2pxl($i, $yl);
			($p1x, $p1y) = ($obj->{vertGrid}) ? 
				$obj->pt2pxl($i, $yh) : ($px, $py+2);
			$img->line($px, ($obj->{vertGrid} ? $py : $py-2), 
				$px, $p1y, $obj->{gridColor});

			$txt = ($obj->{timeDomain}) ? 
				restore_temporal($i, $obj->{timeDomain}) : $i;
			$txt = substr($txt, 0, 22) . '...' 
				if (length($txt) > 25);

			next if ((! $obj->{xAxisVert}) && 
				($px - $prevx < (length($txt) * $sfw)));
			next if ($obj->{xAxisVert} && ($px - $prevx < $sfw));
			$prevx = $px;
			next if ($obj->{xAxisVert} &&  ($px+$sfh >= $xStart));
			
			$img->stringUp(gdSmallFont, $px-($sfh>>1), 
				$py+2+length($txt)*$sfw, $txt, $obj->{textColor}),
			next
				if ($obj->{xAxisVert});

			$img->string(gdSmallFont, $px-length($txt)*($sfw>>1), 
				$py+($sfh>>1), $txt, $obj->{textColor});
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
		my $k = $yl;
		while ($k < $yh) {
			($px,$py) = $obj->pt2pxl(
				((($obj->{xLog}) || ($obj->{horizGrid})) ? 
				$xl : $xaxpt), $k);
			($p1x, $p1y) = ($obj->{horizGrid}) ? 
				$obj->pt2pxl($xh, $k) : ($px+2, $py);
			$img->line(($obj->{horizGrid} ? $px : $px-2), $py, 
				$p1x, $py, $obj->{gridColor});

			$powk = ($obj->{timeRange}) ? 
				restore_temporal(10**$k, $obj->{timeRange}) : 10**$k,
			$img->string(gdSmallFont, $px-5-length($powk)*$sfw, 
				$py-($sfh>>1), $powk, $obj->{textColor})
				if ($n == 0);
			
			$k = $i + $logsteps[$n++];
			($n, $i) = (0, $k)
				if ($n > $#logsteps);
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
	my $tickv = $yl;
	for ($i=0, $j = 0; $tickv < $yh; $i++, $j++ ) {
		$tickv = $yl + ($i * $step);
		last if ($tickv > $yh);
		($px,$py) = $obj->pt2pxl((($obj->{horizGrid}) ? $xl : $xaxpt), $tickv);
		($p1x, $p1y) = ($obj->{horizGrid}) ? 
			$obj->pt2pxl($xh, $tickv) : ($px+2, $py);
		$img->line(($obj->{horizGrid} ? $px : $px-2), $py, $p1x, $py, 
			$obj->{gridColor});

		next if (($skip) && ($j&1));
		$txt = $obj->{timeRange} ? restore_temporal($tickv, $obj->{timeRange}) : $tickv,
		$img->string(gdSmallFont, $px-5-length($txt)*$sfw, $py-($sfh>>1), 
			$txt, $obj->{textColor});
	}
	return 1;
}

sub plotHistoAxes {
	my ($obj) = @_;
	return $obj->plot3DAxes
		if ($obj->{zAxisLabel} || $obj->{threed});

	my ($p1x, $p1y, $p2x, $p2y);
	my $img = $obj->{img};
	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, 
		$obj->{yl}, $obj->{yh});
	my $plottypes = $obj->{plotTypes};
#
#	draw horizontal and vertical axes
	($p1x, $p1y) = $obj->pt2pxl ($xl, $yl),
	($p2x, $p2y) = $obj->pt2pxl($xh, $yl),
	$img->line($p1x, $p1y, $p2x, $p2y, $obj->{gridColor}),
	($p2x, $p2y) = $obj->pt2pxl ($xl, $yh),
	$img->line($p1x, $p1y, $p2x, $p2y, $obj->{gridColor})
		unless ($obj->{vertGrid} || $obj->{horizGrid});

	if ($obj->{vertGrid} || $obj->{horizGrid}) {
#
#	hilight the (0,0) axes, if available
#
#	draw horizontal axis
		($p1x, $p1y) = $obj->pt2pxl($xl, $yl);
		($p2x, $p2y) = $obj->pt2pxl($xl, $yh);
		$img->filledRectangle($p1x, $p1y-1, $p2x, $p2y-1,$obj->{gridColor}); # wide line
#	draw vertical axis
		($p1x, $p1y) = $obj->pt2pxl($xl, $yl);
		($p2x, $p2y) = $obj->pt2pxl($xh, $yl);
		$img->filledRectangle($p1x-1, $p2y, $p2x+1, $p1y,$obj->{gridColor}); # wide line

		($p1x, $p1y) = $obj->pt2pxl($xl, 0),
		($p2x, $p2y) = $obj->pt2pxl($xh, 0),
		$img->filledRectangle($p1x-1, $p2y, $p2x+1, $p1y,$obj->{gridColor})
			if (($yl < 0) && ($yh > 0));
#
#	gridded, create a rectangle
#
		($p1x, $p1y) = $obj->pt2pxl ($xh, $yl);
		($p2x, $p2y) = $obj->pt2pxl ($xl, $yh);
  		$img->rectangle( $p1x, $p1y, $p2x, $p2y, $obj->{gridColor});
  	}
#
#	draw horizontal axis label
	my ($len, $xStart, $xStart2);
	$len = $sfw * length($obj->{yAxisLabel}),
	$xStart = ($p2x+$len/2 > $obj->{width}-10) ? 
		($obj->{width}-10-$len) : ($p2x-$len/2),
	$img->string(gdSmallFont, $xStart, $p2y+ int(4*$sfh/3), 
		$obj->{yAxisLabel}, $obj->{textColor})
		if ($obj->{yAxisLabel});

# vertical axis label
	($p2x, $p2y) = $obj->pt2pxl($xh, $yl),
	$xStart2 = $p2x - ((length($obj->{xAxisLabel}) * $sfw) >> 1),
	$img->string(gdSmallFont, ($xStart2 > 10 ? $xStart2 : 10), 
		$p2y - 3*($sfh>>1), $obj->{xAxisLabel},  $obj->{textColor})
		if $obj->{xAxisLabel};
#
# draw ticks and labels
# 
	my ($i,$px,$py, $step, $j, $txt);
# 
# vertical symbolic domain
#
	my $ary = $obj->{domain};
    
	my $prevx = $obj->{vertEdge};
	for ($i = 1, $j = 0; $i < $xh; $i++, $j++) {
		($px,$py) = $obj->pt2pxl($i, $yl);
		($p1x, $p1y) = ($obj->{horizGrid}) ? 
			$obj->pt2pxl($i, $yh) : ($px+2, $py);
		$img->line(($obj->{horizGrid} ? $px : $px-2), $py, 
			$p1x, $py, $obj->{gridColor});
#
#	skip the label if undefined or it would overlap or its Gantt
#
		next unless (($plottypes & HISTO) && defined($$ary[$j]) && ($sfh < ($prevx - $py)));
		$prevx = $py;
		$txt = ($obj->{timeDomain}) ? 
			restore_temporal($$ary[$j], $obj->{timeDomain}) : $$ary[$j];
#
#	truncate long labels
#
		$txt = substr($txt, 0, 22) . '...' 
			if (length($txt) > 25);

		$img->string(gdSmallFont, ($px-(length($txt)*$sfw)-5), 
			$py-($sfh>>1), $txt, $obj->{textColor});
	}
#
# horizontal
#
#	for LOG(Y):
#
	$prevx = 0;
	if ($obj->{yLog}) {
		$i = $yl;
		my $n = 0;
		my $k = $i;
		my $powk;
		while ($i < $yh) {
			$k = $i + $logsteps[$n++];
			($px,$py) = $obj->pt2pxl($xl, $k);
			($p1x, $p1y) = ($obj->{vertGrid}) ? 
				$obj->pt2pxl($xh, $k) : ($px, $py+2);
			$img->line($px, ($obj->{vertGrid} ? $py : $py-2),
				$px, $p1y, $obj->{gridColor});
#
#	skip the label if it would overlap
#
			next if ($obj->{xAxisVert} && ($sfh > ($px - $prevx)));

			$powk = ($obj->{timeRange}) ? 
				restore_temporal(10**$k, $obj->{timeRange}) : 10**$k;

			($n, $i)  = (0, $k)
				if ($n > $#logsteps);

			next if (length($powk) * ($sfw>>1) > ($px - $prevx));
			next unless ($n == 1);

			$prevx = $px;

			next if ($obj->{xAxisVert} && ($px+$sfh >= $xStart));
			$img->stringUp(gdSmallFont, $px-($sfh>>1), 
				$py+2+length($powk)*$sfw, $powk, $obj->{textColor}),
			next
				if $obj->{xAxisVert};

			$img->string(gdSmallFont, $px-(length($powk) * ($sfw>>1)),
				$py+4, $powk, $obj->{textColor});
		}
		return 1;
	}

	$step = $obj->{horizStep};
	for ($i=$yl, $j = 0; $i <= $yh; $i+=$step, $j++ ) {
		($px,$py) = $obj->pt2pxl($xl, $i);
		($p1x,$p1y) = ($obj->{vertGrid}) ? $obj->pt2pxl($xh, $i) : ($px, $py+2);
		$img->line($px, ($obj->{vertGrid} ? $py : $py-2), $px, $p1y, $obj->{gridColor});
		next if ($obj->{xAxisVert} && ($px - $prevx < $sfh+3));

		$txt = $obj->{timeRange} ? restore_temporal($i, $obj->{timeRange}) : $i;
		next unless ($obj->{xAxisVert} || 
			(length($txt) * ($sfw>>1) < ($px - $prevx)));
		$prevx = $px;

		next if ($obj->{xAxisVert} && ($px+$sfh >= $xStart));
		$img->stringUp(gdSmallFont, $px-($sfh>>1), 
			$py+2+length($txt)*$sfw, $txt, $obj->{textColor}),
		next
			if $obj->{xAxisVert};

		$img->string(gdSmallFont, $px-(length($txt) * ($sfw>>1)),
			$py+4, $txt, $obj->{textColor});
	}
	return 1;
}

sub drawTitle {
	my ($obj) = @_;
	my ($w,$h) = (gdMediumBoldFont->width, gdMediumBoldFont->height);

# centered below chart
	my ($px,$py) = ($obj->{width}/2, $obj->{height} - 40 + $h);

	($px,$py) = ($px - length ($obj->{title}) * $w/2, $py-$h/2);
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

	$xl = 1 if $obj->{symDomain};
	my ($xbot, $ybot) = $obj->pt2pxl($xl, (($yl >= 0) ? $yl : 0));
	
	# Add the data points
	for (my $i = 0; $i < @$ary; $i += 2)
	{
		next unless defined($$ary[$i]);

		($x, $y) = $obj->pt2pxl(
			$obj->{symDomain} ? ($i>>1)+1 : $$ary[$i], 
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
	$brush->arc( 4, 4, 8, 8, 0, 360, $clr ),
	return $brush
		if ($mtype == 8);
#
#	dot - contributed by Andrea Spinelli
	$brush->setPixel( 4,4, $clr ),
	return  $brush
 		if ( $mtype == 10 );
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
	$obj->{errmsg} = "GD cannot read icon file $icon.",
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
	my ($obj, $iconimg, $pxl, $pyb, $pxr, $pyt) = @_;
#
#	force the icon into the defined image area
#
	my ($iconw, $iconh) = $iconimg->getBounds();
	my $img = $obj->{img};
	if ($pxl == $pxr) {
		$pxl -= int($iconw/2);

		my $srcY = 0;
		my $h = $iconh;
		while ($pyb > $pyt) {	
			$h = $pyb - $pyt,
			$srcY = $iconh - $h,
				if ($iconh > ($pyb - $pyt));
			$pyb -= $h;
			$img->copy($iconimg, $pxl, $pyb, 0, $srcY, $iconw, $h);
		}
		return 1;
	}
#
#	must be histogram
	$pyb -= int($iconh/2); # this might need adjusting

	my $limX = $iconw;
	while ($pxl < $pxr) {	
		$limX = ($pxr - $pxl) if ($iconw > ($pxr - $pxl));
		$img->copy($iconimg, $pxl, $pyb, 0, 0, $limX, $iconh);
		$pxl += $limX;
	}
	1;
}

sub plot3DAxes {
	my ($obj) = @_;
	my $img = $obj->{img};
	my ($xl, $xh, $yl, $yh, $zl, $zh) = 
		($obj->{xl}, $obj->{xh}, $obj->{yl}, $obj->{yh}, $obj->{zl}, $obj->{zh});

	my $numRanges = scalar @{$obj->{data}};
	my $zbarw = ($obj->{zh} - $obj->{zl})/($obj->{zAxisLabel} ? $obj->{Zcard}*2 : 2);
	my $ishisto = ($obj->{plotTypes} & HISTO);

	$zl -= (0.8);
	$zh += $zbarw;
	my $yc = ($yl < 0) ? 0 : $yl;
	my @v = ($ishisto) ? 
	(
		$xl, $yl, $zl,	# bottom front left
		$xl, $yl, $zh,	# bottom rear left
		$xh, $yl, $zl,	# top front left
		$xh, $yl, $zh,	# top rear left
		$xl, $yh, $zl,	# bottom front right
		$xl, $yh, $zh,	# bottom rear right
		$xh, $yh, $zh,	# top rear right
#
#	in case floor is above bottom of graph
		$xl, $yl, $zl,	# bottom front left
		$xl, $yh, $zl,	# bottom front right
		$xl, $yh, $zh,	# bottom rear right
		$xl, $yl, $zh	# bottom rear left
	) :
#	its a barchart
	(
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
		my ($imax, $imin, $step) = 
			($obj->{yh}, $obj->{yl}, 
				($ishisto ? $obj->{horizStep} : $obj->{vertStep}));
		
		for ($i = $imin; $i < $imax; $i += $step) {

#			($gx, $gy) = $obj->pt2pxl($i, $yl, $zl),
#			($hx, $hy) = $obj->pt2pxl($i, $yl, $zh),
#			$img->line($gx, $gy, $hx, $hy, $obj->{gridColor}),
#			($gx, $gy) = $obj->pt2pxl($i, $yh, $zh),
#			$img->line($gx, $gy, $hx, $hy, $obj->{gridColor}),
#			next
#				if ($ishisto);

			($gx, $gy) = $obj->pt2pxl($xl, $i, $zl);
			($hx, $hy) = $obj->pt2pxl($xl, $i, $zh);
			$img->line($gx, $gy, $hx, $hy, $obj->{gridColor});
			($gx, $gy) = $obj->pt2pxl($xh, $i, $zh);
			$img->line($gx, $gy, $hx, $hy, $obj->{gridColor});
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
	my $zcard = $obj->{zAxisLabel} ? $obj->{Zcard} : 1;
	my $zbarw = ($zh - $zl)/($zcard*2);
	my $ishisto = ($obj->{plotTypes} & HISTO);

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
		my $xv = $ishisto ? $xl : $xh;
		my $yv = $ishisto ? $yh : $yl;
		for ($i = 0; $i <= $#$zs; $i++) {
			($gx, $gy) = $obj->pt2pxl($xv, $yv, $i+1+0.8);
			$text = $$zs[$i];
			$text = substr($text, 0, 22) . '...' if (length($text) > 25);
			$img->string(gdSmallFont, $gx, $gy, $text, $obj->{textColor});
		}
	}
	my $xs = $obj->{xValues};
	my $xoff = ($yl >= 0) ? 1 : $ishisto ? 0 : 0.5;
	my $zv = (($yl >= 0) || $ishisto) ? $zl : $zh; 
	for ($i = 0; $i <= $#$xs; $i++) {
		($gx, $gy) = $obj->pt2pxl($i+$xoff, $yl, $zv);
		$text = $$xs[$i];
		$text = substr($text, 0, 22) . '...' if (length($text) > 25);

		$gy += (length($text) * $sfw) + 5,
		$img->stringUp(gdSmallFont, $gx-($sfh>>1), $gy, $text, $obj->{textColor}),
		next
			unless $ishisto;

		$gx -= (length($text) * $sfw) + 5;
		$img->string(gdSmallFont, $gx, $gy-($sfw>>1), $text, $obj->{textColor}),
	}
	my $ystep = $ishisto ? $obj->{horizStep} : $obj->{vertStep};
	for ($i = $yl; $i < $yh; $i += $ystep) {
		($gx, $gy) = $obj->pt2pxl($xl, $i, $zl);
		$text = $i;
		$text = substr($text, 0, 22) . '...' if (length($text) > 25);

		$gx -= ((length($text) * $sfw) + 5),
		$img->string(gdSmallFont, $gx, $gy-($sfw>>1), $text, $obj->{textColor}),
		next
			unless $ishisto;

		$gy += ((length($text) * $sfw) + 5),
		$img->stringUp(gdSmallFont, $gx-($sfh>>1), $gy, $text, $obj->{textColor});
	}
	return 1 if $ishisto;
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
	my $k = 0;
	my $color = 'black';
	my $ary;
#
#	extract properties
#
	for ($k = 0; $k < $numRanges; $k++) {
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
#	WE NEED A BETTER CONTROL VALUE HERE!!! since different plots may not
#	have the exact same domain!!!
#
	my $numPts = $#{$obj->{data}->[0]};
	for (my $i = 0, my $j = 0; $i <= $numPts; $i+=4) {
		if ($numRanges == 1) {
#
#	to support multicolor single ranges
			$ary = $obj->{data}->[0];
			$obj->drawCube($$ary[$i], $$ary[$i+1], $$ary[$i+2], $$ary[$i+3],
				0, $fronts[$j], $tops[$j], $sides[$j], 
				$xoff, $xbarw, $zbarw, $$xvals[$$ary[$i]-1], 
				$$zvals[$$ary[$i+3]-1]);
			$j++;
			$j = 0 if ($j > $#fronts);
			next;
		}
#
#	multirange, draw the bar for each dataset
		for ($k = 0; $k < $numRanges; $k++) {
			my $numPts = $#{$obj->{data}->[$k]};
			my $ary = $obj->{data}->[$k];
			$obj->drawCube($$ary[$i], $$ary[$i+1], $$ary[$i+2], $$ary[$i+3],
				$k, $fronts[$k], $tops[$k], $sides[$k], 
				$xoff, $xbarw, $zbarw, $$xvals[$$ary[$i]-1], 
				$$zvals[$$ary[$i+3]-1]);
		}
	}
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
	my $ishisto = $obj->{plotTypes} & HISTO;
	$z++;
#
#	generate value coordinates of visible vertices
	my @v = $ishisto ?
	(
		$xl, $yl, $z - $zbarw,	# left bottom front
		$xr, $yl, $z - $zbarw,	# left top front
		$xr, $yl, $z + $zbarw,	# left top rear
		$xr, $yh, $z + $zbarw,	# right top rear
		$xr, $yh, $z - $zbarw,	# right top front
		$xl, $yh, $z - $zbarw,	# right bottom front
		$xl, $yh, $z + $zbarw	# right bottom rear
	) :
	(
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
	return 1 unless ($obj->{genMap} || $obj->{showValues});
#
#	generate image map for top(right) face only
#
	my $y = ($yh > 0) ? $yh : $yl;
	if ($obj->{genMap}) {
		my $text = ($obj->{zAxisLabel}) ? "($xval, $y, $zval)" : "($xval, $y)";
		my $ary = $polyverts[($ishisto ? 2 : 0)];
		my @ptsary = ();
		for ($i = 0; $i < 4; $i++) {
			push(@ptsary, $xlatverts[$$ary[$i]], $xlatverts[$$ary[$i]+1]);
		}
		$obj->updateImagemap('POLY', $text, 0, $xval, $y, $zval, @ptsary);
	}
	return 1 unless $obj->{showValues};
#
#	render the top text label
#
	my ($mx, $px, $py);

	$mx = ($xr + $xl)/2,
	($px, $py) = $obj->pt2pxl($mx, $yh, $z - $zbarw),
	$img->stringUp(gdTinyFont, $px, $py-10, $y, $obj->{textColor}),
	return 1
		unless $ishisto;

	$mx = ($xr + $xl)/1.9;
	($px, $py) = $obj->pt2pxl($mx, $yh, $z - $zbarw);
	$img->string(gdTinyFont, $px+15, $py, $y, $obj->{textColor});
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
		$val = restore_temporal($val, $obj->{timeRange}) if $obj->{timeRange};
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
	($fx, $fy) = computeCoords($xc, $yc, $vr * 0.6, $hr* 0.6, $bisect, 
		$piefactor);
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
	$plotNum =~ s/([^;\/?:@&=+\$,A-Za-z0-9\-_.!~*'()])/$escapes{$1}/g;
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

#
#	use plotHistoAxes to make axes

sub setGanttPoints {
	my ($obj, $taskary, $starts, $ends, $assignees, $pcts, @depends) = @_;
	my $props = pop @depends;
	my @data = ();
	my %taskhash = ();
	my %starthash = ();
	my $yh = -1E38;
	my $xh = 0;
	my $i;
	for ($i = 0; $i <= $#$taskary; $i++) {
		next unless (defined($$taskary[$i]) && 
			defined($$starts[$i]) && 
			defined($$ends[$i]));
		
		$obj->{errmsg} = 'Duplicate task name.',
		return undef
			if $taskhash{uc $$taskary[$i]};
		
		my $startdate = convert_temporal($$starts[$i], $obj->{timeRange});
		my $enddate = convert_temporal($$ends[$i], $obj->{timeRange});
		$obj->{errmsg} = 'Invalid start date.',
		return undef
			unless defined($startdate);
		$yh = $enddate if ($enddate > $yh);
		
		$obj->{errmsg} = 'Invalid end date.',
		return undef
			unless (defined($enddate) && ($enddate >= $startdate));
		
		$obj->{errmsg} = 'Invalid completion percentage.',
		return undef
			unless ((! $$pcts[$i]) || 
				(($$pcts[$i]=~/^\d+(\.\d+)?$/) &&
				($$pcts[$i] >= 0) && ($$pcts[$i] <= 100)));

		my @deps = ();
		foreach my $d (@depends) {
			next unless $$d[$i];

			$obj->{errmsg} = "Invalid dependency; $$taskary[$i] cannot be self-dependent.",
			return undef
				if (uc $$d[$i] eq uc $$taskary[$i]);
			push(@deps, $$d[$i]);
		}

		$taskhash{uc $$taskary[$i]} = $startdate;
		$starthash{$startdate} = 
			[ [ $$taskary[$i], $startdate, $enddate, $$assignees[$i], $$pcts[$i], \@deps ] ], next
			unless $starthash{$startdate};
		push @{$starthash{$startdate}}, 
			[ $$taskary[$i], $startdate, $enddate, $$assignees[$i], $$pcts[$i], \@deps ] ;
	}		
	foreach my $d (@depends) {
		for ($i = 0; $i <= $#$d; $i++) {
			next unless $$d[$i];
			$obj->{errmsg} = 'Unknown task ' . $$d[$i],
			return undef
				unless $taskhash{uc $$d[$i]};

			$obj->{errmsg} = "Invalid dependency; $$d[$i] precedes $$taskary[$i].",
			return undef
				if ($taskhash{uc $$d[$i]} < $taskhash{uc $$taskary[$i]});
		}
	}
#
#	sort tasks on startdate
	my @started = sort numerically keys(%starthash);
	foreach my $startdate (@started) {
		foreach my $task (@{$starthash{$startdate}}) {
			push(@data, @$task);
			$xh++;
		}
	}
	push(@{$obj->{data}}, \@data);
	push(@{$obj->{props}}, $props);
	$obj->{yl} = $started[0] unless (defined($obj->{yl}) && ($obj->{yl} < $started[0]));
	$obj->{yh} = $yh unless (defined($obj->{yh}) && ($obj->{yh} > $yh));
	$obj->{xl} = 1;
	$obj->{xh} = $xh;
	$obj->{plotTypes} |= GANTT;
	return 1;
}

sub plotGantt {
	my ($obj) = @_;
#
#	collect color
	my $props = $obj->{props}->[0];
	my $data = $obj->{data}->[0];
	my ($xl, $xh, $yl, $yh) = ($obj->{xl}, $obj->{xh}, $obj->{yl}, $obj->{yh});
	my ($s, $t, $i, $j, $deps, $depend, $srcx, $color);
	my ($offset, $span, $pct, $compend, $prtT, $starts, $ends);
	my $img = $obj->{img};

	foreach (split(' ', $props)) {
		$color = $_ if $colors{$_};
	}
	$obj->{$color} = $img->colorAllocate(@{$colors{$color}})
		unless $obj->{$color};
	$obj->{compcolor} = $img->colorAllocate($colors{$color}->[0] * 0.6,
		$colors{$color}->[1] * 0.6,$colors{$color}->[2] * 0.6);
#
#	precompute start/end pts of bar
	my @pts = ();
	my %taskhash = ();
	for ($i = 0, $j = ($#$data+1)/6; $i <= $#$data; $i+=6, $j--) {
		$taskhash{uc $$data[$i]} = $#pts + 1;
		push (@pts, $obj->pt2pxl($j, $$data[$i + 1]),
			$obj->pt2pxl($j, $$data[$i + 2]));
	}
#
#	draw dependency lines 1st
	my $marker = $obj->make_marker('filldiamond', 'black');
	my ($markw, $markh) = $marker->getBounds;
	for ($i = 0; $i <= $#$data; $i+=6) {
		$s = $taskhash{uc $$data[$i]};
		$deps = $$data[$i+5];
		next unless ($deps && ($#$deps >= 0));
		foreach $depend (@$deps) {
			$t = $taskhash{uc $depend};
			$img->line($pts[$s+2], $pts[$s+3], $pts[$t], $pts[$s+3], $obj->{black})
				if ($pts[$s+2] < $pts[$t]); # horiz line if src ends before tgt starts
			$srcx = ($pts[$s+2] < $pts[$t]) ? $pts[$t] : 
				($pts[$s+2] < $pts[$t+2]) ? $pts[$s+2] : $pts[$t];
			$img->line($srcx, $pts[$s+3], $srcx, $pts[$t+3]-$sfh, $obj->{black});
			$img->copy($marker, $srcx-($markw/2), $pts[$t+3]-$sfh, 0, 0, 
				$markw-1, $markh-1);
		}
	}
#
#	then draw boxes
	$offset = $sfh/2;
	for ($i = 0; $i <= $#$data; $i+=6) {
		$s = $taskhash{uc $$data[$i]};
#
#	compute pct. completion and create intermediate start/end pts
		$span = $pts[$s+2] - $pts[$s];
		$pct = $$data[$i+4]/100;
		$compend = $pts[$s] + int($span * $pct);
		$img->filledRectangle($pts[$s], $pts[$s+1] - $offset, 
			$compend, $pts[$s+3] + $offset, $obj->{compcolor})
			if ($pct);
		$img->filledRectangle($compend, $pts[$s+1] - $offset, 
			$pts[$s+2], $pts[$s+3] + $offset, $obj->{$color})
			if ($pct != 1);
#
#	now fill in taskname and assignee text
		$prtT = $$data[$i];
		$prtT .= '(' . $$data[$i+3]. ')' if $$data[$i+3];
		$prtT .= ' : ' . $$data[$i+4] . '%';
		$img->string(gdSmallFont, $pts[$s], $pts[$s+1] - $offset - $sfh,
				$prtT, $obj->{textColor});

		$starts = restore_temporal($$data[$i+1], $obj->{timeRange}),
		$ends = restore_temporal($$data[$i+2], $obj->{timeRange}),

		$prtT = $starts . '->' . $ends,
		$obj->updateImagemap('RECT', $prtT, 
			$$data[$i], $starts, $ends, $$data[$i+4] . ':' . $$data[$i+3],
			$pts[$s], $pts[$s+1] - $offset, $pts[$s+2], $pts[$s+3] + $offset)
			if $obj->{genMap};
	}
	1;
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

B<DBD::Chart::Plot> creates images of various types of graphs for
2 or 3 dimensional data. Unlike GD::Graph, the input data sets
do not need to be uniformly distributed in the domain (X-axis),
and may be either numeric, temporal, or symbolic.

B<DBD::Chart::Plot> supports the following:

=over 4

=item - multiple data set plots

=item - line graphs, areagraphs, scatter graphs, linegraphs w/ points, 
	candlestick graphs, barcharts (2-D, 3-D, and 3-axis), histograms,
	piecharts, box & whisker charts (aka boxcharts), and Gantt charts

=item - optional iconic barcharts or datapoints

=item - a wide selection of colors, and point shapes

=item - optional horizontal and/or vertical gridlines

=item - optional legend

=item - auto-sizing of axes based in input dataset ranges

=item - optional symbolic and temproal (i.e., non-numeric) domain values

=item - automatic sorting of numeric and temporal input datasets to assure 
	proper order of plotting

=item - optional X, Y, and Z axis labels

=item - optional X and/or Y logarithmic scaling

=item - optional title

=item - optional adjustment of horizontal and vertical margins

=item - optional HTML or Perl imagemap generation

=item - composite images from multiple graphs

=item - user programmable colors

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
    my $img = DBD::Chart::Plot->new ( $image_width, $image_height, \%colormap ); 
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

Control generation of imagemaps. When genMap is set to a legal HTML
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

=item timeDomain

When set to a valid format string, the domain data points
are treated as associated temporal values (e.g., date,  time,
timestamp, interval). The values supplied by setPoints will
be strings of the specified format (e.g., 'YYYY-MM-DD'), but
will be converted to numeric time values for purposes of
plotting, so the domain is treated as continuous numeric
data, rather than discrete symbolic. Note that for barcharts,
histograms, candlesticks, or piecharts, temporal domains are
treated as symbolic for plotting purposes, but are sorted
as numeric values.

=item timeRange

When set to a valid format string, the range data points
are treated as associated temporal values (e.g., date,  time,
timestamp, interval). The values supplied by setPoints will
be strings of the specified format (e.g., 'YYYY-MM-DD'), but
will be converted to numeric time values for purposes of
plotting, so the range is treated as continuous numeric
data.

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
specified pointshape. The range and/or domain axis may be logarithmically scaled. 
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
	dblue      histo                   diagcross
	gold                               icon
	lyellow	                           dot
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
may be omitted if none of the datasets cross them at any point. 
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

=item 2 axis 2-D Barcharts and Histograms

Each bar is mapped individually.

=item Piecharts

Each wedge is mapped. The CGI parameter values are used slightly
differently than described above:

X=<wedge-label>&Y=<wedge-value>&Z=<wedge-percent>

=item 3-D Barcharts (either 2 or 3 axis)

The top face of each bar is mapped. The Z CGI parameter will be
empty for 2 axis barcharts.

=item 3-D Histograms (either 2 or 3 axis)

The right face of each bar is mapped. The Z CGI parameter will be
empty for 2 axis barcharts.

=item Line, point, area graphs

A 4 pixel diameter circle around each datapoint is mapped.

=item Candlestick graphs

A 4 pixel diameter circle around both the top and bottom datapoints
of each stick are mapped.


=item Boxcharts

The area of the box is mapped, and 4-pixel diameter circles
are mapped at the end of each extreme whisker.


=item Gantt Charts

The area of each bar in the chart is mapped.


=head1 TO DO

=item programmable fonts

=item symbolic ranges for scatter graphs

=item axis labels for 3-D charts

=item surfacemaps

=item SVG support

=head1 AUTHOR

Copyright (c) 2001 by Presicient Corporation. (darnold@presicient.com)

You may distribute this module under the terms of the Artistic License, 
as specified in the Perl README file.

=head1 SEE ALSO

GD, DBD::Chart. (All available on CPAN).
