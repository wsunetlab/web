<?php 
  global $_DISPLAYNEW;
  $_DISPLAYNEW = false;
  global $_DISPLAYMOTD;
  $_DISPLAYMOTD = false;

  include "nav/default_top.php";

  /*
   * zone-edit.php
   */
?>

<?php
global $a;
if ($a->getAuth() && 
    (getSessionVariable("type") == "admin")) {
  
  $doUpdate = $_GET['doUpdate'];
  $doCreate = $_GET['doCreate'];
  $doDelete = $_GET['doDelete'];

  // 07 Oct 2003 : GWA : Try and prevent reloads from doing damage.
  
  if (doReloadProtect()) {
    $doUpdate = false;
    $doCreate = false;
    $doDelete = false;
  }
  // HANDLE UPDATES/CREATES
 
  $numOperations = $doUpdate + $doCreate + $doDelete;
  if ($numOperations > 1) {

    // 10 Oct 2003 : GWA : Can't do both, sorry. ?>

    <p class=error>
    Sorry, there was an error with your input.  Please try again.
    </p>

    <?php $doUpdate = 0;
    $doCreate = 0;
    $doDelete = 0;
  }
 
  if ($doCreate == 1) {
    $name = $_GET['newZoneName'];
    $motes = $_GET['newZoneMotes'];

    if (ereg("[^0-9,]", $motes)) {
?>
<p class=error>
The list of motes can only contain moteIDs (numbers) and commas.
</p>
<?php
    } else {
      $newQuery = "insert into $_ZONETABLENAME (name, motes) values ('$name', '$motes')";
      $newResult = doDBQuery($newQuery);
      if (DB::isError($newResult)) { ?>
<p align=center>Create Failed (<?php echo $newResult->GetMessage(); ?>)</p>
      <?php } else { ?>
<p align=center>Create Succeeded</p>
      <?php }
    }
  }

  if ($doUpdate == 1) {
    $zone = $_GET['updateZone'];
    $motes = $_GET['updateZoneMotes'];

    if (ereg("[^0-9,]", $motes)) {
?>
<p class=error>
The list of motes can only contain moteIDs (numbers) and commas.
</p>
<?php
    } else {
      $updateQuery = "update $_ZONETABLENAME set motes = '$motes' where id = $zone";
      $updateResult = doDBQuery($updateQuery);
      if (DB::isError($updateResult)) { ?>
<p align=center>Update Failed (<?php echo $updateResult->GetMessage(); ?>)</p>
      <?php } else { ?>
<p align=center>Update Succeeded</p>
      <?php }
    }
  }

  if ($doDelete == 1) {
    $zone = $_GET['deleteZone'];

    $deleteQuery = "delete from $_ZONETABLENAME where id = $zone";
    $deleteResult = doDBQuery($deleteQuery);
    if (DB::isError($deleteResult)) { ?>
<p align=center>Delete Failed (<?php echo $deleteResult->GetMessage(); ?>)</p>
    <?php } else { ?>
<p align=center>Delete Succeeded</p>
    <?php }
  }
 
  ?>

<form method="get" action="<?=$_SERVER['PHP_SELF']?>">
<input type=hidden name=doCreate value=0>
<input type=hidden name=doUpdate value=0>
<input type=hidden name=doDelete value=0>

<div style="color:green;">Create a new zone:</div>

<p>
<table>
<tr>
<td style="text-align:center; color:blue;">Zone Name</td>
<td style="text-align:center; color:blue;">Comma-Separated Mote List</td>
</tr>
<tr>
<td><input name="newZoneName" size=10></td>
<td>
<input name="newZoneMotes" size=60>
</td>
<td>
<input type=submit value="Create Zone" onClick="this.form.doCreate.value = 1;">
</td>
<tr>
</table>
</p>

<br><br>
<div style="color:green;">Update a current zone:</div>

<p>
<table>
<tr>
<td style="text-align:center; color:blue;">Zone</td>
<td style="text-align:center; color:blue;">Comma-Separated Mote List</td>
</tr>
<tr>
<td>
<select name="updateZone">
<option value="empty" selected></option>
<?php
  $zoneQuery = "select name,id,motes from $_ZONETABLENAME";
  $zoneResult = doDBQuery($zoneQuery);
  while ($zoneRow = $zoneResult->fetchRow(DB_FETCHMODE_ASSOC)) {
?>
<option value="<?php echo $zoneRow['id']; ?>" onClick="this.form.updateZoneMotes.value = '<?php echo $zoneRow['motes']; ?>';">
<?php echo $zoneRow['name']; ?></option>
<?php
  }
?>
</select>
</td>
<td>
<input name="updateZoneMotes" size=60>
</td>
<td>
<input type=submit value="Update Zone" onClick="this.form.doUpdate.value = 1;">
</td>
</tr>
</table>
</p>

<br><br>
<div style="color:green;">Delete a zone:</div>

<p>
<select name="deleteZone">
<?php
  $zoneQuery = "select name,id from $_ZONETABLENAME";
  $zoneResult = doDBQuery($zoneQuery);
  while ($zoneRow = $zoneResult->fetchRow(DB_FETCHMODE_ASSOC)) {
?>
<option value="<?php echo $zoneRow['id']; ?>">
<?php echo $zoneRow['name']; ?></option>
<?php
  }
?>
</select>
<input type=submit value="Delete Zone" onClick="this.form.doDelete.value = 1;">
</p>
</form>

<?php }  else { ?>
  <p> You must log in as an administrator to use this page.
<?php } ?>
<?php 
  include "nav/default_bot.php";
?>
