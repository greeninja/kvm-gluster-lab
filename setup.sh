

#!/bin/bash
                                                         
# Node building vars                                                                                               
image_dir="/var/lib/libvirt/images"
base_os_img="/var/lib/libvirt/images/iso/CentOS-7-x86_64-GenericCloud.qcow2"
ssh_pub_key="/root/.ssh/id_ed25519.pub"

# Network Vars
dns_domain="gluster.lab"

# Extra Vars
root_password="password"
os_drive_size="40G"
tmp_dir="/tmp"

# You shouldn't have to change anything below here
                                                         
#################                                                         
##### Start #####
#################

                                                         
# Exit on any failure  
                                                         
set -e           
                                                         
# Create Network files                                                                                             
                                                                                                                   
echo "Creating gluster-lab xml file"                                                                               
                                                         
cat <<EOF > $tmp_dir/gluster-lab.xml
<network>                            
  <name>gluster-lab</name>
  <bridge name="virbr1234"/>
  <forward mode="nat"/>
  <domain name="gluster.lab"/>
  <ip address="10.44.50.1" netmask="255.255.255.0">    <dhcp>
      <range start="10.44.50.10" end="10.44.50.100"/>
    </dhcp>
  </ip>   
</network>               
EOF

echo "Creating gluster network in libvirt"

check_rep=$(virsh net-list --all | grep gluster-lab >/dev/null && echo "0" || echo "1")

networks=()

if [[ $check_rep == "1" ]]; then
  networks+=("gluster-lab")
fi

net_len=$(echo "${#networks[@]}")

if [ "$net_len" -ge 1 ]; then
  for network in ${networks[@]}; do 
    virsh net-define $tmp_dir/$network.xml
    virsh net-start $network
    virsh net-autostart $network
  done
else
  echo "Network already created"
fi

# Check OS image exists

if [ -f "$base_os_img" ]; then
  echo "Base OS image exists"
else
  echo "Base image doesn't exist ($base_os_img). Exiting"
  exit 1
fi

echo "Building Gluster nodes"

count=1

for i in `seq -w 01 03`; do 
  check=$(virsh list --all | grep gluster$i.$dns_domain > /dev/null && echo "0" || echo "1" )
  if [[ $check == "0" ]]; then
    echo "gluster$i.$dns_domain already exists"
    count=$(( $count + 1 ))
  else
    echo "Starting gluster$i"
    echo "Creating $image_dir/gluster$i.$dns_domain.qcow2 at $os_drive_size"
    qemu-img create -f qcow2 $image_dir/gluster$i.$dns_domain.qcow2 $os_drive_size
    for c in {1..2}; do 
      qemu-img create -f qcow2 $image_dir/gluster$i-disk$c.$dns_domain.qcow2 5G
    done
    echo "Resizing base OS image"
    virt-resize --expand /dev/sda1 $base_os_img $image_dir/gluster$i.$dns_domain.qcow2
    echo "Customising OS for gluster$i"
    virt-customize -a $image_dir/gluster$i.$dns_domain.qcow2 \
      --root-password password:$root_password \
      --uninstall cloud-init \
      --hostname gluster$i.$dns_domain \
      --ssh-inject root:file:$ssh_pub_key \
      --selinux-relabel
    echo "Defining gluster$i"
    virt-install --name gluster$i.$dns_domain \
      --virt-type kvm \
      --memory 8192 \
      --vcpus 4 \
      --boot hd,menu=on \
      --disk path=$image_dir/gluster$i.$dns_domain.qcow2,device=disk \
      --disk path=$image_dir/gluster$i-disk1.$dns_domain.qcow2,device=disk \
      --disk path=$image_dir/gluster$i-disk2.$dns_domain.qcow2,device=disk \
      --os-type Linux \
      --os-variant centos7 \
      --network network:gluster-lab \
      --graphics spice \
      --noautoconsole
    
    count=$(( $count + 1 ))
  fi
done


# Build Client
check=$(virsh list --all | grep client01.$dns_domain > /dev/null && echo "0" || echo "1" )
  if [[ $check == "0" ]]; then
    echo "client01.$dns_domain already exists"
    count=$(( $count + 1 ))
  else
    echo "Starting client"
    echo "Creating $image_dir/client01.$dns_domain.qcow2 at $os_drive_size"
    qemu-img create -f qcow2 $image_dir/client01.$dns_domain.qcow2 $os_drive_size
    echo "Resizing base OS image"
    virt-resize --expand /dev/sda1 $base_os_img $image_dir/client01.$dns_domain.qcow2
    echo "Customising OS for client01"
    virt-customize -a $image_dir/client01.$dns_domain.qcow2 \
      --root-password password:$root_password \
      --uninstall cloud-init \
      --hostname client01.$dns_domain \
      --ssh-inject root:file:$ssh_pub_key \
      --selinux-relabel
    echo "Defining client01"
    virt-install --name client01.$dns_domain \
      --virt-type kvm \
      --memory 4096 \
      --vcpus 2 \
      --boot hd,menu=on \
      --disk path=$image_dir/client01.$dns_domain.qcow2,device=disk \
      --os-type Linux \
      --os-variant centos7 \
      --network network:gluster-lab \
      --graphics spice \
      --noautoconsole
  fi

# Print running VMs

virsh list


