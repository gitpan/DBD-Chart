#
# DBD::Chart::Plot -- Two dimensional plotting engine for DBD::Chart
#
#	Copyright (C) 2001 by Dean Arnold <darnold@earthlink.net>
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.
#
#	Change History:
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

package DBD::Chart::Plot;

$DBD::Chart::Plot::VERSION = '0.42';

use GD;
use strict;

my @clrlist = qw(
	white lgray	gray dgray black lblue blue dblue gold lyellow	
	yellow	dyellow	lgreen	green dgreen lred red dred lpurple	
	purple dpurple lorange orange pink dpink marine	cyan	
	lbrown dbrown );

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

my %shapes = (
'fillsquare', 1,
'opensquare', 2,
'horizcross', 3,
'diagcross', 4,
'filldiamond', 5,
'opendiamond', 6,
'fillcircle', 7,
'opencircle', 8);

my @logsteps = (0, log(2)/log(10), log(3)/log(10), log(4)/log(10), 
	log(5)/log(10), 1.0);
	
sub new {
    my $class = shift;
    my $obj = {};
    bless $obj, $class;
    $obj->init (@_);

    return $obj;
}

sub init {
	my ($obj, $w, $h, $bgimg) = @_;

  #  create an image object
	$obj->{'img'} = ($w) ? new GD::Image($w, $h) : new GD::Image(400, 300);
	$obj->{'width'} = ($w) ? $w : 400;
	$obj->{'height'} = ($w) ? $h : 300;
	$obj->{'img'}->copy($bgimg, 0, 0, 0, 0, $w-1, $h-1)
  		if ($bgimg);

# set image margins
	$obj->{'horizMargin'} = 50;
	$obj->{'vertMargin'} = 70;

# create an empty array for point arrays and properties
	$obj->{'data'} = [ ];
	$obj->{'props'} = [ ];
	$obj->{'plotCnt'} = 0;

# used for pt2pxl()
	($obj->{'xl'}, $obj->{'xh'}, $obj->{'yl'}, $obj->{'yh'}) = (0,0,0,0);
	($obj->{'xscale'}, $obj->{'yscale'}) = (0,0);
	($obj->{'horizEdge'}, $obj->{'vertEdge'}, 
		$obj->{'horizStep'}, $obj->{'vertStep'}) = (0,0,0,0);
	$obj->{'haveScale'} = 0; # last calculated min and max still valid

	($obj->{'xAxisLabel'}, $obj->{'yAxisLabel'}) = ('','');
	($obj->{'xLog'}, $obj->{'yLog'}) = (0,0);
	$obj->{'title'} = '';
	$obj->{'errmsg'} = '';
	$obj->{'keepOrigin'} = 0;
	$obj->{'bgColor'} = 'white' if (! $bgimg);

#  allocate some colors
	$obj->{'white'} = $obj->{'img'}->colorAllocate(@{$colors{'white'}});
	$obj->{'black'} = $obj->{'img'}->colorAllocate(@{$colors{'black'}}); 
	$obj->{'transparent'} = 
		$obj->{'img'}->colorAllocate(@{$colors{'transparent'}}); 
	$obj->{'img'}->transparent($obj->{'transparent'});
	
	$obj->{'img'}->interlaced('true');

# black border
	$obj->{'img'}->rectangle( 0, 0,	$obj->{'width'}-1, $obj->{'height'}-1,
		$obj->{'black'});
}

sub numerically { $a <=> $b }

sub setPoints {
	my ($obj, $xary, $y1ary, $y2ary, $props) = @_;
	my @ary = ();
	my %xhash = ();
	my $i;
	$props = $y2ary if (! ref $y2ary);
	my $yary = $y1ary;
	
	if ($#$xary != $#$yary) {
		$obj->{'errmsg'} = 'Unbalanced dataset.';
		return undef;
	}

# validate and construct array of points
	if (! ref $y2ary) {
		for ($i = 0; $i <= $#$xary; $i++) {
#
#	eliminate undefined data points
#
			next if ((! defined($$xary[$i])) || (! defined($$yary[$i])));

			$obj->{'errmsg'} = "Non-numeric domain value $$xary[$i]." and
				return undef
				if ((! $obj->{'symDomain'}) && 
					($$xary[$i]!~/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/));
			
			$obj->{'errmsg'} = "Non-numeric range value $$yary[$i]." and
				return undef
				if ($$yary[$i] !~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/);
		
			if (((! $obj->{'symDomain'}) && ($obj->{'xLog'}) && ($$xary[$i] <= 0)) ||
				(($obj->{'yLog'}) && ($$yary[$i] <= 0))) {
				$obj->{'errmsg'} = 'Negative value supplied for logarithmic axis.';
				return undef;
			}

			if ($obj->{'symDomain'}) {
				push(@ary, $$xary[$i], 
					($obj->{'yLog'} ? log($$yary[$i])/log(10) : $$yary[$i]));
			}
			else {
				$xhash{$$xary[$i]} = $$yary[$i];
			}
		}
#
#	make sure domain values are in ascending order
#
		if (! $obj->{'symDomain'}) {
			my @xsorted = sort numerically keys(%xhash);

			foreach $i (@xsorted) {
#
#	if either xLog or yLog is defined, apply to appropriate dataset now
#
				push(@ary, ($obj->{'xLog'} ? log($i)/log(10) : $i), 
					($obj->{'yLog'} ? log($xhash{$i})/log(10) : $xhash{$i}));
			}
		}
# record the dataset
		push(@{$obj->{'data'}}, \@ary);
		push(@{$obj->{'props'}}, ($props ? $props : 'nopoints'));

		$obj->{'haveScale'} = 0; # invalidate any prior min-max calculations
		return 1;
	}
#
#	must be candlestick, which means X-axis is uniformly distributed,
#	possibly non-numeric
#
	for ($i = 0; $i <= $#$xary; $i++) {
#
#	eliminate undefined data points
#
		next if ((! defined($$xary[$i])) || (! defined($$y1ary[$i])));

		$obj->{'errmsg'} = "Non-numeric range value $$y1ary[$i]." and
			return undef
			if ($$y1ary[$i] !~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/);
		
		$obj->{'errmsg'} = "Non-numeric range value $$y2ary[$i]." and
			return undef
			if ($$y2ary[$i] !~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/);
		
		if ($$y1ary[$i] > $$y2ary[$i]) {
			$obj->{'errmsg'} = 'Range min value greater than range max value.';
			return undef;
		}
			
		if (($obj->{'yLog'}) && (($$y1ary[$i] <= 0) || ($$y2ary[$i] <= 0))) {
			$obj->{'errmsg'} = 'Negative value supplied for logarithmic axis.';
			return undef;
		}

		push(@ary, $$xary[$i],
			[ ($obj->{'yLog'} ? log($$y1ary[$i])/log(10) : $$y1ary[$i]),
			($obj->{'yLog'} ? log($$y2ary[$i])/log(10) : $$y2ary[$i]) ] );
	}
# record the dataset
	push(@{$obj->{'data'}}, \@ary);
	push(@{$obj->{'props'}}, ($props ? 'candle ' . $props : 'candle nopoints'));

	$obj->{'haveScale'} = 0; # invalidate any prior min-max calculations
	return 1;
}

sub error {
  my $obj = shift;
  return $obj->{'errmsg'};
}

sub setOptions {
	my ($obj, %hash) = @_;

	for (keys (%hash)) {
#
#	we need a lot more error checking here!!!
#
		if (($_ eq 'bgColor') && (! $colors{$hash{$_}})) {
			$obj->{'errmsg'} = "Unrecognized color $hash{$_}.";
			return undef;
		}
		$obj->{$_} = $hash{$_};
	}
	return 1;
}

sub plot {
	my ($obj, $format) = @_;

	if ($obj->{'bgColor'}) {
		my $color = ($obj->{$obj->{'bgColor'}}) ? $obj->{$obj->{'bgColor'}} :
			$obj->{'img'}->colorAllocate(@{$colors{$obj->{'bgColor'}}});
		$obj->{'img'}->fill(1, 1, $color );
	}

	$obj->computeScales unless $obj->{'haveScale'};
	$obj->drawTitle if $obj->{'title'}; # vert offset may be increased
	$obj->drawSignature if $obj->{'signature'}; # vert offset may be increased
	$obj->plotAxes;
	$obj->plotData;

	return (($format) && ($format eq 'jpeg')) ? 
		$obj->{'img'}->jpeg : $obj->{'img'}->png;
}

# sets min and max values of all data (xl, yl, xh, yh)
# also sets xscale, yscale, and edge values used in pt2pxl
sub computeScales {
	my $obj = shift;
	my ($i, $ary, $xl, $yl, $xh, $yh, $tl, $th, $props);

# if no data, set arbitrary bounds
	($xl, $yl, $xh, $yh) = (0,0,1,1) and return
		if (! @{$obj->{'data'}});

# cycle through the datasets looking for min and max values
	$ary = ${$obj->{'data'}}[0];
	$props = ${$obj->{'props'}}[0];
	$xl = $$ary[0];
	$xh = $$ary[0];
	$yl = $$ary[1];
	$yh = $$ary[1];
   	if (ref $yl) {
    	$tl = $yl;
    	$yl = $$tl[0];
    	$yh = $$tl[1];
    	$xl = 0;
    	$xh = 1;
    }
    elsif ($obj->{'symDomain'}) { 
    	$tl = 1; 
    	$xl = 0;
    	$xh = 1;
    }
    
	foreach $ary (@{$obj->{'data'}}) {
		for ($i=0; $i<$#{$ary}; $i++) {
			if (! defined($tl)) {
				$xl = ($xl > $$ary[$i]) ? $$ary[$i] : $xl;
				$xh = ($xh < $$ary[$i]) ? $$ary[$i] : $xh;
			}
			$i++;
	    	if (ref $$ary[$i]) {
		    	$tl = $$ary[$i];
				$yl = ($yl > $$tl[0]) ? $$tl[0] : $yl;
				$yh = ($yh < $$tl[1]) ? $$tl[1] : $yh;
		    }
		    else {
				$yl = ($yl > $$ary[$i]) ? $$ary[$i] : $yl;
				$yh = ($yh < $$ary[$i]) ? $$ary[$i] : $yh;
			}
		}
		$th = (scalar(@$ary)-1)/2;
		$xh = $th if (defined($tl) && ($xh < $th));
	}
#
#	if keepOrigin, make sure (0,0) is included
#	(but only if not in logarithmic mode)
#
	if ($obj->{'keepOrigin'}) {
		if (! $obj->{'xLog'}) {
			$xl = 0 if ($xl > 0);
			$xh = 0 if ($xh < 0);
		}
		if (! $obj->{'yLog'}) {
			$yl = 0 if ($yl > 0);
			$yh = 0 if ($yh < 0);
		}
	}
	
# set axis ranges for widest dataset
	($obj->{'xl'}, $obj->{'xh'}, $obj->{'yl'}, $obj->{'yh'}) = 
		$obj->computeRanges($xl, $xh, $yl, $yh);
#
#	heuristically adjust image margins to fit labels
#
	my ($sfw,$sfh) = (gdSmallFont->width, gdSmallFont->height);
	my ($tfw,$tfh) = (gdTinyFont->width, gdTinyFont->height);
	($xl, $xh, $yl, $yh) = ($obj->{'xl'}, $obj->{'xh'}, $obj->{'yl'}, $obj->{'yh'});

	my ($botmargin, $topmargin) = (40, 40);
	$botmargin += (3 * $tfh) if ($obj->{'legend'});
#
#	compute space needed for X axis labels
#
	my $maxlen = 0;
	if ($obj->{'symDomain'}) {
		my $ary = ${$obj->{'data'}}[0];
		for (my $i = 0; $i < $#$ary; $i+=2) {
			$maxlen = length($$ary[$i]) if (length($$ary[$i]) > $maxlen);
			$i++ if (ref $$ary[$i+1]);	# candlesticks
		}
	}
	else {
		my ($txl, $txh) = ($obj->{'xLog'}) ? (10**$xl, 10**$xh) : ($xl, $xh);
		$maxlen = (length($txh) > length($txl)) ? length($txh) : length($txl);
	}
	$botmargin += (($sfw * $maxlen) + 10);
#
#	compute space needed for Y axis labels
#
	my ($rtmargin, $ltmargin) = (40, 20);
	my ($tyl, $tyh) = ($obj->{'yLog'}) ? (10**$yl, 10**$yh) : ($yl, $yh);
	$maxlen = (length($tyh) > length($tyl)) ? length($tyh) : length($tyl);
	$ltmargin += (($sfw * $maxlen) + 10);

# calculate axis scales 
	$obj->{'xscale'} = ($obj->{'width'} - $ltmargin - $rtmargin) / ($xh - $xl);
	$obj->{'yscale'} = ($obj->{'height'} - $topmargin - $botmargin) / ($yh - $yl);

	$obj->{'horizEdge'} = $ltmargin;
	$obj->{'vertEdge'} = $obj->{'height'} - $botmargin;

	$obj->{'haveScale'} = 1;
}

# computes the axis ranges for the input (min,max) tuple
# also computes axis step size for ticks
sub computeRanges {
  my ($obj, $xl, $xh, $yl, $yh) = @_;
  my ($tmp, $om) = (0,0);
  my @sign = ();

	($obj->{'horizStep'}, $obj->{'vertStep'}) = (1,1) and 
		return (0,1,0,1)
		if (($xl == $xh) || ($yl == $yh));
		
	foreach ($xl, $xh, $yl, $yh) {
		push @sign, (($_ < 0) ? -1 : (! $_) ? 0 : 1);
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
	my $xr = (log($xh - $xl))/log(10);
	my $xd = $xr - int($xr);
	$obj->{'horizStep'} = ($xd < 0.4) ? (10 ** (int($xr) - 1)) :
		(($xd >= 0.87) ? (10 ** int($xr)) : (5 * ( 10 ** (int($xr) - 1))) );

	$xr = (log($yh - $yl))/log(10);
	$xd = $xr - int($xr);
	$obj->{'vertStep'} = ($xd < 0.4) ? (10 ** (int($xr) - 1)) :
		(($xd >= 0.87) ? (10 ** int($xr)) : (5 * ( 10 ** (int($xr) - 1))) );

	my ($xm, $ym) = ($obj->{'horizStep'}, $obj->{'vertStep'});
# fudge a little in case limit equals min or max
	return (
		((! $xm) ? 0 : $xm * (int(($xl-0.00001*$sign[0])/$xm) + $sign[0] - 1)),
		((! $xm) ? 0 : $xm * (int(($xh-0.00001*$sign[1])/$xm) + $sign[1] + 1)),
		((! $ym) ? 0 : $ym * (int(($yl-0.00001*$sign[2])/$ym) + $sign[2] - 1)),
		((! $ym) ? 0 : $ym * (int(($yh-0.00001*$sign[3])/$ym) + $sign[3] + 1)));
}

# draws all the datasets in $obj->{'data'}
sub plotData {
	my $obj = shift;
	my ($i, $k, $ary, $px, $py, $prevpx, $prevpy, $pyt, $pyb);
	my ($color, $shape, $line, $img, $prop);
	my @props = ();
	my $legend = $obj->{'legend'};
	my ($xl, $xh, $yl, $yh) = ($obj->{'xl'}, $obj->{'xh'}, $obj->{'yl'}, $obj->{'yh'});
	my ($w,$h) = (gdTinyFont->width, gdTinyFont->height);
# legend is left justified underneath
	my ($p2x, $p2y) = $obj->pt2pxl ($xl, $yl);
	my $legend_ht = $obj->{'height'} - 40 - 20 - (2 * $h);
	my $legend_wd = 10;
	my $legend_maxht = $obj->{'height'} - 40;
	my $marker;

	$img = $obj->{'img'};	
	
 	for ($k = 0; $k < scalar(@{$obj->{'data'}}); $k++) {
		$color = 'black';
		$shape = undef;
		$line = 'line';

		$ary = ${$obj->{'data'}}[$k];
		my $t = ${$obj->{'props'}}[$k];
		$t=~s/\s+/ /g;
		@props = split (' ', $t);
		foreach $prop (@props) {
			$prop = lc $prop;
			$color = $prop and next
				if ($colors{$prop});
			$shape = $shapes{$prop} and next
				if ($shapes{$prop});
			if ($prop eq 'points') {
				$shape = $shapes{'fillcircle'};
				next;
			}
					
			$shape = undef and next 
				if ($prop eq 'nopoints');
			$line = $prop
				if ($prop=~/^(line|noline|fill|bar|candle)$/);
		}
		$obj->{$color} = $obj->{'img'}->colorAllocate(@{$colors{$color}})
			if (! $obj->{$color});
			
		my $yoff = ($shape) ? 9 : 2;
#
#	generate pointshape if requested
#
		$marker = $obj->make_marker($shape, $color)
			if ($shape);
#
#	render legend if requested
#
		if (($legend) && ($$legend[$k])) {
			$legend_ht += 3*$h/2;
			if ($legend_ht > $legend_maxht) {
				$legend_ht = $obj->{'height'} - 40 - 20 - ($h/2);
				$legend_wd += 85;
			}
  			$img->string (gdTinyFont, $legend_wd + 25, $legend_ht,
				$$legend[$k], $obj->{$color});
  			$img->line($legend_wd, $legend_ht+4, $legend_wd+20, 
  				$legend_ht+4, $obj->{$color})
  				if (! $shape);
			$img->copy($marker, $legend_wd+5, $legend_ht, 0, 0, 9, 9)
				if ($shape);
		}

		if (ref $$ary[1]) {
#
#	Candlestick:
#
#	generate brush to draw sticks
#
			my $brush = new GD::Image(2,2);
			my $ci = $brush->colorAllocate(@{$colors{$color}});
			$brush->filledRectangle(0,0,1,1,$ci); # wide line
			$img->setBrush($brush);

# draw the rest of the points and lines 
			for ($i=0, my $j = 1; $i < scalar(@$ary)/2; $i++, $j+=2) {

# get top and bottom points
				my $r = $$ary[$j];
				($px, $pyb) = $obj->pt2pxl ( $i, $$r[0] );
				($px, $pyt) = $obj->pt2pxl ( $i, $$r[1] );

# draw pointshape if requested
				$img->copy($marker, $px-4, $pyb-4, 0, 0, 9, 9) or
					$img->copy($marker, $px-4, $pyt-4, 0, 0, 9, 9)
					if ($shape);
					
# draw top/bottom values if requested
				
				$img->string(gdTinyFont,$px-10,$pyb, 
					(($obj->{'yLog'}) ? 10**($$r[0]) : $$r[0]), $obj->{$color}) or
				$img->string(gdTinyFont,$px-10,$pyt-$yoff,
					(($obj->{'yLog'}) ? 10**($$r[1]) : $$r[1]), $obj->{$color})
					if ($obj->{'showValues'});

# draw line between top and bottom
				$img->line($px, $pyb, $px, $pyt, gdBrushed);
			}
			next;
		}

# draw the first point 
		($px, $py) = $obj->pt2pxl((($obj->{'symDomain'}) ? 0 : $$ary[0]),
			$$ary[1] );

		$img->copy($marker, $px-4, $py-4, 0, 0, 9, 9)
			if ($shape);

		if ($obj->{'showValues'}) {
			
			my $s = ($obj->{'symDomain'}) ? 
				(($obj->{'yLog'}) ? 10**($$ary[1]) : $$ary[1]) : 
				'(' . (($obj->{'xLog'}) ? 10**($$ary[0]) : $$ary[0]) . ',' . 
				(($obj->{'yLog'}) ? 10**($$ary[1]) : $$ary[1]) . ')';
			
			$img->string(gdTinyFont,$px-20,$py-$yoff, $s, $obj->{$color})
		}
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
			($px, $py) = $obj->pt2pxl((($obj->{'symDomain'}) ? $i>>1 : $$ary[$i]), 
				$$ary[$i+1] );

# draw point, maybe
			$img->copy($marker, $px-4, $py-4, 0, 0, 9, 9)
				if ($shape);

			if ($obj->{'showValues'}) {

				my $s = ($obj->{'symDomain'}) ? 
					(($obj->{'yLog'}) ? 10**($$ary[1]) : $$ary[1]) : 
					'(' . (($obj->{'xLog'}) ? 10**($$ary[0]) : $$ary[0]) . ',' . 
					(($obj->{'yLog'}) ? 10**($$ary[1]) : $$ary[1]) . ')';
			
				$img->string(gdTinyFont,$px-20,$py-$yoff, $s, $obj->{$color})
			}

# draw line from previous point, maybe
			$img->line($prevpx, $prevpy, $px, $py, $obj->{$color})
				if ($line eq 'line');
			($prevpx, $prevpy) = ($px, $py);
		}
	}
}

# compute pixel coordinates from datapoint
sub pt2pxl {
	my ($obj, $x, $y) = @_;

	return (
		int($obj->{'horizEdge'} + ($x - $obj->{'xl'}) * $obj->{'xscale'}),
		int($obj->{'vertEdge'} - ($y - $obj->{'yl'}) * $obj->{'yscale'})
	 );
}

# draw the axes, labels, title, grid/ticks and tick labels
sub plotAxes {
# axes run from data points: x -- ($xl,0) ($xh,0);
#                            y -- (0,$yl) (0,$yh);

	my $obj = shift;
	my ($sfw,$sfh) = (gdSmallFont->width, gdSmallFont->height);
	my ($tfw,$tfh) = (gdTinyFont->width, gdTinyFont->height);

	my ($p1x, $p1y, $p2x, $p2y);
	my $img = $obj->{'img'};
	my ($xl, $xh, $yl, $yh) = ($obj->{'xl'}, $obj->{'xh'}, 
		$obj->{'yl'}, $obj->{'yh'});

	my $yaxpt = ((! $obj->{'yLog'}) && ($yl < 0) && ($yh > 0)) ? 0 : $yl;
	my $xaxpt = ((! $obj->{'xLog'}) && ($xl < 0) && ($xh > 0)) ? 0 : $xl;
	$xaxpt = $xl if ($obj->{'symDomain'});
	
	if ($obj->{'vertGrid'} || $obj->{'horizGrid'}) {
#
#	gridded, create a rectangle
#
		($p1x, $p1y) = $obj->pt2pxl ($xl, $yl);
		($p2x, $p2y) = $obj->pt2pxl ($xh, $yh);

  		$img->rectangle( $p1x, $p1y, $p2x, $p2y, $obj->{'black'});
#
#	hilight the (0,0) axes, if available
#
		my $brush = new GD::Image(3,3);
		my $white = $brush->colorAllocate(255, 255, 255);
		my $black = $brush->colorAllocate(0, 0, 0);
		$brush->filledRectangle(0,0,2,2,$black); # wide line
		$img->setBrush($brush);
#	draw X-axis
		($p1x, $p1y) = $obj->pt2pxl($xl, $yaxpt);
		($p2x, $p2y) = $obj->pt2pxl($xh, $yaxpt);
		$img->line($p1x, $p1y, $p2x, $p2y, gdBrushed);
#	draw Y-axis
		($p1x, $p1y) = $obj->pt2pxl($xaxpt, $yl);
		($p2x, $p2y) = $obj->pt2pxl($xaxpt, $yh);
		$img->line($p1x, $p1y, $p2x, $p2y, gdBrushed);
  	}
  	else {
#
#	X axis
		($p1x, $p1y) = $obj->pt2pxl($xl, $yaxpt);
		($p2x, $p2y) = $obj->pt2pxl($xh, $yaxpt);
		$img->line($p1x, $p1y, $p2x, $p2y, $obj->{'black'});
	}

	if ($obj->{'xAxisLabel'}) {
		($p2x, $p2y) = $obj->pt2pxl($xh, $yl);
		my $len = $sfw * length($obj->{'xAxisLabel'});
		my $xStart = ($p2x+$len/2 > $obj->{'width'}-10)
			? ($obj->{'width'}-10-$len) : ($p2x-$len/2);
		$img->string(gdSmallFont, $xStart, $p2y+4*$sfh/3, 
			$obj->{'xAxisLabel'}, $obj->{'black'});
	}

# Y axis
	($p1x, $p1y) = $obj->pt2pxl ($xaxpt, $yl);
	($p2x, $p2y) = $obj->pt2pxl ((($obj->{'vertGrid'}) ? $xl : $xaxpt), $yh);
	
	$img->line($p1x, $p1y, $p2x, $p2y, $obj->{'black'})
		if ((! $obj->{'vertGrid'}) && (! $obj->{'horizGrid'}));

	if ($obj->{'yAxisLabel'}) {
		my $xStart = $p2x - length($obj->{'yAxisLabel'}) * ($sfw >> 1);
		$img->string(gdSmallFont, ($xStart>10 ? $xStart : 10), $p2y - 3*$sfh/2,
			  $obj->{'yAxisLabel'},  $obj->{'black'});
	}
#
# draw ticks and labels
# 
	my ($i,$px,$py, $step, $j, $txt);
# 
# horizontal
#
#	for LOG(X):
#
	if ($obj->{'xLog'}) {
		$i = $xl;
		my $n = 0;
		my $k = $i;
		while ($i < $xh) {
			$k = $i + $logsteps[$n++];

			($px,$py) = $obj->pt2pxl($k, 
				((($obj->{'yLog'}) || 
				($obj->{'vertGrid'}) || ($yl > 0) || ($yh < 0)) ? $yl : 0));
			($p1x, $p1y) = ($obj->{'vertGrid'}) ? 
				$obj->pt2pxl($k, $yh) : ($px, $py+2);
			$py -= 2 if (! $obj->{'vertGrid'});
			$img->line($px, $py, $px, $p1y, $obj->{'black'});
			$py += 2 if (! $obj->{'vertGrid'});
			if ($n == 1) {
				my $powk = 10**$k;
				$img->stringUp(gdSmallFont, $px-$sfh/2, $py+length($powk)*$sfw, 
					$powk, $obj->{'black'});
			}
			($n, $i)  = (0 , $k )
				if ($n == scalar(@logsteps));
		}
	}
	elsif (($obj->{'symDomain'}) || ($obj->{'props'}=~/^candle /)) {
#
# Candlestick or symbolic domain
#
		my $ary = ${$obj->{'data'}}[0];
    
    	my $prevx = 0;
		for ($i = 0, $j = 0; $i < $xh; $i++, $j+=2 ) {
			($px,$py) = $obj->pt2pxl($i, 
				((($obj->{'yLog'}) || 
				($obj->{'vertGrid'}) || ($yl > 0) || ($yh < 0)) ? $yl : 0));
			($p1x, $p1y) = ($obj->{'vertGrid'}) ? 
				$obj->pt2pxl($i, $yh) : ($px, $py+2);
			$py -= 2 if (! $obj->{'vertGrid'});
			$img->line($px, $py, $px, $p1y, $obj->{'black'});
			$py += 2 if (! $obj->{'vertGrid'});
			next if (!defined($$ary[$j]));
#
#	truncate long labels
#
			$txt = $$ary[$j];
			$txt = substr($txt, 0, 7) . '...' 
				if (length($txt) > 10);

			if (defined($obj->{'xAxisVert'}) && ($obj->{'xAxisVert'} == 0)) {
#
#	skip the label if it would overlap
#
				next if (((length($txt)+1) * $sfw) > ($px - $prevx));
				$prevx = $px;

				$img->string(gdSmallFont, $px-length($txt)*($sfw>>1), $py+($sfh>>1), 
					$txt, $obj->{'black'});
			}
			else {
#
#	skip the label if it would overlap
#
				next if (($sfh+1) > ($px - $prevx));
				$prevx = $px;

				$img->stringUp(gdSmallFont, $px-($sfh>>1), $py+2+length($txt)*$sfw, 
					$txt, $obj->{'black'})
			}
		}
	}
	else {
	    $step = $obj->{'horizStep'}; 
    
		for ($i = $xl; $i <= $xh; $i += $step ) {
			($px,$py) = $obj->pt2pxl($i, 
				((($obj->{'yLog'}) || 
				($obj->{'vertGrid'}) || ($yl > 0) || ($yh < 0)) ? $yl : 0));
			($p1x, $p1y) = ($obj->{'vertGrid'}) ? 
				$obj->pt2pxl($i, $yh) : ($px, $py+2);
			$py -= 2 if (! $obj->{'vertGrid'});
			$img->line($px, $py, $px, $p1y, $obj->{'black'});
			$py += 2 if (! $obj->{'vertGrid'});
			if ($obj->{'xAxisVert'}) {
				$img->stringUp(gdSmallFont, $px-($sfh>>1), $py+2+length($i)*$sfw, 
					$i, $obj->{'black'})
			}
			else {
				$img->string(gdSmallFont, $px-length($i)*($sfw>>1), $py+($sfh>>1), 
					$i, $obj->{'black'});
			}
		}
	}
#
# vertical
#
#	for LOG(Y):
#
	if ($obj->{'yLog'}) {
		$i = $yl;
		my $n = 0;
		my $k = $i;
		while ($i < $yh) {
			$k = $i + $logsteps[$n++];
			($px,$py) = $obj->pt2pxl(
				((($obj->{'xLog'}) || ($obj->{'horizGrid'})) ? $xl : $xaxpt), $k);
			($p1x, $p1y) = ($obj->{'horizGrid'}) ? 
				$obj->pt2pxl($xh, $k) : ($px+2, $py);
			$px -=2 if (! $obj->{'horizGrid'});
			$img->line($px, $py, $p1x, $py, $obj->{'black'});
			$px +=2 if (! $obj->{'horizGrid'});
			if ($n == 1) {
				my $powk = 10**$k;
				$img->string(gdSmallFont, $px-5-length($powk)*$sfw, $py-($sfh>>1), 
					$powk, $obj->{'black'});
			}
			
			($n, $i)  = (0 , $k )
				if ($n == scalar(@logsteps));
		}
	}
	else {
		$step = $obj->{'vertStep'};
#
#	if y tick step < (2 * sfh), skip every other label
#
		($px,$py) = $obj->pt2pxl((($obj->{'horizGrid'}) ? $xl : $xaxpt), $yl);
		($p1x,$p1y) = $obj->pt2pxl((($obj->{'horizGrid'}) ? $xl : $xaxpt), $yl+$step);
		my $skip = ($p1y - $py < ($sfh<<1)) ? 1 : 0;

		for ($i=$yl, $j = 0; $i <= $yh; $i+=$step, $j++ ) {
			($px,$py) = $obj->pt2pxl((($obj->{'horizGrid'}) ? $xl : $xaxpt), $i);
			($p1x, $p1y) = ($obj->{'horizGrid'}) ? 
				$obj->pt2pxl($xh, $i) : ($px+2, $py);
			$px -=2 if (! $obj->{'horizGrid'});
			$img->line($px, $py, $p1x, $py, $obj->{'black'});
			$px +=2 if (! $obj->{'horizGrid'});

			next if (($skip) && ($j&1));
			$img->string(gdSmallFont, $px-5-length($i)*$sfw, $py-($sfh>>1), 
				$i, $obj->{'black'});
		}
	}
}

sub drawTitle {
	my ($obj) = @_;
	my ($w,$h) = (gdMediumBoldFont->width, gdMediumBoldFont->height);

# centered below chart
	my ($px,$py) = ($obj->{'width'}/2, $obj->{'height'} - 40);

	($px,$py) = ($px - length ($obj->{'title'}) * $w/2, $py+$h/2);
	$obj->{'img'}->string (gdMediumBoldFont, $px, $py, 
		$obj->{'title'}, $obj->{'black'}); 
}

sub drawSignature {
	my ($obj) = @_;
	my $fw = (gdTinyFont->width * length($obj->{'signature'})) - 5;
# in lower right corner
	my ($px,$py) = ($obj->{'width'} - $fw, $obj->{'height'} - (gdTinyFont->height * 2));

	$obj->{'img'}->string (gdTinyFont, $px, $py, 
		$obj->{'signature'}, $obj->{'black'}); 
}

sub fill_region
{
	my ($obj, $ci, $ary) = @_;
	my $img = $obj->{'img'};

	my ($xl, $xh, $yl, $yh) = ($obj->{'xl'}, $obj->{'xh'}, 
		$obj->{'yl'}, $obj->{'yh'});

	# Create a new polygon
	my $poly = GD::Polygon->new();

	my @bottom;

	my ($xbot, $ybot) = $obj->pt2pxl($xl, (($yl >= 0) ? $yl : 0));
	
	# Add the data points
	for (my $i = 0; $i < @$ary; $i += 2)
	{
		my $value = $$ary[$i];
		next unless defined $value;

		my ($x, $y) = $obj->pt2pxl($$ary[$i], $$ary[$i+1]);
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

sub make_marker
{
	my ($obj, $mtype, $mclr) = @_;

	my $brush = new GD::Image(9,9);
	my $white = $brush->colorAllocate(255, 255, 255);
	my $clr = $brush->colorAllocate(@{$colors{$mclr}});
	$brush->transparent($white);

# square, filled	
	if ($mtype == 1) {
		$brush->filledRectangle(0,0,6,6,$clr);
		return $brush;
	}
# Square, open
	if ($mtype == 2) {
		$brush->rectangle( 0, 0, 6, 6, $clr ); 
		return $brush;
	}

# Cross, horizontal
	if ($mtype == 3) {
		$brush->line( 0, 4, 8, 4, $clr );
		$brush->line( 4, 0, 4, 8, $clr ); 
		return $brush;
	}

# Cross, diagonal
	if ($mtype == 4) {
		$brush->line( 0, 0, 8, 8, $clr );
		$brush->line( 8, 0, 0, 8, $clr );
		return $brush;
	}

# Diamond, filled
	if ($mtype == 5) {
		$brush->line( 0, 4, 4, 8, $clr );
		$brush->line( 4, 8, 8, 4, $clr );
		$brush->line( 8, 4, 4, 0, $clr );
		$brush->line( 4, 0, 0, 4, $clr );
		$brush->fillToBorder( 4, 4, $clr, $clr ) ;
		return $brush;
	}

# Diamond, open
	if ($mtype == 6) {
		$brush->line( 0, 4, 4, 8, $clr );
		$brush->line( 4, 8, 8, 4, $clr );
		$brush->line( 8, 4, 4, 0, $clr );
		$brush->line( 4, 0, 0, 4, $clr );
		return $brush;
	}
# Circle, filled
	if ($mtype == 7) {
		$brush->arc( 4, 4, 8 , 8, 0, 360, $clr );
		$brush->fillToBorder( 4, 4, $clr, $clr );
		return $brush;
	}

# must be Circle, open
	$brush->arc( 4, 4, 8, 8, 0, 360, $clr );
	return $brush;
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
        'horizMargin' => 75,
        'vertMargin' => 100,
        'title' => 'My Graph Title',
        'xAxisLabel' => 'my X label',
        'yAxisLabel' => 'my Y label' );
    
    print $img->plot;

=head1 DESCRIPTION

B<DBD::Chart::Plot> creates images of line and scatter graphs for
two dimensional data. Unlike GD::Graph, the input data sets
do not need to be uniformly distributed in the domain (X-axis).

B<DBD::Chart::Plot> supports the following:

=over 4

=item - multiple data set plots

=item - line graphs, areagraphs, scatter graphs, linegraphs w/ points, 
	and candlestick graphs

=item - a wide selection of colors, and point shapes

=item - optional horizontal and/or vertical gridlines

=item - optional legend

=item - auto-sizing of axes based in input dataset ranges

=item - automatic sorting of numeric input datasets to assure 
	proper order of plotting

=item - optional symbolic (i.e., non-numeric) domain values

=item - optional X and Y axis labels

=item - optional X and/or Y logarithmic scaling

=item - optional title

=item - optional adjustment of horizontal and vertical margins


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

=head2 Establish data points: setPoints()

    $img->setPoints(\@xdata, \@ydata);
    $img->setPoints(\@xdata, \@ydata, 'blue line');
    $img->setPoints(\@xdata, \@ymindata, \@ymaxdata, 'blue points');

Copies the input array values for later plotting.
May be called repeatedly to establish multiple plots in a single graph.
Returns a postive integer on success and C<undef> on failure. 
The error() method can be used to retrieve an error message.
X-axis values may be non-numeric, in which case the set of domain values
is uniformly distributed along the X-axis. Numeric X-axis data will be
properly scaled, including logarithmic scaling is requested.

If two sets of range data (ymindata and ymaxdata in the example above)
are supplied, a candlestick graph is rendered, in which case the domain
data is assumed non-numeric and is uniformly distributed, the first range
data array is used as the bottom value, and the second range data array
is used as the top value of each candlestick. Pointshapes may be specified,
in which case the top and bottom of each stick will be capped with the
specified pointshape. The range axis may be logarithmically scaled. If value
display is requested, the range value of both the top and bottom of each stick
will be printed above and below the stick, respectively.

B<Plot properties:> Properties of each dataset plot can be set
with an optional string as the third argument. Properties are separated
by spaces. The following properties may be set on a per-plot basis
(defaults in capitals):

    COLOR     LINESTYLE  USE POINTS?   POINTSHAPE 
    -----     ---------  -----------   ----------
	BLACK       LINE        POINTS     FILLCIRCLE
	white      noline      nopoints    opencircle
	lgray                              fillsquare  
	gray                               opensquare
	dgray                              filldiamond
	lblue                              opendiamond
	blue                               horizcross
	dblue                              diagcross
	gold
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

=head2 Graph-wide options: setOptions()

    $img->setOptions ('title' => 'My Graph Title',
        'xAxisLabel' => 'my X label',
        'yAxisLabel' => 'my Y label',
        'xLog' => 0,
        'yLog' => 0,
        'horizMargin' => $numHorPixels,
        'vertMargin' => $numvertPixels,
        'horizGrid' => 1,
        'vertGrid' => 1,
        'showValues' => 1,
        'legend' => \@plotnames,
        'symDomain' => 0
     );

As many (or few) of the options may be specified as desired.

Default titles and axis labels are blank. The title will be
centered in the margin space below the graph.
The Y axis label will be left justified
above the Y axis; the X axis label will be placed below the
right end of the X axis.

By default, the graph will be centered within the image, with 50
pixel margin around the graph border. You can obtain more space for 
titles or labels by increasing the image size or increasing the
margin values.

By default, no grid lines are drawn either horizontally or vertically.
By setting horizGrid or vertGrid to a non-zero value, grid lines
will be drawn across or up/down the chart, respectively, from the established 
Y-axis or X-axis ticks. Both options may be enabled in a single chart.

By default, the (x, y) values are not explicitly printed on the chart;
setting showValues to a non-zero value will cause the plot point values
to be printed in the gdTinyFont, centered just above the plotted point.

By default, both the X and Y axes are linearly scaled; logarithmic (base 10)
scaling can be specified for either axis by setting either 'xLog' or
'yLog', or both, to non-zero values.

A legend can be displayed below the chart, left justified and placed
above the chart title string, by setting the 'legend' option to an
array containing the labels for each plot on the chart, in the same order
as the datasets are assigned (i.e., label 0 applies to the 1st setPoints(),
label 1 applies to the 2nd setPoints(), etc.). The legend for each plot is
printed in the same color as the plot. If a point shape has been specified
for a plot, then the point shape is printed with the label; otherwise, a small
line segment is printed with the label. Due to space limitations, 
the number of datasets plotted should be limited to 8 or less.

Domain values are assumed to be numeric (except for candlestick graphs)
and may be non-uniformly distributed. If a symbolic domain is desired,
the 'symDomain' option can be set to a non-zero value, in which case
the domain dataset is uniformly distributed along the X-axis in the
same order as the domain dataset array.


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

=head1 BUGS AND TO DO

=item improved fonts and value display

=item 3-axis barcharts

=item surfacemaps

=head1 AUTHOR

Copyright (c) 2001 by Presicient Corporation. (darnold@presicient.com)

You may distribute this module under the terms of the Artistic License, 
as specified in the Perl README file.

=head1 SEE ALSO

GD::Graph(1), Chart(1), DBD::Chart. (All available on CPAN).

=cut 
