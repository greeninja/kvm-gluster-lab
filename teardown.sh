
#!/bin/bash                                                                                                                                                          
                                                                                                                                                                     
# Network Vars                                                                    
dns_domain="gluster.lab"                                                          

                                                                                  
##### Start #####

# Remove the client VM first

virsh destroy client01.$dns_domain
virsh undefine client01.$dns_domain --remove-all-storage

virsh pool-destroy glusterfs
virsh pool-undefine glusterfs 

# Remove Gluster VMs

for i in `seq -w 01 03`; do
  virsh destroy gluster$i.$dns_domain
  virsh undefine gluster$i.$dns_domain --remove-all-storage
done

# Remove Network files

echo "Removing gluster-lab xml file"

rm $tmp_dir/gluster-lab.xml -rf

echo "Removing ceph networks in libvirt"

for network in gluster-lab; do
  virsh net-destroy $network
  virsh net-undefine $network
done


