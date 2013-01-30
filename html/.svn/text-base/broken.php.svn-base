<?php 
  global $_DISPLAYNEW;
  $_DISPLAYNEW = true;
  global $_DISPLAYMOTD;
  $_DISPLAYMOTD = true;
  include "nav/broken_top.php" ?>

<p>

<center>
<font style="font-size:36px;color:red">
  <strong>MOTELAB IS DOWN</strong>
</font>
</center>
<p>
Please bear with us while we perform necessary maintenance.
<hr>
<p>

<font style="font-size:18px;" color="#800000">
  <strong>MoteLab</strong>
</font>
is a experimental wireless sensor network deployed in 
<a href="http://www.deas.harvard.edu/aboutdeas/ourcampus/deasbuildsandmaps/maxwelldworkin/">
Maxwell Dworkin Laboratory</a>, 
the <a href="http://www.eecs.harvard.edu">
Electrical Engineering and Computer Science</a> building at 
<a href="http://www.harvard.edu">Harvard University</a>.
MoteLab provides a public, permanent testbed for development and testing of
sensor network applications via an intuitive web-based interface.  Registered
users can upload executables, associate those executables with motes to
create a job, and schedule the job to be run on MoteLab.  
During the job all messages and other data are logged to a database which is
presented to the user upon job completion and then can be used for processing
and visualization.  
In addition, simple visualization tools are provided via the
web interface for viewing data while the job is running. 
MoteLab wil facilitate research in sensor network programming environments,
communication protocols, system design, and applications. 

<p>
<font style="font-size:18px;" color="#800000">
  <strong>Hardware</strong>
</font>
<br>
<a href="img/tmote.jpg"><img src="img/tmote.jpg" align=left></a>
We have deployed 190
<a
href="http://www.moteiv.com/products.php">
TMote Sky</a>
sensor "motes", which consist of an TI MSP430 processor running at
8MHz, 10KB of RAM, 1Mbit of Flash memory and a Chipcon CC2420
radio operating at 2.4GHz with an indoor range of approximately 100 meters.
Each node includes sensors for light, temperature, and humidity.

<p>
Each mote is powered from wall power (rather than batteries) and is
connected to the departmental Ethernet, which facilitates direct capture
of data and uploading of new programs. The Ethernet connection is used
as a debugging and reprogramming feature only, as nodes will generally
communicate via radio.


<p>
<font style="font-size:18px;" color="#800000">
  <strong>Software</strong>
</font>
<br>
Nodes run the <a href="http://www.tinyos.net">TinyOS</a> operating
system and are programmed in the 

<a href="http://nescc.sourceforge.net">NesC</a> programming language, a
component-oriented variant of C. Typically, you will be able to
prototype your application either using the
<a
href="http://www.cs.berkeley.edu/~pal/research/tossim.html">TOSSIM</a>
simulation environment or wiht a handful of motes on your desktop. 
You then use the MoteLab web interface to upload your program to the
building-wide network.

<?php 
  include "nav/broken_bot.php" 
?>
