<?php include_once "phpdefaults.php"; 

global $_STYLESHEET;

// 18 Oct 2003 : GWA : Adding this to support redirect for viewing data
//               files.  Otherwise the headers get sent here and we can't
//               later modify them.

?>

<head>
  <title><?php echo $_WWWROOT; echo $_SERVER['PHP_SELF'];?></title>
</head>
<link type="text/css" rel="stylesheet" href="<?php echo $_STYLESHEET;?>">
<body>
  <div id="content">
    <?php
      global $a; ?>
<div id="title">
  <div id="titleimage">
    <a href="index.php">
    <img src="img/logo.png" height=60px width=187px border=0>
    </a>
  </div>
  <div id="titletop">
  <div id="titlemain" class="titleelementleft">
    <a href="index.php" style="text-decoration:none;">
      <font color=#800000> Harvard Sensor Network Testbed </font>
    </a>
  </div>
  </div>
  </div>
