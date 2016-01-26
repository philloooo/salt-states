{% for pkg in ['build-essential', 'libfuse-dev', 'libcurl4-openssl-dev', 'libxml2-dev', 'mime-support', 'automake', 'libtool'] %}
{{pkg}}:
  pkg.installed
{% endfor %}

install_s3fs:
  cmd.run:
    - creates: /usr/bin/s3fs
    - name: |
        git clone https://github.com/s3fs-fuse/s3fs-fuse
        cd s3fs-fuse/
        ./autogen.sh
        ./configure --prefix=/usr --with-openssl
        make
        sudo make install

{% for user in pillar["users"] %}
{{user}}:
  user.present:
    - home: /home/{{user}}
    - uid: {{pillar['users'][user]['uid']}}
    - require_in: 
      - group: filetransfer
    - groups: 
      - filetransfer

/home/{{user}}:
  file.directory:
    - user: root
    - group: root
    - dir_mode: 755
    - requires: 
      - user: {{user}}

{% for bucket in pillar["users"][user]["buckets"] %}
/home/{{user}}/{{bucket}}:
  file.directory:
    - user: {{user}}

mount_{{bucket}}:
  cmd.run:
    - name: s3fs {{bucket}} /home/{{user}}/{{bucket}} -o uid={{pillar['users'][user]['uid']}} -o gid=4000 -o allow_other
    - unless: mountpoint /home/{{user}}/{{bucket}}
    - requires:
      - file: /home/{{user}}/{{bucket}}

{% endfor %}
{% endfor %}

filetransfer:
  group.present:
    - gid: 4000

/etc/ssh/sshd_config:
  file.append:
    - text: |
        Match Group filetransfer
            ChrootDirectory /home/haky/
            AllowTCPForwarding no
            X11Forwarding no
            ForceCommand internal-sftp
            PasswordAuthentication yes


ssh:
  service.running:
    - watch: 
      - file: /etc/ssh/sshd_config
    - reload: True
