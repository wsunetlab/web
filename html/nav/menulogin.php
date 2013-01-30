<div id="menulogin" class="menus">
  <form method="post" style="padding-left:10px;padding-bottom:0px;" action="<?php echo $_SERVER['PHP_SELF'];?>">
    Email Address<br> 
    <input type="text" name="username" 
           value="<?php echo $_REQUEST['username'] ?>">
    <br>
    Password<br>
    <input type="password" name="password">
    <br>
    <center>
    <input type="submit" value="Login">
    <input type="reset">
    </center>
    <?php if (($_REQUEST['username'] != "") &&
                  (!$a->getAuth())) {?>
      <br>Login failed.
    <?php } ?>
  </form> 
</div>
