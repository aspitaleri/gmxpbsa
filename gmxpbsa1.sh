#!/bin/bash 

# GMXPBSA tool is free software. You can redistribute it and/or modify it under the GNU Lessere General Public Lincese as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version (http://www.gnu.org/licenses/lgpl-2.1.html).
# GMXPBSA is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# For any problem, doubt, comment or suggestion please contact me at dimitris3.16@gmail.com or paissoni.cristina@hsr.it
# Copyright 2013 Dimitrios Spiliotopoulos, Cristina Paissoni

#export LC_NUMERIC="en_US.UTF-8"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/function_base.dat


#@@@@@@@@@@@@@@@@@@@#
# (0) Print version #
#@@@@@@@@@@@@@@@@@@@#

if ! [ $# -eq 0 ];then
	if [ $1 == "-h" ]; then
		clear
		echo -e "\n\nGMXPBSA version 2.1.2\n\n"
		exit
	fi
fi



clear

check INPUT.dat ERROR_NO_INPUT

set_variable_default_run "run" "1";
set_variable "root";

RUN=RUN${run}_$root
if [ -d $RUN ]; then

	cp -r $RUN backup0_$RUN;
	
	cd $RUN
		# create the new files "REPORTFILE1 / WARNINGS_gmxpbsa1"
		if [ -f REPORTFILE1 ]  ; then  
			rm REPORTFILE1
		fi
		if [ -f WARNINGS_gmxpbsa1.dat ]  ; then  
			rm WARNINGS_gmxpbsa1.dat
		fi	
	cd ..

	set_variable_default1 "cluster" "n" "$RUN/REPORTFILE1";
	set_variable_default1 "mnp" "1" "$RUN/REPORTFILE1";
#	set_variable_default1 "nodes" "1" "$RUN/REPORTFILE1"; 
#	set_variable_default1 "mem" "5GB" "$RUN/REPORTFILE1"; 

	set_variable_default1 "multitrj" "n" "$RUN/REPORTFILE1";
	if [ $multitrj == "y" ]; then
		set_variable_multiple "root_multitrj";
		N_start_dir=`echo $root_multitrj | awk '{N=split($0,v," "); print N}'`
		for ((i=0; i<$N_start_dir; i++)); do
			start_dir[$i]=`echo $root_multitrj | awk -v i=$(($i+1)) '{N=split($0,v," "); print v[i]}'`
		done
	fi

	cd $RUN
	cp ../INPUT.dat ./run${run}_parameters_1.in
	if [ -f run${run}_parameters.in ]; then 
		check_INPUT=`diff -e run${run}_parameters.in run${run}_parameters_1.in | head -n 1 | cut -d " " -f1`;
	else 
		mv run${run}_parameters_1.in run${run}_parameters.in
	fi 
	if [ -z $check_INPUT ]; then rm -f run${run}_parameters_1.in; else echo -e "\nWARNING!! The INPUT file you are using now is different from the one you used running \"gmxpbsa0.sh\"\n"; fi
else
	echo  -e "\n"$(date +%H:%M:%S)"\n The directory $RUN is not present. Please check the INPUT.dat file or run \"gmxpbsa0.sh\"."		
	echo "Exiting --"
	exit

fi

rm -f \#* *~

if [ $multitrj == "y" ]; then
	FolderFile=$(for ((i=0;i<$N_start_dir; i++)); do ls -1| grep "^${start_dir[$i]}"; done | sed s/" "/"\n"/g | sort -u)
else
	FolderFile=$(ls -1 | grep "^$root")
fi

for Folder in $FolderFile; do

# Check that gmxpbsa0.sh ended correctly.

	if [ ! -e DONE0_$Folder ]; then 
		echo -e "\n"$(date +%H:%M:%S)" \n ERROR: I could not find DONE0_$Folder, probably something went wrong with gmxpbsa0.sh. Please check or re-run it. \n" | tee -a REPORTFILE1 
		echo "Exiting -- please read the REPORTFILE1" 
		exit
	fi


# Check that in all the directories "MD_*" there is the sub-directory "APBS_CALCULATIONS"
	cd $Folder
		check APBS_CALCULATIONS ../REPORTFILE1
	cd ..
done

for Folder in $FolderFile; do
rm -f DONE0_$Folder;
done


# Cycle on all the directories called "$root*/APBS_CALCULATIONS"

for Folder in $FolderFile; do
cd $Folder
   cd APBS_CALCULATIONS



# In this directory we have to do ($calc) apbs calculations. Then, considering that we can use maximum $mnp processors, we will have to repeat the "qsubbing" $D times. 

	calc=$(ls comp*.pqr | wc | awk '{print $1}')
	let "D=$calc/$mnp"
	let "R=$calc%$mnp"
	if [ $R -eq 0 ]; then let "D=$D-1" ; fi

	if [ $calc -lt $mnp ]
	then
		let "D=0"
		let "mnp=$calc"

	fi



# if NO cluster
	if [ $cluster == "n" ]
	then
		echo -e "\n\n$(date +%H:%M:%S) Starting the APBS CALCULATIONS in $Folder directory\n" | tee -a ../../REPORTFILE1
		command=bash
		#for each group of calculations that must be submitted in the same time create a file
		for (( f=0;f<=$D; f++ )); do
			echo -e "#!/bin/bash\n" > file_APBS_$f.sh
			for ((k=0;k<$mnp;k++)); do
				let "index[$k]=($mnp*$f)+$k"
				C=0
				if [ -f apbs${index[$k]}.sh ]; then echo -ne  "bash apbs${index[$k]}.sh" >> file_APBS_$f.sh; fi
				let "ind=${index[$k]}+1"
				if [ -f apbs$ind.sh ]; then C=1; fi
				let "kmax=$mnp-1"
				if [ $k -lt $kmax ] && [ $C -eq "1" ] ; then 
					echo -ne " & ">> file_APBS_$f.sh; 
				else
					echo -e "\nwait" >> file_APBS_$f.sh; 
				fi
			done
			if [ $f -eq 0 ]; then res1=$(date +%s); fi
			chmod u+x file_APBS_$f.sh
			bash file_APBS_$f.sh
			if [ $f -eq 0 ]; then 
				res2=$(date +%s)
			   	dt_each=$(echo "$res2 - $res1" | bc )
				F=$(($D+1))
				dt=$(echo "(${dt_each}+3)*$F" | bc )
				day=$(echo "$dt/86400" | bc )
				dt2=$(echo "$dt-86400*$day" | bc)
				h=$(echo "$dt2/3600" | bc )
				dt3=$(echo "$dt2-3600*$h" | bc )
				dm=$(echo "$dt3/60" | bc )
				printf "The total time estimated for the APBS calculations in the folder $Folder is %02d days %02d hours and %02d minutes\n\n" $day $h $dm | tee -a ../../REPORTFILE1	
			fi
			rm -f file_APBS_$f.sh
			let "group=$f+1"
			echo -e "$(date +%H:%M:%S) In $Folder directory the $group-th group of $mnp apbs calculations was completed" | tee -a ../../REPORTFILE1
		done	
		
		echo -e "$(date +%H:%M:%S) In $Folder directory all apbs*.sh completed for polar solvation calculations" | tee -a ../../REPORTFILE1

		for file in Hapbs*.sh; do 
			Hcal=`bash $file`
		done
		echo -e "$(date +%H:%M:%S) In $Folder directory Hapbs*.sh completed for nonpolar solvation calculations" | tee -a ../../REPORTFILE1
	else
		command=qsub
	fi



# if YES cluster

	if [ $cluster == "y" ]
	then

	# cycle on $mnp

	#let "Mnp=$mnp-1" 
	echo -e "\n\n$(date +%H:%M:%S) Starting the APBS CALCULATIONS in $Folder directory\n" | tee -a ../../REPORTFILE1

	MAX_JOBS=5; #It will be 3*2=6 jobs, 3 for polar/ 3 for non-polar calculations
	let "NGroups=($D+1)/$MAX_JOBS"
	let "RR=($D+1)%$MAX_JOBS"
	if [ $RR -eq 0 ]; then let "NGropus=$NGroups-1" ; fi

	iter=0
	for group in `seq 0 $NGroups`; do
		let "first_apbs=$group*$MAX_JOBS"
		let "last_apbs=(($group+1)*$MAX_JOBS)-1"

		if [ $group -eq $NGroups ]; then last_apbs=$D ; fi

		for j in `seq $first_apbs $last_apbs`; do
			if [ $j -eq $first_apbs ]; then
				eval "Pcalc[$j]=`$command apbs$j.sh`"
				echo -e "$(date +%H:%M:%S) In $Folder directory apbs$j.sh submitted for polar solvation calculations" | tee -a ../../REPORTFILE1
				eval "Hcalc[$j]=`$command -W depend=afterok:${Pcalc[$j]} Hapbs$j.sh`"
				echo -e "$(date +%H:%M:%S) In $Folder directory Hapbs$j.sh submitted for nonpolar solvation calculations" | tee -a ../../REPORTFILE1
			else
				let "k=$j-1"
				eval "Pcalc[$j]=`$command -W depend=afterok:${Hcalc[$k]} apbs$j.sh`"
				echo -e "$(date +%H:%M:%S) In $Folder directory apbs$j.sh submitted for polar solvation calculations" | tee -a ../../REPORTFILE1
				eval "Hcalc[$j]=`$command -W depend=afterok:${Pcalc[$j]} Hapbs$j.sh`"
				echo -e "$(date +%H:%M:%S) In $Folder directory Hapbs$j.sh submitted for nonpolar solvation calculations" | tee -a ../../REPORTFILE1
			fi
		done

		pid_1=`echo ${Hcalc[$last_apbs]}| cut -d . -f1`
		res1=$(date +%s) 
		while [ $iter -le $group ]
		do
    			check=`qstat $pid_1 2> /dev/null | wc -l`
    			sleep 5s
    			if [ $check == 0 ]; then
               			iter=$[$iter+1]
				if [ $iter -eq 1 ]; then
					res2=$(date +%s)
					dt_each=$(echo "$res2 - $res1" | bc )
					F=$(($NGroups+1))
					dt=$(echo "${dt_each}*$F" | bc )
					day=$(echo "$dt/86400" | bc )
					dt2=$(echo "$dt-86400*$day" | bc)
					h=$(echo "$dt2/3600" | bc )
					dt3=$(echo "$dt2-3600*$h" | bc )
					dm=$(echo "$dt3/60" | bc )
					printf "\nThe total time estimated for the APBS calculations in the folder $Folder is %02d days %02d hours and %02d minutes\n" $day $h $dm | tee -a ../../REPORTFILE1
				fi
    			fi
		done
	done

		
	fi

# check that everything goes in the right way
 rm -f Completed_frame.dat Failed_frame.dat
 echo -e "\n\n" | tee -a  ../../REPORTFILE1
 for ((j=0; j<$calc;j++)); do


  if [ -f Hstru$j.out ]; then
	checkH=$( echo $( awk '/Global net APOL energy/ {print $6}' Hstru$j.out) | bc -l )
	if [ ${checkH} ]; then
		echo -e "In $Folder directory Hapbs calculations completed for the $j-th structure" | tee -a ../../REPORTFILE1
		echo -e "Hapbs frame $j" >> Completed_frame.dat 
	else
		echo -e "WARNING!!! In $Folder directory Hapbs calulation relative to frame $j is not completed. Please take a look to this frame and try to do this calculation manually." | tee -a ../../REPORTFILE1 ../../WARNINGS_gmxpbsa1.dat
		echo -e "Hapbs frame $j" >> Failed_frame.dat
	fi
  else
	echo -e "WARNING!!! In $Folder directory Hapbs calulation relative to frame $j did not start. Please take a look to this frame and try to do this calculation manually." | tee -a ../../REPORTFILE1 ../../WARNINGS_gmxpbsa1.dat
	echo -e "Hapbs frame $j" >> Failed_frame.dat
  fi


  if [ -f stru$j.out ]; then
	checkP=$( echo $( awk '/Global net ELEC energy/ {print $6}' stru$j.out) | bc -l )
	if [ ${checkP} ]; then
		echo -e "In $Folder directory apbs calculations completed for the $j-th structure" | tee -a ../../REPORTFILE1
		echo -e "apbs frame $j" >> Completed_frame.dat 
	else
		echo -e "WARNING!!! In $Folder directory apbs calulation relative to frame $j is not completed. Please take a look to this frame and try to do this calculation manually." | tee -a ../../REPORTFILE1 ../../WARNINGS_gmxpbsa1.dat
		echo -e "apbs frame $j" >> Failed_frame.dat
	fi
  else
	echo -e "WARNING!!! In $Folder directory apbs calulation relative to frame $j did not start. Please take a look to this frame and try to do this calculation manually." | tee -a ../../REPORTFILE1 ../../WARNINGS_gmxpbsa1.dat
	echo -e "apbs frame $j" >> Failed_frame.dat
  fi
  
  done

if [ ! -f Failed_frame.dat ]; 
then 
	touch ../../DONE1_$Folder; 
else
	failed_apbs=`grep "^apbs"  Failed_frame.dat | wc -l`
	failed_Hapbs=`grep "^Hapbs"  Failed_frame.dat | wc -l`
	perc_apbs=$(echo "scale=2; $failed_apbs*100/$calc" | bc -l)
	perc_Hapbs=$(echo "scale=2; $failed_Hapbs*100/$calc" | bc -l)
	echo -e "$(date +%H:%M:%S): WARNING!!! In $Folder directory there are $failed_apbs APBS failed frames ($perc_apbs% of the total frames) and $failed_Hapbs HAPBS failed frames ($perc_Hapbs% of the total frames). Please check them!\nIf you want to try to recover them in gmxpbsa2.sh set the option \"RecoverJobs\" to \"y\" in the INPUT.dat file.\n" | tee -a ../../REPORTFILE1
fi

cd ../..

done
cd ..
