all:
  vars:
    docker_users:
      - ubuntu
  hosts:
    %{ for index, ip in ips }
    distribuidos-${format("%02d", index + 1)}:
      ansible_host: ${ip}
      ip: ${ip}
      ansible_user: ubuntu
    %{ endfor }
