make qsys-clean
make qsys
make quartus
make rbf
embedded_command_shell.sh
make dtb
scp ./output_files/soc_system.rbf root@128.59.65.3:/mnt
scp ./soc_system.dtb root@128.59.65.3:/mnt
