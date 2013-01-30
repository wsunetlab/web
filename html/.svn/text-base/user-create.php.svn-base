<?php 
  global $_DISPLAYNEW;
  $_DISPLAYNEW = false;
  global $_DISPLAYMOTD;
  $_DISPLAYMOTD = false;

  include "nav/default_top.php";

  /*
   * user-create.php
   *
   */
?>

<?php
global $a;
if ($a->getAuth() && 
    (getSessionVariable("type") == "admin")) {
  
  $doUpdate = $_GET['doUpdate'];
  $doCreate = $_GET['doCreate'];
  $doDelete = $_GET['doDelete'];
  $doAccept = $_GET['doAccept'];
  $doReject = $_GET['doReject'];

  // 07 Oct 2003 : GWA : Try and prevent reloads from doing damage.
  
  if (doReloadProtect()) {
    $doUpdate = false;
    $doCreate = false;
    $doDelete = false;
    $doAccept = false;
    $doReject = false;
  }
 
  $numOperations = $doUpdate + $doCreate + $doDelete + $doAccept + $doReject;

  if ($numOperations > 1) {

    // 10 Oct 2003 : GWA : Can't do both, sorry. ?>

    <p class=error>
    Sorry, there was an error with your input.  Please try again.
    </p>

    <?php $doUpdate = 0;
    $doCreate = 0;
    $doDelete = 0;
    $doAccept = 0;
    $doReject = 0;
  }
  
  // 10 Oct 2003 : GWA : Grab common user variables.  Any sort of sanity
  //               checking on these should have been done by javascript
  //               before the form was submitted, although I guess we should
  //               also do a bit here to make sure that things are OK if
  //               we're being scripted.

  $userName = trim($_GET['userName']);
  $firstName = trim($_GET['firstName']);
  $lastName = trim($_GET['lastName']);
  $userType = trim($_GET['userType']);
  $userQuota = trim($_GET['userQuota']);
  $academicInstitution = trim($_GET['academicInstitution']);
  $isStudent = trim($_GET['isStudent']);
  $advisorName = trim($_GET['advisorName']);
  $advisorEmail = trim($_GET['advisorEmail']);

  // 10 Jul 2006 : GWA : Need this to update the DB password.

  $userDBName = trim($_GET['dbname']);

  // 12 Dec 2003 : GWA : Fix bug where insert barfs on administrators
  //               because userQuota not defined.

  if ($userType == 'admin') {
    $userQuota = 0;
  }

  // DO CREATES
  //
  // 10 Oct 2003 : GWA : We have some common information that we want to 
  //               build up here.

  if ($doCreate) {

    if ($isStudent) {
      $studentOK = 1;
    } else {
      $studentOK = 0;
    }

    // 01 Aug 2006 : GWA : Moved all of this into a function that does all
    //               the work.

    $error = createNewUser($userName, 
                           $firstName, 
                           $lastName, 
                           "",
                           $userType,
                           $userQuota,
                           $academicInstitution,
                           $studentOK,
                           $advisorName,
                           $advisorEmail,
                           "",
                           true,
                           true);
  }

  if ($doAccept) {
    $allIDS = explode(",", $_GET['userArray']);
    
    // 01 Aug 2006 : GWA : Process each user separately.

    foreach ($allIDS as $unused => $pendingUserID) {
      $pendingUserQuery = "select * from " . $_PENDINGUSERTABLENAME . " " .
                          " where id=" . $pendingUserID;
      $pendingUserResult = doDBQuery($pendingUserQuery);
      $pendingUserRef = $pendingUserResult->fetchrow(DB_FETCHMODE_ASSOC); ?>
      <p> Creating user <?= $pendingUserRef['firstname']?> 
      <?= $pendingUserRef['lastname'] ?> ... 
      <?php $error = createNewUser($pendingUserRef['username'],
                             $pendingUserRef['firstname'],
                             $pendingUserRef['lastname'],
                             "",
                             "normal",
                             "30",
                             $pendingUserRef['academicInstitution'],
                             $pendingUserRef['isStudent'],
                             $pendingUserRef['advisorName'],
                             $pendingUserRef['advisorEmail'],
                             $pendingUserRef['jobDescription'],
                             false,
                             true);
      if ($error == "") { ?>
        <span style="color:green;"><strong>SUCCESS</strong></span><br>
      <?php } else { ?>
        <span style="color:red;"><strong>FAIL:</strong>
        <?= $error?></span><br>
      <?php }

      if ($error == "") {
        $dropPendingUserQuery = "delete from " . 
                                $_PENDINGUSERTABLENAME . " " .
                                "where id=" . $pendingUserID;
        doDBQuery($dropPendingUserQuery);
      }
    }
  }

  if ($doReject) {

    // 01 Aug 2006 : GWA : I think that it's best to do this silently.  I
    //               I don't anticipate having to reject many user
    //               applications!

    $allIDS = explode(",", $_GET['userArray']);
    
    // 01 Aug 2006 : GWA : Process each user separately.

    foreach ($allIDS as $unused => $pendingUserID) {
      $dropPendingUserQuery = "delete from " . 
                              $_PENDINGUSERTABLENAME . " " .
                              "where id=" . $pendingUserID;
      doDBQuery($dropPendingUserQuery);
    }
  }

  if ($doUpdate) {
   
    $error = false;

    if ($userPassword != "") { ?>

      <p> Updating password ...
      
      <?php
      if ($userPassword != $userPassword2) { ?>
        <span style="color:red;"> FAILED Passwords do not match </span> </p>
        <?php $error = true;
      } else { ?>
        <span style="color:green;"> SUCCEEDED </span> </p>
      <?php }
    } 
    
    if (!$error) { ?>
      <p> Updating user information ... 
       
      <?php 
      if ($userPassword != "") {
        $updateUserInfo = "update " . $_SESSIONTABLENAME .
                        " set username=\"" . $userName . "\"" .
                        ", password=MD5(\"" . $userPassword . "\")" .
                        ", firstname=\"" . $firstName . "\"" .
                        ", lastname=\"" . $lastName . "\"" .
                        ", type=\"" . $userType . "\"" . 
                        ", quota=" . $userQuota .
                        " where id=" . $_GET['updateID'];
      } else {
        $updateUserInfo = "update " . $_SESSIONTABLENAME .
                        " set username=\"" . $userName . "\"" .
                        ", firstname=\"" . $firstName . "\"" .
                        ", lastname=\"" . $lastName . "\"" .
                        ", type=\"" . $userType . "\"" . 
                        ", quota=" . $userQuota .
                        " where id=" . $_GET['updateID'];
      }
      $updateUserInfoResult = doDBQuery($updateUserInfo, false);
      if (DB::isError($updateUserInfoResult)) {
        $error = true; ?>
        <span style="color:red;"> FAILED <?php echo $updateUserInfoResult->GetMessage(); ?></span> </p>
      <?php } else { ?>
        <span style="color:green;"> SUCCEEDED </span> </p>
      <?php }
    }
    
    if (!$error && $userPassword != "") { ?>
      <p> Updating database password ...

      <?php 
      $updateUserPassword = "SET PASSWORD FOR " . $userDBName . 
                            "@'%'=PASSWORD(\"" . $userPassword . "\");";
      $updateUserPasswordResult = doDBQuery($updateUserPassword, false);
      if (DB::isError($updateUserPasswordResult)) { ?>
      
        <span style="color:red;"> FAILED <?php echo $updateUserPasswordResult->GetMessage(); ?></span> </p>
      <?php } else { ?>
        <span style="color:green;"> SUCCEEDED </span> </p>
      <?php }
    }
  }

  if ($doDelete) {
    
    // 10 Oct 2003 : GWA : This should be pretty simple, but I want to think
    //               about what to do with the old data and such before I
    //               implement this.  For now we just don't support it.

  } ?>
  
  <?php
  // LIST PENDING USERS
  ?> 
  <p>
    <h2>Pending Users</h2>
  <p>

  <?php $pendingUserQuery = "select * from $_PENDINGUSERTABLENAME";
  $pendingUserResult = doDBQuery($pendingUserQuery);

  if ($pendingUserResult->numRows() > 0) { ?>
    <p> There <?php if ($pendingUserResult->numRows() == 1) {
      echo "is";
    } else {
      echo "are";
    } ?> <?=$pendingUserResult->numRows()?> pending <?php if
    ($pendingUserResult->numRows() == 1) {
      echo "user";
    } else {
      echo "users";
    } ?>:<br><br>
   
    <table border=0
           hspace=4
           cellpadding=5px
           style="border-collapse:collapse; 
                  empty-cells:show;
                  width:100%;">
    <tr bgcolor="#e0e0e0">
    <tr>
    <td width=3% bgcolor="#e0e0e0">
    <td width=20% bgcolor="#e0e0e0"><b>Name</b>
    <td width=10% bgcolor="#e0e0e0"><b>Email</b>
    <td width=10% bgcolor="#e0e0e0"><b>School</b>
    <td width=5%  bgcolor="#e0e0e0"><b>Student?</b>
    <td width=20% bgcolor="#e0e0e0"><b>Advisor</b>
    <td width=32% bgcolor="#e0e0e0"><b>Use Description</b>
    </tr>
    <?php while ($pendingUserRef =
           $pendingUserResult->fetchrow(DB_FETCHMODE_ASSOC)) { ?>
      <tr>
        <td>
          <input id="<?= $pendingUserRef['id']?>"
                 class=pendingUser
                 type=checkbox>
        </td>
        <td>
          <?= $pendingUserRef['firstname'] ?> <?= $pendingUserRef['lastname']?>
        </td>
        <td>
          <a href="mailto:<?= $pendingUserRef['username']?>"><?=
          $pendingUserRef['username']?></a>
        </td>
        <td>
          <?= $pendingUserRef['academicInstitution'] ?>
        </td>
        <td>
          <?php if ($pendingUserRef['isStudent'] == 1) { ?>
          <span style="color:green;">Y</span>
          <?php } else { ?>
          <span style="color:red;">N</span>
          <?php } ?>
        </td>
        <td>
          <?php if ($pendingUserRef['isStudent'] == 1) {
            echo $pendingUserRef['advisorName'];
          } else { ?>
            <span style="color:grey;">N/A</span>
          <?php } ?>
        </td>
        <td>
          <?= $pendingUserRef['jobDescription'] ?>
        </td>
      </tr>
      <?php } ?>
      </table>
      <p>
      <input id="selectAll" type=button onClick="selectAll(true);"
             value="Select All">
      <input id="unselectAll" type=button onClick="selectAll(false);"
             value="Unselect All">
      <input id="acceptAll" type=button onClick="acceptAll();"
             value="Accept All Checked">
      <input id="rejectAll" type=button onClick="rejectAll();"
             value="Reject All Checked">
      
  <?php } else { ?>
    <p>There are no pending users at this time.
  <?php } ?>
  <hr>
  
  <h2>Create New User</h2>
  <form name=ourForm method=get action="user-create.php">
    Email Address/User Name : <br> 
    <input type="text" name="userName" 
           style="width:20em;">
    <br>
    First Name : <br>
    <input type="text" name="firstName"
           style="width:20em;">
    <br>
    Last Name : <br>
    <input type="text" name="lastName"
           style="width:20em;">
    <br>
    Academic Institution : <br>
    <input type="text" name="academicInstitution"
           style="width:20em;">
    <br>
    Is Student? : 
    <input type="checkbox" name="isStudent" onchange="changeIsStudent();">
    <br>
    Advisor Name : <br>
    <input type="text" name="advisorName"
           style="width:20em;" disabled>
    <br>
    Advisor Email : <br>
    <input type="text" name="advisorEmail"
           style="width:20em;" disabled>
    <br><br>
    Type
    <select name="userType"
            onChange="if (this.value=='normal') {
                        this.form.userQuota.disabled = false;
                      } else {
                        this.form.userQuota.disabled = true;
                      }">
      <option value="normal"> 
        normal
      </option>
      <option value="admin">
        admin
      </option>
    </select>
    Quota (in min)
    <select name="userQuota">
      <option value=30>
        30
      </option>
      <option value=60>
        60
      </option>
      <option value=120>
        2 hours
      </option>
      <option value=240>
        4 hours
      </option>
      <option value=480>
        8 hours
      </option>
      <option value=720>
        12 hours
      </option>
      <option value=1440>
        24 hours
      </option>
    </select>
    <br><br>
    <input type=hidden name=dbname value="">
    <input type=hidden name=doCreate value=0>
    <input type=hidden name=doUpdate value=0>
    <input type=hidden name=doDelete value=0>
    <input type=hidden name=doAccept value=0>
    <input type=hidden name=doReject value=0>
    <input type=hidden name=updateID>
    <input type=hidden name=userArray>
    <input type=submit name=createUser
           value="Create New User"
           onClick="document.ourForm.doCreate.value=1;">
    <input type=submit name=updateUser
           value="Update User" disabled
           onClick="document.ourForm.doUpdate.value=1;">
    <input type=reset
           value="Reset Form"
           onClick="document.ourForm.createUser.disabled = false;
                    document.ourForm.updateUser.disabled = true;
                    document.ourForm.userQuota.disabled = false;">
    <input type=hidden name=ReloadProtect value=<?php echo time(); ?>>
  </form>
  <hr>

  <?php 

  // LIST EXISTING USERS

  $userNumberQuery = "select type, count(*) as number from " .
                     $_SESSIONTABLENAME . " group by type";
  $userNumberResult = doDBQuery($userNumberQuery);

  $numberAdmin = 0;
  $numberRegular = 0;

  while($userNumberRef = $userNumberResult->fetchrow(DB_FETCHMODE_ASSOC)) {
    if ($userNumberRef['type'] == "admin") {
      $numberAdmin = $userNumberRef['number'];
    } else if ($userNumberRef['type'] == "normal") {
      $numberRegular = $userNumberRef['number'];
    }
  }

  $userQuery = "select id, username, firstname, lastname, type, quota, dbname from " .
               $_SESSIONTABLENAME . " order by lastname";
  $userResult = doDBQuery($userQuery);?>
  <p>
    <h2>Existing Users</h2>
  <p>
  <span style="color:red;"><b><?php echo $numberAdmin; ?>
  administrators.</b></span><br>
  <span style="color:green;"><b><?php echo $numberRegular; ?>
  regular users.</b></span>
  <p>
  <table border=0
         hspace=4
         cellpadding=5px
         style="border-collapse:collapse; 
                empty-cells:show;
                width:100%;">
  <tr bgcolor="#e0e0e0">
  <tr>
  <td width=30% bgcolor="#e0e0e0"><b>Name</b></td>
  <td width=20% bgcolor="#e0e0e0"><b>Username</b></td>
  <td width=20% bgcolor="#e0e0e0"><b>Type</b></td>
  <td width=20% bgcolor="#e0e0e0"><b>Quota</b></td>
  <td width=10% bgcolor="#e0e0e0"><b>Edit</b></td>
  </tr>

  <?php while ($userRef = $userResult->fetchRow(DB_FETCHMODE_ASSOC)) { ?>
    <tr>
      <td> 
        <?php echo $userRef['firstname']; ?> <?php echo
        $userRef['lastname'];?>
      </td>
      <td>
        <?php echo $userRef['username']; ?>
      </td>
      <td>
        <?php echo $userRef['type']; ?>
      </td>
      <td>
        <?php echo $userRef['quota']; ?>
      </td>
      <td>
        <a style="color:blue;cursor:pointer;"
        onClick="document.ourForm.userName.value=
                  '<?php echo $userRef[username];?>';
                document.ourForm.firstName.value=
                  '<?php echo $userRef[firstname];?>';
                document.ourForm.lastName.value=
                  '<?php echo $userRef[lastname];?>';
                document.ourForm.userType.value=
                  '<?php echo $userRef[type];?>';
                document.ourForm.updateID.value =
                  '<?php echo $userRef[id];?>';
                document.ourForm.userQuota.value =
                  '<?php echo $userRef[quota];?>';
                document.ourForm.dbname.value =
                  '<?php echo $userRef[dbname];?>';
                if ('<?php echo $userRef[type];?>'=='admin') {
                  document.ourForm.userQuota.disabled = true;
                } else {
                  document.ourForm.userQuota.disabled = false;
                }
                document.ourForm.createUser.disabled = true;
                document.ourForm.updateUser.disabled = false;
                ">
          edit
        </a>
      </td>
    </tr>
  <?php } ?>
  
  </table>

  <script language="JavaScript">
  <!--
    var workingList = new Array();
  
    function getElementsByClass(cls) {
      var a, b, c, i, j, o;
      b = document.getElementsByTagName("body").item(0);
      a = b.getElementsByTagName("*");
      o = new Array();
      j = 0;
      for (i = 0; i < a.length; i++) {
        if (a[i].className == cls) {
          o[j] = a[i];
          j++;
        }
      }
      return o;
    }

    function selectAll(direction) {
      hidingElements = getElementsByClass('pendingUser');
      for (i = 0; i < hidingElements.length; i++) {
        hidingElements[i].checked = direction;
      }
    }
  
    function acceptAll() {
      hidingElements = getElementsByClass('pendingUser');
      var j = 0;
      var passingOptions = "";
      for (i = 0; i < hidingElements.length; i++) {
        if (hidingElements[i].checked) {
          if (j != 0) {
            passingOptions += ",";
          }
          passingOptions += hidingElements[i].id;
          j++;
        }
      }
      document.ourForm.userArray.value = passingOptions;
      document.ourForm.doAccept.value=1;
      document.ourForm.submit();
      return;
    }
    
    function rejectAll() {
      hidingElements = getElementsByClass('pendingUser');
      var j = 0;
      var passingOptions = "";
      for (i = 0; i < hidingElements.length; i++) {
        if (hidingElements[i].checked) {
          if (j != 0) {
            passingOptions += ",";
          }
          passingOptions += hidingElements[i].id;
          j++;
        }
      }
      document.ourForm.userArray.value = passingOptions;
      document.ourForm.doReject.value=1;
      document.ourForm.submit();
      return;
    }

    function changeIsStudent() {
      if (document.ourForm.isStudent.checked) {
        document.ourForm.advisorName.disabled = false;
        document.ourForm.advisorEmail.disabled = false;
      } else {
        document.ourForm.advisorName.disabled = true;
        document.ourForm.advisorName.value = "";
        document.ourForm.advisorEmail.disabled = true;
        document.ourForm.advisorEmail.value = "";
      }
    }
  //-->
  </script>
<?php }  else { ?>
  <p> You must log in as an administrator to use this page.
<?php } ?>
<?php 
  include "nav/default_bot.php";
?>
