package hellomote;
import java.io.*;
import java.util.*;
import java.sql.*;
import java.text.*;

public class AnalyzeConnectivity {

	/**
	 * @param args
	 */
	static String userid="root", password="linhtinh";
        static String url = "jdbc:mysql://netlab.encs.vancouver.wsu.edu:3306/auth";
        static Connection con = null;
        static Statement stmt = null;
        static PreparedStatement moteDataStatement = null,moteInsertStatement = null;
	static Statement moteCreateTableStat = null, linkQualityTableStat = null;


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

	public static String getDateTime(){
		Calendar currentDate = Calendar.getInstance();
  		SimpleDateFormat formatter = new SimpleDateFormat("MM_dd_yyyy_HH_mm_ss");
  		String dateNow = formatter.format(currentDate.getTime());
 // 		System.out.println("Date :  " + dateNow);
		return dateNow;
	}

	public static void main(String[] args) {
		String strLine;
		StringTokenizer stringTokenizer;
		String tokenArray[] = null;
		int INF_VALUE = 9999999;
		List<String> moteIdList;
		String jobID, topologyId;
		if(args.length == 0){
		  jobID = null;
		  topologyId = null;
		}else{
				
		  jobID = args[0];
		  topologyId = args[1];
		}

	//	int noOfMotes = 3;
	try{
		Connection con = getJDBCConnection();
        	moteDataStatement = con.prepareStatement("select moteid,ip_addr from auth.motes where active='1'");
        	ResultSet rs = moteDataStatement.executeQuery();

        	moteIdList = new ArrayList<String>();
	
        	while(rs.next()){
                	String moteId = rs.getString("moteid");
                	moteIdList.add(moteId);               
        	}

		int noOfMotes = moteIdList.size();
		int noOfFiles = noOfMotes;
//		System.out.println("No of Motes: "+noOfMotes + " No of Files: " + noOfFiles);

		int maxMsgFromSToR[][] = new int[10][10];

	//	int maxMsgFromSToR[][] = new int[noOfMotes][noOfMotes];
		int minMsgFromSToR[][] = new int[10][10];

	//	int minMsgFromSToR[][] = new int[noOfMotes][noOfMotes];
		int totalMsgFromSToR[][] = new int[10][10];

	//	int totalMsgFromSToR[][] = new int[noOfMotes][noOfMotes];
		double prr[][] = new double[noOfMotes][noOfMotes];

		for (int i = 0; i < noOfMotes; i++) {
			for (int j = 0; j < noOfMotes; j++) {

				if (j == i)
					continue;
				else {
		int arrI = Integer.parseInt(moteIdList.get(i).toString());
		int arrJ = Integer.parseInt(moteIdList.get(j).toString());

		//minMsgFromSToR[i][j] = INF_VALUE;
		minMsgFromSToR[arrI][arrJ] = INF_VALUE;
					
 // minMsgFromSToR[Integer.parseInt(moteIdList.get(i).toString())][Integer.parseInt(moteIdList.get(j).toString())] = INF_VALUE;
				}
				
			}
		}
	
	moteCreateTableStat = con.createStatement();
	String currentDate = getDateTime();

	moteCreateTableStat.executeUpdate("create table auth.data_"+currentDate+"(id INT NOT NULL AUTO_INCREMENT, PRIMARY KEY(id), send_addr varchar(100), msg_counter varchar(100), rec_addr varchar(100), time_Stamp DATETIME, topology_id varchar(100), job_id varchar(100))");

	int l=0;



	
	for (l = 0; l < noOfFiles; l++){
	//	System.out.println("Current Fl No:"+ l);	

// Modified by Jenis & Date: Feb 13 2013: Used mote id list to identify file .
//	System.out.println("Moteid:"+moteIdList.get(l).toString());
	String fileName = "/var/www/web/daemon/hellomote/USB".concat((moteIdList.get(l).toString()).concat("Data.txt"));

//	System.out.println("File name: " + fileName);

	FileInputStream fstream = new FileInputStream(fileName);
	DataInputStream in = new DataInputStream(fstream);
	BufferedReader br = new BufferedReader(new InputStreamReader(in));

	List<String[]> tokenList = new ArrayList<String[]>();
	
	while ((strLine = br.readLine()) != null) {
//		System.out.println("cmg in loop to read the data: "+strLine);	
		stringTokenizer = new StringTokenizer(strLine);
//		System.out.println("StringTokenizer:"+stringTokenizer);
		int i = 0;
		
		tokenArray = new String[13];
	
		while (stringTokenizer.hasMoreElements()) {
			tokenArray[i] = (String) stringTokenizer.nextElement();
			i++;
		//	System.out.println("Tokens:"+tokenArray[i]);
		}

		String msg_hex = tokenArray[8].concat(tokenArray[9]);
		int msg_decimal = Integer.parseInt(msg_hex, 16);
		int receiver_node = Integer.parseInt(tokenArray[4]);
	//	int sender_node = Integer.parseInt(tokenArray[tokenArray.length - 1]);

		//TODO	
		int sender_node = Integer.parseInt(tokenArray[10]);

//		System.out.println("Msg Decimal:"+msg_decimal);
//		System.out.println("Sender Node:"+sender_node);
//		System.out.println("Receiver node:"+receiver_node);

		moteCreateTableStat.executeUpdate("insert into auth.data_"+currentDate+"(send_addr,msg_counter,rec_addr,time_Stamp,topology_id,job_id) values ("+Integer.toString(sender_node)+","+Integer.toString(msg_decimal)+","+Integer.toString(receiver_node)+","+ "NOW()"+","+topologyId+","+jobID+")");


		totalMsgFromSToR[receiver_node][sender_node]++;

		if (msg_decimal > maxMsgFromSToR[receiver_node][sender_node]){				
			maxMsgFromSToR[receiver_node][sender_node] = msg_decimal;
		}
		
		if (msg_decimal < minMsgFromSToR[receiver_node][sender_node]){
			minMsgFromSToR[receiver_node][sender_node] = msg_decimal;
		}

		tokenList.add(tokenArray);
	}
//	System.out.println("Current l:"+l);

	in.close();
}

	linkQualityTableStat = con.createStatement();
	linkQualityTableStat.executeUpdate("drop table if exists auth.linkQuality");
        linkQualityTableStat.executeUpdate("create table auth.linkQuality(id INT NOT NULL AUTO_INCREMENT, PRIMARY KEY(id), send_addr varchar(100), PRR varchar(100), rec_addr varchar(100))");

	for (int i = 0; i < noOfMotes; i++) {
		for (int j = 0; j < noOfMotes; j++) {
			if (j == i)
			continue;
			else {
		int moteI = Integer.parseInt(moteIdList.get(i).toString());	
		int moteJ = Integer.parseInt(moteIdList.get(j).toString());

//			prr[i][j] = (double) totalMsgFromSToR[i][j]/ (maxMsgFromSToR[i][j] - minMsgFromSToR[i][j] + 1)* 100;

			prr[i][j] = (double) totalMsgFromSToR[moteI][moteJ]/ (maxMsgFromSToR[moteI][moteJ] - minMsgFromSToR[moteI][moteJ] + 1)* 100;

//			 linkQualityTableStat.executeUpdate("insert into auth.linkQuality"+"(send_addr,PRR,rec_addr) values ("+Integer.toString(i)+","+prr[i][j]+","+Integer.toString(j)+")");

			 linkQualityTableStat.executeUpdate("insert into auth.linkQuality"+"(send_addr,PRR,rec_addr) values ("+Integer.toString(moteI)+","+prr[i][j]+","+Integer.toString(moteJ)+")");
			System.out.println("Sender: "+ moteI+ " Receiver: "
					+ moteJ+ " Actual Number of Msg Received: "
					+ totalMsgFromSToR[moteI][moteJ]
					+ " Expected Number of Msg Received: "
					+ (maxMsgFromSToR[moteI][moteJ]
					- minMsgFromSToR[moteI][moteJ] + 1)
					+ " Packet reception Ratio: "
					+ prr[i][j] + "%");
					}
				}
			} 
	} catch (Exception e) {
			e.printStackTrace();
			System.err.println("Error: " + e);
			System.out.println("Error:"+e.getMessage());
			
	}

}

}
