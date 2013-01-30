// NAME : dbDump.java
//
// DESCRIPTION : dbDump is a java utility for dumping messages from tinyos
// motes to a database.  Currently the only database supported is MySQL, that
// being the one that we are using here at Harvard.  But support for other
// databases could be added without too much trouble.  Mainly the difficult
// portion of dbDump is reading info from the MIG-Generated classes and using
// that information to figure out how to extract the necessary info.
//
// Current dbDump supports both multiple message classes and multiple
// connections, to different motes and/or serial forwarders.  The classes are
// applied to all connections, although if it would be useful to associate
// them with a given connection that could be done.
//
// AUTHOR : Geoffrey Werner-Allen (gwa) : gwa@post.harvard.edu

import java.sql.*;
import java.util.*;
import java.io.*;
import java.text.*;
import java.lang.reflect.*;
import java.lang.Class;
import java.net.URL;
import java.net.URLClassLoader;
import java.lang.ClassLoader;
import net.tinyos.message.*;
import net.tinyos.packet.*;

import com.mysql.jdbc.Driver.*;
import com.mysql.jdbc.Blob.*;

@SuppressWarnings("unchecked")
public class dbDump
{

  // STATICALLY INITIALIZED DATA

  // Database Related Variables and Defaults

  
  // 08 Jul 2003 : GWA : The only database type currently supported.

  public static final String DEFAULT_DB_TYPE = "mysql";
  
//  public static final String DEFAULT_DB_HOST = "localhost";
public static final String DEFAULT_DB_HOST = "netlab.encs.vancouver.wsu.edu";
  public String dbHost = DEFAULT_DB_HOST;

  public static final int DEFAULT_DB_PORT = 3306;
  public int dbPort = DEFAULT_DB_PORT;
  
  public static final String DEFAULT_DB_DATABASE = "dbDumpDatabase";
  public String dbDatabase = DEFAULT_DB_DATABASE;

  // 05 Jan 2007 : GWA : Adding in some retries here.  I haven't seen this
  //                     more than twice, so hopefully this is OK.

  public static final int DEFAULT_DB_CONNECTION_ATTEMPTS = 5;
  public static final int DEFAULT_DB_CONNECTION_WAIT = 1000;

  public static final int DEFAULT_SF_CONNECTION_ATTEMPTS = 1000;
  public static final int DEFAULT_SF_CONNECTION_WAIT = 30000;

  public String dbConnection;

  public static final String DEFAULT_DB_USER = "dbDump";
  public String dbUser = DEFAULT_DB_USER;
  
  public static final String DEFAULT_DB_PASSWORD = "";
  public String dbPassword = DEFAULT_DB_PASSWORD;

  public static final boolean DEFAULT_DB_CREATE_TABLE = true;
  public boolean dbCreateTable = DEFAULT_DB_CREATE_TABLE;

  public static final String DEFAULT_DB_TABLE_NAME = "dbDumpTest";
  public String dbTablePrefix = DEFAULT_DB_TABLE_NAME;

  private static boolean DEFAULT_DB_USE_TIMESTAMP = true;
  private boolean dbUseTimestamp = DEFAULT_DB_USE_TIMESTAMP;

  private Connection dbCon;
  
  // 08 Jul 2003 : GWA : MySql specific constants to simplify certain
  //               things.

  public static final String MYSQL_CREATE_PREFIX = "CREATE TABLE";
  public static final String MYSQL_INSERT_PREFIX = "INSERT INTO";
 

  // Mote Connection / SF Related Defaults
  
  public static final String DEFAULT_SF_HOST = "localhost";
  public static final int DEFAULT_SF_PORT = 9000;
  public static final int DEFAULT_SF_GROUPID = -1;
  
  // 11 Aug 2003 : GWA : Used to hold information about how to connect to
  //               motes.

  private ArrayList moteInfo;
  
  // 08 Jul 2003 : GWA : No default here.

  private ArrayList classInfo;
  
  private static final String DEFAULT_MATCH_PREFIX = "get_";


  // 11 Aug 2003 : GWA : Used to hold information about each message class.

  private ArrayList messageInfo;

  private PreparedStatement dbPreparedStatement;
  private String dbPreparedStatementS;

  // 27 Oct 2003 : GWA : Various error strings passed to error().

  private static final String DBDUMP_CLASSFORNAME_ERROR = 
    "dbDump: Class.forName failed for class.  Exiting.";

  private static final String DBDUMP_METHODACCESS_ERROR =
    "dbDump: problem accessing method.  Exiting.";

  private static final String DBDUMP_DATABASECONNECT_ERROR =
    "dbDump: problem connecting to database.  Exiting.";

  private static final String DBDUMP_SFCONNECT_ERROR =
    "dbDump: problem connecting to serial forwarder. Ignoring this serial forwarder";

  private static final String DBDUMP_DBQUERY_ERROR = 
    "dbDump: could not execute database query.  Exiting.";

  private static final String DBDUMP_EXTRACT_ERROR =
    "dbDump: could not extract data from message.  Exiting.";

  private static final String DBDUMP_AMTYPE_ERROR = 
    "dbDump: could not extract AMTYPE from message class.  Exiting.";

  private static final String DBDUMP_UNSUPTYPE_ERROR =
    "dbDump: This message type is not supported." +
    "It will be omitted from the database tables.";
  
  private static final String DBDUMP_UNSUPFATAL_ERROR =
    "dbDump: This message type is not supported.  Exiting.";

  private static final String DBDUMP_REDIRECT_ERROR =
    "dbDump: Redirect failed.  File may not be accessible.  Exiting.";
  
  private static final String DBDUMP_THREADSTART_ERROR = 
    "dbDump: Error starting threads.  Exiting.";
  
  private static final String DBDUMP_MYSTERY_ERROR = 
    "dbDump: Detected error.  Exiting.";

  public static final boolean DBDUMP_VERBOSE = false;
  public boolean dbVerbose = DBDUMP_VERBOSE;

  public static final boolean DBCLASSES_AUTONUMBER = false;
  public boolean dbClassesAutonumber = DBCLASSES_AUTONUMBER;

  public boolean doTestOnly = false;

  // 11 Aug 2003 : GWA : Required constructor.  Doesn't do much.

  public dbDump() {
  }


  // NAME : parseClasses
  //
  // CALLED : by main() during static initialization.
  //
  // PURPOSE : extract information from the mig-generated java class files
  //           about message types.  Prepares various SQL statements, and
  //           structures describing each message class and, within each, the
  //           field formats themselves.
  //
  // 11 Aug 2003 : GWA : Changed to support multiple class files, hence
  //               multiple message types.  Now we store all of the
  //               information about each message in the above ArrayList,
  //               which is walked every time a message is received.
  //
  // 27 Oct 2003 : GWA : Changed again to support multiple database field
  //               types.  Single field support should now be fairly solid,
  //               although we're not making any promises about arrays.

  public void parseClasses() {
    
    // 27 Oct 2003 : GWA : Stores info for each registered class.

    ListIterator allClasses = classInfo.listIterator();

    while (allClasses.hasNext()) {

      dbDumpMessageInfo currentInfo = (dbDumpMessageInfo) allClasses.next();
      Class currentClass = currentInfo.classObj;

      // 11 Aug 2003 : GWA : Grab all the declared methods in the message
      //               class.

      Method internalArray[] = currentClass.getDeclaredMethods();
      currentInfo.fieldArray = new ArrayList();

      // 11 Aug 2003 : GWA : Extract the messageID field.  This is important
      //               when supporting multiple message classes because we
      //               want to know which template to apply to a given
      //               received message.
      // 
      // 27 Oct 2003 : GWA : Note that we currently make no effort to avoid
      //               AM_TYPE collisions.  This is the users responsibility
      //               and undefined behavior will result and probably crash
      //               dblogger.

      try {
        Field idField = currentClass.getField("AM_TYPE");
        currentInfo.messageType = idField.getInt(null);
      } catch (Exception e) {
        error(DBDUMP_AMTYPE_ERROR, e);
      }

      // 08 Jul 2003 : GWA : We pull all of the methods out of the class
      //               and search for ones that match our prefix.  This is
      //               very MIG-specific, which means that if the format
      //               of the MIG-generated file changes this will break.

      for (int i = 0; i < internalArray.length; i++) {
        
        String Name = ((Method) internalArray[i]).getName();
        
        // 27 Oct 2003 : GWA : Skip methods that don't match our prefix.

        if (!Name.startsWith(DEFAULT_MATCH_PREFIX)) {
            continue;
        }
       
        // 27 Oct 2003 : GWA : Allocate a new struct to hold the data that
        //               encapsulates each field of each class.

        dbDumpFieldInfo newInfo = new dbDumpFieldInfo();

        // 08 Jul 2003 : GWA : To get the MIG stem we trim off the 
        //               match prefix.  This also gives us the name that
        //               we use for the MySql database.
        //
        // 27 Oct 2003 : GWA : Again, no attempt to make sure that this is
        //               unique, although that's probably handled elsewhere.

        Name = Name.replaceFirst(DEFAULT_MATCH_PREFIX, "");

        // 08 Jul 2003 : GWA : Call various methods within the MIG class
        //               to gather static data about each field.
        
        // 27 Oct 2003 : GWA : We need to do a better job of assigning
        //               different java objects to MySQL field types.  For
        //               now, here's the assignments that we are working on.
        //
        //               JAVA   ------->  MySQL
        //               int              INTEGER
        //               short            MEDIUMINT
        //               float            FLOAT
        //               long             BIGINT
        //               byte             SMALLINT
        //
        // 27 Oct 2003 : GWA : All of the above seem to work.

        try {
          Method extractMethod = 
            currentClass.getDeclaredMethod("get_" + Name);
          Class extractClass = extractMethod.getReturnType();
          newInfo.type = extractClass.getName();
          
          // 27 Oct 2003 : GWA : When faced with a type that we don't
          //               support we want to react gracefully: what we'll
          //               do is just skip it.  Therefore it won't be in
          //               the database, but the rest of the fields should
          //               work fine.  
          //
          // 12 Dec 2003 : GWA : Adding support for array types.

          if ((!newInfo.type.equals("int")) &&
              (!newInfo.type.equals("short")) &&
              (!newInfo.type.equals("float")) &&
              (!newInfo.type.equals("long")) &&
              (!newInfo.type.equals("byte")) && 
              (!newInfo.type.equals("[B")) &&
              (!newInfo.type.equals("[S")) &&
              (!newInfo.type.equals("[I")) &&
              (!newInfo.type.equals("[J"))) {
            System.err.println(DBDUMP_UNSUPTYPE_ERROR + newInfo.type); 
            continue; 
          }
        } catch (Exception e) {
          error(DBDUMP_UNSUPFATAL_ERROR, e);
        }
        
        try {
            
          // 08 Jul 2003 : GWA : Retrieve various methods and apply
          //              them to generate static information about
          //              fields.

          Method isArrayM = currentClass.getDeclaredMethod("isArray_" + Name);
            
          newInfo.isArray = 
            ((Boolean) isArrayM.invoke(null)).booleanValue();
          
          Method sizeM;
          if (newInfo.isArray) {
            sizeM = currentClass.getDeclaredMethod("totalSize_" + Name);
          } else {
            sizeM = currentClass.getDeclaredMethod("size_" + Name);
          }

          // 08 Jul 2003 : GWA : Populate the fields of our new
          //               dbDumpInfo struct.

          newInfo.name = Name;
          newInfo.size = ((Integer) sizeM.invoke(null)).intValue();
          newInfo.get = internalArray[i];
      
        } catch (Exception e) {
          error(DBDUMP_METHODACCESS_ERROR, e);
        }
        
        currentInfo.fieldArray.add(newInfo);
      }


      // 08 Jul 2003 : GWA : Now assemble the statement to create the
      //               appropriate database.
      //               
      //               Note: currently the only two MySql fields used are
      //               int (for anything scalar) and tinyblob (for arrays).
      //               This would be one thing that could be improved in
      //               the future.
      
      // 11 Aug 2003 : GWA : Update to (try) and use unique table names for
      //               multiple class files, if they were passed.

      String dbCreateStatement = MYSQL_CREATE_PREFIX + " " + 
                                 dbTablePrefix + "_" +
                                 currentInfo.classID +  " ( "; 
      String dbPreparedStatementS = MYSQL_INSERT_PREFIX + " " + 
                                    dbTablePrefix + "_" +
                                    currentInfo.classID + " SET ";
      int i = 1;
      
      ListIterator dbInfoIt = currentInfo.fieldArray.listIterator();
      while (dbInfoIt.hasNext()) {

        dbDumpFieldInfo currentFieldInfo = (dbDumpFieldInfo) dbInfoIt.next();
        currentFieldInfo.index = i;
        i++;
        
        // 27 Oct 2003 : GWA : Added field handling here as well, pretty much
        //                     as described above.  We branch on the type of
        //                     object being returned by the accessor method
        //                     and use that to insert the proper database
        //                     field type.  For now we are going to leave the
        //                     array handling in place and just do this for
        //                     single fields, mainly because I think that
        //                     that actually might work.

        if (currentFieldInfo.isArray) {
            dbCreateStatement += currentFieldInfo.name + " TEXT";
        } else {
            if (currentFieldInfo.type.compareTo("int") == 0) {
              dbCreateStatement += currentFieldInfo.name +
                                   " INTEGER DEFAULT '0'";
            } else if (currentFieldInfo.type.compareTo("short") == 0) {
              dbCreateStatement += currentFieldInfo.name +
                                   " MEDIUMINT DEFAULT '0'";
            } else if (currentFieldInfo.type.compareTo("float") == 0) {
              dbCreateStatement += currentFieldInfo.name +
                                   " FLOAT DEFAULT '0'";
            } else if (currentFieldInfo.type.compareTo("long") == 0) {
              dbCreateStatement += currentFieldInfo.name +
                                   " BIGINT DEFAULT '0'";
            } else if (currentFieldInfo.type.compareTo("byte") == 0) {
              dbCreateStatement += currentFieldInfo.name + 
                                   " SMALLINT DEFAULT '0'";
            } else {
              // TODO : Should never get here (handled above).
            }
        }
   
        dbPreparedStatementS += currentFieldInfo.name + "=?";

        if (dbInfoIt.hasNext()) {
            dbPreparedStatementS += ", ";
            dbCreateStatement += ", ";
        }
      }
      
      dbPreparedStatementS += ", motelabMoteID=?;";
      dbCreateStatement += ", insert_time TIMESTAMP, motelabMoteID INT " +
                           ", motelabSeqNo INT AUTO_INCREMENT PRIMARY KEY);";

      currentInfo.createString = dbCreateStatement;
      currentInfo.insertString = dbPreparedStatementS;
    }

    return;
  }


  // NAME : establishBDConnection
  //
  // CALLED : by main() during static initialization.  
  //
  // PURPOSE : Sets up a database connection that all threads share.  Also
  //           prepares the statements that each message class will use to
  //           insert things into the database.  Also creates the databases
  //           that each message type will use.
  //
  // NOTES : This could be reworked to support another database, hopefully
  //         not requiring TOO much effort, but for now it's mySQL only.

  private void establishDBConnection() {

    // 11 Aug 2003 : GWA : Based on values set on the command line (and
    //               defaults), set up the DB connection string.

    dbConnection = "jdbc:"+DEFAULT_DB_TYPE;
    dbConnection += "://" + dbHost;
    dbConnection += ":" + dbPort;
    dbConnection += "/" + dbDatabase;

    // 11 Aug 2003 : GWA : Now, attempt a connection.

    boolean succeeded = false;
    Exception outsideE = null;

    for (int attemptCount = 0; 
         attemptCount < DEFAULT_DB_CONNECTION_ATTEMPTS; 
         attemptCount++) {
      succeeded = true;
      try {
        System.err.println("Attempting Connection...");
        Class.forName("com.mysql.jdbc.Driver");
        dbCon = DriverManager.getConnection(dbConnection, dbUser, dbPassword);
      } catch (Exception e) {
        outsideE = e;
        succeeded = false;
      }
      if (succeeded) {
        break;
      }
      synchronized(this) {
        
        java.util.Date currentDate = new java.util.Date();
       
        System.err.print("WARNING: Couldn't connect to database");
        System.err.print(" at time " + currentDate + ".");
        System.err.print(" Attempt " + attemptCount + "\n");
       
	System.err.println("trying to connect to " + dbConnection + " with " + dbUser + " and " + dbPassword);
 
        try {
          this.wait(DEFAULT_DB_CONNECTION_WAIT);
        } catch (Exception f) {}
      }
  }
    if (!succeeded) {
      error(DBDUMP_DATABASECONNECT_ERROR, outsideE);
    }

    // 11 Aug 2003 : GWA : Next try to create the databases for each message
    //               class and prepare the insert statements.

    try {
      ListIterator allClasses = classInfo.listIterator();
      Statement dbStatement = dbCon.createStatement();
      while (allClasses.hasNext()) {
        dbDumpMessageInfo currentInfo = (dbDumpMessageInfo) allClasses.next();
        
        // 27 Oct 2003 : GWA : Only print this if verbose is enabled.

        if (dbVerbose) {
          System.err.println(currentInfo.createString);
        }

        dbStatement.executeUpdate(currentInfo.createString);
        currentInfo.preparedStatement = 
          dbCon.prepareStatement(currentInfo.insertString);
      }
      dbStatement.close();
    } catch (Exception e) {
      error(DBDUMP_DBQUERY_ERROR, e);
    }
    
    return;
  }


  // NAME : executeStatement 
  //
  // CALLED ; By processMessage() each time a message is received and data
  //          needs to be added to the database.
  //
  // PURPOSE : Because mySQL is not synchronized and we'd prefer to avoid
  //           table locking, we build in the synchronization here.  This
  //           ensures that only one mySQL update is executing at any given
  //           time.

  private void executeStatement(PreparedStatement toExecute) {
    try {
      toExecute.execute(); 
    } catch (Exception e) {
        error(DBDUMP_DBQUERY_ERROR, e);
    }
    
    return;
  }


  // NAME : printInfo
  //
  // CALLED : By main() if the verbose option is enabled.
  //
  // PURPOSE : To dump information about classes that were discovered in the
  //           message class.  Eventually we are going to build in an option
  //           that allows us to just dump this information for diagnostic
  //           purposes.

  private void printInfo () {
  
    System.out.println("EXTRACTED MESSAGE CLASSES:");

    ListIterator allClasses = classInfo.listIterator();
    
    int i = 1;

    while (allClasses.hasNext()) {
    
      dbDumpMessageInfo currentInfo = (dbDumpMessageInfo) allClasses.next();
      System.out.println("CLASS " + i + ".");
      ListIterator dbInfoIt = currentInfo.fieldArray.listIterator();
      System.out.println(currentInfo.toString());
      int j = 1;
      while (dbInfoIt.hasNext()) {
          System.out.println("\tFIELD " + j + ".");
          dbDumpFieldInfo current = (dbDumpFieldInfo) dbInfoIt.next();
          System.out.println(current.toString());
          j++;
      }
      i++;
    }

    return;
  }

  
  // NAME : processMessage
  //
  // CALLED : The eventual destination of the callbacks registered with
  //          moteIF.
  //
  // PURPOSE : Actual does the work of unpacking a message and dumping the
  //           fields into the database.  Takes a messageType from the actual
  //           callback registered with moteIF and uses that to process the
  //           passed message.

  public synchronized void processMessage(int dest_addr, Message msg, 
                                          dbDumpMessageInfo messageType) {

    // 18 Aug 2003 : GWA : Holds the information about each field.

    ListIterator dbDataGet = messageType.fieldArray.listIterator();
    
    // 18 Aug 2003 : GWA : We've already preprocessed this message to make
    //               this a tad bit faster.

    PreparedStatement dbPreparedStatement = messageType.preparedStatement;

    // 18 Aug 2003 : GWA : Loop through the fields and insert information
    //               into our database statement.

    int currentIndex = 0;
    while (dbDataGet.hasNext()) {
        
      dbDumpFieldInfo current = (dbDumpFieldInfo) dbDataGet.next();
      try {
        Object data = current.get.invoke(msg);
        
        // 18 Aug 2003 : GWA : Right now arrays go into a 'BLOB' MySQL type.
        //               This is kind of unfortunate because that type
        //               doesn't view well from the MySQL console.  But it's
        //               the best thing that we could think up and someday
        //               maybe we'll do something smarter.  For now we just
        //               try and avoid using arrays in messages.
        //
        // 15 Dec 2003 : GWA : Changed this to put bytes/int arrays into
        //               BLOB's, char arrays into TEXT for easy reading.
        //
        // 15 Dec 2003 : GWA : Just kidding, everything goes in TEXT.  The
        //               types are pretty much equivalent except for, AFAICT,
        //               TEXT types are visible in mysql whereas BLOB types
        //               are not.

        if (current.isArray) {
          if (current.type.compareTo("[B") == 0) {
            byte byteArray[] = (byte []) data;
            dbPreparedStatement.setBytes(current.index, byteArray);
          
          } else if (current.type.compareTo("[S") == 0) {
            short shortArray[] = (short []) data;
            ByteArrayOutputStream byteStream = new ByteArrayOutputStream();
            
            for (int i = 0; i < shortArray.length; i++) {
                byteStream.write(shortArray[i] >> 8);
                byteStream.write(shortArray[i]);
            }
            
            byte byteArray[] = byteStream.toByteArray();
            dbPreparedStatement.setBytes(current.index, byteArray);
        
          } else if (current.type.compareTo("[I") == 0) {
            int intArray[] = (int []) data;
            ByteArrayOutputStream byteStream = new ByteArrayOutputStream();

            for (int i = 0; i < intArray.length; i++) {
                byteStream.write(intArray[i] >> 24);
                byteStream.write(intArray[i] >> 16);
                byteStream.write(intArray[i] >> 8);
                byteStream.write(intArray[i]);
            }

            byte byteArray[] = byteStream.toByteArray();
            dbPreparedStatement.setBytes(current.index, byteArray);
            
          } else if (current.type.compareTo("[J") == 0) {
            long longArray[] = (long []) data;
            ByteArrayOutputStream byteStream = new ByteArrayOutputStream();

            for (int i = 0; i < longArray.length; i++) {
                byteStream.write((int) longArray[i] >> 56);
                byteStream.write((int) longArray[i] >> 48);
                byteStream.write((int) longArray[i] >> 40);
                byteStream.write((int) longArray[i] >> 32);
                byteStream.write((int) longArray[i] >> 24);
                byteStream.write((int) longArray[i] >> 16);
                byteStream.write((int) longArray[i] >> 8);
                byteStream.write((int) longArray[i]);
            }

            byte byteArray[] = byteStream.toByteArray();
            dbPreparedStatement.setBytes(current.index, byteArray);
          }
        } else {

          // 27 Oct 2003 : GWA : Add handling for various column types.
          
          if (current.type.compareTo("int") == 0) {
            dbPreparedStatement.setInt(current.index, 
                                       ((Integer) data).intValue()); 
          } else if (current.type.compareTo("short") == 0) {
            dbPreparedStatement.setShort(current.index, 
                                         ((Short) data).shortValue()); 
          } else if (current.type.compareTo("float") == 0) {
            dbPreparedStatement.setFloat(current.index, 
                                         ((Float) data).floatValue()); 
          } else if (current.type.compareTo("long") == 0) {
            dbPreparedStatement.setLong(current.index, 
                                        ((Long) data).longValue()); 
          } else if (current.type.compareTo("byte") == 0) {
            dbPreparedStatement.setByte(current.index, 
                                        ((Byte) data).byteValue()); 
          } else {

            // 27 Oct 2003 : GWA : Shouldn't ever get here.
            
            error(DBDUMP_MYSTERY_ERROR, null);
          }
        }
        
        currentIndex = current.index;

      } catch (Exception e) {
        error(DBDUMP_EXTRACT_ERROR, e);
      }
    }
    
    try {
      dbPreparedStatement.setInt(currentIndex + 1, 
                                 messageType.moteID);
    } catch (Exception e) {
      error(DBDUMP_EXTRACT_ERROR, e);
    }

    executeStatement(dbPreparedStatement);

    return;
  }

  
  // NAME : error
  //
  // CALLED : Whenever something sucks big-time.
  //
  // PURPOSE : Private error handler.

  private static void error(String error, Exception e) {
    error(error, e, true);
  }

  private static void error(String error, Exception e, boolean doShutdown) {
      System.err.println("DBLOGGER ERROR: " + error);
      if (e != null) {
        e.printStackTrace();
      }
      if (doShutdown) {
        System.exit(-1);
      }
  }

  // NAME : main
  //
  // PURPOSE : main execution engine.  Creates an object of type dbDump and
  //           calls the requisite methods required to execute things.

  public static void main(String[] args) {
   
    // 11 Aug 2003 : GWA : Create our object.

    dbDump ourDBDump = new dbDump();

    // 11 Aug 2003 : GWA : Initialize certain globals.
    
    ourDBDump.moteInfo = new ArrayList();
    ourDBDump.classInfo = new ArrayList();

    // 11 Aug 2003 : GWA : Parse command line arguments.

    ourDBDump.processArgs(args);
    
    // 11 Aug 2003 : GWA : Parse message classes.

    ourDBDump.parseClasses();

    // 14 Jul 2006 : GWA : Adding an option here to only test the provided
    //               classes for correctness, rather than do anything.
    //               Hopefully this is really this simple.

    if (ourDBDump.doTestOnly) {
      return;
    }

    // 11 Aug 2003 : GWA : Hook up to the database, creating tables and such.

    ourDBDump.establishDBConnection();

    // 14 Jul 2006 : GWA : We should ALWAYS do this.

    ourDBDump.printInfo();
    
    ourDBDump.startThreads();
  
    return;
  }


  // NAME : startThreads
  //
  // CALLED : by main.
  //
  // DESCRIPTION : get the ball rolling: fire up all the threads that we
  //               created and initialized, which will connect and then we're
  //               done.

  private void startThreads() {

    ListIterator allMotes = moteInfo.listIterator();
    
    int threadID = 1;
    
    while (allMotes.hasNext()) {

      String[] currentInfo = (String []) allMotes.next();

      dbConnection newConnection = new dbConnection(currentInfo, threadID);
      Thread current = new Thread(newConnection);
      newConnection.setMe(current);
      current.start();

      threadID += 1;
    }

    return;
  }


  // NAME : processArgs
  // 
  // CALLED : First private function called by main.
  //
  // PURPOSE : Process command line args and set up our global and static
  //           variables appropriately.  

  private void processArgs(String[] args) {
      
    boolean seenConnect = false;
    boolean seenClasses = false;
    boolean seenTestOnly = false;

    for (int i = 0; i < args.length; i++) {

      Integer convertInt = new Integer(0);

      if (args[i].equals("--dbHost")) {
      
        if (++i >= args.length) { usage(args);}
        
        dbHost = args[i];

      } else if (args[i].equals("--dbPort")) {
          
        if (++i >= args.length) { usage(args);}
        
        dbPort = convertInt.valueOf(args[i]).intValue();

      } else if (args[i].equals("--dbDatabase")) {

        if (++i >= args.length) { usage(args);}
        
        dbDatabase = args[i];

      } else if (args[i].equals("--dbUser")) {

        if (++i >= args.length) { usage(args);}
       
        dbUser = args[i];

      } else if (args[i].equals("--dbPassword")) {
          
        if (++i >= args.length) { usage(args);}
          
        dbPassword = args[i];

      } else if (args[i].equals("--dbNoNewTable")) {

        dbCreateTable = false;
        dbUseTimestamp = false;

      } else if (args[i].equals("--dbTablePrefix")) {

        if (++i >= args.length) { usage(args);}
        
        dbTablePrefix = args[i];

      } else if (args[i].equals("--dbNoTimestamp")) {

        dbUseTimestamp = false;
      
      } else if (args[i].equals("--classesAutonumber")) {

        dbClassesAutonumber = true;

      } else if (args[i].equals("--verbose")) {
        
        dbVerbose = true;
      
      } else if (args[i].equals("--redirect")) {
        
        if (++i >= args.length) { usage(args);}
        
        // 27 Oct 2003 : GWA : Do real error redirecting that should work.
        
        try {
          System.setOut(new PrintStream (new FileOutputStream (args[i])));
          System.setErr(new PrintStream (new FileOutputStream (args[i])));
        } catch (Exception e) {
          error(DBDUMP_REDIRECT_ERROR, e);
        }
      } else if (args[i].equals("--redirectOutput")) {
        
        if (++i >= args.length) { usage(args);}
        
        // 27 Oct 2003 : GWA : Do real error redirecting that should work.
        
        try {
          System.setOut(new PrintStream (new FileOutputStream (args[i])));
        } catch (Exception e) {
          error(DBDUMP_REDIRECT_ERROR, e);
        }
      } else if (args[i].equals("--redirectError")) {
        
        if (++i >= args.length) { usage(args);}
        
        // 27 Oct 2003 : GWA : Do real error redirecting that should work.
        
        try {
          System.setErr(new PrintStream (new FileOutputStream (args[i])));
        } catch (Exception e) {
          error(DBDUMP_REDIRECT_ERROR, e);
        }
      } else if (args[i].equals("--testOnly")) {
     
        doTestOnly = true;
        seenTestOnly = true;

      } else if (args[i].equals("--connect")) {
       
        // 11 Aug 2003 : GWA : Store this to compare it below.

        int compareIndex = i;
        
        if (++i >= args.length) { usage(args);}

        // 11 Aug 2003 : GWA : We walk until we see the next option.

        for (; (i < args.length) && 
               (!(args[i].startsWith("--")));
               i++) {
          
          // 11 Aug 2003 : GWA : We'll actually do the string
          //               disassembly here, in order to do error
          //               checking during startup.

          String[] moteInfoString = args[i].split(":");
          if (moteInfoString.length > 4) { usage(args); }

          // 11 Aug 2003 : GWA : We could do some checking here to make
          //               sure that things are in the proper format,
          //               but I'm going to defer that for now.

          moteInfo.add(moteInfoString); 
        }

        // 11 Aug 2003 : GWA : Must have at least one mote if using
        //               this option.

        if (compareIndex == i) { usage(args); }
      
        seenConnect = true;
        i -= 1;

      } else if (args[i].equals("--classes")) {

        int compareIndex = i;
        int classID = 1;

        // 12 Aug 2003 : GWA : We need to know where the classes are 
        //               supposed to be.

        if (++i >= args.length) { usage(args);}

        ClassLoader sysClassLoader = ClassLoader.getSystemClassLoader();

        URL[] urls = ((URLClassLoader)sysClassLoader).getURLs();
       
        try {

          for (; (i < args.length) && 
                 (!(args[i].startsWith("--")));
                 i++) {
           
            // 11 Aug 2003 : GWA : We might as well do this now.  We could
            //               wait until later but we'd rather break here.
          
            Class currentMessageClass = Class.forName(args[i]);
            
            // 11 Aug 2003 : GWA : Create a new object to describe this
            //               message class, initialize the Class Object
            //               element, and add it to the list.

            dbDumpMessageInfo newInfo = new dbDumpMessageInfo();
            
            // 11 Aug 2003 : GWA : Currently for the name we just use the
            //               name the java class returns.

            newInfo.name = currentMessageClass.getName();
            newInfo.classObj = currentMessageClass;
            classInfo.add(newInfo);

            if (!dbClassesAutonumber) {
              i += 1;
              if ((i >= args.length) || (args[i].startsWith("--"))) {
                usage(args);
              }
              try {
                newInfo.classID = Integer.parseInt(args[i]);
              } catch (Exception e) {
                usage(args);
              }
            } else {
              newInfo.classID = classID++;
            }
          }
        } catch (Exception e) {
          error(DBDUMP_CLASSFORNAME_ERROR + args[i], e);
        }
        
        if (compareIndex == i) { usage(args);}
        
        seenClasses = true;
        i -= 1;
      }
    }
  
    if ((!seenTestOnly && !seenConnect) || !seenClasses) { usage(args);}
   
    // 11 Aug 2003 : GWA : Continue setup process.  If the user wants us to
    //               use a timestamp on the table name, add that here.

    if (dbUseTimestamp) {
        StringBuffer dbNewTableName = new StringBuffer(dbTablePrefix + "_");
        SimpleDateFormat tempDate = new SimpleDateFormat("yyyyMMddHHmmss"); 
        java.util.Date currentDate = new java.util.Date();
        FieldPosition beginning = new FieldPosition(0);
        tempDate.format(currentDate, dbNewTableName, beginning);
        dbTablePrefix = dbNewTableName.toString();
    }
  
    return;
  }

  
  // NAME : usage
  //
  // CALLED : mainly from processArgs when the user is causing a problem.
  //
  // PURPOSE : inform joe user that they are clueless.
 
  private void usage(String[] args) {
    
    String Usage = new String("");
    Usage += "Usage : dbDump [--dbHost database_hostname (localhost)]\n";
    Usage += "        [--dbPort database_port_num (3306)]\n";
    Usage += "        [--dbDatabase database_name (dbDumpDatabase)]\n";
    Usage += "        [--dbUser database_username (dbDump)]\n";
    Usage += "        [--dbPassword database_password (\"\")\n";
    Usage += "        [--dbNoNewTable]\n";
    Usage += "        [--dbTablePrefix (dbDumpTest)]\n";
    Usage += "        [--dbNoTimestamp]\n";
    Usage += "        [--classesAutonumber]\n";
    Usage += "        [--verbose]\n";
    Usage += "        [--classLocation]\n";
    Usage += "        [--connect host:port:GID, host2:port:GID, ...]\n";
    Usage += "        [--classes class [classID], class2 [classID] ...]\n";
    Usage += "        [--redirect file]\n";
    System.out.print(Usage);
    System.exit(-1);

    // 18 Aug 2003 : GWA : Does not return.
  }
 
  
  // NAME : dbConnection
  //
  // PURPOSE : Encapsulate information about each distinct mote/serial
  //           forwarder connection that we need to make.  Implements a
  //           thread interface.

  class dbConnection implements Runnable, PhoenixError
  {
    private String connectString;
    private int connectPort;
    private int connectGID;
    private int threadID;
    private MoteIF sf;
    public int moteID;
    private Thread me;
    private PhoenixSource ourPhoenix = null;
    private int attemptCount;
    private boolean connected;
    
    // NAME : dbConnection
    //
    // PURPOSE : Set up our private information on creation.  Parses the
    //           connect string passed in by the user.  We could (and perhaps
    //           should) do this during argument parsing so that we can catch
    //           errors there, but for now it's here.

    dbConnection(String[] connect, int ID) {
      connectString = connect[0];
      
      if ((connect.length > 1) && !(connect[1].equals(""))) {
        connectPort = Integer.parseInt(connect[1]);
      } else {
        connectPort = DEFAULT_SF_PORT;
      }
      
      if ((connect.length > 2) && !(connect[2].equals(""))) {
        connectGID = Integer.parseInt(connect[2]);
      } else {
        connectGID = DEFAULT_SF_GROUPID;
      }

      if ((connect.length > 3) && !(connect[3].equals(""))) {
        moteID = Integer.parseInt(connect[3]);
      } else {
        moteID = 0;
      }
      
      // 13 Aug 2003 : GWA : Probably for display purposes only.

      threadID = ID;
      attemptCount = 0;
      connected = false;
    }

    public void setMe(Thread myself) {
      me = myself;
    }

    // NAME : run
    //
    // CALLED : On thread start.
    // 
    // PURPOSE : Not too complicated.  Connect to the mote/sf and register 
    //           all of the known message types.  Then sit back and wait for
    //           stuff to happen.
   
    private void tryConnect() {
      System.err.println("TRYING TO CONNECT " + attemptCount);
      try {
        if (ourPhoenix != null) {
          ourPhoenix.shutdown();
        }
        ourPhoenix = 
          BuildSource.makePhoenix("sf@" + connectString + ":" +
                                  connectPort, null);
        ourPhoenix.setPacketErrorHandler(this);
        sf = new MoteIF(ourPhoenix);
      
        ListIterator allClasses = classInfo.listIterator();
        
        while (allClasses.hasNext()) {
          dbDumpMessageInfo currentInfo = 
            ((dbDumpMessageInfo) allClasses.next()).ourClone();
          currentInfo.moteID = this.moteID;
          sf.registerListener((Message) currentInfo.classObj.newInstance(),
                              currentInfo);
        }

      } catch (Exception e) {
        // 03 Jan 2007 : GWA : I'm not sure very many errors come here, and
        //               it's hard to handle so forget it.
        connected = false;
        ourPhoenix.shutdown();
      }
      return;
    }

    public void run() {
      tryConnect();
      return;
    }

    public void error (java.io.IOException e) {
      attemptCount++;
      connected = false;

      if (attemptCount < DEFAULT_SF_CONNECTION_ATTEMPTS) {
        
        java.util.Date currentDate = new java.util.Date();
       
        System.err.print("WARNING: Couldn't connect to " + moteID);
        System.err.print(" at time " + currentDate + ".");
        System.err.print(" Attempt " + attemptCount + "\n");

        synchronized(this) {
          try {
            this.wait(DEFAULT_SF_CONNECTION_WAIT);
          } catch (Exception f) {}
        }

        tryConnect();
        return;
      } else {
        // 14 Jul 2006 : GWA : Improve error handling.
        System.err.println("DBLOGGER ERROR: " + DBDUMP_SFCONNECT_ERROR);
        if (e != null) {
          e.printStackTrace();
        }
        
        // 07 Dec 2003 : GWA : I know that this is unsafe, but since the
        //               threads in this application are more or less
        //               independent this is going to have to do for now.  In
        //               the future we probably want to pass an exception up
        //               and let it be handled here in a loop of some sort.
        
        ourPhoenix.shutdown();
      }
    }
  }


  // NAME : dbDumpMessageInfo
  //
  // PURPOSE : Encapsulate information about one message type.  Includes the
  //           callback that we register with MoteIF in order to allow our
  //           general message processing / database insertion function above
  //           to distinguish between various message types.

  class dbDumpMessageInfo implements MessageListener, Cloneable
  {
    public String name;
    public Class classObj;
    public int messageType;
    public ArrayList fieldArray;
    public String createString;
    public String insertString;
    public PreparedStatement preparedStatement;
    public int classID;
    public int moteID;

    public String toString() {
      String assemble = new String();
      assemble += "\tCLASSNAME: " + name;
      assemble += "\n\tAM ID: " + messageType;
      //assemble += ", toCreate: " + createString;
      //assemble += ", toInsert: " + insertString + "\n";
      return assemble;
    }

    // 13 Aug 2003 : GWA : This is the callback that we register for each
    //               message type.  Simply calls into our general message
    //               processing function above including this class which
    //               includes information about how to extract the necessary
    //               fields and how to insert them into the database.

    public void messageReceived(int dest_addr, Message msg) {
      processMessage(dest_addr, msg, this);
      return;
    }
    
    public dbDumpMessageInfo ourClone() {
      dbDumpMessageInfo newInfo = new dbDumpMessageInfo();
      newInfo.name = this.name;
      newInfo.classObj = this.classObj;
      newInfo.messageType = this.messageType;
      newInfo.fieldArray = this.fieldArray;
      newInfo.createString = this.createString;
      newInfo.insertString = this.insertString;
      newInfo.preparedStatement = this.preparedStatement;
      newInfo.classID = this.classID;
      
      return newInfo;
    }
  }
 
  
  // NAME : dbDumpFieldInfo
  //
  // PURPOSE : Encapsulate information about one field of a given message
  //           type.  

  class dbDumpFieldInfo 
  {
    public String name;
    public boolean isArray;
    public int size;
    public Method get;
    public int index;
    public String type;

    public String toString() {
      String assemble = new String();
      assemble = "\t\tNAME: " + name +
                 "\n\t\tINDEX: " + index +
                 "\n\t\tISARRAY: " + isArray +
                 "\n\t\tTYPE: " + type +
                 "\n\t\tSIZE: " + size;
      return assemble;
    }
  }
}

