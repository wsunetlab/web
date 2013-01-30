<?php
  $_DISPLAYNEW = false;
  include "nav/default_top.php";

  /*
   * jobs-submit.php
   *
   * INPUTS: 
   *  1a) GET['jobid'].  Optional.
   *  1b) POST['jobid']. 
   *  2) POST['files[]'].  Optional.
   *
   * OUTPUTS:
   *
   * FUNCTION:
   *
   * GOES:
   *
   * CREATED: 24 Jul 2003
   *
   * AUTHOR: GWA
   */
?>
<?php

global $a;
if ($a->getAuth()) {

  global $_JOBFILESTABLENAME;

  $user = getSessionVariable("username");
  $userid = getSessionVariable("id");

  $jobName = trim($_REQUEST['Name']);
  $jobDescription = trim($_REQUEST['Description']);
  $jobCurrentPanel = trim($_REQUEST['Where']);
  $jobDistType = trim($_REQUEST['DistType']);
  $jobInfo = $_REQUEST['Info'];
  $jobClassInfo = $_REQUEST['Classes'];

  // 20 Apr 2004 : GWA : This is somewhat hackish, but easier than
  //               maintaining seperate MYSQL schema for different states.
  //               Our job schema are inclusive in that they include things
  //               that people don't have.  Even though PHP actually does
  //               'the right thing' here when faced with a empty request
  //               query, we put this in just to emphasize that this won't
  //               get set unless you have power management stuff online.

  if ($_HAVEPOWERMANAGE) {
    $jobPowerManage = $_REQUEST['doPowerManage'];
  } else {
    $jobPowerManage = 0;
  }

  if (getSessionVariable("type") == "admin") {
    $jobCronJob = $_REQUEST['IsCronJob'];
    if ($jobCronJob) {
      $jobCronFreq = $_REQUEST['CronFreq'];
      $jobCronTime = $_REQUEST['CronTime'];
    } else {
      $jobCronFreq = 0;
      $jobCronTime = 0;
    }
    $jobDuringRun = $_REQUEST['DuringRun'];
    $jobPostProcess = $_REQUEST['PostProcess'];
  } else {
    $jobCronJob = 0;
    $jobCronFreq = 0;
    $jobCronTime = 0;
    $jobDuringRun = "";
    $jobPostProcess = "";
  }
  
  $splitInfo = explode("|", $jobInfo);
  $splitClasses = explode(",", $jobClassInfo);
  
  $fileInfo = array();
  $classInfo = array();

  foreach ($splitInfo as $current) {
    $newElement = sscanf($current, "( %d, %d )");
    array_push($fileInfo, $newElement);
  }

  foreach ($splitClasses as $current) {
    $newElement = sscanf($current, "%d");
    array_push($classInfo, $newElement);
  }

  //
  // 28 Jul 2003 : GWA : TODO : Better error handling.
  //

  $jobDB = DB::Connect($_DSN);
  if (DB::isError($jobDB)) {
    die($jobDB->GetMessage());
  }

  if ($jobID = $_GET['jobid']) {
   
    //
    // 28 Jul 2003 : GWA : TODO: PRIORITY HIGH
    //               Need some verification here please... want to make
    //               sure that we don't needlessly overwrite somebody elses
    //               stuff.
    //

    $insertQuery = "update " . $_JOBSTABLENAME .
                   " set name=\"" . $jobName . "\"" . 
                   ", description=\"" . $jobDescription . "\"" .
                   ", owner=\"" . $user . "\"" .
                   ", userid=" . $userid . 
                   ", currentpanel=\"" . $jobCurrentPanel . "\"" .
                   ", disttype=\"" . $jobDistType . "\"" .
                   ", moteprogram=\"" . $jobInfo . "\"" . 
                   ", powermanage=" . $jobPowerManage .
                   ", cronjob=" . $jobCronJob .
                   ", crontime=" . $jobCronTime .
                   ", cronfreq=" . $jobCronFreq .
                   ", duringrun=\"" . $jobDuringRun . "\"" .
                   ", postprocess=\"" . $jobPostProcess . "\"" .
                   " where id=" . $jobID;
  } else {
    
    $insertQuery = "insert into " .
                   $_JOBSTABLENAME . 
                   " set name=\"" . $jobName . "\"" . 
                   ", description=\"" . $jobDescription . "\"" .
                   ", owner=\"" . $user . "\"" .
                   ", userid=" . $userid . 
                   ", currentpanel=\"" . $jobCurrentPanel . "\"" .
                   ", disttype=\"" . $jobDistType . "\"" .
                   ", moteprogram=\"" . $jobInfo . "\"" . 
                   ", powermanage=" . $jobPowerManage .
                   ", cronjob=" . $jobCronJob .
                   ", crontime=" . $jobCronTime .
                   ", cronfreq=" . $jobCronFreq .
                   ", duringrun=\"" . $jobDuringRun . "\"" .
                   ", postprocess=\"" . $jobPostProcess . "\"" .
                   ", created=NULL";
  }
  
  $insertResult = $jobDB->query($insertQuery);
  
  //
  // 28 Jul 2003 : GWA : TODO : Better error handling.
  //
  
  if (DB::isError($insertResult)) {
    die($insertResult->getMessage());
  }

  if (!$_GET['jobid']) {
    //
    // 28 Jul 2003 : GWA : Now we do the insert.  Then we retrieve the
    //               jobID and set it.
    //

    $jobIDQuery = "select LAST_INSERT_ID() from " .
                  $_JOBSTABLENAME .
                  " limit 1";
    
    $jobIDResult = $jobDB->query($jobIDQuery);
    
    if (DB::isError($jobIDResult)) {
      die($jobIDResult->getMessage());
    }
    
    $jobIDResultRow = $jobIDResult->fetchRow();
    $jobID = $jobIDResultRow[0];
  }

  if ($_GET['jobid']) {

    //
    // 28 Jul 2003 : GWA : We're just going to nuke the relevant entries
    //               in the jobfiles table and start over.
    //

    $deleteQuery = "delete from " . $_JOBFILESTABLENAME . 
                   " where jobid=" . $jobID;
    
    $deleteResult = $jobDB->query($deleteQuery);

    if (DB::isError($deleteResult)) {
      die($deleteResult->getMessage());
    }
  }

  $fileInsert = "insert into " . $_JOBFILESTABLENAME .
                " set jobid=" . $jobID . 
                ", moteid=?, fileid=?";
  
  $classInsert = "insert into " . $_JOBFILESTABLENAME .
                 " set jobid=" . $jobID .
                 ", fileid=?";

  $filePrepare = $jobDB->prepare($fileInsert);
  $classPrepare = $jobDB->prepare($classInsert);

  $jobDB->executeMultiple($filePrepare, $fileInfo);
  $jobDB->executeMultiple($classPrepare, $classInfo);
  ?>
  
  <?php if ($_GET['jobid']) { ?>
    <p style="color:green;"> 
      Job <?php echo $jobID;?> was modified. 
    </p>
  <?php } else { ?>
    <p style"color:green;">
      Job <?php echo $jobID;?> was created.
    </p>
  <?php } ?>
  <form name="schedulejob" method="get" 
        action="view-schedule.php?jobID=<?php echo $jobID;?>">
    <input type="submit" value="Schedule">
    <input type="hidden" name="jobid" value="<?php echo $jobID;?>">
  </form>
<?php } else { ?>
  <p> You cannot create jobs until you log in.
<?php } ?>
<?php
  include "nav/default_bot.php";
?>
