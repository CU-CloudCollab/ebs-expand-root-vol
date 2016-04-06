# cloud-ebs-root-expand_vol
Expand Instance Root Volume

1. Get Instance ID, Volume ID Root Device mount point
2. Stop Instance
3. Get Volume Instance Details 
4. Detach Root Volume
5. Take Snapshot
6. Create New Volutme using VolumeID from above
7. Attache Volume to instance
8. Start Instance
9. Clean UP
