NAME
    DBD::Chart::Plot - Two dimensional plotting engine for
    DBD::Chart

SYNOPSIS
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

DESCRIPTION
    DBD::Chart::Plot creates images of line and scatter graphs for
    two dimensional data. Unlike GD::Graph, the input data sets do
    not need to be uniformly distributed in the domain (X-axis).

    DBD::Chart::Plot supports the following:

    - multiple data set plots
    - line graphs, areagraphs, scatter graphs, linegraphs w/ points, 
            and candlestick graphs
    - a wide selection of colors, and point shapes
    - optional horizontal and/or vertical gridlines
    - optional legend
    - auto-sizing of axes based in input dataset ranges
    - automatic sorting of numeric input datasets to assure 
            proper order of plotting
    - optional symbolic (i.e., non-numeric) domain values
    - optional X and Y axis labels
    - optional X and/or Y logarithmic scaling
    - optional title
    - optional adjustment of horizontal and vertical margins
PREREQUISITES
    GD.pm module minimum version 1.26 (available on CPAN)
        GD.pm requires additional libraries:

    libgd
    libpng
    zlib
USAGE
  Create an image object: new()

            use DBD::Chart::Plot; 

            my $img = DBD::Chart::Plot->new; 
            my $img = DBD::Chart::Plot->new ( $image_width, $image_height ); 
            my $anotherImg = new DBD::Chart::Plot; 

        Creates an empty image. If image size is not specified, the
        default is 400 x 300 pixels.

  Establish data points: setPoints()

            $img->setPoints(\@xdata, \@ydata);
            $img->setPoints(\@xdata, \@ydata, 'blue line');
            $img->setPoints(\@xdata, \@ymindata, \@ymaxdata, 'blue points');

        Copies the input array values for later plotting. May be
        called repeatedly to establish multiple plots in a single
        graph. Returns a postive integer on success and `undef' on
        failure. The error() method can be used to retrieve an error
        message. X-axis values may be non-numeric, in which case the
        set of domain values is uniformly distributed along the X-
        axis. Numeric X-axis data will be properly scaled, including
        logarithmic scaling is requested.

        If two sets of range data (ymindata and ymaxdata in the
        example above) are supplied, a candlestick graph is
        rendered, in which case the domain data is assumed non-
        numeric and is uniformly distributed, the first range data
        array is used as the bottom value, and the second range data
        array is used as the top value of each candlestick.
        Pointshapes may be specified, in which case the top and
        bottom of each stick will be capped with the specified
        pointshape. The range axis may be logarithmically scaled. If
        value display is requested, the range value of both the top
        and bottom of each stick will be printed above and below the
        stick, respectively.

        Plot properties: Properties of each dataset plot can be set
        with an optional string as the third argument. Properties
        are separated by spaces. The following properties may be set
        on a per-plot basis (defaults in capitals):

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

        E.g., if you want a red scatter plot (red dots but no lines)
        with filled diamonds, you could specify

            $p->setPoints (\@xdata, \@ydata, 'Points Noline Red filldiamond');

  Graph-wide options: setOptions()

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
        centered in the margin space below the graph. The Y axis
        label will be left justified above the Y axis; the X axis
        label will be placed below the right end of the X axis.

        By default, the graph will be centered within the image,
        with 50 pixel margin around the graph border. You can obtain
        more space for titles or labels by increasing the image size
        or increasing the margin values.

        By default, no grid lines are drawn either horizontally or
        vertically. By setting horizGrid or vertGrid to a non-zero
        value, grid lines will be drawn across or up/down the chart,
        respectively, from the established Y-axis or X-axis ticks.
        Both options may be enabled in a single chart.

        By default, the (x, y) values are not explicitly printed on
        the chart; setting showValues to a non-zero value will cause
        the plot point values to be printed in the gdTinyFont,
        centered just above the plotted point.

        By default, both the X and Y axes are linearly scaled;
        logarithmic (base 10) scaling can be specified for either
        axis by setting either 'xLog' or 'yLog', or both, to non-
        zero values.

        A legend can be displayed below the chart, left justified
        and placed above the chart title string, by setting the
        'legend' option to an array containing the labels for each
        plot on the chart, in the same order as the datasets are
        assigned (i.e., label 0 applies to the 1st setPoints(),
        label 1 applies to the 2nd setPoints(), etc.). The legend
        for each plot is printed in the same color as the plot. If a
        point shape has been specified for a plot, then the point
        shape is printed with the label; otherwise, a small line
        segment is printed with the label. Due to space limitations,
        the number of datasets plotted should be limited to 8 or
        less.

        Domain values are assumed to be numeric (except for
        candlestick graphs) and may be non-uniformly distributed. If
        a symbolic domain is desired, the 'symDomain' option can be
        set to a non-zero value, in which case the domain dataset is
        uniformly distributed along the X-axis in the same order as
        the domain dataset array.

  Draw the image: plot()

             $img->plot();

        Draws the image and returns it as a string. To save the
        image to a file:

            open (WR,'>plot.png') or die ("Failed to write file: $!");
            binmode WR;            # for DOSish platforms
            print WR $img->plot();
            close WR;

        To return the graph to a browser via HTTP:

            print "Content-type: image/png\n\n";
            print  $img->plot();

        The range of values on each axis is automatically computed
        to optimize the data placement in the largest possible area
        of the image. As a result, the origin (0, 0) axes may be
        omitted if none of the datasets do not cross them at any
        point. Instead, the axes will be drawn on the left and
        bottom borders using the value ranges that appropriately fit
        the dataset(s).

BUGS AND TO DO
    improved fonts and value display
    3-axis barcharts
    surfacemaps
AUTHOR
        Copyright (c) 2001 by Dean Arnold <darnold@earthlink.net>.

        You may distribute this module under the terms of either the
        GNU General Public License or the Artistic License, as
        specified in the Perl README file.

SEE ALSO
        GD::Graph(1), Chart(1), DBD::Chart. (All available on CPAN).

