use DBD::Chart::Plot;

my %colormap = ( 
	'red',  [ 255, 0, 0 ], 
	'blue', [ 0, 0, 255 ], 
	'newcolor', [ 124, 37, 97 ]
);
my @x = ( 10, 20, 30, 40, 50);
my @y1 = ( 23, -39, 102, 67, 80);
my @y2 = ( 53, 39, 127, 89, 108);
my @y3 = ( 35, 45, 55, 65, 75);
my @xdate = ( '2002-01-24', '2002-01-25', '2002-01-26', '2002-01-27', '2002-01-28');
my @ytime = ( '0:12:34', '11:29:00', '5:57:33', '22:22:22', '4:06:01');
my @xdate2 = ( '1970-01-24', '1975-01-25', '1985-01-26', '1997-01-27', '2030-01-28');
my @ytime2 = ( '0:12:34', '11:29:00', '255:57:33', '2222:22:22', '4328:06:01');
my @xbox = ();
my @xfreq = ();
my @yfreq = ();
my %xbhash = ();
my @z = qw (Q1 Q2 Q3 Q4 Q1 Q2 Q3 Q4 Q1 Q2 Q3 Q4 Q1 Q2 Q3 Q4);
my @x3d = qw(North North North North 
East East East East South South South South West West West West);
my @y3d = (
	123, 354, 987, 455,
	346, 978, 294, 777,
	765, 99,  222, 409,
	687, 233, 555, 650);

open(HTMLF, ">plottest.html");
print HTMLF "<html><body>
<img src=simpline.png alt='simpline' usemap=#simpline><p>
<img src=simpscat.png alt='simpscat' usemap=#simpscat><p>
<img src=simparea.png alt='simparea' usemap=#simparea><p>
<img src=symline.png alt='symline' usemap=#symline><p>
<img src=simpbar.png alt='simpbar' usemap=#simpbar><p>
<img src=iconbars.png alt='iconbars' usemap=#iconbars><p>
<img src=simpbox.png alt='simpbox' usemap=#simpbox><p>
<img src=simpcandle.png alt='simpcandle' usemap=#simpcandle><p>
<img src=simppie.png alt='simppie' usemap=#simppie><p>
<img src=pie3d.png alt='pie3d' usemap=#pie3d><p>
<img src=bar3d.png alt='bar3d' usemap=#bar3d><p>
<img src=bar3axis.png alt='bar3axis' usemap=#bar3axis><p>
<img src=simphisto.png alt='simphisto' usemap=#simphisto><p>
<img src=histo3d.png alt='histo3d' usemap=#histo3d><p>
<img src=histo3axis.png alt='histo3axis' usemap=#histo3axis><p>
<img src=templine.png alt='templine' usemap=#templine><p>
<img src=templine2.png alt='templine2' usemap=#templine2><p>
<img src=logtempline.png alt='logtempline' usemap=#logtempline><p>
<img src=tempbar.png alt='tempbar' usemap=#tempbar><p>
<img src=temphisto.png alt='temphisto' usemap=#temphisto><p>
<img src=complinept.png alt='complinept' usemap=#complinept><p>
<img src=complpa.png alt='complpa' usemap=#complpa><p>
<img src=compblpa.png alt='compblpa' usemap=#compblpa><p>
<img src=complnbox.png alt='complnbox' usemap=#complnbox><p>
<img src=compllbb.png alt='compllbb' usemap=#compllbb><p>
<img src=comphisto.png alt='comphisto' usemap=#comphisto><p>
<img src=compbars.png alt='compbars' usemap=#compbars><p>
<img src=simpgantt.png alt='simpgantt' usemap=#simpgantt><p>
";

foreach (1..100) {
	push @xbox, int(rand(51)+10);
	$xbhash{$xbox[$#xbox]} += 1, next
		if $xbhash{$xbox[$#xbox]};
	$xbhash{$xbox[$#xbox]} = 1;
}

foreach my $xb (10..60) {
	push(@xfreq, $xb);
	push (@yfreq, $xbhash{$xb} ? $xbhash{$xb} : 0);
}

my @xfreq2 = ();
my @yfreq2 = ();
my @xbox2 = ();
my %xbhash2 = ();
foreach (1..200) {
	push @xbox2, int(rand(61)+10);
	$xbhash2{$xbox2[$#xbox2]} += 1, next
		if $xbhash2{$xbox2[$#xbox2]};
	$xbhash2{$xbox2[$#xbox2]} = 1;
}

foreach my $xb (10..70) {
	push(@xfreq2, $xb);
	push (@yfreq2, $xbhash2{$xb} ? $xbhash2{$xb} : 0);
}

goto $ARGV[0] if ($ARGV[0]);
#
#	simple line chart
#
simpline:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Linegraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'simpline',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png',
		horizGrid => 1,
		vertGrid => 1
	);
	$img->setPoints(\@x, \@y1, 'line newcolor fillcircle');
	dump_img($img, 'png', 'simpline');
	exit 0 if $ARGV[0];
#
#	simple scatter chart
#
simpscat:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Scattergraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'simpscat',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png',
		showValues => 1
	);
	$img->setPoints(\@x, \@y1, 'noline newcolor filldiamond');
	dump_img($img, 'png', 'simpscat');
#
#	simple area chart
#
simparea:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Areagraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'simparea',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png',
	);
	$img->setPoints(\@x, \@y1, 'fill newcolor');
	dump_img($img, 'png', 'simparea');
#
#	simple linechart w/ sym domain and icons
#
symline:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Symbolic Domain Linegraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'symline',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png',
		symDomain => 1,
		showValues => 1
	);
	$img->setPoints(\@xdate, \@y1, 'line newcolor fillcircle');
	dump_img($img, 'png', 'symline');
#
#	simple bar chart
#
simpbar:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Barchart Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'simpbar',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		showValues => 1,
		xAxisVert => 1
	);
	$img->setPoints(\@xdate, \@y1, 'bar newcolor');
	dump_img($img, 'png', 'simpbar');
#
#	simple bar chart w/ icons
#
iconbars:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Iconic Barchart Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'iconbars',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		mapScript => 'ONCLICK="alert(\'Got X=:X, Y=:Y\')"',
		icons => [ 'pumpkin.png' ],
		horizGrid => 1,
		gridColor => 'blue',
		textColor => 'dbrown'
	);
	$img->setPoints(\@xdate, \@y1, 'bar icon');
	dump_img($img, 'png', 'iconbars');
#
#	simple boxchart
#
simpbox:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Boxchart Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'simpbox',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png',
		showValues => 1
	);
	$img->setPoints(\@xbox, 'box newcolor');
	$img->setPoints(\@xbox2, 'box red');
	dump_img($img, 'png', 'simpbox');
#
#	simple candlestick
#
simpcandle:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Candlestick Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'simpcandle',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		showValues => 1,
		showGrid => 1
	);
	$img->setPoints(\@x, \@y1, \@y2, 'candle newcolor fillsquare');
	dump_img($img, 'png', 'simpcandle');
#
#	simple pie chart
#
simppie:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Piechart Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'simppie',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
	);
	$img->setPoints(\@x, \@y2, 'pie red blue newcolor green yellow');
	dump_img($img, 'png', 'simppie');
#
#	3-D pie chart
#
pie3d:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => '3-D Piechart Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'pie3d',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		threed => 1
	);
	$img->setPoints(\@x, \@y2, 'pie red green blue orange newcolor fillcircle');
	dump_img($img, 'png', 'pie3d');
#
#	3-D barchart
#
bar3d:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Linegraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'bar3d',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		threed => 1,
		showValues => 1,
		horizGrid => 1
	);
	$img->setPoints(\@x, \@y1, 'bar orange');
	dump_img($img, 'png', 'bar3d');
#
#	3-axis bar chart
#
bar3axis:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => '3 Axis Barchart Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'bar3axis',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		zAxisLabel => 'Date',
		showValues => 1,
		horizGrid => 1
	);
	$img->setPoints(\@x3d, \@y3d, \@z, 'bar red');
	dump_img($img, 'png', 'bar3axis');
#
#	simple histogram
#
simphisto:
	my $img = DBD::Chart::Plot->new(400, 400, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Histogram Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'simphisto',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		showValues => 1
	);
	$img->setPoints(\@x, \@y2, 'histo newcolor');
	dump_img($img, 'png', 'simphisto');
#
#	3-D histogram
#
histo3d:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Linegraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'histo3d',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		threed => 1,
		showValues => 1,
		horizGrid => 1
	);
	$img->setPoints(\@x, \@y2, 'histo orange');
	dump_img($img, 'png', 'histo3d');
#
#	3-axis histogram
#
histo3axis:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Linegraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'histo3axis',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		zAxisLabel => 'Some Other Range',
		showValues => 1,
		horizGrid => 1
	);
	$img->setPoints(\@x3d, \@y3d, \@z, 'histo red');
	dump_img($img, 'png', 'histo3axis');
#
#	linechart w/ temporal domain
#
templine:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Temporal Domain Linegraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'templine',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png',
		showValues => 1,
		timeDomain => 'YYYY-MM-DD',
		xAxisVert => 1
	);
	$img->setPoints(\@xdate, \@y1, 'line newcolor fillcircle');
	dump_img($img, 'png', 'templine');
#
#	linechart w/ temporal domain and range
#
templine2:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Temporal Domain & Range Linegraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'templine2',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png',
		timeDomain => 'YYYY-MM-DD',
		timeRange => '+HH:MM:SS'
	);
	$img->setPoints(\@xdate, \@ytime, 'line newcolor fillcircle');
	dump_img($img, 'png', 'templine2');
#
#	log linechart w/ temporal domain and range
#
logtempline:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Logarithmic Temporal Linegraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'logtempline',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png',
		timeDomain => 'YYYY-MM-DD',
		timeRange => '+HH:MM:SS',
#		xLog => 1,
		yLog => 1,
		xAxisVert => 1,
		horizGrid => 1,
		vertGrid => 1
	);
	$img->setPoints(\@xdate2, \@ytime2, 'line newcolor fillcircle');
	dump_img($img, 'png', 'logtempline');
#
#	barchart w/ temp. domain
#
tempbar:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Temporal Domain Barchart Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'tempbar',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		timeDomain => 'YYYY-MM-DD'
	);
	$img->setPoints(\@xdate, \@y1, 'bar red');
	dump_img($img, 'png', 'tempbar');
#
#	histo w/ temp domain
#
temphisto:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Temporal Histogram Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'temphisto',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		timeDomain => 'YYYY-MM-DD'
	);
	$img->setPoints(\@xdate, \@y2, 'histo blue');
	dump_img($img, 'png', 'temphisto');
#
#	composite (line, scatter)
#
complinept:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Composite Line and Pointgraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'complinept',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png'
	);
	$img->setPoints(\@x, \@y1, 'line newcolor fillcircle');
	$img->setPoints(\@x, \@y2, 'noline blue opensquare');
	dump_img($img, 'png', 'complinept');
#
#	composite (area, line, scatter)
#
complpa:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Composite Line, Point and Areagraph Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'complpa',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png'
	);
	$img->setPoints(\@x, \@y1, 'line newcolor fillcircle');
	$img->setPoints(\@x, \@y2, 'noline blue opensquare');
	$img->setPoints(\@x, \@y3, 'fill red');
	dump_img($img, 'png', 'complpa');
#
#	composite (area, bar, line, scatter)
#
compblpa:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Composite Bar, Line, Point, and Area Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'compblpa',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png',
	);
	$img->setPoints(\@x, \@y3, 'bar red');
	$img->setPoints(\@x, \@y1, 'line newcolor fillcircle');
	$img->setPoints(\@x, \@y2, 'noline blue opensquare');
	$img->setPoints(\@x, \@y3, 'fill green');
	dump_img($img, 'png', 'compblpa');
#
#	composite (line, box)
#
complnbox:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Composite Line  and Box Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'complnbox',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png'
	);
	$img->setPoints(\@xbox, 'box newcolor');
	$img->setPoints(\@xfreq, \@yfreq, 'line red');
	dump_img($img, 'png', 'complnbox');
#
#	composite (line, line, box, box)
#
compllbb:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Multi line and box composite Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'compllbb',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		logo => 'gowilogo.png',
	);
	$img->setPoints(\@xfreq, \@yfreq, 'line newcolor');
	$img->setPoints(\@xbox, 'box newcolor');
	$img->setPoints(\@xfreq2, \@yfreq2, 'line red');
	$img->setPoints(\@xbox2, 'box red');
	dump_img($img, 'png', 'compllbb');
#
#	composite (histo, histo)
#
comphisto:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Composite Histogram Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'comphisto',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		threed => 1,
		showValues => 1
	);
	$img->setPoints(\@x, \@y2, 'histo red');
	$img->setPoints(\@x, \@y3, 'histo blue');
	dump_img($img, 'png', 'comphisto');
#
#	composite (bar, bar, bar)
#
compbars:
	my $img = DBD::Chart::Plot->new(650, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Composite Barcharts Test',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'compbars',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
		icons => [ 'pumpkin.png', 'turkey.png' ],
#		threed => 1, 
		showValues => 1, horizGrid => 1, vertGrid => 1
	);
	$img->setPoints(\@x, \@y1, 'bar icon');
	$img->setPoints(\@x, \@y2, 'bar icon');
	$img->setPoints(\@x, \@y3, 'bar green');
	dump_img($img, 'png', 'compbars');
#
#	Simple Gantt Chart
simpgantt:
my @tasks = ( 'First task', '2nd Task', '3rd task', 'Another task', 'Final task');
my @starts = ( '2002-01-24', '2002-02-01', '2002-02-14', '2002-01-27', '2002-03-28');
my @ends = ( '2002-01-31', '2002-02-25', '2002-03-10', '2002-02-27', '2002-04-15');
my @assigned = ( 'DAA',       'DWE',       'SAM',       'KPD',        'WLA');
my @pct = (     25,            37,         0,          0,              0 );
my @depends = ( '3rd task',  'Final task', undef,    '2nd task',  undef);
my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
$img->setOptions(
	xAxisLabel => 'Tasklist',
	yAxisLabel => 'Schedule',
	title => 'Gantt Test',
	signature => '(C) 2002, GOWI Systems',
	genMap => 'simpgantt',
	mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
	mapType => 'HTTP',
	logo => 'gowilogo.png',
	timeRange => 'YYYY-MM-DD',
	vertGrid => 1,
	textColor => 'orange',
	xAxisVert => 1
);
$img->setPoints(\@tasks, \@starts, \@ends, \@assigned, \@pct, \@depends,
	'gantt red') || die $img->{errmsg};
dump_img($img, 'png', 'simpgantt');
#
#	Error cases:
#	composite (pie, histo) 
#
errors:
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Composite Error Test 1',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'compph',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
	);
	$img->setPoints(\@x, \@y2, 'pie red green blue yellow');
	$img->setPoints(\@x, \@y2, 'histo red green blue yellow');
	dump_img($img, 'png', 'compph');
#
#	composite (pie, pie)
#
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'COmposite Error Test 2',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'comppies',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP'
	);
	$img->setPoints(\@x, \@y2, 'pie red green blue yellow');
	$img->setPoints(\@x, \@y3, 'pie red green blue yellow');
	dump_img($img, 'png', 'comppies');
#
#	composite (pie, line)
#
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Composite Error Test 3',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'comppiel',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
	);
	$img->setPoints(\@x, \@y1, 'line newcolor fillcircle');
	$img->setPoints(\@x, \@y2, 'pie red green blue newcolor orange');
	dump_img($img, 'png', 'comppiel');
#
#	composite (box, bar)
#
	my $img = DBD::Chart::Plot->new(500, 500, \%colormap);
	$img->setOptions(
		xAxisLabel => 'Some Domain',
		yAxisLabel => 'Some Range',
		title => 'Composite Error Test 4',
		signature => '(C) 2002, GOWI Systems',
		genMap => 'compbxbar',
		mapURL => 'http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM',
		mapType => 'HTTP',
	);
	$img->setPoints(\@x, \@y1, 'bar red');
	$img->setPoints(\@x, 'box red');
	dump_img($img, 'png', 'compbxbar');

print HTMLF "</hmtl></body>\n";
close HTMLF;

sub numerically { $a <=> $b }

sub dump_img {
	my ($img, $fmt, $fname) = @_;
	open(OUTF, ">$fname.$fmt");
	binmode OUTF;
	print OUTF $img->plot($fmt);
	close OUTF;

	print HTMLF $img->getMap, "\n";
	1;
}

