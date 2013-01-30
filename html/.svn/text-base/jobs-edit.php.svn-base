<?php 
  global $_DISPLAYNEW;
  $_DISPLAYNEW = false;
  global $_DISPLAYMOTD;
  $_DISPLAYMOTD = false;

  include "nav/default_top.php";

  /*
   * jobs-edit.php
   *
   */

?>

<?php
global $a;
if ($a->getAuth()) {

  // 04 Sep 2003 : GWA : First, grab jobs from the database.
  
  $user = getSessionVariable("username");

  $ourDB = DB::Connect($_DSN);
  if (DB::isError($ourDB)) {
    die($ourDB->GetMessage());
  }
  
  $jobQuery = "select name, id from " .
              $_JOBSTABLENAME . 
              " where owner=\"" . $user . "\"";
  $jobResult = $ourDB->query($jobQuery);
  
  if (DB::isError($fileResult)) {
    die($jobResult->getMessage());
  } ?>

  <?php
  // 04 Sep 2003 : GWA : Just a simple form selecting jobs that this user has
  //               access to.
  ?>
  
  <form method="get" action="jobs-create.php">
    <select name=jobid size=16 style="width:20em;">
    <?php while ($row = $jobResult->fetchRow(DB_FETCHMODE_ASSOC)) { ?>
      <option value=<?php echo $row['id'];?>>
        <?php echo $row['name'];?>
      </option>
    <?php } ?>
    </select>
    <input type=submit value="Edit Job">
  </form>
<?php } else { ?>
  <p> You cannot edit jobs until you log in.
<?php } ?>

<?php 
  include "nav/default_bot.php";
?>
