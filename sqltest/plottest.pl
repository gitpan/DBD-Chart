use DBI;

use constant PI => 3.1415926;

$dbh = DBI->connect('dbi:Chart:');

$dbh->do("update colormap set redvalue=255, greenvalue=0, bluevalue=0
where name='red'");
$dbh->do("update colormap set redvalue=0, greenvalue=0, bluevalue=255
where name='blue'");
$dbh->do("insert into colormap values('newcolor', 124, 37, 97)");

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
<img src=iconhisto.png alt='iconhisto' usemap=#iconhisto><p>
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
<img src=denseline.png alt='denseline'><p>
<img src=densearea.png alt='densearea'><p>
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
	$dbh->do('create table simpline (x integer, y integer)');
	$sth = $dbh->prepare('insert into simpline values(?, ?)');
	for ($i = 0; $i <= $#x; $i++) {
		$sth->execute($x[$i], $y1[$i]);
	}
	$sth = $dbh->prepare("select linegraph, imagemap from simpline
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' and Y-AXIS='Some Range' AND
	TITLE='Linegraph Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	LOGO='gowilogo.png' AND FORMAT='PNG' AND SHOWGRID=1 AND
	MAPNAME='simpline' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML' AND COLOR=newcolor AND SHAPE=fillcircle");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'simpline');
	print "simpline OK\n";
#
#	simple scatter chart
#
simpscat:
	$sth = $dbh->prepare("select pointgraph, imagemap from simpline
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' and Y-AXIS='Some Range' AND
	TITLE='Scattergraph Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	LOGO='gowilogo.png' AND FORMAT='PNG' AND SHOWGRID=0 AND
	MAPNAME='simpscat' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML' AND SHOWVALUES=1");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'simpscat');
	print "simpscat OK\n";
#
#	simple area chart
#
simparea:
	$sth = $dbh->prepare("select areagraph, imagemap from simpline
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' and Y-AXIS='Some Range' AND
	TITLE='Areagraph Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	LOGO='gowilogo.png' AND FORMAT='PNG' AND SHOWGRID=1 AND
	MAPNAME='simparea' AND COLOR=newcolor AND
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML' AND SHOWVALUES=0");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'simparea');
	print "simparea OK\n";
#
#	simple linechart w/ sym domain and icons
#
symline:
	$dbh->do('create table symline (xdate varchar(20), y integer)');
	$sth = $dbh->prepare('insert into symline values(?, ?)');
	for ($i = 0; $i <= $#x; $i++) {
		$sth->execute($xdate[$i], $y1[$i]);
	}
	$sth = $dbh->prepare("select linegraph, imagemap from symline
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' and Y-AXIS='Some Range' AND
	TITLE='Symbolic Domain Linegraph Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	LOGO='gowilogo.png' AND FORMAT='PNG' AND SHOWGRID=1 AND
	MAPNAME='symline' AND
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML' AND COLOR=newcolor AND SHAPE=fillcircle");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'symline');
	print "symline OK\n";
#
#	simple bar chart
#
simpbar:
	$sth = $dbh->prepare("select barchart, imagemap from symline
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' and Y-AXIS='Some Range' AND
	TITLE='Barchart Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	FORMAT='PNG' AND SHOWVALUES=1 AND
	MAPNAME='simpbar' AND
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML' AND COLOR=newcolor");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'simpbar');
	print "simpbar OK\n";
#
#	simple bar chart w/ icons
#
iconbars:
	$sth = $dbh->prepare("select barchart, imagemap from symline
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' and Y-AXIS='Some Range' AND
	TITLE='Iconic Barchart Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	FORMAT='PNG' AND SHOWVALUES=1 AND ICON='pumpkin.png' AND
	MAPNAME='iconbars' AND SHOWGRID=1 AND GRIDCOLOR=blue AND
	TEXTCOLOR=dbrown AND
	MAPSCRIPT='ONCLICK=\"alert(''Got X=:X, Y=:Y'')\"' AND
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'iconbars');
	print "iconbars OK\n";
#
#	simple bar chart w/ icons
#
iconhisto:
	$sth = $dbh->prepare("select histogram, imagemap from symline
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' and 
	Y-AXIS='Some Range' AND
	TITLE='Iconic Histogram Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	FORMAT='PNG' AND ICON='pumpkin.png' AND
	MAPNAME='iconhisto' AND SHOWGRID=1 AND GRIDCOLOR=red AND
	TEXTCOLOR=newcolor AND
	MAPSCRIPT='ONCLICK=\"alert(''Got X=:X, Y=:Y'')\"' AND
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'iconhisto');
	print "iconhisto OK\n";
#
#	simple boxchart
#
simpbox:
	$dbh->do('create table simpbox (xbox integer, xbox2 integer)');
	$sth = $dbh->prepare('insert into simpbox values(?, ?)');
	for ($i = 0; $i <= $#xbox; $i++) {
		$sth->execute($xbox[$i], $xbox2[$i]);
	}
	$sth = $dbh->prepare("select boxchart, imagemap from simpbox
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' AND
	TITLE='Boxchart Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	FORMAT='PNG' AND COLORS=(newcolor, red) AND SHOWVALUES=1 AND
	MAPNAME='simpbox' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'simpbox');
	print "simpbox OK\n";
#
#	simple candlestick
#
simpcandle:
	$dbh->do('create table simpcandle (x integer, ylo integer, yhi integer)');
	$sth = $dbh->prepare('insert into simpcandle values(?, ?, ?)');
	for ($i = 0; $i <= $#x; $i++) {
		$sth->execute($x[$i], $y1[$i], $y2[$i]);
	}
	$sth = $dbh->prepare("select candlestick, imagemap from simpcandle
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' AND
	Y-AXIS = 'Price' AND
	TITLE='Candlestick Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	FORMAT='PNG' AND COLORS=(newcolor) AND SHAPE=fillsquare AND
	SHOWVALUES=1 AND SHOWGRID=1 AND
	MAPNAME='simpcandle' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'simpcandle');
	print "simpcandle OK\n";
#
#	simple pie chart
#
simppie:
	$dbh->do('create table simppie (x integer, y2 integer)');
	$sth = $dbh->prepare('insert into simppie values(?, ?)');
	for ($i = 0; $i <= $#x; $i++) {
		$sth->execute($x[$i], $y2[$i]);
	}
	$sth = $dbh->prepare("select piechart, imagemap from simppie
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' AND
	TITLE='Piechart Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	FORMAT='PNG' AND COLORS=(red, blue, newcolor, green, yellow) AND
	MAPNAME='simppie' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'simppie');
	print "simppie OK\n";
#
#	3-D pie chart
#
pie3d:
	$sth = $dbh->prepare("select piechart, imagemap from simppie
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' AND
	TITLE='3-D Piechart Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	FORMAT='PNG' AND COLORS=(red, blue, newcolor, green, yellow) AND
	3-D=1 AND
	MAPNAME='pie3d' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'pie3d');
	print "pie3d OK\n";
#
#	3-D barchart
#
bar3d:
	$sth = $dbh->prepare("select barchart, imagemap from simpline
	where WIDTH=500 AND HEIGHT=500 AND X-AXIS='Some Domain' AND
	Y-AXIS='Some Range' AND
	TITLE='3-D Barchart Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	FORMAT='PNG' AND COLORS=(orange) AND
	3-D=1 AND SHOWGRID=1 AND
	MAPNAME='bar3d' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'bar3d');
	print "bar3d OK\n";
#
#	3-axis bar chart
#
bar3axis:
	$dbh->do('create table bar3axis (Region varchar(10), Sales integer, Quarter CHAR(2))');
	$sth = $dbh->prepare('insert into bar3axis values(?, ?, ?)');
	for ($i = 0; $i <= $#x3d; $i++) {
		$sth->execute($x3d[$i], $y3d[$i], $z[$i]);
	}
	$sth = $dbh->prepare("select barchart, imagemap from bar3axis
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='3 Axis Barchart Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Region' AND Y-AXIS='Sales' AND Z-AXIS='Quarter' AND
	FORMAT='PNG' AND COLORS=(red) AND
	SHOWGRID=1 AND SHOWVALUES=1 AND
	MAPNAME='bar3axis' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'bar3axis');
	print "bar3axis OK\n";
#
#	simple histogram
#
simphisto:
	$sth = $dbh->prepare("select histogram, imagemap from simppie
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Histogram Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	FORMAT='PNG' AND COLOR=newcolor AND
	SHOWGRID=1 AND SHOWVALUES=1 AND
	MAPNAME='simphisto' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'simphisto');
	print "simphisto OK\n";
#
#	3-D histogram
#
histo3d:
	$sth = $dbh->prepare("select histogram, imagemap from simppie
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Histogram Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	FORMAT='PNG' AND COLOR=orange AND 3-D=1 AND
	SHOWGRID=1 AND SHOWVALUES=1 AND
	MAPNAME='histo3d' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'histo3d');
	print "histo3d OK\n";
#
#	3-axis histogram
#
histo3axis:
	$sth = $dbh->prepare("select histogram, imagemap from bar3axis
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='3 Axis Histogram Test' AND SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Region' AND Y-AXIS='Sales' AND Z-AXIS='Quarter' AND
	FORMAT='PNG' AND COLORS=(red) AND
	SHOWGRID=1 AND SHOWVALUES=1 AND
	MAPNAME='histo3axis' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'histo3axis');
	print "histo3axis OK\n";
#
#	linechart w/ temporal domain
#
templine:
	$dbh->do('create table templine (xdate date, y integer)');
	$sth = $dbh->prepare('insert into templine values(?, ?)');
	for ($i = 0; $i <= $#xdate; $i++) {
		$sth->execute($xdate[$i], $y1[$i]);
	}
	$sth = $dbh->prepare("select linegraph, imagemap from templine
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Temporal Domain Linegraph Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	X-ORIENT='VERTICAL' AND LOGO='gowilogo.png' AND
	FORMAT='PNG' AND COLORS=newcolor AND
	SHOWGRID=1 AND SHOWVALUES=1 AND
	MAPNAME='templine' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'templine');
	print "templine OK\n";
#
#	linechart w/ temporal domain and range
#
templine2:
	$dbh->do('create table templine2 (xdate date, y interval)');
	$sth = $dbh->prepare('insert into templine2 values(?, ?)');
	for ($i = 0; $i <= $#xdate; $i++) {
		$sth->execute($xdate[$i], $ytime[$i]);
	}
	$sth = $dbh->prepare("select linegraph, imagemap from templine2
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Temporal Range Linegraph Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	X-ORIENT='VERTICAL' AND LOGO='gowilogo.png' AND
	FORMAT='PNG' AND COLORS=newcolor AND
	SHOWGRID=1 AND SHOWVALUES=1 AND SHAPE=fillcircle AND
	MAPNAME='templine2' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'templine2');
	print "templine2 OK\n";
#
#	log linechart w/ temporal domain and range
#
logtempline:
	$dbh->do('create table logtempline (xdate date, y interval)');
	$sth = $dbh->prepare('insert into logtempline values(?, ?)');
	for ($i = 0; $i <= $#xdate2; $i++) {
		$sth->execute($xdate2[$i], $ytime2[$i]);
	}

	$sth = $dbh->prepare("select linegraph, imagemap from logtempline
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Logarithmic Temporal Range Linegraph Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	X-ORIENT='VERTICAL' AND Y-LOG=1 AND
	FORMAT='PNG' AND COLORS=newcolor AND
	SHOWGRID=1 AND SHOWVALUES=1 AND SHAPE=fillcircle AND
	MAPNAME='logtempline' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'logtempline');
	print "logtempline OK\n";
#
#	barchart w/ temp. domain
#
tempbar:
	$sth = $dbh->prepare("select barchart, imagemap from templine
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Temporal Barchart Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	FORMAT='PNG' AND COLORS=red AND
	SHOWVALUES=1 AND 
	MAPNAME='tempbar' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'tempbar');
	print "tempbar OK\n";
#
#	histo w/ temp domain
#
temphisto:
	$sth = $dbh->prepare("select histogram, imagemap from templine2
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Temporal Histogram Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	FORMAT='PNG' AND COLORS=blue AND
	SHOWVALUES=1 AND 
	MAPNAME='temphisto' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'temphisto');
	print "temphisto OK\n";
#
#	composite (line, scatter)
#
complinept:
	$sth = $dbh->prepare("select image, imagemap from
	(select linegraph from simpline
		where color=newcolor and shape=fillcircle) simpline,
	(select pointgraph from simppie
		where color=blue and shape=opensquare) simppt
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Composite Line/Pointgraph Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	FORMAT='PNG' AND 
	MAPNAME='complinept' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'complinept');
	print "complinept OK\n";
#
#	composite (area, line, scatter)
#
complpa:
	$dbh->do('create table complpa (x integer, y integer)');
	$sth = $dbh->prepare('insert into complpa values(?, ?)');
	for ($i = 0; $i <= $#x; $i++) {
		$sth->execute($x[$i], $y3[$i]);
	}
	$sth = $dbh->prepare("select image, imagemap from
	(select linegraph from simpline
		where color=newcolor and shape=fillcircle) simpline,
	(select pointgraph from simppie
		where color=blue and shape=opensquare) simppt,
	(select areagraph from complpa
		where color=red) simparea
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Composite Line/Point/Areagraph Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	FORMAT='PNG' AND 
	MAPNAME='complpa' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'complpa');
	print "complpa OK\n";
#
#	composite (area, bar, line, scatter)
#
compblpa:
	$sth = $dbh->prepare("select image, imagemap from
	(select linegraph from simpline
		where color=newcolor and shape=fillcircle) simpline,
	(select pointgraph from simppie
		where color=blue and shape=opensquare) simppt,
	(select areagraph from complpa
		where color=green) simparea,
	(select barchart from complpa
		where color=red) simpbar
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Composite Bar/Line/Point/Areagraph Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	FORMAT='PNG' AND 
	MAPNAME='compblpa' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'compblpa');
	print "compblpa OK\n";
#
#	composite (line, box)
#
complnbox:
	$dbh->do('drop table simpbox');
	$dbh->do('create table simpbox (x integer)');
	$sth = $dbh->prepare('insert into simpbox values(?)');
	for ($i = 0; $i <= $#xbox; $i++) {
		$sth->execute($xbox[$i]);
	}
	$dbh->do('create table complnbox (xfreq integer, yfreq integer)');
	$sth = $dbh->prepare('insert into complnbox values(?, ?)');
	for ($i = 0; $i <= $#xfreq; $i++) {
		$sth->execute($xfreq[$i], $yfreq[$i]);
	}
	$sth = $dbh->prepare("select image, imagemap from
	(select linegraph from complnbox
		where color=red and shape=fillcircle) simpline,
	(select boxchart from simpbox
		where color=newcolor) simpbox
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Composite Box and Line Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	FORMAT='PNG' AND 
	MAPNAME='complnbox' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'complnbox');
	print "complnbox OK\n";
#
#	composite (line, line, box, box)
#
compllbb:
	$dbh->do('create table simpbox2 (x integer)');
	$sth = $dbh->prepare('insert into simpbox2 values(?)');
	for ($i = 0; $i <= $#xbox2; $i++) {
		$sth->execute($xbox2[$i]);
	}
	$dbh->do('create table compllbb (xfreq2 integer, yfreq2 integer)');
	$sth = $dbh->prepare('insert into compllbb values(?, ?)');
	for ($i = 0; $i <= $#xfreq2; $i++) {
		$sth->execute($xfreq2[$i], $yfreq2[$i]);
	}
	$sth = $dbh->prepare("select image, imagemap from
	(select linegraph from complnbox
		where color=newcolor and shape=fillcircle) simpline,
	(select boxchart from simpbox
		where color=newcolor) simpbox,
	(select linegraph from compllbb
		where color=red and shape=fillcircle) simpline2,
	(select boxchart from simpbox2
		where color=red) simpbox2
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Composite Multiple Box and Line Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	FORMAT='PNG' AND 
	MAPNAME='compllbb' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'compllbb');
	print "compllbb OK\n";
#
#	composite (histo, histo)
#
comphisto:
	$sth = $dbh->prepare("select image, imagemap from
	(select histogram from simppie
		where color=red) histo1,
	(select histogram from complpa
		where color=blue) histo2
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Composite Histogram Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	FORMAT='PNG' AND 3-D=1 AND SHOWVALUES = 1 AND
	MAPNAME='comphisto' AND 
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'comphisto');
	print "comphisto OK\n";
#
#	composite (bar, bar, bar)
#
compbars:
	$sth = $dbh->prepare("select image, imagemap from
	(select barchart from simppie
		where color=red) bars1,
	(select barchart from complpa
		where color=blue) bars2
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Composite Barchart Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Some Domain' AND Y-AXIS='Some Range' AND
	FORMAT='PNG' AND SHOWVALUES = 1 AND SHOWGRID=1 AND
	MAPNAME='compbars' AND ICONS=('pumpkin.png', 'turkey.png' ) AND
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'compbars');
	print "compbars OK\n";
#
#	dense numeric graph (sin/cos)
denseline:
	$dbh->do('create table densesin (angle float, sine float)');
	$dbh->do('create table densecos (angle float, cosine float)');
	$sth = $dbh->prepare('insert into densesin values(?,?)');
	$sth2 = $dbh->prepare('insert into densecos values(?,?)');
	for ($i = 0; $i < 4*PI; $i += (PI/180)) {
		$sth->execute($i, sin($i));
		$sth2->execute($i, cos($i));
	}
	$sth = $dbh->prepare("select image, imagemap from
	(select linegraph from densesin
		where color=red) densesin,
	(select linegraph from densecos
		where color=blue) densecos
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Composite Dense Linegraph Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Angle (Radians)' AND Y-AXIS='Sin/Cos' AND
	FORMAT='PNG'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'denseline', 1);
	print "denseline OK\n";

densearea:
	$sth = $dbh->prepare("select image, imagemap from
	(select areagraph from densesin
		where color=red) densesin,
	(select areagraph from densecos
		where color=blue) densecos
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Composite Dense Areagraph Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Angle (Radians)' AND Y-AXIS='Sin/Cos' AND
	FORMAT='PNG'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'densearea', 1);
	print "densearea OK\n";

simpgantt:
my @tasks = ( 'First task', '2nd Task', '3rd task', 'Another task', 'Final task');
my @starts = ( '2002-01-24', '2002-02-01', '2002-02-14', '2002-01-27', '2002-03-28');
my @ends = ( '2002-01-31', '2002-02-25', '2002-03-10', '2002-02-27', '2002-04-15');
my @assigned = ( 'DAA',       'DWE',       'SAM',       'KPD',        'WLA');
my @pct = (     25,            37,         0,          0,              0 );
my @depends = ( '3rd task',  'Final task', undef,    '2nd task',  undef);

	$dbh->do('create table simpgantt (task varchar(30),
		starts date, ends date, assignee varchar(3), pctcomplete integer, 
		dependent varchar(30))');
	$sth = $dbh->prepare('insert into simpgantt values(?,?,?,?,?,?)');
	for ($i = 0; $i <= $#tasks; $i++) {
		$sth->execute($tasks[$i], $starts[$i], $ends[$i], $assigned[$i],
			$pct[$i], $depends[$i]);
	}

	$sth = $dbh->prepare("select gantt, imagemap from simpgantt
	where WIDTH=500 AND HEIGHT=500 AND 
	TITLE='Simple Gantt Chart Test' AND 
	SIGNATURE='(C)2002, GOWI Systems' AND
	X-AXIS='Tasks' AND Y-AXIS='Schedule' AND
	COLOR=red AND LOGO='gowilogo.png' AND
	MAPNAME='simpgantt' AND
	MAPURL='http://www.gowi.com/cgi-bin/sample.pl?x=:X&y=:Y&z=:Z&plotno=:PLOTNUM'
	AND MAPTYPE='HTML' AND
	X-ORIENT='VERTICAL' AND
	FORMAT='PNG'");
	$sth->execute;
	$row = $sth->fetchrow_arrayref;
	dump_img($row, 'png', 'simpgantt');
	print "simpgantt OK\n";

print HTMLF "</hmtl></body>\n";
close HTMLF;

sub numerically { $a <=> $b }

sub dump_img {
	my ($row, $fmt, $fname, $nomap) = @_;
	open(OUTF, ">$fname.$fmt");
	binmode OUTF;
	print OUTF $$row[0];
	close OUTF;

	print HTMLF $$row[1], "\n" unless $nomap;
	1;
}

