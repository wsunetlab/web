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
// 	static Connection con = null;
 	static Statement stmt = null;
// 	static PreparedStatement preparedStatement = null;
	static File nullProgDir = new File("/opt/tinyos-2.x/apps/Null");
        static File moteProgDir = new File("/opt/tinyos-2.x/apps/RadioCountToLeds/");
	static String CFLAGS_POWER = "-DCC2420_DEF_RFPOWER=";
        static String CFLAGS_CHANNEL = "-DCC2420_DEF_CHANNEL=";

	static Process nullProgProcess = null, readDataProcess = null, eraseProgProcess= null;


 	public static Connection getJDBCConnection(){
         	try {
			Class.forName("com.mysql.jdbc.Driver").newInstance();
	        } catch(java.lang.ClassNotFoundException e) {
         		System.out.println("ClassNotFoundException: ");
         		System.out.println(e.getMessage());
         	} catch(Exception e){
			System.out.println("Exceotion caught here:"+e.toString());	
		}
		Connection con = null;
         	try {
         	
		con = DriverManager.getConnection(url, userid, password);
         	
		} catch(Exception ex) {

         	System.err.println("SQLException: " + ex.getMessage());
         	}
         	
		return con;
 	}

	private static void installNullApp(String moteNumber,String moteAddress){
                String response = "";
                try{
                        System.out.println("Null Program Installation:");
//                ProcessBuilder nullPB = new ProcessBuilder("make", "telosb", "install."+moteNumber,"bsl,"+moteAddress);
//                nullPB.directory(nullProgDir);
//		nullPB.directory(new File("/opt/tinyos-2.x/apps/Null/"));
//		System.out.println("Current Dir: "+ System.getProperty("user.dir")+ "current user:"+System.getProperty("user.name"));
//                nullProgProcess = nullPB.start();
//                InputStream shellIn = nullProgProcess.getInputStream();
//		String output1 = loadStream(nullProgProcess.getInputStream());
		
//		String Error1 = loadStream(nullProgProcess.getErrorStream());
//                int shellExitStatus = nullProgProcess.waitFor();
//                response = convertStreamToStr(shellIn);

//                System.out.println("Exit status:" + shellExitStatus);
		
//                System.out.println("Output status:" + output1);
//                System.out.println("Error status:" + Error1);
//                System.out.println("Response:"+response);

		ProcessBuilder nullPB = new ProcessBuilder("/usr/bin/tos-bsl", "--telosb", "-c", moteAddress, "-r", "-e", "-I", "-p", "/opt/tinyos-2.x/apps/Null/build/telosb/main.ihex");
		
		nullProgProcess = nullPB.start();
		
		String output1 = loadStream(nullProgProcess.getInputStream());
		String Error1 = loadStream(nullProgProcess.getErrorStream());
		
		int shellExitStatus = nullProgProcess.waitFor();
		
		System.out.println("Exit status:" + shellExitStatus);
		System.out.println("Output status:" + output1);
                System.out.println("Error status:" + Error1);
                }catch(Exception e){
                        System.out.println("Error:"+e);
                }

        }

	private static void installMainApp(String moteNumber, String moteAddress,String transPower){
                String response = "";
                try{

                System.out.println("Mote Program Installation:");
                ProcessBuilder mainPB = new ProcessBuilder("make", "telosb", "install."+moteNumber,"bsl,"+moteAddress);
                Map<String,String> env = mainPB.environment();
                env.put("CFLAGS",CFLAGS_POWER+transPower);
		System.out.println("cmg here after setting environment - Jenis");
                mainPB.directory(moteProgDir);
		
		System.out.println("cmg here after setting directory - Jenis");
                Process moteProgProcess = mainPB.start();
		
		System.out.println("cmg here after starting mote process - Jenis");

                InputStream mainShellIn = moteProgProcess.getInputStream();
                int shellExitStatus = moteProgProcess.waitFor();
                response = convertStreamToStr(mainShellIn);

                System.out.println("Exit status:" + shellExitStatus);
                System.out.println("Response:"+response);
                }catch(Exception e){
                        System.out.println("Caught Error:"+e);
                }

        }

private static String loadStream(InputStream s) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(s));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = br.readLine()) != null)
            sb.append(line).append("\n");
        return sb.toString();
}

	 public static String convertStreamToStr(InputStream is) throws IOException {
                if (is != null){
                        Writer writer = new StringWriter();
                        char[] buffer = new char[1024];
                        try {
                        Reader reader = new BufferedReader(new InputStreamReader(is,"UTF-8"));
                        int n;
                        while ((n = reader.read(buffer)) != -1) {
                                writer.write(buffer, 0, n);
                        }
                        } finally {
                                is.close();
                        }
                        return writer.toString();
                }else {
                        return "";
                }
        }





	public static void main(String[] args) {

		String s, s1;
		String CFLAGS_POWER = "-DCC2420_DEF_RFPOWER=";
		String transPower=null;
		PreparedStatement preparedStatement = null;
		ResultSet rs = null;
		Connection con = null;		
		if(args.length != 0){
			transPower = args[0];
		}
		

	try {
	System.out.println("********Program Starts******");
	
	con = getJDBCConnection();
	if(con != null){
		System.out.println("A database connection has been established - Jenis");
	}
	preparedStatement = con.prepareStatement("select moteid,ip_addr from auth.motes where active='1'");
	if(preparedStatement != null){
		System.out.println("Prepared Statement is not null - Jenis");
		rs = preparedStatement.executeQuery();
	}else{
		System.out.println(" Prepared statement is Null - Jenis");
	}

	List<String> moteIdList = new ArrayList<String>();
	List<String> moteAddrList = new ArrayList<String>();
	
	if(rs != null){
		while(rs.next()){
			String moteId = rs.getString("moteid");
			String moteAddr = rs.getString("ip_addr");
	
			moteIdList.add(moteId);
			moteAddrList.add(moteAddr);		
		}
	}else{
		System.out.println(" RS is Null - Jenis");
	}
	
	System.out.println("List added");
	//int noOfMotes = 3;
	int noOfMotes = moteIdList.size();
	System.out.println("No of Motes: "+noOfMotes);
	for (int i = 0; i < noOfMotes; i++) {
		/**
		* Install Null Program 
		**/
		installNullApp(moteIdList.get(i).toString(),moteAddrList.get(i).toString());
	}

	for(int j = 0; j < noOfMotes; j++) {

		/**
        	* Install Actual Program 
        	**/
		installMainApp(moteIdList.get(j).toString(),moteAddrList.get(j).toString(),transPower);
	}

	String gatherCommand = "/var/www/web/daemon/hellomote/GatherData.pl ".concat(Integer.toString(noOfMotes));
	
	File apacheHtmlDir = new File("/var/www/web/daemon/hellomote/");
 	readDataProcess = Runtime.getRuntime().exec(gatherCommand, null,apacheHtmlDir);


	BufferedReader stdInput2 = new BufferedReader(new InputStreamReader(readDataProcess.getInputStream()));

	BufferedReader stdError2 = new BufferedReader(new InputStreamReader(readDataProcess.getErrorStream()));

	// read the output from the command

	System.out.println("Data read started; Here is the standard output of the command:\n");
	
	while ((s1 = stdInput2.readLine()) != null) {
		System.out.println(s1);
	}
	while ((s1 = stdError2.readLine()) != null) {
                System.out.println(s1);
        }

        for (int k = 0; k < noOfMotes; k++) {
		/**
                * Erase all motes before completion
                **/
                installNullApp(moteIdList.get(k).toString(),moteAddrList.get(k).toString());

	}

	} catch (Exception e) {
		System.out.println("Exception Generated:"+e.toString());
	}finally{
		try{
			if(rs!= null){
			rs.close();
			}
			if(preparedStatement!= null){
                        preparedStatement.close();
                	}
			if(con!= null){
                        con.close();
                	}
		}catch(SQLException ex){
			System.out.println("SQL Exception generated");
		}
	}
	
	
}

}
