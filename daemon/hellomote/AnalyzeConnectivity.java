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
  		System.out.println("Date :  " + dateNow);
		return dateNow;
	}

	public static void main(String[] args) {
		String strLine;
		StringTokenizer stringTokenizer;
		String tokenArray[] = null;
		int INF_VALUE = 9999999;
	//	int noOfMotes = 3;
	try{
	Connection con = getJDBCConnection();
        moteDataStatement = con.prepareStatement("select moteid,ip_addr from auth.motes 	where active='1'");
        ResultSet rs = moteDataStatement.executeQuery();

        List moteIdList = new ArrayList();
	
        while(rs.next()){
                String moteId = rs.getString("moteid");
                moteIdList.add(moteId);               
        }

		int noOfMotes = (int) moteIdList.size();
		int noOfFiles = noOfMotes;

		int maxMsgFromSToR[][] = new int[noOfMotes][noOfMotes];
		int minMsgFromSToR[][] = new int[noOfMotes][noOfMotes];
		int totalMsgFromSToR[][] = new int[noOfMotes][noOfMotes];
		double prr[][] = new double[noOfMotes][noOfMotes];

		for (int i = 0; i < noOfMotes; i++) {
			for (int j = 0; j < noOfMotes; j++) {
				if (j == i)
					continue;
				else {
					minMsgFromSToR[i][j] = INF_VALUE;
				}
			}
		}
	
	moteCreateTableStat = con.createStatement();
	String currentDate = getDateTime();
	moteCreateTableStat.executeUpdate("create table auth.data_"+currentDate+"(id INT NOT NULL AUTO_INCREMENT, PRIMARY KEY(id), send_addr varchar(100), msg_counter varchar(100), rec_addr varchar(100), time_Stamp DATETIME)");

	for (int currentFileNo = 0; currentFileNo < noOfFiles; currentFileNo++) 		{
	
//	String fileName = "/opt/tinyos-2.x/apps/RadioCountToLeds/USB".concat(Integer.toString(currentFileNo).concat("Data.txt"));
// String fileName = "/var/www/web/html/USB".concat(Integer.toString(currentFileNo).concat("Data.txt"));
String fileName = "/var/www/web/daemon/hellomote/USB".concat(Integer.toString(currentFileNo).concat("Data.txt"));
	FileInputStream fstream = new FileInputStream(fileName);
	DataInputStream in = new DataInputStream(fstream);
	BufferedReader br = new BufferedReader(new InputStreamReader(in));
	List<String[]> tokenList = new ArrayList<String[]>();
	
	while ((strLine = br.readLine()) != null) {
		
		stringTokenizer = new StringTokenizer(strLine);
		
		int i = 0;
		
		tokenArray = new String[12];
	
		while (stringTokenizer.hasMoreElements()) {
			tokenArray[i] = (String) stringTokenizer.nextElement();
			i++;
		}

		String msg_hex = tokenArray[8].concat(tokenArray[9]);
		int msg_decimal = Integer.parseInt(msg_hex, 16);
		int receiver_node = Integer.parseInt(tokenArray[4]);
		int sender_node = Integer.parseInt(tokenArray[tokenArray.length - 1]);
		
		moteCreateTableStat.executeUpdate("insert into auth.data_"+currentDate+"(send_addr,msg_counter,rec_addr,time_Stamp) values ("+Integer.toString(sender_node)+","+Integer.toString(msg_decimal)+","+Integer.toString(receiver_node)+","+ "NOW())");

		totalMsgFromSToR[receiver_node][sender_node]++;

		if (msg_decimal > maxMsgFromSToR[receiver_node][sender_node])				maxMsgFromSToR[receiver_node][sender_node] = msg_decimal;
		
		if (msg_decimal < minMsgFromSToR[receiver_node][sender_node])
		minMsgFromSToR[receiver_node][sender_node] = msg_decimal;

		tokenList.add(tokenArray);
	}

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
			prr[i][j] = (double) totalMsgFromSToR[i][j]/ (maxMsgFromSToR[i][j] - minMsgFromSToR[i][j] + 1)* 100;

			 linkQualityTableStat.executeUpdate("insert into auth.linkQuality"+"(send_addr,PRR,rec_addr) values ("+Integer.toString(i)+","+prr[i][j]+","+Integer.toString(j)+")");

			System.out.println("Sender: "+ i+ " Receiver: "
					+ j+ " Actual Number of Msg Received: "
					+ totalMsgFromSToR[i][j]
					+ " Expected Number of Msg Received: "
					+ (maxMsgFromSToR[i][j]
					- minMsgFromSToR[i][j] + 1)
					+ " Packet reception Ratio: "
					+ prr[i][j] + "%");
					}
				}
			}
	} catch (Exception e) {
			System.err.println("Error: " + e);
	}

}

}
