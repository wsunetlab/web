JAVAC=/usr/bin/javac
JAR=/usr/bin/jar
TINYOS=tinyos.jar
JDBC=mysql-connector-java-5.1.10-bin.jar
dbDump.jar: dbDump.java
	$(JAR) xf $(TINYOS)
	rm -rf META-INF
	$(JAR) xf $(JDBC)
	rm -rf META-INF
	$(JAVAC) -classpath $(TINYOS):$(JDBC) dbDump.java
	$(JAR) cmf dbDump.manifest dbDump.jar *.class
	$(JAR) uf dbDump.jar net com org
	rm -rf *.class net org com
dbDump.java:
clean:
	rm -f dbDump.jar *.class
