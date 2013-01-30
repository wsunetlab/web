#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <sys/time.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <getopt.h>
#include <unistd.h>
#include <sys/wait.h>

#define CMD_PROGRAM "%s %s:%d %s --telosb -r -e -I -p > /dev/null 2>&1"
#define CMD_ERASE "%s %s:%d . --telosb -r -e > /dev/null 2>&1"

enum {
  STR_LEN               = 256,
  CMD_LEN               = 4096,
  INPUT_SIZE            = 8192,
  MAX_HOSTS             = 256,
  TCPING_CLOSED         = 1,
  TCPING_OPEN           = 0,
  TCPING_TIMEOUT        = 2,
  FAIL_ERASE            = 3,
  MAX_ATTEMPTS          = 5,
  ATTEMPT_WAIT          = 2,
  EC_SUCCESS            = 0,
  STATUS_PROGRAMMED     = 0,
  STATUS_PROGRAM_BSL    = 1,
  STATUS_PROGRAM_HEADER = 2,
  STATUS_PROGRAM_NODEVICE = 3,
  STATUS_PROGRAM_TIMEOUT = 4,
  STATUS_FAIL_EXEC       = 5,
  STATUS_INIT           = 6,
  RET_ERROR             = -1,
};

typedef struct programmingNodes {
  char  strBinary[STR_LEN];
  char  strHost[STR_LEN];
  int   programPort;
  int   status;
  int   erase;
  int   attempts;
} eprb_t;

int     parse(int argc, char* argv[]);
int     readHosts();
int     tcping(char* strHost, int nPort);
void    summary(eprb_t* mibs, int len);
int     reprogram(eprb_t* mibs, int len);
void    reprogram_thread(int idx);
void    usage();
int     persistent_exec(char* cmd, 
                        int attempts, 
                        int wait, 
                        int id, 
                        eprb_t * eprb); 

eprb_t  mibs[MAX_HOSTS];
int     len;
char*   strUispPath     = NULL;
int     debug           = 0;

int main(int argc, char* argv[]) {
  
  // parse command line
  int ret   = parse(argc,argv);
  int unused;
 
  if(ret == RET_ERROR) {
    fprintf(stdout, "error processing command line\n");
  } else {
    ret = readHosts();
    len = ret;
    
    if(ret == RET_ERROR) {
      fprintf(stdout, "error reading hosts from stdin\n");
    } else {  
      // reprogram motes
      ret = reprogram(mibs,ret);
      if(ret == RET_ERROR) {
        fprintf(stdout, "error spinning off reprogramming threads\n");
      } else {
        summary(mibs, len);
      }
    }
  }
  
  if(ret == RET_ERROR) {
    usage();
  }
  exit(ret);
}

int reprogram(eprb_t* mibs, int len) {
  int i,rc,status;
  //pthread_t threads[MAX_HOSTS];
  pid_t threadIDS[MAX_HOSTS];
  
  for(i = 0; i < len; i++) {
    pid_t threadID;
    do {
      threadID = fork();
    } while (threadID == -1);

    if (threadID == 0) {
      reprogram_thread(i);
      exit(0);
    } else {
      threadIDS[i] = threadID;
    }
  }

  for(i = 0; i < len; i++) {
    int status;
    int realStatus;
    waitpid(threadIDS[i], &status, 0);
    if (WIFEXITED(status)) {
      mibs[i].status = WEXITSTATUS(status);
    }
  }
}

void reprogram_thread(int idx) {

  int i = idx;
  int retry;
  int status;
  int j, portStatus;

  // 14 Mar 2006 : GWA : PROGRAM.

  char cmd[CMD_LEN];
  
  if (mibs[i].erase == 0) {
    sprintf(cmd,
            CMD_PROGRAM, 
            strUispPath, 
            mibs[i].strHost,
            mibs[i].programPort,
            mibs[i].strBinary);
  } else {
    sprintf(cmd,
            CMD_ERASE, 
            strUispPath, 
            mibs[i].strHost,
            mibs[i].programPort);
  }
  
  if (debug > 0) {
    fprintf(stdout,
            "[%d] executing cmd: %s\n", 
            idx, 
            cmd);
  }

  for (i = 0; i < MAX_ATTEMPTS; i++) {
    execl("/bin/sh", "sh", "-c", cmd, (char *) 0);
  }

  exit(STATUS_FAIL_EXEC);
}

void summary(eprb_t* mibs, int len) {
  int i;
  int succ = 0;
  int no_ping = 0;
  int no_prog = 0;
  for(i=0; i<len; i++) {
    fprintf(stdout,"%s\t%d\t", mibs[i].strHost, mibs[i].programPort);
    switch(mibs[i].status) {
      case STATUS_PROGRAMMED:
        succ++;
        fprintf(stdout,"%s\t", "OK");
        break;

      case STATUS_PROGRAM_TIMEOUT:
        no_ping++;
        fprintf(stdout,"%s\t", ">>FAIL TCP");
        break;

      case STATUS_PROGRAM_BSL:
        no_prog++;
        fprintf(stdout,"%s\t", ">>FAIL PROGRAM");
        break;
  
      case STATUS_PROGRAM_NODEVICE:
        no_prog++;
        fprintf(stdout,"%s\t", ">>FAIL PROGRAM");
        break;

      case STATUS_PROGRAM_HEADER:
        no_prog++;
        fprintf(stdout,"%s\t", ">>FAIL HEADER");
        break;
      
      case STATUS_FAIL_EXEC:
        no_prog++;
        fprintf(stdout,"%s\t", ">>INTERNAL ERROR");
        break;

      case STATUS_INIT:
        fprintf(stdout,"%s\t", ">>INTERNAL ERROR");
        break;
        
      default:
        fprintf(stdout,"%s\t", "invalid status");
        break;
    }
    if(debug>0) {
      fprintf(stdout,"%d\t%s\n", mibs[i].attempts, mibs[i].strBinary); 
    } else { 
      fprintf(stdout,"\n");
    }
  }
  printf("SUMMARY: OK %d, NOPING %d, NOPROGRAM %d\n",
         succ,
         no_ping,
         no_prog);
}

int parse(int argc, char* argv[]) {
  
  char  c = -1;
  while((c = getopt(argc,argv,"u:h:v")) != -1) {
    switch (c) {
     
      case 'u':
        strUispPath = (char*) malloc(sizeof(char)*strlen(optarg));
        strcpy(strUispPath,optarg);
        break;
        
      case 'v':
        debug=1;
        fprintf(stderr, "Enabling verbose output\n");
        break;
      
      case 'h':
        return RET_ERROR;
      
      case '?':
        if (debug) {
          fprintf(stdout,"unknown option\n");
        }
        return RET_ERROR;
        
      default:
        if (debug) {
          fprintf(stdout,"unknown option\n");
        }
        return RET_ERROR;
    }
  }

  if(strUispPath==NULL) {
    return RET_ERROR;
  } else {
    return 1;
  }
}

int readHosts() {
  int   len = 0;
  char  input[INPUT_SIZE];
  int   currentPort = 0;

  char* ret = NULL;
  
  while ((ret = fgets(input, INPUT_SIZE, stdin)) != NULL) {
    
    if (input[strlen(ret) - 1] == '\n') {
      input[strlen(ret) - 1] = '\0';
    }
    
    mibs[len].status  = STATUS_INIT;
       
    if(index(input,':') == NULL) {
      break;
    }
    
    char * hostName = strtok(input, ":");
    if(hostName == NULL) {
      return -1;
    }
    if (debug) {
      printf("hostName=%s\n", hostName);
    }
    strcpy(mibs[len].strHost, hostName);
    
    char * portNumber = strtok(NULL,":");
    if(portNumber == NULL) {
      return -1;
    }
    if (debug) {
      printf("portNumber=%s\n", portNumber);
    }
    mibs[len].programPort = atoi(portNumber);
        
    char * fileName = strtok(NULL,":");
    if(fileName == NULL) {
      return -1;
    }
    if (debug) {
      printf("fileName=%s\n", fileName);
    }
    strcpy(mibs[len].strBinary, fileName); 
    if (!(strcmp(fileName, "."))) {
      mibs[len].erase = 1;
    } else {
      mibs[len].erase = 0;
    }
    if (debug) {
        printf("erase=%d\n", mibs[len].erase);
    }
    mibs[len].attempts = 0;
    len++;
  }
  
  if(debug>0) fprintf(stdout,"found %d hosts\n", len);
  
  if( len > 0 ) {
    return len;
  } else {
    return -1;
  }
}

void usage() {
  fprintf(stdout,"usage: ml-program [OPTION]\n");
  fprintf(stdout,"\nRequired:\n");
  fprintf(stdout,"\t-u %-15s command to execute UISP\n","/path/to/uisp");
  fprintf(stdout,"\nOptional:\n");
  fprintf(stdout,"\t-v %-15s verbose reporting\n","");
}
