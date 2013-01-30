<?php 
include_once "phpdefaults.php"; 
require_once "Auth/Auth.php";
//require_once "DB.php";

// 14 Jul 2006 : GWA : Naming the session preserves logins across browser
//               restarts.  This has always annoyed me.

$params = array(
  "dsn" => $_DSN,
  "sessionName" => "motelabAUTH");
$a = new Auth("DB", $params, "", false);
$a->setLoginCallback("importSessionVariables");
$a->start();

if ($_GET['logout'] == true) {
  $a->logout();
}

// 29 Oct 2003 : GWA : We need database access _everywhere_, so we're just
//               going to put this in here so that we don't have to worry
//               about it in the code.

if ($a->getAuth()) {
  $DB = startDB();
}

if (($_POST['newUserID'] != '') &&
    (getSessionVariable('origtype') == 'admin')) {
  doSuperUserBecome($_POST['newUserID']);
}

global $_STYLESHEET;

// 18 Oct 2003 : GWA : Adding this to support redirect for viewing data
//               files.  Otherwise the headers get sent here and we can't
//               later modify them.

if (!$_GET['redirect']) {
?>

<head>
  <title><?php echo $_WWWROOT; echo $_SERVER['PHP_SELF'];?></title>
</head>
<link type="text/css" rel="stylesheet" href="<?php echo $_STYLESHEET;?>">
<body>
  <div id="content">
    <?php
      global $a;
      include "title.php"; ?>
    <div id="menu"> <?php 
      global $_DISPLAYLOGIN;
      if (!isset($_DISPLAYLOGIN)) {
        $_DISPLAYLOGIN = true;
      }
      if (!$a->getAuth() && $_DISPLAYLOGIN) {
        include "menulogin.php";
      } else {
        global $_DISPLAYMOTD;
        if ($_DISPLAYMOTD) {
          include "menumotd.php";
        }
      } 
      global $_DISPLAYNEW;
      if ($_DISPLAYNEW) {
        include "menuwhatsnew.php";
      } ?>
  </div>
  <?php if (($a->getAuth()) &&
            (getSessionVariable('origtype') == 'admin')) { 
    if (getSessionVariable('id') != getSessionVariable('origid')) { ?>
      <p class=error>
        Now masquerading as <?php echo getSessionVariable('username'); ?>.
        Please be careful!
      </p>
    <?php }
    $allUsersQuery = "select id, username from " . $_SESSIONTABLENAME .
                     " order by username";
    $allUsersResult = doDBQuery($allUsersQuery);
    ?>
    <form name=superUserAccessForm method=post
          action=<?php echo $_SERVER['PHP_SELF']; ?>>
      Become user:
      <select name=newUserID>
      <?php 
      while ($allUserRef = $allUsersResult->fetchRow(DB_FETCHMODE_ASSOC)) {
        ?>
        <option value=<?php echo $allUserRef['id'];?>>
          <?php echo $allUserRef['username']; ?>
        </option>
        <?php } ?>
      </select>
      <input type=submit value="Change User">
      <?php if (getSessionVariable('id') != getSessionVariable('origid')) { ?>
        <input type=button value="Return"
               onClick="this.form.newUserID.value=<?php
                 echo getSessionVariable('origid');?>;
                 this.form.submit();">
      <?php } ?>
    </form>
  <?php } ?>
<?php } ?>
