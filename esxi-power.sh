#!/bin/bash
#June 14, 2019
#by Robert John Canare

#default variables that not needed to modify
email="email"
from_email="email"
smtp="192.168.1.20"

#confidential variables
esxi_password='password'

#ESXi hosts address
esxi1_address=
esxi2_address=

#pinging PHIL static IP that not part of the UPS powered
ping_host_1=

#pinging PHIL static IP that not part of the UPS powered
ping_host_2=

############################################################################################################################################################################################################################################################

ping -q -c1 $ping_host_1> /dev/null

if [ $? -eq 0 ];
then
    echo "HOST 1 is up, PHIL power is up."> powerstatus-logs.txt
else
    ping -q -c1 $ping_host_2> /dev/null

    if [ $? -eq 0 ];
    then
        echo "HOST 2 is up, PHIL power is up."> powerstatus-logs.txt
    else
        echo "PHIL main power is down!">> powerstatus-logs.txt

        #sending email notification to IT support email.
        sendemail -f $from_email -t $email -u "subject" -m "PHIL office main power is down and all the servers will be shutdown after 5 minutes, any false possitive you can stop the script on 192.168.1.75" -o tls=no -s 192.168.1.20:25

        sleep 5

        echo "Starting 5 minutes timer.">> powerstatus-logs.txt

#modify the time according to your requirment
runtime="1 minute"
endtime=$(date -ud "$runtime" +%s)
while [[ $(date -u +%s) -le $endtime ]]
do
    ping -q -c1 $ping_host_1> /dev/null
    if [ $? -eq 0 ];
    then
        echo "HOST 1 is up and waiting for HOST 2 to stop the timer.">> powerstatus-logs.txt

        ping -q -c1 $ping_host_2> /dev/null

        if [ $? -eq 0 ];
        then
            echo "Power is back before" $runtime"!">> powerstatus-logs.txt
            exit 0
        fi
    else
        #echo "Time Now: `date +%H:%M:%S`"
        echo "Waiting for the main power to come back within"  $runtime"...">> powerstatus-logs.txt
    fi
done

#if power not coming within a time range it will shutdown the ESXi hosts
echo "Still no power within" $runtime".">> powerstatus-logs.txt
sleep 5

sendemail -f $from_email -t $email -u "PHIL power status" -m "PHIL office main power is still down and all the servers will be shutting down, any false possitive you can stop the script on 192.168.1.75." -o tls=no -s 192.168.1.20:25

sleep 5

            #power off V.M's commands execute here.

            #For ESXi1(172.16.64.20) CURRENT VMID: 1, 10, 11, 7, 8, 9
            #power off commands
            echo "Shutting down all the V.M's on ESXi1.">> powerstatus-logs.txt
            sshpass -p $esxi_password ssh root@$esxi1_address vim-cmd vmsvc/power.off 1
            sshpass -p $esxi_password ssh root@$esxi1_address vim-cmd vmsvc/power.off 10
            sshpass -p $esxi_password ssh root@$esxi1_address vim-cmd vmsvc/power.off 11
            sshpass -p $esxi_password ssh root@$esxi1_address vim-cmd vmsvc/power.off 7
            sshpass -p $esxi_password ssh root@$esxi1_address vim-cmd vmsvc/power.off 8
            sshpass -p $esxi_password ssh root@$esxi1_address vim-cmd vmsvc/power.off 9

            #enter maintenance mode command
            echo "Entering maintenance mode on ESXi1">> powerstatus-logs.txt
            sshpass -p $esxi_password ssh root@$esxi1_address esxcli system maintenanceMode set --enable true
            echo "Shutting down ESXi1 host">> powerstatus-logs.txt
            sshpass -p $esxi_password ssh root@$esxi1_address poweroff
sleep 5

echo "ESXi1 is properly shutdown.">> powerstatus-logs.txt

            #For ESXi2(172.16.64.30) CURRENT VMID: 1, 10, 2, 3, 4, 5, 6
            #power off commands
            echo "Shutting down all the V.M's on ESXi2.">> powerstatus-logs.txt
            sshpass -p $esxi_password ssh root@$esxi2_address vim-cmd vmsvc/power.off 1
            sshpass -p $esxi_password ssh root@$esxi2_address vim-cmd vmsvc/power.off 10
            sshpass -p $esxi_password ssh root@$esxi2_address vim-cmd vmsvc/power.off 2
            sshpass -p $esxi_password ssh root@$esxi2_address vim-cmd vmsvc/power.off 3
            sshpass -p $esxi_password ssh root@$esxi2_address vim-cmd vmsvc/power.off 4
            sshpass -p $esxi_password ssh root@$esxi2_address vim-cmd vmsvc/power.off 5
            sshpass -p $esxi_password ssh root@$esxi2_address vim-cmd vmsvc/power.off 6

            #enter maintenance mode command
            echo "Entering maintenance mode on ESXi2">> powerstatus-logs.txt
            sshpass -p $esxi_password ssh root@$esxi2_address esxcli system maintenanceMode set --enable true
            echo "Shutting down ESXi2 host">> powerstatus-logs.txt
            sshpass -p $esxi_password ssh root@$esxi2_address poweroff

sleep 5

echo "ESXi2 is properly shutdown.">> powerstatus-logs.txt

#waiting 2 days for the main power to come back
runtime="1440 minute"
endtime=$(date -ud "$runtime" +%s)
while [[ $(date -u +%s) -le $endtime ]]
do
    ping -q -c1 $ping_host_1> /dev/null
    if [ $? -eq 0 ]; then
        echo "HOST 1 is back, it seems main power is up.">> powerstatus-logs.txt

        ping -q -c1 $ping_host_2> /dev/null

        if [ $? -eq 0 ];
        then
            echo "HOST 2 is back, main power is up.">> powerstatus-logs.txt
            sleep 5

            #power on V.M's commands execute here.
            #For ESXi1(172.16.64.20) CURRENT VMID: 1, 10, 11, 7, 8, 9
            echo "Powering up ESXi1 host using wake on lan(WOL)">> powerstatus-logs.txt
            #ESXi1 WOL
            wakeonlan -i 172.16.64.20 00:1E:4F:22:D2:6B

            echo "Powering up ESXi2 host using wake on lan(WOL)">> powerstatus-logs.txt
            #ESXi2 WOL
            wakeonlan -i 172.16.64.30 00:1E:4F:15:3F:80

            sleep 300

            echo "Exiting maintenance mode on ESXi1">> powerstatus-logs.txt
            sshpass -p $esxi_password ssh root@$esxi1_address esxcli system maintenanceMode set --enable false

            #power on commands for ESXi1
            echo "Powering up all the VM's on ESXi1">> powerstatus-logs.txt
            sshpass -p $esxi_password ssh root@$esxi1_address vim-cmd vmsvc/power.on 1
            sshpass -p $esxi_password ssh root@$esxi1_address vim-cmd vmsvc/power.on 10
            sshpass -p $esxi_password ssh root@$esxi1_address vim-cmd vmsvc/power.on 11
            sshpass -p $esxi_password ssh root@$esxi1_address vim-cmd vmsvc/power.on 7
            sshpass -p $esxi_password ssh root@$esxi1_address vim-cmd vmsvc/power.on 9

            sleep 5

            echo "Exiting maintenance mode on ESXi2">> powerstatus-logs.txt
            sshpass -p $esxi_password ssh root@$esxi2_address esxcli system maintenanceMode set --enable false

            #power on commands for ESXi2
            echo "Powering up all the ESXi hosts.">> powerstatus-logs.txt
            sshpass -p $esxi_password ssh root@$esxi2_address vim-cmd vmsvc/power.on 10
            sshpass -p $esxi_password ssh root@$esxi2_address vim-cmd vmsvc/power.on 3
            sshpass -p $esxi_password ssh root@$esxi2_address vim-cmd vmsvc/power.on 4

            echo "All the servers are back on normal state">> powerstatus-logs.txt

            sleep 5

            sendemail -f $from_email -t $email -u "PHIL power status" -m "PHIL office main power is up and all the servers are up and running, any false possitive you can stop the script on 192.168.1.75" -o tls=no -s 192.168.1.20:25
            exit 0
        fi
    else
        #echo "Time Now: `date +%H:%M:%S`"
        echo "Waiting for the main power.">> powerstatus-logs.txt
    fi
done
    fi

fi
