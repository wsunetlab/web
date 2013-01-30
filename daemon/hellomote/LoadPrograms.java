package hellomote;

import java.io.*;
import java.util.*;
import java.sql.*;

public class LoadPrograms {

	/**
	 * @param args
	 */
	
	static String userid="root", password="linhtinh";

 	static String url = "jdbc:mysql://netlab.encs.vancouver.wsu.edu:3306/auth";
 	static Connection con = null;
 	static Statement stmt = null;
 	static PreparedStatement preparedStatement = null;


 	public static Connection getJDBCConnection(){
         	try {
			Class.forName("com.mysql.jdbc.Driver");
	        } catch(java.lang.ClassNotFoundException e) {
         		System.err.print("ClassNotFoundException: ");
         		System.err.println(e.getMessage());
         	}	

         	try {
         	
		con = DriverManager.getConnection(url, userid, password);
         	
		} catch(Exception ex) {

         	System.err.println("SQLException: " + ex.getMessage());
         	}
         	
		return con;
 	}

	public static void main(String[] args) {

		String s, s1;

	try {
 	Process userName = Runtime.getRuntime().exec(new String[] {"who", "am", "i"});
	BufferedReader userInput = new BufferedReader(new InputStreamReader(userName.getInputStream()));

while ((s = userInput.readLine()) != null) {
              System.out.println("username:"+s);
        }
System.out.println("changes accepted");
	File nullProgDir = new File("/opt/tinyos-2.x/apps/Null");
	File moteProgDir = new File("/opt/tinyos-2.x/apps/RadioCountToLeds/");
//	File apacheHtmlDir = new File("/var/www/web/html/");
	Connection con = getJDBCConnection();
	preparedStatement = con.prepareStatement("select moteid,ip_addr from auth.motes where active='1'");
	ResultSet rs = preparedStatement.executeQuery();

	List moteIdList = new ArrayList();
	List moteAddrList = new ArrayList();

	while(rs.next()){
		String moteId = rs.getString("moteid");
		String moteAddr = rs.getString("ip_addr");
	
		moteIdList.add(moteId);
		moteAddrList.add(moteAddr);		
	}

	//int noOfMotes = 3;
	int noOfMotes = (int) moteIdList.size();
	
	Process moteProgProcess = null;
	Process nullProgProcess = null, readDataProcess = null, eraseProgProcess= null;

	for (int i = 0; i < noOfMotes; i++) {
	String nullCommand = "make telosb install.".concat(moteIdList.get(i).toString()).concat(" bsl,").concat(moteAddrList.get(i).toString());

	nullProgProcess = Runtime.getRuntime().exec(nullCommand, null,
						nullProgDir);
	
	String moteCommand = "make telosb install.".concat(moteIdList.get(i).toString()).concat(" bsl,").concat(moteAddrList.get(i).toString());

	moteProgProcess = Runtime.getRuntime().exec(moteCommand, null,
						moteProgDir);

	BufferedReader stdInput = new BufferedReader(new InputStreamReader(moteProgProcess.getInputStream()));

	BufferedReader stdError = new BufferedReader(new InputStreamReader(moteProgProcess.getErrorStream()));

	// read the output from the command

	System.out.println("Here is the standard output of the command:\n");

	while ((s = stdInput.readLine()) != null) {
	//	System.out.println(s);
	}

	// read any errors from the attempted command

	System.out.println("Here is the standard error of the command (if any):\n");

	while ((s = stdError.readLine()) != null) {
		System.out.println(s);
	}
	
}

	String gatherCommand = "./GatherData.pl ".concat(Integer.toString(noOfMotes));
	
//	readDataProcess = Runtime.getRuntime().exec(gatherCommand, null,moteProgDir);
//File apacheHtmlDir = new File("/var/www/web/html/");
File apacheHtmlDir = new File("/var/www/web/daemon/hellomote/");
 	readDataProcess = Runtime.getRuntime().exec(gatherCommand, null,apacheHtmlDir);


	BufferedReader stdInput2 = new BufferedReader(new InputStreamReader(readDataProcess.getInputStream()));

	BufferedReader stdError2 = new BufferedReader(new InputStreamReader(readDataProcess.getErrorStream()));

	// read the output from the command

	System.out.println("Here is the standard output of the command:\n");
	
	while ((s1 = stdInput2.readLine()) != null) {
		System.out.println(s1);
	}

        for (int j = 0; j < noOfMotes; j++) {
	System.out.println("cmg after message");
        	String eraseCommand = "make telosb install.".concat(moteIdList.get(j).toString()).concat(" bsl,").concat(moteAddrList.get(j).toString());

        eraseProgProcess = Runtime.getRuntime().exec(eraseCommand, null,
                                                nullProgDir);

	BufferedReader stdInput3 = new BufferedReader(new InputStreamReader(eraseProgProcess.getInputStream()));

        BufferedReader stdError3 = new BufferedReader(new InputStreamReader(eraseProgProcess.getErrorStream()));

        // read the output from the command

        System.out.println("Here is the standard output of the command:\n");

        while ((s1 = stdInput3.readLine()) != null) {
                System.out.println(s1);
        }

	}

	// read any errors from the attempted command

//	System.out.println("Here is the standard error of the command (if any):\n");
	
	while ((s1 = stdError2.readLine()) != null) {
		//System.out.println(s1);
	}

	} catch (Exception e) {
		System.out.println(e.getMessage());
	}
	
}

}
