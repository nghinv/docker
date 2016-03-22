#!/bin/bash

#set -e

# Copy files from /usr/share/jenkins/ref into /var/jenkins_home
# So the initial JENKINS-HOME is set with expected content.
# Don't override, as this is just a reference setup, and use from UI
# can then change this, upgrade plugins, etc.

write_key() {
	mkdir /var/jenkins_home/.ssh
	mkdir ~/.ssh
	echo "$1" >> /var/jenkins_home/.ssh/authorized_keys
	echo "$1" >> ~/.ssh/authorized_keys
	chown -Rf jenkins:jenkins /var/jenkins_home/.ssh
	chmod 0700 -R /var/jenkins_home/.ssh
	chmod 0700 -R ~/.ssh/
	echo "HOME: "
	ls -lsa ~/ ~/.ssh/

}

JENKINS_SLAVE_SSH_PUBKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD7muO/wzoh9ntayr3MH5IoJJTi04EtLJ8VbLLKVPCT4FA7VP157eBlgs85i8wOJ7C10kqw0d1TCxgNiEQJV8P8xcliY97jC+EJmPCcq7RyvygTTq999fHXKuzw4xfDuHaREEKDKXnDNBhScNkimu2xjKVlbmJzBfG96dOs/Xi3WehbCpCjvQeO1XlwFDG5Mbne+1eWmSfqZbcFanCy4g1nWlOegpy/piDYkhjmTMvJBQvM9T71hstNAjJY87gOYZsWispkSS+g9IduAjPOOq6MUfMX8jnNsAacK3M9UoJredoanwfjR/SSWT8U0aNNt78xucwqB+qwxgv5QEXdVycl nghi_nguyenvan@MAY107"

if [[ $JENKINS_SLAVE_SSH_PUBKEY == ssh-* ]]; then
  write_key "${JENKINS_SLAVE_SSH_PUBKEY}"
fi
if [[ $# -gt 0 ]]; then
  if [[ $1 == ssh-* ]]; then
    write_key "$1"
    shift 1
  else
    exec "$@"
  fi
fi
#exec /usr/sbin/sshd -D $@
nohup /usr/sbin/sshd &

/etc/init.d/mysql start


copy_reference_file() {
	f="${1%/}"
	b="${f%.override}"
	echo "$f" >> "$COPY_REFERENCE_FILE_LOG"
	rel="${b:23}"
	dir=$(dirname "${b}")
	echo " $f -> $rel" >> "$COPY_REFERENCE_FILE_LOG"
	if [[ ! -e /var/jenkins_home/${rel} || $f = *.override ]]
	then
		echo "copy $rel to JENKINS_HOME" >> "$COPY_REFERENCE_FILE_LOG"
		mkdir -p "/var/jenkins_home/${dir:23}"
		cp -r "${f}" "/var/jenkins_home/${rel}";
		# pin plugins on initial copy
		[[ ${rel} == plugins/*.jpi ]] && touch "/var/jenkins_home/${rel}.pinned"
	fi;
}
export -f copy_reference_file
touch "${COPY_REFERENCE_FILE_LOG}" || (echo "Can not write to ${COPY_REFERENCE_FILE_LOG}. Wrong volume permissions?" && exit 1)
echo "--- Copying files at $(date)" >> "$COPY_REFERENCE_FILE_LOG"
find /usr/share/jenkins/ref/ -type f -exec bash -c "copy_reference_file '{}'" \;

# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then
  eval "exec java $JAVA_OPTS -jar /usr/share/jenkins/jenkins.war --httpPort=80 $JENKINS_OPTS \"\$@\""
fi

# As argument is not jenkins, assume user want to run his own process, for sample a `bash` shell to explore this image
exec "$@"
