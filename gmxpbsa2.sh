#!/bin/bash

# GMXPBSA tool is free software. You can redistribute it and/or modify it under the GNU Lessere General Public Lincese as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version (http://www.gnu.org/licenses/lgpl-2.1.html).
# GMXPBSA is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# For any problem, doubt, comment or suggestion please contact me at dimitris3.16@gmail.com or paissoni.cristina@hsr.it
# Copyright 2013 Dimitrios Spiliotopoulos, Cristina Paissoni

#export LC_NUMERIC="en_US.UTF-8"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/function_base.dat
source $DIR/print_files.dat

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



#@@@@@@@@@@@@@@@@@#
# (1) Let's start #
#@@@@@@@@@@@@@@@@@#

clear
check INPUT.dat ERROR_NO_INPUT

set_variable_default_run "run" "1";
set_variable "root";
set_variable_default_run "backup" "y";


RUN=RUN${run}_$root


if [ -d $RUN ]; then

	if [ $backup == "y" ]; then
		cp -r $RUN backup1_$RUN;
	fi	
	cd $RUN
		if [ -f REPORTFILE2 ]  ; then  
			rm REPORTFILE2
		fi
	cd ..
	
	set_variable_default1 "protein_alone" "n" "$RUN/REPORTFILE2";
	set_variable_default1 "cas" "n" "$RUN/REPORTFILE2";
	set_variable_default1 "pdf" "n" "$RUN/REPORTFILE2";
	set_variable_default1 "coulomb" "coul" "$RUN/REPORTFILE2";
	set_variable_default1 "cluster" "n" "$RUN/REPORTFILE2";
	set_variable_default1 "mnp" "1" "$RUN/REPORTFILE2"; 
	if [ $cluster == "y" ]
	then
		set_variable "Q";
		set_variable_default2 "budget_name" ""; 
		set_variable_default2 "walltime" "";
	        #set_variable_default1 "nodes" "1" "$RUN/REPORTFILE2"; 
		#set_variable_default1 "mem" "5GB" "$RUN/REPORTFILE2";
	        set_variable_default1 "option_clu" "select=$mnp:ncpus=1:mem=5GB " "$RUN/REPORTFILE2";
		set_variable_default2 "option_clu2" "";	
	fi

	set_variable_default1 "multitrj" "n" "$RUN/REPORTFILE2";
	if [ $multitrj == "y" ]; then
		set_variable_multiple "root_multitrj";
		N_start_dir=`echo $root_multitrj | awk '{N=split($0,v," "); print N}'`
		for ((i=0; i<$N_start_dir; i++)); do
			start_dir[$i]=`echo $root_multitrj | awk -v i=$(($i+1)) '{N=split($0,v," "); print v[i]}'`
		done
	fi

	if [ $coulomb == "coul" ]; then Coul_keyword="Coulomb overall"; else Coul_keyword="GMX-coul overall"; fi
	
	nf=$(which apbs 2>/dev/null | awk -F / '{print NF-1 }') 
	if [ $nf ]; then apbs_path=$(which apbs| cut -d / -f -$nf); fi
	set_variable_default1 "Apath" "$apbs_path" "$RUN/REPORTFILE2";
	if [ -z $Apath ]; then 
		echo -e "\n"$(date +%H:%M:%S)" \n ERROR: I could not find apbs Path. Exiting... \n" >> $RUN/REPORTFILE2
		echo "Exiting -- please read the REPORTFILE2"
		exit 
	fi

	cd $RUN
	cp ../INPUT.dat ./run${run}_parameters2.in
	if [ -f run${run}_parameters.in ]; then 
		check_INPUT=`diff -e run${run}_parameters.in run${run}_parameters2.in | head -n 1 | cut -d " " -f1`;
	else 
		mv run${run}_parameters2.in run${run}_parameters.in
	fi 
	if [ -z $check_INPUT ]; then rm -f run${run}_parameters2.in; else echo -e "\nWARNING!! The INPUT file you are using now is different from the one you used running \"gmxpbsa0.sh\"\n"; fi
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


#@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (2) Failed Jobs Recovery #
#@@@@@@@@@@@@@@@@@@@@@@@@@@#
var_exit=0;
for Folder in $FolderFile; do
	
    if [ ! -f DONE1_$Folder ]; then
		
    	RecoverJobs=$(awk -v Var="RecoverJobs" '{ if($1==Var) print $2}' ../INPUT.dat);
	cd $Folder/APBS_CALCULATIONS/
		calc_tot=`ls comp*.pqr | wc -l`
		failed_apbs=`grep "^apbs"  Failed_frame.dat | wc -l`
		failed_Hapbs=`grep "^Hapbs"  Failed_frame.dat | wc -l`
		failed=`more Failed_frame.dat | wc -l`
		perc_apbs=$(echo "scale=2; $failed_apbs*100/$calc_tot" | bc -l)
		perc_Hapbs=$(echo "scale=2; $failed_Hapbs*100/$calc_tot" | bc -l)	
	cd ../..


	if [ -z "$RecoverJobs" ]; then
		echo -e "In the directory $Folder there are $failed_apbs APBS calculations (corresponding to the $perc_apbs% of the calculations) and $failed_Hapbs HAPBS calculations (corresponding to the $perc_Hapbs% of the calculations) that didn't finsh in a correct way. Please check the file $RUN/$Folder/APBS_CALCULATIONS/Failed_frame.dat. If you want to try to recover these frames set the variable \"RecoverJobs\" in the INPUT.dat file to \"y\", instead set it to \"n\". \n "  | tee -a REPORTFILE2
			var_exit=1;
	else
		if [ "$RecoverJobs" == "n" ]; then
				echo -e "WARNING!!! In the directory  $Folder the $failed failed frames won't be recovered since the variable \"RecoverJobs\" has been set to \"n\" in the INPUT.dat file, however please check the file $RUN/$Folder/APBS_CALCULATIONS/Failed_frame.dat and consider to recover these frames later."  | tee -a REPORTFILE2
		else
#----------------------------Recover Jobs-----------------------------------------------------------

			cd $Folder
   			cd APBS_CALCULATIONS
	
    			echo -e "$(date +%H:%M:%S) Starting the recovery of $failed APBS CALCULATIONS in $Folder directory" | tee -a ../../REPORTFILE2
			tot_apbs=`grep "^apbs" Failed_frame.dat | wc -l | awk '{print $1}'`
			if [ -z $tot_apbs ]; then tot_apbs=0; fi
			tot_hapbs=`grep "^Hapbs" Failed_frame.dat | wc -l | awk '{print $1}'`
			if [ -z $tot_hapbs ]; then tot_hapbs=0; fi

			for ((i=0; i<$tot_apbs; i++)); do
				apbs_fr[$i]=`grep -n "^apbs" Failed_frame.dat | awk '{print $3}' | head -n $(($i+1)) | tail -n 1`
			done
			for ((i=0; i<$tot_hapbs; i++)); do
				hapbs_fr[$i]=`grep -n "^Hapbs" Failed_frame.dat | awk '{print $3}' | head -n $(($i+1)) | tail -n 1`
			done


			let "Dapbs=$tot_apbs/$mnp"
			let "Rapbs=$tot_apbs%$mnp"
			if [ $Rapbs -eq 0 ]; then let "Dapbs=$Dapbs-1" ; fi
			mnp_apbs=$mnp
			if [ $tot_apbs -lt $mnp ]
			then
				let "Dapbs=0"
				let "mnp_apbs=$tot_apbs"
			fi

			let "Dhapbs=$tot_hapbs/$mnp"
			let "Rhapbs=$tot_hapbs%$mnp"
			if [ $Rhapbs -eq 0 ]; then let "Dhapbs=$Dhapbs-1" ; fi
			mnp_hapbs=$mnp
			if [ $tot_hapbs -lt $mnp ]
			then
				let "Dhapbs=0"
				let "mnp_hapbs=$tot_hapbs"
			fi


			
			if [ $cluster == "n" ]
			then
				command=bash
				#for each group of calculations that must be submitted in the same time create a file
				if [ $tot_apbs -gt 0 ]; then
				for (( f=0;f<=$Dapbs; f++ )); do
					echo -e "#!/bin/bash\n" > RECOVERfile_APBS_$f.sh
					let "kmax=$mnp_apbs-1"
					if [ $f -eq $Dapbs ] && [ $Rapbs -ne 0 ]; then let "kmax=$Rapbs-1"; fi

					for ((k=0;k<=$kmax;k++)); do
						let "index[$k]=($mnp_apbs*$f)+$k"
						frame=${apbs_fr[${index[$k]}]}
						if [ -f apbs$frame.sh ]; then echo -ne  "bash apbs$frame.sh" >> RECOVERfile_APBS_$f.sh; fi
						if [ $k -lt $kmax ]; then 
							echo -ne " & ">> RECOVERfile_APBS_$f.sh; 
						else
							echo -e "\nwait" >> RECOVERfile_APBS_$f.sh; 
						fi
					done
					chmod u+x RECOVERfile_APBS_$f.sh
					bash RECOVERfile_APBS_$f.sh

					rm -f RECOVERfile_APBS_$f.sh
					let "group=$f+1"
					echo -e "$(date +%H:%M:%S) In $Folder directory the $group-th group of apbs calculations was completed" | tee -a ../../REPORTFILE1

				done
				fi
			
				if [ $tot_hapbs -gt 0 ]; then	
				for (( f=0;f<=$Dhapbs; f++ )); do
					echo -e "#!/bin/bash\n" > RECOVERfile_hAPBS_$f.sh
					let "kmax=$mnp_hapbs-1"
					if [ $f -eq $Dhapbs ] && [ $Rhapbs -ne 0 ]; then let "kmax=$Rhapbs-1"; fi
					
					for ((k=0;k<=$kmax;k++)); do
						let "index[$k]=($mnp_hapbs*$f)+$k"
						frame=${hapbs_fr[${index[$k]}]}
						if [ -f Hapbs$frame.sh ]; then echo -ne  "bash Hapbs$frame.sh" >> RECOVERfile_hAPBS_$f.sh; fi
						
						if [ $k -lt $kmax ]; then 
							echo -ne " & ">> RECOVERfile_hAPBS_$f.sh; 
						else
							echo -e "\nwait" >> RECOVERfile_hAPBS_$f.sh; 
						fi
					done
					chmod u+x RECOVERfile_hAPBS_$f.sh
					bash RECOVERfile_hAPBS_$f.sh

					rm -f RECOVERfile_hAPBS_$f.sh
					let "group=$f+1"
					echo -e "$(date +%H:%M:%S) In $Folder directory the $group-th group of Hapbs calculations was completed" | tee -a ../../REPORTFILE1

				done
				fi
				
			fi	
				
				
				
    			if [ $cluster == "y" ]
			then
				
				if [ $tot_apbs -gt 0 ]; then 
					for ((count=0; count<=$Dapbs; count++)); do
						recoverPRINT_POLAR_SH_cluster "$count" "$mnp_apbs" "$Apath" "$Q" "$Dapbs" "$tot_apbs" "$budget_name" "$walltime" "${apbs_fr[*]}" "$option_clu" "$option_clu2" > RECOVERapbs$count.sh
						chmod 700 RECOVERapbs$count.sh
				 	done
				fi
			
				if [ $tot_hapbs -gt 0 ]; then 
				 	for ((count=0; count<=$Dhapbs; count++)); do
						recoverPRINT_NONPOLAR_SH_cluster "$count" "$mnp_hapbs" "$Apath" "$Q" "$Dhapbs" "$tot_hapbs" "$budget_name" "$walltime" "${hapbs_fr[*]}" "$option_clu" "$option_clu2" > RECOVERHapbs$count.sh
						chmod 700 RECOVERHapbs$count.sh
 					done
				fi

			
				
			command=qsub
				
	################################
	#Starting Recovery in case of cluster=y

	MAX_JOBS=5; #It will be 5*2=10 jobs, 5 for polar/ 5 for non-polar calculations
#dividere APBS/Hapbs...

	if [ $tot_apbs -ge $tot_hapbs ]; then D=$Dapbs; else D=$Dhapbs; fi
	let "NGroups=($D+1)/$MAX_JOBS"
	let "RR=($D+1)%$MAX_JOBS"
	if [ $RR -eq 0 ]; then let "NGropus=$NGroups-1" ; fi

	iter=0
	for group in `seq 0 $NGroups`; do
		let "first_apbs=$group*$MAX_JOBS"
		let "last_apbs=(($group+1)*$MAX_JOBS)-1"

		if [ $group -eq $NGroups ]; then last_apbs=$D ; fi

		A=-10; B=-10;
		for j in `seq $first_apbs $last_apbs`; do
			if [ $j -eq $first_apbs ]; then
				if [ -f RECOVERapbs$j.sh ]; then
					eval "Pcalc[$j]=`$command RECOVERapbs$j.sh`"
					echo -e "$(date +%H:%M:%S) In $Folder directory RECOVERapbs$j.sh submitted for polar solvation calculations" | tee -a ../../REPORTFILE1
					A=$j
				fi
			else
				if [ -f RECOVERapbs$j.sh ]; then
					let "k=$j-1"
					eval "Pcalc[$j]=`$command -W depend=afterok:${Pcalc[$k]} RECOVERapbs$j.sh`"
					echo -e "$(date +%H:%M:%S) In $Folder directory RECOVERapbs$j.sh submitted for polar solvation calculations" | tee -a ../../REPORTFILE1
					A=$j
				fi
				#eval "Hcalc[$j]=`$command -W depend=afterok:${Pcalc[$j]} Hapbs$j.sh`"
				#echo -e "$(date +%H:%M:%S) In $Folder directory Hapbs$j.sh submitted for nonpolar solvation calculations" | tee -a ../../REPORTFILE1
			fi
		done

		for j in `seq $first_apbs $last_apbs`; do
			if [ $j -eq $first_apbs ]; then
				if [ -f RECOVERHapbs$j.sh ]; then
					if [ $A -eq -10 ]; then
						eval "Hcalc[$j]=`$command RECOVERHapbs$j.sh`"
						B=$j
					else
						eval "Hcalc[$j]=`$command -W depend=afterok:${Pcalc[$A]} RECOVERHapbs$j.sh`"
						B=$j
					fi
					echo -e "$(date +%H:%M:%S) In $Folder directory RECOVERHapbs$j.sh submitted for nonpolar solvation calculations" | tee -a ../../REPORTFILE1

				fi
			else
				if [ -f RECOVERHapbs$j.sh ]; then
					let "k=$j-1"
					eval "Hcalc[$j]=`$command -W depend=afterok:${Hcalc[$k]} RECOVERHapbs$j.sh`"
					echo -e "$(date +%H:%M:%S) In $Folder directory RECOVERHapbs$j.sh submitted for nonpolar solvation calculations" | tee -a ../../REPORTFILE1
					B=$j
				fi

			fi
		done


		if [ $B -eq -10 ]; then pid_1=`echo ${Pcalc[$A]}| cut -d . -f1`; else pid_1=`echo ${Hcalc[$B]}| cut -d . -f1`; fi
		res1=$(date +%s) 
		iter=0
		#echo -e "pid1= " $pid_1"\tgroup= "$group"\titer= "$iter"\tD="$D"\n"; 
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

	############################################	
				
				
				
	fi #fi cluster=y; ora iniziano controlli.			
		

    
	#check:

    			for ((i=1; i<=$failed; i++)) ; do
	        		Job=`more Failed_frame.dat | head -n $i | tail -n 1 | awk '{print $0}'`
	    			in=`more Failed_frame.dat | head -n $i | tail -n 1 | awk '$1~/^H/ { printf "H\n"}'`;
				num=`more Failed_frame.dat | head -n $i | tail -n 1 | awk '{print $3}'`;
				name="$in"stru"$num".out;
    
	    			if [ -f $name ]; then
					if [ $in ]; then checkH=$( echo $( awk '/Global net APOL energy/ {print $6}' $name) | bc -l );
	       					else checkH=$( echo $( awk '/Global net ELEC energy/ {print $6}' $name) | bc -l );
					fi
					if [ ${checkH} ]; then
						echo -e "In $Folder directory the job \"$Job\" was recoverd" | tee -a ../../REPORTFILE2
						echo -e $Job >> Recovered_frame.dat 
					else
						echo -e "WARNING!!! In $Folder directory  the job \"$Job\" was NOT recoverd. Please take a look to this file and try to perform this calculation manually." | tee -a ../../REPORTFILE2
						echo -e $Job >> NOT_Recovered_frame.dat
					fi
	  			else
					echo -e "WARNING!!! In $Folder directory the job \"$Job\" was NOT recoverd because the calculation didn't start. Please take a look to this file and try to perform this calculation manually." | tee -a ../../REPORTFILE2
					echo -e $Job >> NOT_Recovered_frame.dat
	  			fi 
  			done

 			if [ -f NOT_Recovered_frame.dat ]; then 
	  			not_rec=`more  NOT_Recovered_frame.dat | wc -l | awk '{print $1}'`; 
				new_perc=$(echo "scale=2; $not_rec*100/(2*$calc_tot)" | bc -l)

				echo -e "\n################################################################"
				echo -e "\nThere are still $not_rec calculations ($new_perc% of the total calculations) that have not been recovered in directory $Folder. Take a look at the file NOT_Recovered_frame.dat in the directory APBS_CALCULATION. The final calculation will be performed on the other frames.\n"  | tee -a ../../REPORTFILE2
				echo -e "################################################################\n"
			else
				echo -e "\nIn the directory $Folder all the failed frames has been recovered succesfully!!\n"
				touch ../../DONE1_$Folder
  			fi
			
			
			cd ../..
		fi

#----------------------------------------------------------------------------------------------------
		
	fi
   fi
done
if [ $var_exit -eq 1 ]; then
	echo -e "Exiting! Please read the REPORTFILE2 and consider to recover manually the failed jobs.\n" |  tee -a REPORTFILE2
	exit
fi

#@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (3) STORE OLD FILES       #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@#


for Folder in $FolderFile; do
cd $Folder

check APBS_CALCULATIONS ../REPORTFILE2
check SUMMARY_FILES ../REPORTFILE2

# The APBS input and output files are stored, and so are the SH files to run them #
cd APBS_CALCULATIONS
rm -f \#*  *~ io.mc
if [ -f ../../DONE1_$Folder ]; then
	if [ -f stru0.in ]; then mkdir INs;  mv *stru*.in INs; tar cfz INs.tar.gz INs && rm -rf INs; fi
	if [ -f stru0.out ]; then mkdir OUTs;  mv *stru*.out OUTs; tar cfz OUTs.tar.gz OUTs && rm -rf OUTs; fi
	if [ -f apbs0.sh ]; then mkdir SHs;  mv *apb*sh SHs; tar cfz SHs.tar.gz SHs && rm -rf SHs; fi
	if [ -f comp0.pqr ]; then mkdir PQRs;  mv *.pqr PQRs; tar cfz PQRs.tar.gz PQRs && rm -rf PQRs; fi
	rm -f ../../DONE1_$Folder
fi
cd ..


#@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (4) ENERGY CALCULATIONS   #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@#

echo -e " \n"$(date +%H:%M:%S)" The overall energy calculation procedures are initiated in "$Folder"..." | tee -a ../REPORTFILE2

cd SUMMARY_FILES

rm -f *.val data_*.dat final_values;
touch Coulomb.val; touch  LennJon.val; touch ApolSolv.val; touch PolaSolv.val;

let "tot=$(ls stru*.rep | wc | awk '{print $1}')";

# Control the number of ststistical term in each REP file
for (( i=0; i<$tot; i++ )); do list[$i]=111110; done
for (( i=0; i<$tot; i++ )); do
	excl=0;
	Control_REPfile "$Coul_keyword" "$i" "excl"
	Control_REPfile "Lenn-Jon overall" "$i" "excl"
	Control_REPfile "^nonpolar solvation" "$i" "excl"
	Control_REPfile "^polar solvation" "$i" "excl"
	if [ $excl -eq 1 ]; then list[$i]=$i; fi
done

# For each REP file, VAL files are filled with the data contained in each REP file for: Coulombic, LJ, nonpolar solvation and polar solvation data.
frames=0;
for (( cC=0; cC<$tot; cC++ )); do
	if [ $cC -ne ${list[$cC]} ]; then
		cat stru$cC\.rep | grep "$Coul_keyword" | awk -v cC=$cC '{printf cC"\t"$4"\tCo\n"}' | tee -a Coulomb.val data_$cC.dat > /dev/null;
		cat stru$cC\.rep | grep "Lenn-Jon overall" | awk -v cC=$cC '{printf cC"\t"$4"\tLJ\n"}' |tee -a LennJon.val data_$cC.dat > /dev/null;
		cat stru$cC\.rep | grep "nonpolar solvation" | awk -v cC=$cC '{printf cC"\t"$5"\tAp\n"}' | tee -a ApolSolv.val data_$cC.dat > /dev/null;
		cat stru$cC\.rep | grep "^polar solvation" | awk -v cC=$cC '{printf cC"\t"$5"\tPo\n"}' | tee -a PolaSolv.val data_$cC.dat > /dev/null;
		frames=$(($frames+1));
	fi
done
printf "%-23s \t=\t %4s\n\n" "Number of frames" $frames > Complete.val

# For each VAL file, average and std_dev are calculated
if [ -f WARNINGS.dat ]; then rm -f WARNINGS.dat; fi
Average "Coulomb.val" "2" "Overall Coulombic" "av_Coul"
Average "LennJon.val" "2" "Overall Lennard-Jones" "av_LJ"
Average "PolaSolv.val" "2" "Polar solvation" "av_Pol"
Average "ApolSolv.val" "2" "Npolar solvation" "av_Npol"

# polar and apolar contributions are calculated
POLAR=`echo "$av_Coul+$av_Pol" |bc -l`
APOLAR=`echo "$av_LJ+$av_Npol" |bc -l`

printf "\n%-23s \t=\t %-6.3f\tkJ/mol\n" "Polar contribution" $POLAR >> Complete.val
printf "%-23s \t=\t %-6.3f\tkJ/mol\n\n" "Non-polar contribution" $APOLAR >> Complete.val

# The total energy for each frame is calculated, then an average is performed
for (( i=0; i<$tot; i++ )); do
	if [ $i -ne ${list[$i]} ]; then
		awk 'BEGIN{tot=0};{tot=tot+$2};END{printf i "\t" tot "\n"}' i=$i data_$i.dat | tee -a data_$i.dat final_values &> /dev/null;
	fi
done

Average "final_values" "2" "Final Value" "av"

# If the difference between the energy-value of frame i and the relative average is greater then 2-std_dev the frame is excluded.
if [ -f WARNINGS.dat ]; then
	OUTLIERS=`sort -k 2 -n WARNINGS.dat -u | awk '{if ($1=="FRAME") printf("%d ",$2);}'`
	N_OUT=`echo $OUTLIERS | awk '{print NF}'`
	N_frames=`echo "$frames - $N_OUT" | bc -l`
	printf "%-23s \t=\t %4s\n\n" "Number of frames" $N_frames > Complete_No_Outliers.val
	
	Average_No_Outliers "Coulomb.val" "2" "Overall Coulombic" "av_Coul_NoOut" "$OUTLIERS" 
	Average_No_Outliers "LennJon.val" "2" "Overall Lennard-Jones" "av_LJ_NoOut" "$OUTLIERS" 
	Average_No_Outliers "PolaSolv.val" "2" "Polar solvation" "av_Pol_NoOut" "$OUTLIERS" 
	Average_No_Outliers "ApolSolv.val" "2" "Npolar solvation" "av_Npol_NoOut" "$OUTLIERS" 

	# polar and apolar contributions are calculated
	POLAR_NoOut=`echo "$av_Coul_NoOut+$av_Pol_NoOut" |bc -l`
	APOLAR_NoOut=`echo "$av_LJ_NoOut+$av_Npol_NoOut" |bc -l`

	printf "\n%-23s \t=\t %-6.3f\tkJ/mol\n" "Polar contribution" $POLAR_NoOut >> Complete_No_Outliers.val
	printf "%-23s \t=\t %-6.3f\tkJ/mol\n\n" "Non-polar contribution" $APOLAR_NoOut >> Complete_No_Outliers.val

	Average_No_Outliers "final_values" "2" "Final Value" "av_final" "$OUTLIERS"
	mv Complete.val Complete_all_frames.val
	mv Complete_No_Outliers.val Complete.val
fi


#@@@@@@@@@@@@@@@@@@@#
# (5) MMPBSA PLOT   #
#@@@@@@@@@@@@@@@@@@@#

# mmpbsa_plot, containing each snapshot MM/PBSA value, is generated
echo -e  $(date +%H:%M:%S)" The mmpbsa_plot file, containing each snapshot MM/PBSA value, is generated in "$Folder"..." | tee -a ../../REPORTFILE2

printf "%-10s    %-10s    %-10s    %-10s    %-10s    %-10s \n" "# frame" "DeltaG(kJ/mol)" "Coul(kJ/mol)" "vdW(kJ/mol)" "PolSol(kJ/mol)" "NpoSol(kJ/mol)" > mmpbsa_plot
for (( i=0; i<$tot; i++ )); do
  	if [ $i -ne ${list[$i]} ]; then
  		 val=`tail -1 data_$i.dat | awk '{print $2}'`; 
 		 LeJ=`grep "LJ" data_$i.dat | awk '{print $2}'`; Cou=`grep "Co" data_$i.dat | awk '{print $2}'`; 
 		 PoS=`grep "Po" data_$i.dat | awk '{print $2}'`; ApS=`grep "Ap" data_$i.dat | awk '{print $2}'`;
 		 printf "%-10s \t %-4.3f \t %-4.3f \t %-4.3f \t %-4.3f \t %-4.3f \n" "$i" "$val" "$Cou" "$LeJ" "$PoS" "$ApS" >> mmpbsa_plot
	fi
done

rm -f data_*.dat final_values Coulomb.val LennJon.val ApolSolv.val  PolaSolv.val;



#@@@@@@@@@@@@@@@@@@@@@@@@#
# Generation of PDF file #
#@@@@@@@@@@@@@@@@@@@@@@@@#
if [ "$pdf" = "y" ]; then
 
 if [ -f Complete.pdf ]; then rm -f Complete.pdf Complete.dvi Complete.aux Complete.tex Complete.log Complete.ps; fi 
 
 echo -e $(date +%H:%M:%S)"Started generating Complete.pdf in "$Folder"..." | tee -a ../../REPORTFILE2
 
 sTdEVco=`grep "Overall Coulombic" Complete.val | awk '{print $NF}'`
 sTdEVlj=`grep "Overall Lennard-Jones" Complete.val | awk '{print $NF}'`
 sTdEVps=`grep "^Polar solvation" Complete.val | awk '{print $NF}'`
 sTdEVas=`grep "^Npolar solvation" Complete.val | awk '{print $NF}'`

 # Generation of a TEX file
 echo '\documentclass[a4paper,10pt]{article}'                                   >> Complete.tex;
 echo '\title{Binding free energy calculations}' 		                >> Complete.tex;
 echo '\author{GMXPBSA}'                                                        >> Complete.tex;
 echo '\begin{document}'                                                        >> Complete.tex;
 echo $(ls str*.rep | wc | awk '{print $1}')' frames considered \\'             >> Complete.tex;
 echo ' \\'                                                                     >> Complete.tex;
 echo '\begin{center}'                                                          >> Complete.tex;
 echo '\begin{tabular}{|c|c|}'                                                  >> Complete.tex;
 echo '\hline\hline'                                                            >> Complete.tex;
 echo ' & {kJ/mol} \\'                        					>> Complete.tex;
 echo '\hline'                                                			>> Complete.tex;
 echo 'Coulombic & '$av_Coul' $\pm$ '$sTdEVco' \\'				>> Complete.tex;
 echo 'Lennard-Jones & '$av_LJ' $\pm$ '$sTdEVlj' \\'				>> Complete.tex;
 echo 'Polar solvation & '$av_Pol' $\pm$ '$sTdEVps' \\'			>> Complete.tex;
 echo 'Nonpolar solvation & '$av_Npol' $\pm$ '$sTdEVas' \\'			>> Complete.tex;
 echo 'Final Value & '$mEAN_fi' $\pm$ '$sTdEVfi' \\'				>> Complete.tex;
 echo '\hline'									>> Complete.tex;
 echo '\end{tabular}'								>> Complete.tex;
 echo '\end{center}'								>> Complete.tex;
 echo '\end{document}'								>> Complete.tex;
 
 # ... which is postprocessed into a PDF file.
 latex Complete.tex &> /dev/null;
 dvips Complete.dvi -o &> /dev/null;
 dvipdf Complete.dvi &> /dev/null;
 rm -f Complete.dvi Complete.aux Complete.tex Complete.log Complete.ps

fi


if [ -f WARNINGS.dat ]; then N_warnings=`grep "^FRAME" WARNINGS.dat | wc -l`; echo -e "There are "$N_warnings" WARNINGS. Take a look at the WARNINGS.dat file in "$(pwd)"." | tee -a ../../REPORTFILE2 ; fi

echo -e $(date +%H:%M:%S)" The calculation procedures are terminated for "$Folder".\n" | tee -a ../../REPORTFILE2

cd ..
cd ..

done


if [ $cas == "n" -a $multitrj == "n" ]; then
	cp $root/SUMMARY_FILES/Complete.val ./Final_MMPBSA.dat
fi

if [ $cas == "y" -o $multitrj == "y" ]; then
	touch Compare_MMPBSA.dat 
	if [ $protein_alone == "y" ]; then
		printf "%-15s %-20s %-15s %-15s %-22s %-22s %-22s %-22s\n" "# system" "G(kJ/mol)" "Polar(kJ/mol)" "NPolar(kJ/mol)" "Coul(kJ/mol)" "VdW(kJ/mol)" "PolSol(kJ/mol)" "NpoSol(kJ/mol)" > Compare_MMPBSA.dat 
	else
		printf "%-15s %-20s %-15s %-15s %-22s %-22s %-22s %-22s\n" "# system" "DeltaG(kJ/mol)" "Polar(kJ/mol)" "NPolar(kJ/mol)" "Coul(kJ/mol)" "VdW(kJ/mol)" "PolSol(kJ/mol)" "NpoSol(kJ/mol)" > Compare_MMPBSA.dat 
	fi

if [ $cas == "n" ]; then

	for ((i=0; i<$N_start_dir; i++)); do

		DeltaG[$i]=`grep "Final Value" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f", $4}' `
		DeltaG_dev[$i]=`grep "Final Value" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $6}'`
		Polar=`grep "Polar contribution" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		NonPolar=`grep "Non-polar contribution" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		Coul=`grep "Overall Coulombic" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		Coul_dev=`grep "Overall Coulombic" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $6}' `
		VdW=`grep "Overall Lennard-Jones" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		VdW_dev=`grep "Overall Lennard-Jones" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $6}' `
		PolSol=`grep "Polar solvation" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		PolSol_dev=`grep "Polar solvation" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $6}' `
		NpoSol=`grep "Npolar solvation" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		NpoSol_dev=`grep "Npolar solvation" ${start_dir[$i]}/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $6}' `
			
		printf "%-15s %-20s %-15s %-15s %-22s %-22s %-22s %-22s\n" "${start_dir[$i]}" "${DeltaG[$i]} +/- ${DeltaG_dev[$i]}" "$Polar" "$NonPolar" "$Coul +/- $Coul_dev" "$VdW +/- $VdW_dev" "$PolSol +/- $PolSol_dev" "$NpoSol +/- $NpoSol_dev" >> Compare_MMPBSA.dat 
	done

else	
	i=0
	for Folder in $FolderFile; do
		DeltaG[$i]=`grep "Final Value" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f", $4}' `
		DeltaG_dev[$i]=`grep "Final Value" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $6}'`
		Polar=`grep "Polar contribution" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		NonPolar=`grep "Non-polar contribution" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		Coul=`grep "Overall Coulombic" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		Coul_dev=`grep "Overall Coulombic" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $6}' `
		VdW=`grep "Overall Lennard-Jones" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		VdW_dev=`grep "Overall Lennard-Jones" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $6}' `
		PolSol=`grep "Polar solvation" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		PolSol_dev=`grep "Polar solvation" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $6}' `
		NpoSol=`grep "Npolar solvation" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $4}' `
		NpoSol_dev=`grep "Npolar solvation" $Folder/SUMMARY_FILES/Complete.val | awk '{printf "%3.1f",  $6}' `
			
		printf "%-15s %-20s %-15s %-15s %-22s %-22s %-22s %-22s\n" "$Folder" "${DeltaG[$i]} +/- ${DeltaG_dev[$i]}" "$Polar" "$NonPolar" "$Coul +/- $Coul_dev" "$VdW +/- $VdW_dev" "$PolSol +/- $PolSol_dev" "$NpoSol +/- $NpoSol_dev" >> Compare_MMPBSA.dat 
		i=$(echo "$i + 1" | bc -l)
	done
fi		
	
	
	
	
	if [ $protein_alone == "y" ]; then
		printf "\n\n%-25s %-25s %-25s\n" "# system" "G(kJ/mol)" "DeltaG(kJ/mol)" >> Compare_MMPBSA.dat
	else
		printf "\n\n%-25s %-25s %-25s\n" "# system" "DeltaG(kJ/mol)" "DeltaDeltaG(kJ/mol)" >> Compare_MMPBSA.dat
	fi

	
if [ $cas == "n" ]; then
	
	for ((i=0; i<$N_start_dir; i++)); do
		if [ $i -eq 0 ]; then
			printf "%-25s %-25s %-25s\n" "${start_dir[$i]}" "${DeltaG[$i]} +/- ${DeltaG_dev[$i]}" "-" >> Compare_MMPBSA.dat
		else
			DeltaDeltaG=$(echo "${DeltaG[$i]} - ${DeltaG[0]}"|bc -l | awk '{printf "%3.1f", $1}')
			DeltaDeltaG_dev=$(echo "(${DeltaG_dev[$i]}*${DeltaG_dev[$i]}) + (${DeltaG_dev[0]}*${DeltaG_dev[0]})" | bc -l)
			DeltaDeltaG_dev=$(echo "sqrt(${DeltaDeltaG_dev})"|bc -l | awk '{printf "%3.1f", $1}')
			printf "%-25s %-25s %-25s\n" "${start_dir[$i]}" "${DeltaG[$i]} +/- ${DeltaG_dev[$i]}" "${DeltaDeltaG} +/- ${DeltaDeltaG_dev}" >> Compare_MMPBSA.dat
		fi	
	
	done

else
	
	i=0; ref=0;
	for Folder in $FolderFile; do
		a=`echo $Folder | awk '{if($1 ~ /MUTATION/) {print 1} else {print 0}}'`
		if [ $ref -eq 0 ]; then
			if [ $a -eq 0 ]; then
				Ref_Dir=$i;
				ref=100;
			fi
		fi
		i=$(echo "$i + 1" | bc -l)
	done

	
	
	if [ ! $multitrj == "y" ]; then 
		N_start_dir=1;
		start_dir[0]=$root;
	fi

	i=0; ref=0;
	for ((i=0; i<$N_start_dir; i++)); do val_start_dir[$i]=1; done
	i=0;
	for Folder in $FolderFile; do
		if [ $i -eq $Ref_Dir ]; then
		#	mut="ref"
			printf "%-25s %-25s %-25s\n" "$Folder" "${DeltaG[$i]} +/- ${DeltaG_dev[$i]}" "-" >> Compare_MMPBSA.dat
		else
		#	a=`echo $Folder | awk '{if($1 ~ /MUTATION/) {print 1} else {print 0}}'`
		#	if [ $a -eq 1 ]; then
		#		for ((j=0; j<$N_start_dir; j++)); do
		#			i_ref_prova=`echo $Folder | awk -v start_dir=${start_dir[$j]}_ -v j=$j '{if ($1 ~ start_dir) printf j}'`
		#			if [ $i_ref_prova ]; then i_ref=$i_ref_prova; fi	
		#		done	
		#		res_type=`egrep "^MUTATION[[:blank:]]*${start_dir[$i_ref]}[[:blank:]]" ../INPUT.dat| head -n ${val_start_dir[$i_ref]} |tail -n 1 | awk '{if($1=="MUTATION") print $4}'`
		#		res_id=`egrep "^MUTATION[[:blank:]]*${start_dir[$i_ref]}[[:blank:]]" ../INPUT.dat| head -n ${val_start_dir[$i_ref]}|tail -n 1 | awk '{if($1=="MUTATION") print $3}'`
		#		prot_lig=`egrep "^MUTATION[[:blank:]]*${start_dir[$i_ref]}[[:blank:]]" ../INPUT.dat| head -n ${val_start_dir[$i_ref]}|tail -n 1 | awk '{if($1=="MUTATION") print $5}'`
		#		mut=${res_type}${res_id}ALA_${prot_lig}
		#		val_start_dir[$i_ref]=$((${val_start_dir[$i_ref]}+1))
		#	else
		#		mut="--"
		#	fi
			DeltaDeltaG=$(echo "${DeltaG[$i]} - ${DeltaG[$Ref_Dir]}"|bc -l | awk '{printf "%3.1f", $1}')
			DeltaDeltaG_dev=$(echo "(${DeltaG_dev[$i]}*${DeltaG_dev[$i]}) + (${DeltaG_dev[$Ref_Dir]}*${DeltaG_dev[$Ref_Dir]})" | bc -l)
			DeltaDeltaG_dev=$(echo "sqrt(${DeltaDeltaG_dev})"|bc -l | awk '{printf "%3.1f", $1}')
			printf "%-25s %-25s %-25s\n" "$Folder" "${DeltaG[$i]} +/- ${DeltaG_dev[$i]}" "${DeltaDeltaG} +/- ${DeltaDeltaG_dev}" >> Compare_MMPBSA.dat
		fi

			i=$(echo "$i + 1" | bc -l)
	done

fi
fi



#Conclusion
echo -e  $(date +%H:%M:%S)"\n#### PLEASE READ AND CITE THE FOLLOWING REFERENCE ####\n\n" | tee -a REPORTFILE2
echo -e  "-------- -------- ------------------- -------- --------\nS Pronk, S Páll, R Schulz, P Larsson, P Bjelkmar, R Apostolov, MR Shirts,\nJC Smith, PM Kasson, D van der Spoel, B Hess and E Lindahl\nGROMACS 4.5: a high-throughput and highly parallel open source molecular\nsimulation toolkit\nBioinformatics 29 (2013) pp. 845-854\n-------- -------- ------------------- -------- --------\n\n" | tee -a REPORTFILE2
echo -e  "-------- -------- ------------------- -------- --------\nNA Baker, D Sept, S Joseph, MJ Holst, and JA McCammon\nElectrostatics of nanosystems: Application to microtubules and the ribosome\nProc. Natl. Acad. Sci. USA 98 (2001) pp. 10037-10041\n-------- -------- ------------------- -------- --------\n\n" | tee -a REPORTFILE2
echo -e  "-------- -------- ------------------- -------- --------\nC Paissoni, D Spiliotopoulos, G Musco, A Spitaleri\nGMXPBSA 2.0: a GROMACS tool to perform MM/PBSA and computational alanine scanning\nComputer Physics Communication 185 (2014) pp. 2920-2929\n-------- -------- ------------------- -------- --------\n\n" | tee -a REPORTFILE2
echo -e  "-------- -------- ------------------- -------- --------\nD Spiliotopoulos, A Spitaleri, G Musco\nInteractions with Molecular Dynamics Simulations and Binding Free Energy Calculations:\nAIRE-PHD1, a Comparative Study.\nPLoS ONE 7(10) (2012) pp. e46902\n-------- -------- ------------------- -------- --------\n\n" | tee -a REPORTFILE2
echo -e  "\n\nThanks for using GMXPBSA tool!\n" | tee -a REPORTFILE2



cd ..
