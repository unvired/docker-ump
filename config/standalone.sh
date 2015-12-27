#!/bin/sh

DIRNAME=`dirname "$0"`
PROGNAME=`basename "$0"`
GREP="grep"

# Use the maximum available, or set MAX_FD != -1 to use that
MAX_FD="maximum"

# OS specific support (must be 'true' or 'false').
cygwin=false;
darwin=false;
linux=false;
case "`uname`" in
    CYGWIN*)
        cygwin=true
        ;;

    Darwin*)
        darwin=true
        ;;

    Linux)
        linux=true
        ;;
esac

# ------------ JAVA

# Set the java minimum and java maximum values
# Default -server -Xms1G -Xmx2G -XX:MaxPermSize=400m
if [ "x$JAVA_MIN_MEM" = "x" ]; then
  JAVA_MIN_MEM="512m"
fi
if [ "x$JAVA_MAX_MEM" = "x" ]; then
  JAVA_MAX_MEM="1G"
fi
if [ "x$JAVA_MAX_PERM" = "x" ]; then
  JAVA_MAX_PERM="300m"
fi

sed -i "s:JAVA-MIN-MEM:${JAVA_MIN_MEM}:" /opt/unvired/UMP3/bin/standalone.conf
sed -i "s:JAVA-MAX-MEM:${JAVA_MAX_MEM}:" /opt/unvired/UMP3/bin/standalone.conf
sed -i "s:JAVA-MAX-PERM:${JAVA_MAX_PERM}:" /opt/unvired/UMP3/bin/standalone.conf


# Read an optional running configuration file
if [ "x$RUN_CONF" = "x" ]; then
    RUN_CONF="$DIRNAME/standalone.conf"
fi
if [ -r "$RUN_CONF" ]; then
    . "$RUN_CONF"
fi

# For Cygwin, ensure paths are in UNIX format before anything is touched
if $cygwin ; then
    [ -n "$JBOSS_HOME" ] &&
        JBOSS_HOME=`cygpath --unix "$JBOSS_HOME"`
    [ -n "$JAVA_HOME" ] &&
        JAVA_HOME=`cygpath --unix "$JAVA_HOME"`
    [ -n "$JAVAC_JAR" ] &&
        JAVAC_JAR=`cygpath --unix "$JAVAC_JAR"`
fi

# Setup JBOSS_HOME
RESOLVED_JBOSS_HOME=`cd "$DIRNAME/.."; pwd`
if [ "x$JBOSS_HOME" = "x" ]; then
    # get the full path (without any relative bits)
    JBOSS_HOME=$RESOLVED_JBOSS_HOME
else
 SANITIZED_JBOSS_HOME=`cd "$JBOSS_HOME"; pwd`
 if [ "$RESOLVED_JBOSS_HOME" != "$SANITIZED_JBOSS_HOME" ]; then
   echo "WARNING JBOSS_HOME may be pointing to a different installation - unpredictable results may occur."
   echo ""
 fi
fi
export JBOSS_HOME

# ----------------------------------------------------------------------------------------------------------------------------------
# Set up all the configurations

# Set the datasource user id and password from the environment
# MYSQL Server name default is mysql overridden with DB_HOST env variable
# MYSQL database name default is ump3 overridden with DB_NAME
# MYSQL user name default is root overridden with DB_USER env variable
# MYSQL password default is root overridden with DB_PASSWORD
# MYSQL Server name default is umpdb and database name is ump3_scheduler for Quartz, can be changed in the quartz.properties file

# ------------ MYSQL

if [ "x$DB_HOST" = "x" ]; then
  DB_HOST="mysql"
fi
if [ "x$DB_NAME" = "x" ]; then
  DB_NAME="ump3"
fi
if [ "x$DB_USER" = "x" ]; then
  DB_USER="root"
fi
if [ "x$DB_PASSWORD" = "x" ]; then
  DB_PASSWORD="root"
fi

sed -i "s/DB-HOST/$DB_HOST/" /opt/unvired/UMP3/standalone/configuration/standalone-full.xml
sed -i "s/DB-NAME/$DB_NAME/" /opt/unvired/UMP3/standalone/configuration/standalone-full.xml
sed -i "s/DB-USER/$DB_USER/" /opt/unvired/UMP3/standalone/configuration/standalone-full.xml
sed -i "s/DB-PASSWORD/$DB_PASSWORD/" /opt/unvired/UMP3/standalone/configuration/standalone-full.xml

# ------------ Hazelcast
if [ "x$HZ_MULTICAST_GROUP" = "x" ]; then
  HZ_MULTICAST_GROUP="224.2.2.3"
fi
if [ "x$HZ_MULTICAST_PORT" = "x" ]; then
  HZ_MULTICAST_PORT="54327"
fi

sed -i "s/HZ-MULTICAST-GROUP/${HZ_MULTICAST_GROUP}/" /opt/unvired/UMP3/standalone/configuration/hazelcast.xml
sed -i "s/HZ-MULTICAST-PORT/${HZ_MULTICAST_PORT}/" /opt/unvired/UMP3/standalone/configuration/hazelcast.xml

# ------------ LOG-LEVEL
if [ "x$LOG_LEVEL" = "x" ]; then
  LOG_LEVEL="ERROR"
fi

sed -i "s/LOG-LEVEL/${LOG_LEVEL}/" /opt/unvired/UMP3/standalone/configuration/standalone-full.xml

# ------------ JCO

#
# If the SAP JCO files have been provided copy them and copy the correct module xml .. Docker enablement
#
if [ -f /var/UMPinput/sapjco3.jar ]; then
  yes | cp /var/UMPinput/sapjco3.jar /opt/unvired/UMP3/modules/unvired/com/sap/jco/main/
  yes | cp /opt/unvired/UMP3/modules/unvired/com/sap/jco/main/module.xml.enabled /opt/unvired/UMP3/modules/unvired/com/sap/jco/main/module.xml
else
  # Since the jar is not there copy the disabled module.xml to avoid module load errors
  yes | cp /opt/unvired/UMP3/modules/unvired/com/sap/jco/main/module.xml.disabled /opt/unvired/UMP3/modules/unvired/com/sap/jco/main/module.xml
fi

if [ -f /var/UMPinput/libsapjco3.so ]; then
	yes | cp /var/UMPinput/libsapjco3.so /opt/unvired/UMP3/modules/unvired/com/sap/jco/main/
fi

# ----------------------------------------------------------------------------------------------------------------------------------

# Setup the JVM
if [ "x$JAVA" = "x" ]; then
    if [ "x$JAVA_HOME" != "x" ]; then
        JAVA="$JAVA_HOME/bin/java"
    else
        JAVA="java"
    fi
fi

if [ "$PRESERVE_JAVA_OPTS" != "true" ]; then
    # Check for -d32/-d64 in JAVA_OPTS
    JVM_D64_OPTION=`echo $JAVA_OPTS | $GREP "\-d64"`
    JVM_D32_OPTION=`echo $JAVA_OPTS | $GREP "\-d32"`

    # Check If server or client is specified
    SERVER_SET=`echo $JAVA_OPTS | $GREP "\-server"`
    CLIENT_SET=`echo $JAVA_OPTS | $GREP "\-client"`

    if [ "x$JVM_D32_OPTION" != "x" ]; then
        JVM_OPTVERSION="-d32"
    elif [ "x$JVM_D64_OPTION" != "x" ]; then
        JVM_OPTVERSION="-d64"
    elif $darwin && [ "x$SERVER_SET" = "x" ]; then
        # Use 32-bit on Mac, unless server has been specified or the user opts are incompatible
        "$JAVA" -d32 $JAVA_OPTS -version > /dev/null 2>&1 && PREPEND_JAVA_OPTS="-d32" && JVM_OPTVERSION="-d32"
    fi

    CLIENT_VM=false
    if [ "x$CLIENT_SET" != "x" ]; then
        CLIENT_VM=true
    elif [ "x$SERVER_SET" = "x" ]; then
        if $darwin && [ "$JVM_OPTVERSION" = "-d32" ]; then
            # Prefer client for Macs, since they are primarily used for development
            CLIENT_VM=true
            PREPEND_JAVA_OPTS="$PREPEND_JAVA_OPTS -client"
        else
            PREPEND_JAVA_OPTS="$PREPEND_JAVA_OPTS -server"
        fi
    fi

    if [ $CLIENT_VM = false ]; then
        NO_COMPRESSED_OOPS=`echo $JAVA_OPTS | $GREP "\-XX:\-UseCompressedOops"`
        if [ "x$NO_COMPRESSED_OOPS" = "x" ]; then
            "$JAVA" $JVM_OPTVERSION -server -XX:+UseCompressedOops -version >/dev/null 2>&1 && PREPEND_JAVA_OPTS="$PREPEND_JAVA_OPTS -XX:+UseCompressedOops"
        fi

        NO_TIERED_COMPILATION=`echo $JAVA_OPTS | $GREP "\-XX:\-TieredCompilation"`
        if [ "x$NO_TIERED_COMPILATION" = "x" ]; then
            "$JAVA" $JVM_OPTVERSION -server -XX:+TieredCompilation -version >/dev/null 2>&1 && PREPEND_JAVA_OPTS="$PREPEND_JAVA_OPTS -XX:+TieredCompilation"
        fi
    fi

    JAVA_OPTS="$PREPEND_JAVA_OPTS $JAVA_OPTS"
fi

if [ "x$JBOSS_MODULEPATH" = "x" ]; then
    JBOSS_MODULEPATH="$JBOSS_HOME/modules"
fi

if $linux; then
    # consolidate the server and command line opts
    SERVER_OPTS="$JAVA_OPTS $@"
    # process the standalone options
    for var in $SERVER_OPTS
    do
       case $var in
         -Djboss.server.base.dir=*)
              JBOSS_BASE_DIR=`readlink -m ${var#*=}`
              ;;
         -Djboss.server.log.dir=*)
              JBOSS_LOG_DIR=`readlink -m ${var#*=}`
              ;;
         -Djboss.server.config.dir=*)
              JBOSS_CONFIG_DIR=`readlink -m ${var#*=}`
              ;;
       esac
    done
fi
# determine the default base dir, if not set
if [ "x$JBOSS_BASE_DIR" = "x" ]; then
   JBOSS_BASE_DIR="$JBOSS_HOME/standalone"
fi
# determine the default log dir, if not set
if [ "x$JBOSS_LOG_DIR" = "x" ]; then
   JBOSS_LOG_DIR="$JBOSS_BASE_DIR/log"
fi
# determine the default configuration dir, if not set
if [ "x$JBOSS_CONFIG_DIR" = "x" ]; then
   JBOSS_CONFIG_DIR="$JBOSS_BASE_DIR/configuration"
fi

# For Cygwin, switch paths to Windows format before running java
if $cygwin; then
    JBOSS_HOME=`cygpath --path --windows "$JBOSS_HOME"`
    JAVA_HOME=`cygpath --path --windows "$JAVA_HOME"`
    JBOSS_MODULEPATH=`cygpath --path --windows "$JBOSS_MODULEPATH"`
    JBOSS_BASE_DIR=`cygpath --path --windows "$JBOSS_BASE_DIR"`
    JBOSS_LOG_DIR=`cygpath --path --windows "$JBOSS_LOG_DIR"`
    JBOSS_CONFIG_DIR=`cygpath --path --windows "$JBOSS_CONFIG_DIR"`
fi

# Display our environment
echo "========================================================================="
echo ""
echo "  JBoss Bootstrap Environment"
echo ""
echo "  JBOSS_HOME: $JBOSS_HOME"
echo ""
echo "  JAVA: $JAVA"
echo ""
echo "  JAVA_OPTS: $JAVA_OPTS"
echo ""
echo "========================================================================="
echo ""

while true; do
   if [ "x$LAUNCH_JBOSS_IN_BACKGROUND" = "x" ]; then
      # Execute the JVM in the foreground
      eval \"$JAVA\" -D\"[Standalone]\" $JAVA_OPTS \
         \"-Dorg.jboss.boot.log.file=$JBOSS_LOG_DIR/boot.log\" \
         \"-Dlogging.configuration=file:$JBOSS_CONFIG_DIR/logging.properties\" \
         -jar \"$JBOSS_HOME/jboss-modules.jar\" \
         -mp \"${JBOSS_MODULEPATH}\" \
         -jaxpmodule "javax.xml.jaxp-provider" \
         org.jboss.as.standalone \
         -Djboss.home.dir=\"$JBOSS_HOME\" \
         "$@"
      JBOSS_STATUS=$?
   else
      # Execute the JVM in the background
      eval \"$JAVA\" -D\"[Standalone]\" $JAVA_OPTS \
         \"-Dorg.jboss.boot.log.file=$JBOSS_LOG_DIR/boot.log\" \
         \"-Dlogging.configuration=file:$JBOSS_CONFIG_DIR/logging.properties\" \
         -jar \"$JBOSS_HOME/jboss-modules.jar\" \
         -mp \"${JBOSS_MODULEPATH}\" \
         -jaxpmodule "javax.xml.jaxp-provider" \
         org.jboss.as.standalone \
         -Djboss.home.dir=\"$JBOSS_HOME\" \
         "$@" "&"
      JBOSS_PID=$!
      # Trap common signals and relay them to the jboss process
      trap "kill -HUP  $JBOSS_PID" HUP
      trap "kill -TERM $JBOSS_PID" INT
      trap "kill -QUIT $JBOSS_PID" QUIT
      trap "kill -PIPE $JBOSS_PID" PIPE
      trap "kill -TERM $JBOSS_PID" TERM
      if [ "x$JBOSS_PIDFILE" != "x" ]; then
        echo $JBOSS_PID > $JBOSS_PIDFILE
      fi
      # Wait until the background process exits
      WAIT_STATUS=128
      while [ "$WAIT_STATUS" -ge 128 ]; do
         wait $JBOSS_PID 2>/dev/null
         WAIT_STATUS=$?
         if [ "$WAIT_STATUS" -gt 128 ]; then
            SIGNAL=`expr $WAIT_STATUS - 128`
            SIGNAL_NAME=`kill -l $SIGNAL`
            echo "*** JBossAS process ($JBOSS_PID) received $SIGNAL_NAME signal ***" >&2
         fi
      done
      if [ "$WAIT_STATUS" -lt 127 ]; then
         JBOSS_STATUS=$WAIT_STATUS
      else
         JBOSS_STATUS=0
      fi
      if [ "$JBOSS_STATUS" -ne 10 ]; then
            # Wait for a complete shudown
            wait $JBOSS_PID 2>/dev/null
      fi
      if [ "x$JBOSS_PIDFILE" != "x" ]; then
            grep "$JBOSS_PID" $JBOSS_PIDFILE && rm $JBOSS_PIDFILE
      fi
   fi
   if [ "$JBOSS_STATUS" -eq 10 ]; then
      echo "Restarting JBoss..."
   else
      exit $JBOSS_STATUS
   fi
done
