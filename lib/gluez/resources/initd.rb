require 'base64'

resource :initd do
  optional    :daemon_opts, :default => ""
  mandatory   :daemon
  
  ready!
  
  self.as_user "root"

  script = <<-EOF
    #!/bin/sh

    ### BEGIN INIT INFO
    # Provides:          #{self.name}
    # Required-Start:    $local_fs $remote_fs $network $syslog
    # Required-Stop:     $local_fs $remote_fs $network $syslog
    # Default-Start:     2 3 4 5
    # Default-Stop:      0 1 6
    # Short-Description: starts #{self.name}
    # Description:       starts #{self.name}
    ### END INIT INFO

    PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
    DAEMON=#{self.daemon}
    DAEMON_OPTS=#{self.daemon_opts}
    NAME=#{self.name}
    DESC=$NAME

    # Include defaults if available
    if [ -f /etc/default/#{self.name} ]; then
      . /etc/default/#{self.name}
    fi

    test -x $DAEMON || exit 0

    set -e

    . /lib/lsb/init-functions

    case "$1" in
      start)
        echo -n "Starting $DESC: "
        start-stop-daemon --start --quiet --pidfile /var/run/$NAME.pid --exec $DAEMON -- $DAEMON_OPTS || true
        echo "$NAME."
        ;;

      stop)
        echo -n "Stopping $DESC: "
        start-stop-daemon --stop --quiet --pidfile /var/run/$NAME.pid --exec $DAEMON || true
        echo "$NAME."
        ;;

      restart|force-reload)
        echo -n "Restarting $DESC: "
        start-stop-daemon --stop --quiet --pidfile /var/run/$NAME.pid --exec $DAEMON || true
        sleep 1
        start-stop-daemon --start --quiet --pidfile /var/run/$NAME.pid --exec $DAEMON -- $DAEMON_OPTS || true
        echo "$NAME."
        ;;    
      reload)
        echo -n "Reloading $DESC configuration: "
        start-stop-daemon --stop --signal HUP --quiet --pidfile /var/run/$NAME.pid --exec $DAEMON || true
        echo "$NAME."
        ;;

      status)
        status_of_proc -p /var/run/$NAME.pid "$DAEMON" $NAME && exit 0 || exit $?
        ;;
      *)
        echo "Usage: $NAME {start|stop|restart|reload|force-reload|status}" >&2
        exit 1
        ;;
    esac

    exit 0
  EOF
  
  script64 = Base64.encode64(script.multiline_strip)

  setup "cat >~/.gluez_transfer <<\\DATA
#{script64}
DATA"
  
  steps do |step|
    step.checks << "-f /etc/init.d/#{self.name}"
    step.code = "touch /etc/init.d/#{self.name}"
  end
  steps do |step|
    step.checks << %Q("\\$(cat ~/.gluez_transfer | base64 -i -d - | md5sum - | awk '{print \\$1}')" = "\\$(md5sum /etc/init.d/#{self.name} | awk '{print \\$1}')")
    step.code = "chmod +x /etc/init.d/#{self.name} && cat ~/.gluez_transfer | base64 -i -d - > /etc/init.d/#{self.name}"
  end
  
end