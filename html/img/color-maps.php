<?php
/*
 * color-maps.php
 *
 * INPUTS: Maps in img/maps dir, info about mote location in tables.
 *
 * OUTPUTS: Maps with mote locations marked.
 *
 * GOES: Nowhere!
 *
 * CREATED: 19 Apr 2004
 *
 * AUTHOR: GWA
 */
  include_once "../nav/sitespecific.php";
  include_once "../nav/phpdefaults.php";
  header("Content-type: image/png");
  $floor = $_GET['floor'];
  if (isset($_GET['small'])) {
    $small = true;
  } else {
    $small = false;
  }

  if (isset($_GET['motes']) && trim($_GET['motes']) != "") {
    $moteSet = explode(",", $_GET['motes']);
  } else {
    $allMotes = true;
  }
  
  $_ARROWANGLE = deg2rad(20);
  $_ARROWLENGTH = 10;
  $_OUTRADIUS = 10;
  $_OUTANGLE = deg2rad(30);

  //    Jun 2004 : swies : Caching turned off b/c of dynamic maps.
  //
  // 20 Apr 2004 : GWA : We put output maps in the cache.  Currently we only
  //               output at full res and let the browser scale the smaller
  //               images.  This is kind of slow at least in Mozilla, so it
  //               may be changed when I get annoyed enougb by it.

  function drawArrow($im, $x1, $y1, $x2, $y2, $color) {
    global $_ARROWANGLE;
    global $_ARROWLENGTH;
    $angle = atan2($y2 - $y1, $x2 - $x1) + M_PI;
    $x3 = $x2 + cos($angle - $_ARROWANGLE) * $_ARROWLENGTH;
    $y3 = $y2 + sin($angle - $_ARROWANGLE) * $_ARROWLENGTH;
    $x4 = $x2 + cos($angle + $_ARROWANGLE) * $_ARROWLENGTH;
    $y4 = $y2 + sin($angle + $_ARROWANGLE) * $_ARROWLENGTH;
    $drawArray = array($x2, $y2, $x3, $y3, $x4, $y4);
    imagefilledpolygon($im, $drawArray, 3, $color);
  }
  
  function writeNumber ($im, $x, $y, $angle, $color, $text) {
    $_DOWNTEXTPUSH = 50;
    $_UPTEXTPUSH = -20;
    if ($angle < (M_PI / 2)) {
      $x1 = $x - (cos($angle) * $_UPTEXTPUSH);
      $y1 = $y + (sin($angle) * $_UPTEXTPUSH);
    } else {
      $angle -= M_PI;
      $x1 = $x - (cos($angle) * $_DOWNTEXTPUSH);
      $y1 = $y + (sin($angle) * $_DOWNTEXTPUSH);
    }
    $color = imagecolorallocate($im, 0, 0, 0);
    imagettftext($im, 10, rad2deg($angle),
                $x1,
                $y1,
                $color, 
                "TIMESBD.TTF",
                $text);
  }

  function drawToFrom($im, $x1, $y1, $x2, $y2, $color, $number) {
    global $_OUTANGLE;
    global $_OUTRADIUS;
    // 16 Jul 2006 : GWA : I'm too lazy to figure out why disabled motes are
    //               being drawn with a link to (0,0), so I'll just turn it
    //               off here.  There's definitely no mote at (0,0) so this
    //               is obviously wrong.

    if (($x2 == 0) && ($y2 == 0)) {
      return;
    } else if (($x1 == 0) && ($x2 == 0)) {
      return;
    }

    $angle = atan2($y2 - $y1, $x2 - $x1);
    $x3 = (cos ($angle + $_OUTANGLE) * $_OUTRADIUS) + $x1; 
    $y3 = (sin ($angle + $_OUTANGLE) * $_OUTRADIUS) + $y1;
    $x4 = (cos ($angle + M_PI - $_OUTANGLE) * $_OUTRADIUS) + $x2;
    $y4 = (sin ($angle + M_PI - $_OUTANGLE) * $_OUTRADIUS) + $y2;
    imageline($im, $x3, $y3, $x4, $y4, $color); 
    $x5 = ($x3 + $x4) / 2;
    $y5 = ($y3 + $y4) / 2;
    if ($y4 > $y3) {
    $angle = M_PI - atan2($y4 - $y3, $x4 - $x3);
    } else {
    $angle = M_PI - atan2($y3 - $y4, $x3 - $x4);
    }
    drawArrow($im, $x3, $y3, $x5, $y5, $color);
  }
  
  $im = imagecreatefrompng("maps/" . $floor . ".png");
  $blue = imagecolorallocate($im, 0, 0, 255);
  $red = imagecolorallocate($im, 255, 0, 0);
  $black = imagecolorallocate($im, 0, 0, 0);
  $white = imagecolorallocate($im, 255, 255, 255);
  $lightgrey = imagecolorallocate($im, 230, 230, 230);
  $lightblue = imagecolorallocate($im, 200, 200, 255);
  $lightred = imagecolorallocate($im, 255, 200, 200);
  $lightblack = imagecolorallocate($im, 100, 100, 100);

  $DB = startDB();
  $motes = array();
  $onFloorQuery = "select moteid, pixelx, pixely, active, floor from " .
                  $_MOTESTABLENAME;
                  #" where floor=" . $floor;
  $motes = doDBQueryAssoc($onFloorQuery);
  /* Ensure that $moteSet is valid */
  $floorArray = array();
  if (!is_array($moteSet)) {
    $moteSet = array();
    while (list($moteid, $moteinfo) = each($motes)) {
      $moteSet = array_merge($moteSet, array($moteid));
      $floorArray[$moteid] = $moteinfo[3];
    }
  } else {
    while (list($moteid, $moteinfo) = each($motes)) {
      $floorArray[$moteid] = $moteinfo[3];
    }
  }

  /* Make sure we're drawing all motes in our set, regardless of connections */
  $drawMotes = array(); 
  foreach ($moteSet as $moteid) {
    $drawMotes[$moteid] = 1;
  }
 
  $connect = array();
  $finalConnectInfo = array();
  $connectQuery = "select moteid, linkquality, floor from " .
                  $_MOTESTABLENAME;
                  #" where floor=" . $floor;
  $connect = doDBQueryAssoc($connectQuery);

  while (list($moteid, $connectinfo) = each($connect)) {
    $innerSplit = array();
    $innerSplit = explode("|", $connectinfo[0]);
    $finalConnectInfo[$moteid] = array(); 
    foreach ($innerSplit as $currentInner) {
      $innerElement = sscanf($currentInner, "( %d, %f, %f )");
      if (($floorArray[$moteid] == $floor) ||
          ($floorArray[$innerElement[0]] == $floor)) {
        if (count($moteSet) == 1) {
          if (in_array($moteid, $moteSet)) {
            $finalConnectInfo[$moteid][$innerElement[0]] = $innerElement[1];
            $drawMotes[$innerElement[0]] = 1;
            $drawMotes[$moteid] = 1;
          } else if (in_array($innerElement[0], $moteSet)) {
            $finalConnectInfo[$moteid][$innerElement[0]] = $innerElement[1];
            $drawMotes[$innerElement[0]] = 1;
            $drawMotes[$moteid] = 1;
          }
        } else {
          if (in_array($moteid, $moteSet) &&
              in_array($innerElement[0], $moteSet)) {
            $finalConnectInfo[$moteid][$innerElement[0]] = $innerElement[1];
            $drawMotes[$innerElement[0]] = 1;
            $drawMotes[$moteid] = 1;
          }
        }
      }
    }
  }

  $motes = array();
  $onFloorQuery = "select moteid, pixelx, pixely, active, linkquality, floor"
                  . " from " . $_MOTESTABLENAME;
                  
  $motes = doDBQueryAssoc($onFloorQuery);
  while (list($moteid, $moteinfo) = each($motes)) {
    if ($drawMotes[$moteid] != 1) {
      continue;
    }
    // 01 Sep 2004: swies: distinguish between disabled and broken motes
    $color = $blue;
    if ($moteinfo[3] == "") {
      $color = $red;
    }
    if ($moteinfo[2] == 0) {
      $color = $black;
    }
    if ($moteinfo[4] != $floor) {
      if ($color == $red) {
        $color = $lightred;
      } else if ($color == $blue) {
        $color = $lightblue;
      } else if ($color == $black) {
        $color = $lightblack;
      }
    }

    # MDW: 22-Feb-06: Various changes here to make the layout look
    # good with the TelosLab setup.
    if ($moteid % 2 == 0) {
      $moteinfo[0] = $moteinfo[0] + 10;
    }
    imagefilledellipse($im, $moteinfo[0], $moteinfo[1], 20, 20, $color);
    imagefilledellipse($im, $moteinfo[0], $moteinfo[1], 18, 18, $lightgrey);
    if ($moteid > 0 && $moteid < 10) {
      imagettftext($im, 8, 0,
                  $moteinfo[0] - 3,
                  $moteinfo[1] + 4,
                  $color, 
                  getcwd() . "/TIMESBD.TTF",
                  $moteid);
    } else if ($moteid >= 10 && $moteid < 100) {
      imagettftext($im, 8, 0,
                  $moteinfo[0] - 5,
                  $moteinfo[1] + 4,
                  $color, 
                  getcwd() . "/TIMESBD.TTF",
                  $moteid);
    } else {
      imagettftext($im, 8, 0,
                  $moteinfo[0] - 7,
                  $moteinfo[1] + 4,
                  $color, 
                  getcwd() . "/TIMESBD.TTF",
                  $moteid);
    }
  }
 
  while (list($moteid, $connectinfo) = each($finalConnectInfo)) {
    if (is_array($moteSet) && count($moteSet) > 1 && !in_array($moteid, $moteSet))
      continue;
    while (list($tomoteid, $lineweight) = each($connectinfo)) {
      if ($moteid == $tomoteid) {
        continue;
      }
      $red = $blue = $green = 0;
      if ($lineweight <= 0.33) {
        $red = ($lineweight * 3) * 255;
      } else if ($lineweight <= 0.67) {
        $red = 255;
        $green = (($lineweight - 0.34) * 3) * 255;
      } else {
        $green = 255;
        $red = 255 - ((($lineweight - 0.67) * 3) * 255);
      }
      $prettyWeight = sprintf("%.3f", $lineweight);
      $linecolor = imagecolorallocate($im, $red, $green, $blue);
      drawToFrom($im, $motes[$moteid][0], $motes[$moteid][1],
                 $motes[$tomoteid][0], $motes[$tomoteid][1], 
                 $linecolor, $prettyWeight);
    }
  }

  $DB->disconnect();
 
  // 14 Jul 2006 : GWA : Only want to cache maps with all the mote data on
  //               them.

  imagepng($im);
  imagedestroy($im);
?>
