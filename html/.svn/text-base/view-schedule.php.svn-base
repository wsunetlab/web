<?php
  $_DISPLAYNEW = false;
  include "nav/default_top.php";

  /*
   * jobs-schedule.php
   *
   * INPUTS:
   *  1) GET['jobid'].  Optional.
   *
   * OUTPUTS:
   *
   * FUNCTION:
   *
   * GOES:
   *
   * CREATED: 02 Aug 2003 
   *
   * AUTHOR: GWA
   */
?>
<?php

global $a;

if ($a->getAuth()) { 

  global $_NUMDAYSAHEAD;
  global $_DEFAULTLENGTH;
  global $_DEFAULTRESOLUTION;
  global $_DEFAULTJOBLENGTH;
  global $_JOBSCHEDULEDELTA;

  $user = getSessionVariable("username");
  $userType = getSessionVariable("type");
  $pageCurrentTime = time();

  if ($_GET['numHours']) {
  
    $resolution = $_GET['resolution'];
    $startTime = $_GET['startDay'] + ($_GET['startHour'] * 60 * 60);
    $startHour = $_GET['startHour'];
    $startDay = $_GET['startDay'];
    $length = $_GET['numHours'] * 60;
     
  } else {

    $resolution = $_DEFAULTRESOLUTION;
    $startTime = strtotime(date("D M j Y G:00"));
    $startDay = strtotime(date("D M j Y"));
    $startHour = date("G");
    $length = $_DEFAULTLENGTH;
  }
 
  global $_DSN;
  global $_JOBSTABLENAME;
  global $_JOBSCHEDULETABLENAME;
  
  if ($_GET['jobID']) {
    $jobID = $_GET['jobID'];
    $jobNameQuery = "select name from " . $_JOBSTABLENAME .
                    " where id=$jobID";
    $jobNameResult = doDBQuery($jobNameQuery);
    $jobNameRef = $jobNameResult->fetchRow(DB_FETCHMODE_ASSOC);
    $jobName = $jobNameRef['name'];
  } else {
    $jobID = 0;
  }

  $jobLength = 0;

  $doSchedule = $_GET['doSchedule'];
  $doDelete = $_GET['doDelete'];
  
  if (doReloadProtect()) {
    $doSchedule = false;
    $doDelete = false;
  }

  // 28 Oct 2003 : GWA : Adding user job quota support.

  $quotaQuery = "select quota, used from " . $_SESSIONTABLENAME .
                " where username=\"" . $user . "\"";
  $quotaResult = doDBQuery($quotaQuery);
  $quotaRef = $quotaResult->fetchRow(DB_FETCHMODE_ASSOC);
  $userQuota = $quotaRef['quota'];
  $userUsed = $quotaRef['used'];
  $userAvailable = $userQuota - $userUsed;
  $userNowAvailable = $userAvailable;
  $userNow = $userUsed;

  if ($doSchedule == true) {
  
    // 28 Oct 2003 : GWA : Disable quota checking for admins.

    if ($userType != "admin") {
    
      $numMinutes = (int) (ceil($_GET['jobEnd'] - $_GET['jobStart']) / 60);
      
      // 28 Oct 2003 : GWA : User is out of minutes.
      
      if ($numMinutes > $userAvailable) { 
        $doSchedule = false;
        ?>
        <p style="color:red;">
          Sorry, we cannot schedule this job because it exceeds your quota.
          You have <?php echo $userAvailable; ?> minutes remaining.
        </p>
      <?php 
        $sawError = 1;
        $printedMessage = 1;
      } else {
        $userNow = $userUsed + $numMinutes;
        $userNowAvailable = $userQuota - $userNow;
      }
    } else {
      $numMinutes = 0;
    }
      
    // 07 Dec 2003 : GWA : An extra bit of logic required now to catch badly
    //               formed insertions.
    
    if (!$sawError) {
      if (($_GET['jobStart'] + $_JOBSCHEDULEDELTA) >= $_GET['jobEnd']) {
        $sawError = 1;
      }
    }

    if (!$sawError) {
      // 14 Jul 2004 : swies : set up our moteprogram info
      $zoneMotes = "select motes from $_ZONETABLENAME where id = " . $_GET['zoneID'];
      $zoneMotesResult = doDBQuery($zoneMotes);
      $zoneInfo = $zoneMotesResult->fetchrow(DB_FETCHMODE_ASSOC);
      $moteList = explode(",", $zoneInfo['motes']);

      $myMotes = array();
      $myFiles = array();
      $moteFiles = "select moteid, fileid from jobfiles where jobid = " .
                     $_GET['jobID'];
      $moteFilesResult = doDBQuery($moteFiles);
      while ($row = $moteFilesResult->fetchrow(DB_FETCHMODE_ASSOC)) {
        if (in_array($row['moteid'], $moteList)) {
          array_push($myMotes, $row['moteid']);
          array_push($myFiles, $row['fileid']);
        }
      }

      // 02 Aug 2004: swies : fire off an error if no programs assigned for this zone
      if (count($myMotes) == 0) { 
        $doSchedule = false;
        ?>
        <p style="color:red;">
          Sorry, we cannot schedule this job because you have not
          assigned any programs to run in this zone.  Please
          <a href="jobs-create.php?jobid=<?php echo $_GET['jobID'];?>">
          edit this job</a> to run programs on more motes and try again.
        </p>
      <?php 
        $sawError = 1;
        $printedMessage = 1;
      }
    }

    if (!$sawError) {
      $myProg = "";
      for ($i = 0; $i < count($myMotes); $i++) {
        if ($i != 0) {
          $myProg .= "|";
        }
        $myProg .= $myMotes[$i] . "," . $myFiles[$i];
      }

      // 06 Sep 2003 : GWA : First, lock the tables.
      doLockTables($_JOBSCHEDULETABLENAME, "write");

      // 13 Jul 2004 : swies : need different checking for zones
      $checkZone = "select UNIX_TIMESTAMP(start) as unixstart," .
                     " UNIX_TIMESTAMP(end) as unixend, state," .
                     " moteprogram" .
                     " from ". $_JOBSCHEDULETABLENAME . 
                     " where state!=" . $_JOBPLEASEDELETE .
                     " having (unixstart <= " . $_GET['jobStart'] .
                     " and unixend >= " . $_GET['jobEnd'] .
                     ") or (unixstart > " . $_GET['jobStart'] .
                     " and unixstart < " . $_GET['jobEnd'] .
                     ") or (unixend > " . $_GET['jobStart'] .
                     " and unixend < " . $_GET['jobEnd'] . ")";
      $checkZoneResult = doDBQuery($checkZone);

      $checkMotes = array();
      while ($row = $checkZoneResult->fetchrow(DB_FETCHMODE_ASSOC)) {
        if ($row['moteprogram'] == NULL) {
          /* a different scheduler/jobdaemon put something on the whole lab */
          $sawError = 1;
        } else {
          $checkProg = explode("|", $row['moteprogram']);
          foreach ($checkProg as $p) {
            $p = explode(",", $p);
            array_push($checkMotes, $p[0]);
          }
        }
      }
      if (count(array_intersect($myMotes, $checkMotes)) != 0) {
        $sawError = 1;
      }

      if (!$sawError) {
        $insertQuery = "insert into " .
                       $_JOBSCHEDULETABLENAME .
                       " set jobid=" . $_GET['jobID'] . 
                       ", zoneid=" . $_GET['zoneID'] . 
                       ", moteprogram='" . $myProg . "'" .
                       ", jobdaemon=\"" . $_JOBDAEMON . "\"" .
                       ", quotacharge=" . $numMinutes .
                       ", start=FROM_UNIXTIME(" . $_GET['jobStart'] . ")" .
                       ", end=FROM_UNIXTIME(" . $_GET['jobEnd'] . ")";
        
        doDBQuery($insertQuery);
        
        // 20 Jul 2006 : GWA : Something else new.  Fire off the appropriate
        //               daemon here for fun, since locking should prevent
        //               problems.
        //
        // 20 Jul 2006 : GWA : Doh.  Gotta start it in the background.
        
        if ($_GET['jobStart'] <= time()) {
          exec("$_JOBDAEMONEXECUTABLE > /dev/null 2> /dev/null &");
        }
      }

      doUnlockTables();
    }

    // 15 Dec 2003 : GWA : Finally caught this: we were updating user quotas
    //               on failed job entries.  Should be fixed now.

    if (!$sawError) {
      if ($userType != "admin") {
        $updateQuota = "update " . $_SESSIONTABLENAME .
                       " set used=" . $userNow .
                       " where username=\"" . $user . "\"";
        $updateResult = doDBQuery($updateQuota);
        setSessionVariable("used", $userNow);
      }
    }
  }

  if ($doDelete) {
    $deleteReturn = deleteJobSchedule($_GET['deleteID']);
    if ($deleteReturn == 1) { ?>
      <p class=error>
        There was a problem deleting this job.
      </p>
    <?php } else if ($deleteReturn == 2) {
      exec("$_JOBDAEMONEXECUTABLE > /dev/null 2> /dev/null &");
    }
  }

  $jobsQuery = "select name, owner, id from " .
               $_JOBSTABLENAME . 
               " where owner=\"" . $user . "\"" .
               " order by created desc";
  $jobsResult = doDBQuery($jobsQuery);

  $zonesQuery = "select name, id from $_ZONETABLENAME";
  $zonesResult = doDBQuery($zonesQuery);

  ?>
  <br> 
  <form method="get" action="<?php echo $_SERVER['PHP_SELF'];?>"
        name=scheduleParams>
    Show 
    <select name=numHours>
      <?php foreach (array(4, 6, 12, 24, 48) as $currentNum) { ?>
        <option value=<?php echo $currentNum;
                      if ($currentNum == ($length / 60)) {
                        echo " selected";
                      } ?>>
          <?php echo $currentNum;?>
        </option>
      <?php } ?>
    </select>
    hours starting at
    <select name=startHour>
      <?php $currentHour = date("G"); 
      for ($i = 0; $i < 24; $i++) { ?>
        <option value=<?php echo $i; 
          if ($i == $startHour) {
            echo " selected";
          } ?>>
          <?php echo $i;?>:00
        </option>
      <?php } ?>
    </select>
    on 
    <select name=startDay>
      <?php for ($i = 0; $i < $_NUMDAYSAHEAD; $i++) {
        $value = strtotime("+" . $i . " day");
        $pretty = date("D M j Y", $value);
        $value = strtotime($pretty);?>
        <option value="<?php echo $value;?>"  
                       <?php if ($value == $startDay) {
                         echo " selected";
                       } ?>>
          <?php echo $pretty;?>
        </option>
      <?php } ?>
    </select>
    in
    <select name=resolution>
      <?php foreach (array(5, 15, 30, 60) as $currentRes) { ?>
        <option value=<?php echo $currentRes;
                      if ($currentRes == $resolution) {
                        echo " selected";
                      } ?> >
          <?php echo $currentRes; ?>
        </option>
      <?php } ?>
    </select>
    minute chunks.
    <input type="button" 
           onClick="doSubmit('refresh');"
           value="Update Schedule">
    <span id="doAutoReload" style="display:none;">
      <input type="button"
             onClick="doAutoReload();"
             value="Enable Auto Reload">
    </span>
    <span id="disableAutoReload">
      <input type="button"
             onClick="disableAutoReload();"
             value="Disable Auto Reload">
    </span>
    <br>
    Time on MoteLab is <?php echo date("H:i:s") ?>
    <br><br>
    <?php if ($doSchedule == true && $sawError && !$printedMessage) { ?>
      <div style="color:red;">
      There was an error processing your job entry.  Please examine the 
      updated schedule below and see if you either scheduled a job in the
      past or the schedule changed while you were scheduling.  You may also
      have tried to schedule the same job twice, perhaps by hitting
      refresh.
      </div><br>
    <?php } else if ($doSchedule == true) { ?>
      <div style="color:darkgreen;">
        Successfully scheduled job <?php echo $jobName; ?><br><br>
      </div>
    <?php } ?> 
    <?php if ($jobsResult->numRows() == 0) { ?>
      You must <a href="jobs-create.php">create</a> a job before
      you can schedule one.
    <?php } else { 
      if ($userType != "admin") { ?>
      <p> 
        You have a quota of <?php echo $userQuota; ?> minutes.  You have 
        <?php echo $userNow; ?> minutes of pending jobs.
        You have <?php echo $userNowAvailable; ?> minutes available.
      </p>
      <?php } ?>
      Run 
      <select name=jobID
        onChange="document.scheduleParams.jobid.value=this.value">
        <?php while ($row = $jobsResult->fetchrow(DB_FETCHMODE_ASSOC)) { ?>
          <option value="<?php echo $row['id'];?>"
                         <?php if ($row['id'] == $jobID) {
                           echo " selected";
                         }?>>
            <?php echo $row['name'];?>
          </option>
        <?php } ?>
      </select> 
      on 
      <select name=zoneID
        onChange="document.scheduleParams.zoneid.value=this.value">
        <?php while ($row = $zonesResult->fetchrow(DB_FETCHMODE_ASSOC)) { ?>
          <option value="<?php echo $row['id'];?>">
            <?php echo $row['name'];?>
          </option>
        <?php } ?>
      </select>
      <input type="button"
             name="scheduleSubmit"
             onClick="doSubmit('schedule');"
             value="Schedule Job"
             disabled>
    <?php } ?>
    <input type="hidden" name="doSchedule" value=0>
    <input type="hidden" name="jobStart">
    <input type="hidden" name="jobEnd">
    <input type="hidden" name="jobid" value=<?php echo $jobID;?>>
    <input type="hidden" name=ReloadProtect value=<?php echo time();?>>
    <input type="hidden" name="doDelete" value=0>
    <input type="hidden" name="deleteID">
  </form>
  <p>
  To begin selecting, double click on an available slot.
  <br>
  To continue selecting, single click on an adjacent slot.
  <br>
  To cancel your selection, double click again anywhere inside your
  selection.
  </p>
  <?php 

  $start = $startTime; 
  $resolution = $resolution * 60;
  $jobLength = $jobLength * 60;
  $length = $length * 60;

  global $_JOBSCHEDULETABLENAME;
  global $_JOBPENDING;
  global $_JOBRUNNING;
  global $_JOBFINISHED;

  $scheduleQuery = "select jobschedule.id, jobschedule.jobid," .
                   " jobschedule.end, jobschedule.zoneid," .
                   " jobschedule.state, jobs.name, jobs.owner," .
                   " zones.id as zoneid, zones.name as zonename," .
                   " UNIX_TIMESTAMP(jobschedule.start) as unixstart," . 
                   " UNIX_TIMESTAMP(jobschedule.end) as unixend from (" .
                   $_JOBSCHEDULETABLENAME . " as jobschedule, " .
                   $_JOBSTABLENAME . " as jobs)" .
                   " left join $_ZONETABLENAME as zones" .
                   " on zones.id=jobschedule.zoneid" .
                   " where jobs.id=jobschedule.jobid" .
                   //" and jobschedule.state!=5 having".
                   " having".
                   " ((((unixstart >= " . $startTime . ")" .
                   " and" .
                   " (unixstart < (" . $startTime . " + ". $length . ")))" .
                   " or" .
                   " ((unixend > " . $startTime . ")" .
                   " and" .
                   " (unixend <= (" . $startTime . " + " . $length . "))))" .
                   " or" .
                   " ((" . $startTime . " > unixstart)" .
                   " and" .
                   " (unixend > (" . $startTime . " + " . $length . "))))" .
                   " order by unixstart";
  $scheduleResult = doDBQuery($scheduleQuery);
  //$row = $scheduleResult->fetchRow(DB_FETCHMODE_ASSOC);
  $jobStart = 0;
  $jobEnd = 0;
  $rowSpan = 0;
  $innerPrint = "";
  $startPrint = "";
  $freeSpaceStartsID = 0;
  $scheduleEarlyOK = 0;
  $scheduleNowOK = 0;

  $scheduleArray = array_fill(0, $length/$resolution, "");

  while ($row = $scheduleResult->fetchRow(DB_FETCHMODE_ASSOC)) {
    if ($row['state'] == $_JOBRUNNING) {
      $class = "jobRunning";
    } elseif ($row['state'] == $_JOBPENDING) {
      $class = "jobPending";
    } elseif ($row['state'] == $_JOBFINISHED) {
      $class = "jobFinished";
    } elseif ($row['state'] == $_JOBPLEASEDELETE) {
      $class = "jobDeleted";
    }

    $jobString = "<span class=$class>[" . $row['owner'] . " " . $row['id'] . " " .
                   $row['name'] . " (" . $row['zonename'] . ")";
    //delete button - maybe we only want to do this on the last timeslot?
    if ((($row['owner'] == getSessionVariable('username')) ||
          (getSessionVariable('type') == 'admin')) &&
         (($row['state'] == $_JOBPENDING) ||
          ($row['state'] == $_JOBRUNNING))) {
      $jobString .= "<span onClick= \"doDelete(" . $row['id'] . ")\"
      style=\"color:black;cursor:pointer;\">Delete</span>";
    }
    $jobString .= "]</span> ";

    $startIndex = ($row['unixstart'] - $start) / $resolution;
    if ($startIndex < 0) {
      $startIndex = 0;
    }

    $endIndex = ($row['unixend'] - $start) / $resolution;
    if ($endIndex > $length/$resolution) {
      $endIndex = $length/$resolution;
    }

    while ($startIndex < $endIndex) {
      $scheduleArray[$startIndex] .= $jobString;
      $startIndex++;
    }
  }
  ?>
  <table border=1px 
         align=center
         cellpadding=5px
         style="border-collapse:collapse; 
                empty-cells:show;
                width:90%;">
  <?php 
  $sawThePast = false;
  $sawTheFuture = false;
  for ($currentTime = $start, $i = 0; 
       $currentTime < $start + $length;
       $currentTime += $resolution, $i++) {
    $prettyTime = date("H:i", $currentTime);
    if (($currentTime + $resolution) <
        ($pageCurrentTime + $_JOBSCHEDULEDELTA)) {
      $cellClass = "scheduleUnavailable";
      $freeSpaceStartsID = $i+1;
      $sawThePast = true;
      // only let javascript move the scheduled time up to NOW if
      // there's nothing in the previous timeslot
      if ($scheduleArray[$i] == "")
        $scheduleEarlyOK = 1;
      else 
        $scheduleEarlyOK = 0;
      $mouseScript = "";
    } else {
      $sawTheFuture = true;
      $cellClass = "scheduleFree";
      $mouseScript = " onMouseOver=\"doMouseOver(this);\"" .
                     " onMouseOut=\"doMouseOut(this);\"" .
                     " ondblClick=\"doDblClick(this);\"" .
                     " onClick=\"doClick(this);\"";
    }
   ?>
<tr>
<td style="width:1px;"><?= $prettyTime ?></td>
<td class=<?= $cellClass ?> id="<?= $i+1 ?>"<?= $mouseScript ?>>
<?= $scheduleArray[$i] ?>
</td>
</tr>
  <?php
  } 
  if ($sawThePast && $sawTheFuture) {
    $scheduleNowOK = 1;
  }
  ?>

  </table>

<script language="JavaScript">
<!--
  var selectStarted = false;
  var numNodes = <?php echo $length/$resolution; ?>;
  var selectMax = 0;
  var selectMin = 0;
  var freeTimeStartID = <?php echo $freeSpaceStartsID; ?>;
  var scheduleEarlyOK = <?php echo $scheduleEarlyOK; ?>;
  var scheduleNowOK = <?php echo $scheduleNowOK; ?>;
  var motelabTimeDriftCalc;
  var doReload = true;
  var doReloadSave;

  onload = doTimeDrift;
  
  function doTimeDrift() {
    var pageGenDate = new Date();
    motelabTimeDriftCalc = 
      Math.floor(pageGenDate.getTime() / 1000) - 
        <?php echo $pageCurrentTime;?>; 
    var timeToReload = ((Math.ceil(<?php echo $pageCurrentTime;?>/
                                  <?php echo $resolution;?>)) *
                        <?php echo $resolution;?>) - 
                        <?php echo $pageCurrentTime;?>;
    setTimeout("doTimedReload()", timeToReload * 1000);
  }
  
  function doTimedReload() {
    if (!doReload) {
      return;
    }
    window.location.reload();
  }
  
  function doAutoReload() {
    doReload = true;
    document.getElementById('doAutoReload').style.display='none';
    document.getElementById('disableAutoReload').style.display='';
  }
  function disableAutoReload() {
    doReload = false;
    document.getElementById('doAutoReload').style.display='';
    document.getElementById('disableAutoReload').style.display='none';
  }
  function doDelete(jobID) {
    document.scheduleParams.doDelete.value=1;
    document.scheduleParams.deleteID.value=jobID;
    document.scheduleParams.submit();
  }

  function doSubmit(type) {
    var ourDate = new Date();
    var freeTimeStart = Math.floor(ourDate.getTime() / 1000);
    freeTimeStart -= motelabTimeDriftCalc;
    if (type == "schedule") {
      if (selectStarted == false) {
        alert("You must select a time to run the job on the schedule");
        return false;
      } else {
        var totalTime = (selectMax - selectMin) - 1;
        totalTime *= <?php echo $resolution;?>;
        var startTime = <?php echo $startTime;?> + 
                        (selectMin * <?php echo $resolution; ?>);
        <?php
        // 07 Dec 2003 : GWA : Moving to being able to schedule a job _now_
        //               introduces some extra complexity here.  If the user
        //               selected an uneven bit of time we have to a) inform
        //               them and b) make sure that the starttime is actually
        //               before the endtime.
        // ?>
        if ((selectMin == freeTimeStartID) &&
            (scheduleNowOK == 1)) {
          var endTime = startTime + totalTime;
          if (freeTimeStart > startTime)
            var startTime = freeTimeStart;
          else if (scheduleEarlyOK == 1)
            var startTime = freeTimeStart;
          var jobLength = Math.floor((endTime - startTime) / 60);
          <?php // 07 Dec 2003 : GWA : This is weird, but the PHP insertion
          //                     code will catch if the job starts after it
          //                     ends.  What we want to alert about is that
          //                     fact that the job won't actually start on
          //                     the boundary, but rather ASAP.  
          // ?>
          var motelabDate = new Date(startTime * 1000);
          motelabDate.setMinutes(motelabDate.getMinutes() + 1);
          motelabDate.setSeconds(0);
          var msg = 
            "NOTE: You have chosen to run your job now.\n" +
            " Your job will start" +
            " at approximately " + motelabDate.toLocaleString() +
            "\nand run for about " + jobLength + 
            " minutes.\n";
          if (startTime + <?php echo $_JOBSCHEDULEDELTA;?> < endTime) {
            if (!confirm(msg)) {
              return false;
            }
          }
        } else {
          var startTime = <?php echo $startTime;?> + 
                          (selectMin * <?php echo $resolution; ?>);
          var endTime = startTime + totalTime;
        }

        document.scheduleParams.doSchedule.value = 1;
        document.scheduleParams.jobStart.value = startTime;
        document.scheduleParams.jobEnd.value = endTime;
        document.scheduleParams.submit();
      }
    } else if (type == "refresh") {
      if (selectStarted == true) {
        var msg = 
        "WARNING: Refreshing the schedule will destroy the selection" + 
        " you have made\n" +
        "Click OK to Continue, Cancel to go back\n";
        if (!confirm(msg)) {
          return false;
        }
      }
      document.scheduleParams.doSchedule.value = 0;
      document.scheduleParams.submit();
    }
    return true;
  }

  function doClick(currentElement) {
    if (selectStarted == false) {
      return true;
    } else if (currentElement.id == selectMin) {
      selectMin -= 1;
      currentElement.className = 'scheduleFreeSelected';
    } else if (currentElement.id == selectMax) {
      selectMax += 1;
      currentElement.className = 'scheduleFreeSelected';
    } else if ((selectMin + 1) != (selectMax - 1)) {
      if (currentElement.id == (selectMin + 1)) {
        selectMin += 1;
        currentElement.className = 'scheduleFreeNotSelected';
        doMouseOut(currentElement);
      } else if (currentElement.id == (selectMax - 1)) {
        selectMax -= 1;
        currentElement.className = 'scheduleFreeNotSelected';
        doMouseOut(currentElement);
      }
    }
    return true;
  }
    
  function doDblClick(currentElement) {
    var nextState;
    if (selectStarted == true) {
      if (currentElement.className != "scheduleFreeSelected") {
        return true;
      } else {
        nextState = "scheduleFree";
      }
    } else {
      nextState = "scheduleFreeNotSelected";
    }
    
    for (var i = 1; i < numNodes; i++) {
      if ((document.getElementById(i).className == "scheduleFree") ||
          (document.getElementById(i).className == "scheduleFreeHighlight") ||
          (document.getElementById(i).className == "scheduleFreeSelected") ||
          (document.getElementById(i).className == "scheduleFreeNotSelected")) {
        document.getElementById(i).className=nextState;
      }
    }

    if (selectStarted == true) {
      selectStarted = false;
      doReload = doReloadSave;
      selectMax = 0;
      selectMin = 0;
      return true;
    }

    currentElement.className="scheduleFreeSelected";
    selectStarted = true;
    doReloadSave = doReload;
    doReload = false;
    selectMax = parseInt(currentElement.id) + 1;
    selectMin = currentElement.id - 1;
    document.scheduleParams.scheduleSubmit.disabled = false;
    return true;
  }

  function doMouseOver(currentElement) {
    if (selectStarted == false) {
      currentElement.className='scheduleFreeHighlight';
    } else if ((currentElement.id == selectMax) ||
          (currentElement.id == selectMin)) {
      currentElement.className='scheduleFreeHighlight';
    }
    return true;
  }

  function doMouseOut(currentElement) {
    if (currentElement.className == 'scheduleFreeHighlight') {
      if (selectStarted == true) {
        currentElement.className = 'scheduleFreeNotSelected';
      } else {
        currentElement.className = 'scheduleFree';
      }
    }
    return true;
  }

//-->
</script>

<?php } else { ?>
  <p> You cannot schedule jobs until you log in. </p>
<?php } ?>

<?php 
  include "nav/default_bot.php";
?>
  
