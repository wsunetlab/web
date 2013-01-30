<?php

  $_TOPDONE = false;
  $_NUMMOTES = 6;
  $_NEWJOBID = -1;
  $_DISPLAYNEW;

  // 07 Dec 2003 : GWA : These need to be kept in synch with 
  //               util/job-daemon.pl.

  $_JOBPENDING = 0;
  $_JOBRUNNING = 1;
  $_JOBFINISHED = 2;
  $_JOBENDPROBLEM = 4;
  $_JOBPLEASEDELETE = 5; 

  $_UNAVAILABLECOLOR = "#ff904b";

  $_NUMDAYSAHEAD = 10;

  $_DEFAULTRESOLUTION = 5;
  $_DEFAULTLENGTH = 360;
  $_DEFAULTJOBLENGTH = 30;
  
  $_USERPRIVILEGES = "ALL";
  
  // 07 Dec 2003 : GWA : The amount of time we require in front of a job to
  //               do the scheduling.

  $_JOBSCHEDULEDELTA = 120;
  
  require_once "DB.php";
  require_once "sitespecific.php";
  date_default_timezone_set("America/Los_Angeles");

  function importSessionVariables ($user) {

    global $_DSN;
    global $_SESSIONTABLENAME;
    global $a;
    
    $db = DB::connect($_DSN);
    
    if (DB::isError($db)) {
      die ($db->GetMessage());
    }

    $query_string = "select * from " . $_SESSIONTABLENAME . 
                    " where username=\"" . $user . "\"";

    $result = $db->query($query_string);

    if (DB::isError($result)) {
      die ($result->getMessage());
    }

    $row = $result->fetchRow(DB_FETCHMODE_ASSOC);

    // 21 Jul 2003 : GWA : We might as well take all of this, even if some of
    //               it duplicates information that Auth has already stored.
    //
    
    while (list($key, $value) = each($row)) {

      // 31 Oct 2003 : GWA : We now store the superuser id in a special spot
      //               on login.  We also save the original type because we
      //               want to actually change types when we masquerade, but
      //               be able to come back.

      if (($key == 'id') && ($row['type'] == 'admin')) {
        $a->setAuthData('origid', $value, true);
      }
      if (($key == 'type') && ($row['type'] == 'admin')) {
        $a->setAuthData('origtype', $value, true);
      }
      $a->setAuthData($key, $value, true);  
    }
    $db->disconnect();
    
    if ((stristr($_SERVER['PHP_SELF'], "index.php") == "index.php")) {
      header("Location: user-home.php");
    }
  }
  
  function doSuperUserBecome($userid) {

    global $_SESSIONTABLENAME;
    global $a;

    $query_string = "select * from " . $_SESSIONTABLENAME . 
                    " where id=" . $userid;

    $result = doDBQuery($query_string);

    $row = $result->fetchRow(DB_FETCHMODE_ASSOC);

    while (list($key, $value) = each($row)) {
      $a->setAuthData($key, $value, true);  
    }
  }

  function getSessionVariable($name) {
    global $a;
    return $a->getAuthData($name);
  }

  function setSessionVariable($name, $value) {
    global $a;
    $a->setAuthData($name, $value);
    return;
  }

  function displayFileList() {
 
    global $_DSN;
    $mydb = DB::Connect($_DSN);

    if (DB::IsError($mydb)) {
      die($mydb->GetMessage());
    }
    
    $user = getSessionVariable("username");

    global $_FILESTABLENAME;
    $query_string = "select * from " . $_FILESTABLENAME . 
                    " where user=\"" . $user . "\"";
    
    $result = $mydb->query($query_string);

    if (DB::IsError($result)) {
      die($result->GetMessage());
    }

    if ($result->numRows() == 0) {?>
      <p>You have not uploaded any files.
    <?php } else { ?>
      <table border="1" width=100%>
        <caption>Files that you have uploaded</caption>
        <tr>
          <th> Reference Name
          <th> Upload Date
          <th> Comments
        </tr>
      <?php while ($row = $result->fetchRow(DB_FETCHMODE_ASSOC)) { ?>
        <tr>
          <td> <?php echo $row['name'] ?>
          <td> <?php echo $row['uploaded'] ?>
          <td> <?php echo $row['description'] ?>
        </tr>
      <?php } ?>
      </table>
    <?php }

    $mydb->disconnect();
  }
  
  function doDataUpdate($DB, $jobID, $userDB) {
  
    $basicQuery = "select dbprefix, jobtempdir from " . $_JOBSTABLENAME . 
                  " as jobs, " . $_JOBSCHEDULETABLENAME .
                  " as jobschedule where jobs.id=jobschedule.jobid and" .
                  " jobschedule.id=" . $jobID;
    $basicResult = $DB->query($basicQuery);
    if (DB::isError($basicResult)) {
      die($basicResult);
    }
    $basicRef = $basicResult->fetchRow(DB_FETCHMODE_ASSOC);
    $jobTablePrefix = $basicRef['dbprefix'];
    $jobDataDir = $_JOBDATAROOT . $basicRef['jobtempdir'];

    // 20 Oct 2003 : GWA : Get all the classes to update.

    $classesQuery = "select " . $_JOBFILESTABLENAME .
                    ".fileid from " . $_JOBFILESTABLENAME .
                    " as jobfiles, " . $_JOBSCHEDULETABLENAME .
                    " as jobschedule, " . $_JOBSTABLENAME .
                    " as jobs where jobschedule.id=" . $jobID .
                    " and jobschedule.jobid=jobs.id" .
                    " and jobfiles.jobid=jobs.id" .
                    " and jobfiles.moteid=0 limit 1";
    $classesResult = $DB->query($classesQuery);
    if (DB::isError($classesResult)) {
      die($classesResult->GetMessage());
    }

    // 20 Oct 2003 : GWA : Now walk through all of our classes and update
    //               data.

    while ($classesRef = $classesResult->fetchRow(DB_FETCHMODE_ASSOC)) {
      $classID = $classesRef['fileid'];
      $tableName = $jobTablePrefix . "_" . $classID;
      $testQuery = "select * from " . $userDB . "." . $tableName;
      $dataUpdateCommand = $_DATAUPDATEROOT . " \"" . $testQuery . "\" " .
                           "> \"" . $jobDataDir . "/" . $classID . ".dat\"";
      exec($dataUpdateCommand);
    }
  }
  
  function doReloadProtect() {
    if ($_REQUEST['ReloadProtect'] != "") {
      if (getSessionVariable($_REQUEST['ReloadProtect']) == "true") {
        return true;
      } else {
        setSessionVariable($_REQUEST['ReloadProtect'], "true");
        return false;
      }
    }
  }
  
  function doLockTables($table, $type) {
    global $DB;
    $lockQuery = "lock tables " . $table . " " . $type;
    $lockResult = $DB->query($lockQuery);
    if (DB::isError($lockResult)) {
      die($lockResult->GetMessage());
    }
    return;
  }

  function doUnlockTables() {
    global $DB;
    $lockQuery = "unlock tables";
    $lockResult = $DB->query($lockQuery);
    if (DB::isError($lockResult)) {
      die($lockResult->GetMessage());
    }
    return;
  }

  function doDBQuery($queryString, $dieOnError = true) {
    global $DB;
    $queryResult = $DB->query($queryString);
    if ($dieOnError &&
        (DB::isError($queryResult))) {
      die($queryResult->getMessage());
    }
    return $queryResult;
  }
  
  function doDBQueryAssoc($queryString, $dieOnError = true) {
    global $DB;
    $queryResult = $DB->getAssoc($queryString);
    if ($dieOnError &&
        (DB::isError($queryResult))) {
      die($queryResult->getMessage());
    }
    return $queryResult;
  }

  function startDB($dieOnError = true) {
    global $_DSN;
    $ourDB = DB::Connect($_DSN);
    if ($dieOnError &&
        (DB::IsError($ourDB)) ) {
      die($ourDB->getMessage());
    }
    return $ourDB;
  }

  function deleteJobSchedule($scheduleID, $dieOnError = false) {
    global $_JOBSTABLENAME;
    global $_JOBSCHEDULETABLENAME;
    global $_SESSIONTABLENAME;
    global $_JOBPLEASEDELETE;
    global $_JOBRUNNING;

    $user = getSessionVariable('username');
    $type = getSessionVariable('type');

    // 31 Oct 2003 : GWA : Three steps here:
    //
    //               1) Do error checking: does the user own this job, etc.
    //               2) Update quota.
    //               3) Do delete.

    // 31 Oct 2003 : GWA : First, check if deleting user is owner, and if job
    //               actually exists.

    $checkQuery = "select jobs.owner from " . $_JOBSTABLENAME .
                  " as jobs, " . $_JOBSCHEDULETABLENAME .
                  " as jobschedule where jobschedule.jobid=jobs.id and" .
                  " jobschedule.id=" . $scheduleID;
    $checkResult = doDBQuery($checkQuery);
    if ($checkResult->numRows() == 0) {
      return 1;
    }
    $checkRow = $checkResult->fetchRow(DB_FETCHMODE_ASSOC);
    if ($user != $checkRow['owner'] && $type != "admin") {
      return 1;
    }
    
    // 31 Oct 2003 : GWA : Fetch quota info.

    $quotaQuery = "select quotacharge" .
                  " , state from " . 
                  $_JOBSCHEDULETABLENAME . 
                  " where id=" . $scheduleID;
    $quotaResult = doDBQuery($quotaQuery);
    $quotaRef = $quotaResult->fetchRow(DB_FETCHMODE_ASSOC);
    $minutesToAdd = $quotaRef['quotacharge'];

    // 31 Oct 2003 : GWA : Next actually perform delete.
    //
    // 07 Dec 2003 : GWA : Actually removing the job from the table causes
    //               all sorts of races and problems.  (deleting a currently
    //               running job causes motelab constipation bug).  So
    //               instead of actually removing the job we're just going to
    //               set a flag that will let the job-daemon kill the job the
    //               next time it wakes up.
    
    if ($quotaRef['state'] == $_JOBRUNNING) {
      $deleteQuery = "update " . $_JOBSCHEDULETABLENAME .
                     " set state=" . $_JOBPLEASEDELETE . 
                     ", end=NOW() " .
                     " where id=" . $scheduleID;
    } else {
      $deleteQuery = "update " . $_JOBSCHEDULETABLENAME .
                     " set state=" . $_JOBPLEASEDELETE . 
                     " where id=" . $scheduleID;
    }
    doDBQuery($deleteQuery);
                  
    // 31 Oct 2003 : GWA : Update users quota.
    //
    // 09 Dec 2003 : GWA : AHA!  Don't want to do this twice if the job is
    //               already running, since job-daemon will take care of it.
    
    if ($quotaRef['state'] != $_JOBRUNNING) {
      if (getSessionVariable('type') != 'admin') {
        $oldQuota = getSessionVariable('used');
        $newQuota = $oldQuota - $minutesToAdd;
        
        // 09 Dec 2003 : GWA : There are some strange corner cases that could
        //               cause this.

        if ($newQuota < 0) {
          $newQuota = 0;
        }

        $updateQuotaQuery = "update " . $_SESSIONTABLENAME .
                            " set used=" . $newQuota .
                            " where username=\"" . $user . "\"";
        doDBQuery($updateQuotaQuery);
        setSessionVariable('used', $newQuota);
      }
    } else {

      // 20 Jul 2006 : GWA : If the job is running might as well fire off the
      //               daemon to get rid of it right away!
      return 2;
    }
    
    // 31 Oct 2003 : GWA : All done.
    
    return 0;
  }
  
  function generatePassword($length = 8) {

    // start with a blank password
    $password = "";

    // define possible characters
    $possible = "0123456789bcdfghjkmnpqrstvwxyz"; 
                
    // set up a counter
    $i = 0; 
                        
    // add random characters to $password until $length is reached
    while ($i < $length) { 

      // pick a random character from the
      // possible ones
      $char = substr($possible, mt_rand(0, strlen($possible)-1), 1);

      // we don't want this
      // character if it's
      // already in the password
      if (!strstr($password, $char)) { 
        $password .= $char;
        $i++;
      }

    }
    // done!
    return $password;
  }

  // 01 Aug 2006 : GWA : Moved from userCreate page to make things a bit
  //               cleaner there.

  function createNewUser($userName, 
                         $firstName, 
                         $lastName, 
                         $userPassword,
                         $userType,
                         $userQuota,
                         $academicInstitution,
                         $isStudent,
                         $advisorName,
                         $advisorEmail,
                         $useDescription,
                         $printOutput = false,
                         $sendEmail = false) {

    global $_SESSIONTABLENAME;
    global $_USERROOT;
    global $_JOBDIRNAME;
    global $_UPLOADDIRNAME;
    global $_USERPRIVILEGES;
    global $_MOTELABADMINADDRESS;

    // 01 Aug 2006 : GWA : Verify that username is unique!
    
    doLockTables($_SESSIONTABLENAME, "write");
   
    if ($printOutput) { ?> 
      <p> 1. Checking user name for uniqueness ...
    <?php }

    $userNameCheckQuery = "select username from " . $_SESSIONTABLENAME .
                    " where username=\"" . $userName . "\"";
    $userNameCheckResult = doDBQuery($userNameCheckQuery);
    
    if ($userNameCheckResult->numRows() > 0) {
      doUnlockTables();
      if ($printOutput) { ?> 
        <span style="color:red;"><strong>FAIL</strong></span></p>
      <?php }
      return "Username already exists";
    }
    if ($printOutput) { ?> 
      <span style="color:green;"><strong>OK</strong></span><br>
    <?php }


    // 01 Aug 2006 : GWA : Generate a random password if one not provided.
    
    if ($userPassword == "") {
      $userPassword = generatePassword();
    }
      
    // 10 Oct 2003 : GWA : Unfortunately we can't rely on the userid to
    //               create some of this stuff.  Because MySQL doesn't allow
    //               '@' in database names we have be creative.  Essentially
    //               we parse the username and remove the part before the
    //               ampersand.  We try using that as the database name, if
    //               it doesn't conflict with anything else.  We'll set that
    //               here before going any farther.

    list($userID, $unused) = explode("@", $userName);
    
    // 21 Jan 2004 : GWA : We've encountered an email address that break's
    //               this, namely one that contains a '.'.  Implementing a
    //               workaround.

    $userID = str_replace(".", "", $userID);
    
    // 03 May 2005 : GWA : "-" also seems to break.

    $userID = str_replace("-", "", $userID);
    $userID = substr($userID, 0, 12);

    $dbCheckQuery = "select dbname from " . $_SESSIONTABLENAME .
                    " where dbname like \"" . $userID . "%\"";
    $dbCheckResult = doDBQuery($dbCheckQuery);

    if ($dbCheckResult->numRows() > 0) {

      // 10 Oct 2003 : GWA : We have a collision, so figure out how to
      //               generate a new ID.
      
      $userIDAddition = 1;
      while ($dbCheckRef = $dbCheckResult->fetchRow(DB_FETCHMODE_ASSOC)) {
        list ($currentIDAddition) = explode($userID, $dbCheckRef['dbname']);
        if (strcspn($currentIDAddition, "0123456789") != 0) {
          next;
        }
        if ($currentIDAddition > $userIDAddition) {
          $userIDAddition = $currentIDAddition + 1;
        }
      }
      $userID .= $userIDAddition;
    }
    
    // 10 Oct 2003 : GWA : TODO : Currently we aren't doing cleanup.  We
    //               probably should at some point.

    $userRoot = $_USERROOT . $userName;
    $userJobRoot = $userRoot . "/" . $_JOBDIRNAME;
    $userUploadRoot = $userRoot . "/" . $_UPLOADDIRNAME;
    
    $userRoot = addslashes($userRoot);
    $userJobRoot = addslashes($userJobRoot);
    $userUploadRoot = addslashes($userUploadRoot) . "/";

    // 10 Oct 2003 : GWA : Now create directories user will use.
    //
    // 10 Jul 2006 : GWA : Do this FIRST since it's what breaks if we try and
    //               recreate an old user.
    
    if ($printOutput) { ?> 
      <p> 2. Creating user directories ... 
    <?php }

    if ((!mkdir($userRoot, 0775)) || 
        (!mkdir($userJobRoot, 0775)) ||
        (!mkdir($userUploadRoot, 0775))) {
      doUnlockTables();
      if ($printOutput) { ?> 
        <span style="color:red;"><strong>FAIL</strong></span></p>
      <?php }
      return "Problem creating user directories";
    }
    if ($printOutput) { ?> 
      <span style="color:green;"><strong>OK</strong></span><br>
    <?php }
      
    // 10 Oct 2003 : GWA : Phew, almost done.  Now just do the actual insert.
    
    if ($printOutput) { ?> 
      <p> 3. Inserting user into database ... 
    <?php }
    
    $userInsertQuery = "insert into " . $_SESSIONTABLENAME .
                       " set username=\"" . $userName . "\"" .
                       ", password=MD5(\"" . $userPassword . "\")" .
                       ", type=\"" . $userType . "\"" . 
                       ", exec_dir=\"" . $userUploadRoot . "\"" .
                       ", firstname=\"" . mysql_real_escape_string($firstName) . "\"" .
                       ", lastname=\"" . mysql_real_escape_string($lastName) . "\"" . 
                       ", dbname=\"" . $userID . "\"" .
                       ", quota=" . $userQuota . 
                       ", academicInstitution=\"" . mysql_real_escape_string($academicInstitution) .  "\"" . 
                       ", isStudent=" . $isStudent . 
                       ", advisorName=\"" . mysql_real_escape_string($advisorName) . "\"" .
                       ", advisorEmail=\"" . $advisorEmail . "\"" .
                       ", jobDescription=\"" . mysql_real_escape_string($useDescription) . "\"";
    $userInsertResult = doDBQuery($userInsertQuery, false);
    if (DB::isError($userInsertResult)) {
      if ($printOutput) { ?> 
        <span style="color:red;"><strong>FAIL</strong></span></p>
      <?php }
      doUnlockTables();
      return "Problem insert user into database";
    }
    if ($printOutput) { ?> 
      <span style="color:green;"><strong>OK</strong></span><br>
    <?php }

    doUnlockTables();

    // 10 Oct 2003 : GWA : OK, geez, that was hard.  Now we get to do the fun
    //               stuff.  First, create the MySQL tables this user will
    //               use and grant them access.

    if ($printOutput) { ?> 
      <p> 4. Creating user MySQL databases ... 
    <?php }

    $createUserDatabase = "create database " . $userID;
    $createUserDatabaseResult = doDBQuery($createUserDatabase, false);
    if (DB::isError($createUserDatabaseResult)) {
      if ($printOutput) { ?> 
        <span style="color:red;"><strong>FAIL</strong></span></p>
      <?php }
      return "Problem creating user database" . $userID;
    }
    if ($printOutput) { ?> 
      <span style="color:green;"><strong>OK</strong></span><br>
    <?php }
    
    if ($printOutput) { ?> 
      <p> 5. Granting user MySQL access ... 
    <?php }
    
    $createUserTableGrant = "grant " . $_USERPRIVILEGES . 
                            " on " . $userID . ".*" .
                            " to " . $userID . "@'%'" .
                            " identified by '" . $userPassword . "'";
    $createUserTableResult = doDBQuery($createUserTableGrant, false);
    if (DB::isError($createUserTableResult)) {
      if ($printOutput) { ?> 
        <span style="color:red;"><strong>FAIL</strong></span></p>
      <?php }
      return "Problem granting user database access";
    }
    if ($printOutput) { ?> 
      <span style="color:green;"><strong>OK</strong></span><br>
    <?php }

    if (!$sendEmail) {
      return "";
    }

    if ($printOutput) { ?> 
      <p> 6. Sending user email ...
    <?php }
   
    // 01 Aug 2006 : GWA : Send the user an email with their username and
    //               password.  Might want to add the advisor in here but for
    //               now this is easier.

    $emailTO = $userName . ", " . $_MOTELABADMINADDRESS;
    $emailSUBJECT = "MoteLab Account Created";
    $emailBODY = <<<TEST
The MoteLab account that you requested has been created:
  
  User Name: $userName
  Password: $userPassword

You can change your password to something more memorable here:

http://192.168.72.58/user-info.php

(Please do not choose a particularly important password!)

We have also created a database table name "$userID" where results from your
experiments will be stored. You can access the database like so:
  
  mysql -h motelab.eecs.harvard.edu -u $userID -p<MoteLab Password> $userID

We strongly encourage you to sign up for the MoteLab users list, which you
can do here:

https://www.eecs.harvard.edu/mailman/listinfo/motelab-users

We use this list for important updates about the status of the lab, etc.

Questions about using MoteLab? Check the FAQ First:

http://motelab.eecs.harvard.edu/faq.php

Enjoy MoteLab!

The MoteLab Team
TEST;
    $emailHEADERS = "From: motelab-admin@vancouver.wsu.edu";
    mail($emailTO, $emailSUBJECT, $emailBODY, $emailHEADERS);
    
    if ($printOutput) { ?> 
      <span style="color:green;"><strong>OK</strong></span><br>
    <?php }

    return "";
  }
?>
