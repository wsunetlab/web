<?php
global $a;
if($a->getAuth()){
 // connect to database
// mysql_connect("localhost", "root", "linhtinh") or die(mysql_error());
// mysql_select_db("auth") or die(mysql_error());

 // get node positions
 $posrs = mysql_query("SELECT abs_x, abs_y, moteid FROM motes") or die(mysql_error());
}
?>

<applet code = 'MainGraph' 
    archive = 'MoteGraphApplet.jar', 
    width = 800, 
    height = 600>
 <param name="pos" value="<?php while($pos = mysql_fetch_array($posrs)) echo $pos['moteid'].":".$pos['abs_x'].",".$pos['abs_y'].";"; ?>">
</applet>
