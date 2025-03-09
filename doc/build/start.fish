# set -x JAVA_HOME /usr/lib/jvm/java-11-openjdk
# set -x PATH $JAVA_HOME/bin $PATH

set -x LIBQT6 /opt/Qt6/6.8.2/lib
set -x LD_LIBRARY_PATH $LIBQT6 $LD_LIBRARY_PATH


set -x LD_LIBRARY_PATH /opt/Qt6/6.8.2/plugins/platforms $LD_LIBRARY_PATH

set -x QT_PLUGIN_PATH /opt/Qt6/6.8.2/plugins

set -x LIBQT6 /opt/Qt6/6.8.2/lib
set -x LD_LIBRARY_PATH $LIBQT6 $LD_LIBRARY_PATH
set -x QT_PLUGIN_PATH /opt/Qt6/6.8.2/plugins

set -x QT_DEBUG_PLUGINS 1
deskflow
