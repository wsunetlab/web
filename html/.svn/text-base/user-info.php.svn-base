<?php 
  global $_DISPLAYNEW;
  $_DISPLAYNEW = false;
  global $_DISPLAYMOTD;
  $_DISPLAYMOTD = false;

  include "nav/default_top.php";

  /*
   * user-info.php
   *
   */
?>

<?php
global $a;
if ($a->getAuth()) {

  $userName = getSessionVariable("username");
  $userID = getSessionVariable("id");

  if ($_POST['doReset']) {
    list($doNewPass, $unused) = explode("@", $userName);
  } else {
    $doNewPass = $_POST['newPass'];
  }

  if (doReloadProtect()) {
    $doNewPass = "";
  }

  if ($doNewPass != "") {
    
    $oldPass = $_POST['oldPass'];
    $newPass = $_POST['newPass'];
    $dbUserName = getSessionVariable("dbname");
    $error = 0;
    
    // 27 Oct 2003 : GWA : Skip checks when user is resetting their password.

    if (!$_POST['doReset']) {
      if (!$error && 
          ($newPass != $_POST['newPass2'])) { ?>
        <p style="color:red;">
          The two passwords you provided do not match.  Please try again.
        </p>
        <?php $error = 1;
      }

      // 20 Oct 2003 : GWA : Grab hash of old password.

      if (!$error) {
        
        $passwordQuery = "select password from " . $_SESSIONTABLENAME . 
                         " where username=\"" . $userName . "\"";
        $passwordResult = doDBQuery($passwordQuery);
        $passwordRef = $passwordResult->fetchrow(DB_FETCHMODE_ASSOC);
        $oldSavedPass = $passwordRef['password'];
        
        // 20 Oct 2003 : GWA : Check and see if old passwords match.
        
        if ($oldSavedPass != MD5($oldPass)) { ?>
          <p class=error>
            Incorrect password.
          </p>
          <?php $error = 1;
        }
      }
    } else {
      $newPass = $doNewPass;
    }

    // 20 Oct 2003 : GWA : Set new password.

    if (!$error) {

      $passwordUpdate = "update " . $_SESSIONTABLENAME .
                        " set password=\"" . MD5($newPass) . "\"" .
                        " where username=\"" . $userName . "\"";
      $passwordResult = doDBQuery($passwordUpdate);
      
      // 27 Oct 2003 : GWA : Have to update it in the database as well.
      
      $dbPasswordUpdate = "update " . $_MYSQLTABLENAME .
                          " set Password=PASSWORD(\"" .$newPass . "\")" . 
                          " where User=\"" . $dbUserName . "\"";
      $dbPasswordResult = doDBQuery($dbPasswordUpdate);
      $dbPasswordFlush = "flush privileges";
      $dbPasswordFlushResult = doDBQuery($dbPasswordFlush);
      
      if (!$_POST['doReset']) { ?>
        <p style="color:green;">
          You have successfully changed your password.  You can use the new
          password next time you log in.
        </p>
      <?php } else { ?>
        <p style="color:green;">
          You have successfully reset your password.  It is now the user
          portion of the email address you use as your user name.  Please
          change it as soon as possible.
        </p>
    <?php }
    }
  } ?>
  <?php 
  $userInfoQuery = "select * from " . $_SESSIONTABLENAME . 
                   " where id=" . $userID;
  $userInfoResult = doDBQuery($userInfoQuery);
  $userInfoRef = $userInfoResult->fetchRow(DB_FETCHMODE_ASSOC);
  ?>
  <p>
    <span style="color:blue;"> 
      MoteLab User Name 
    </span> 
    : <?php echo $userInfoRef['username']; ?>
    <br>
    <span style="color:blue;"> 
      MoteLab User Class
    </span> 
    : <?php echo $userInfoRef['type']; ?>
    <br>
    <?php if ($userInfoRef['type'] != "admin") { ?>
      <span style="color:blue;"> 
        MoteLab Quota/Used
      </span> 
      : <?php echo $userInfoRef['quota'];?>
      / <?php echo $userInfoRef['used'];?>
      <br>
    <?php } ?>
    <span style="color:blue;"> 
      MoteLab Database Name/Handle
    </span> 
    : <?php echo $userInfoRef['dbname']; ?>
  </p>
  <p>
    To connect to the MySQL database running on motelab.eecs.harvard.edu,
    try something like this:<br><br>
    <code>
    mysql -h motelab.eecs.harvard.edu -u <?php echo $userInfoRef['dbname'];?> -p
    </code><br><br>
    Note that your MoteLab database name is <em>not</em> necessarily the same
    as the user portion of the email address that is your MoteLab username.
    At the prompt enter your password, and then type:<br><br>
    <code>
    use <?php echo $userInfoRef['dbname'];?>;
    </code><br><br>
    This will take you to your database.  Typing:<br><br>
    <code>
    show tables;
    </code><br><br>
    Will show a list of the tables where motelab has stored your data.  The
    table names have the following format:<br><br>
    <code>
    JobName_UniqueRunID_ClassID
    </code><br><br>
    From there, you're on your own!
  <hr>
  <p>
    You can access a mote's serial forwarder through a TCP connection to
    motelab.  The port number is 20000 plus the mote ID number.  So to talk
    with mote 3, you would connect to port 20003 on motelab.
  </p>
  <hr>
  <p>
    You can change your password here.
    <br> 
    Please do not use a particularly important password.
  </p>
  <form name=changePassword method=post action="user-info.php">
    <input type=hidden name=doReset value=0>
    Old Password : <br>
    <input type=password name="oldPass" style="width:20em;">
    <br>
    New Password : <br>
    <input type=password name="newPass" style="width:20em;">
    <br>
    New Password (repeat) : <br>
    <input type=password name="newPass2" style="width:20em;">
    <br>
    <input type=button value="Change password"
           onClick="this.form.doReset.value=0; this.form.submit();">
    <input type=button value="Reset password"
           onClick="this.form.doReset.value=1; this.form.submit();">
    <input type=hidden name=ReloadProtect value=<?php echo time(); ?>>
    </form>
<?php }  else { ?>
  <p> You cannot edit your user info until you log in.
<?php } ?>
<?php 
  include "nav/default_bot.php";
?>
