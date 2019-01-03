#!/bin/bash 

# GMXPBSA tool is free software. You can redistribute it and/or modify it under the GNU Lessere General Public Lincese as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version (http://www.gnu.org/licenses/lgpl-2.1.html).
# GMXPBSA is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# For any problem, doubt, comment or suggestion please contact me at dimitris3.16@gmail.com or paissoni.cristina@hsr.it

# Copyright 2013 Dimitrios Spiliotopoulos, Cristina Paissoni

#export LC_NUMERIC="en_US.UTF-8"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/function_base.dat
source $DIR/function_gmx.dat
source $DIR/function_apbs.dat
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

#@@@@@@@@@@@@@@@@@@#
# (1) Let's start #
#@@@@@@@@@@@@@@@@@@#
clear 
if [ -f REPORTFILE0 ]  ; then  rm REPORTFILE0; fi
if [ -f WARNINGS_gmxpbsa0.dat ]  ; then rm WARNINGS_gmxpbsa0.dat; fi

touch REPORTFILE0
check INPUT.dat REPORTFILE0
rm -f \#* *~


#@@@@@@@@@@@@@@@#
# (2) Variables #
#@@@@@@@@@@@@@@@#

set_variable_default "run" "1";
set_variable "root";

set_variable_default "multitrj" "n";
if [ $multitrj == "y" ]; then
	set_variable_multiple "root_multitrj";
	N_start_dir=`echo $root_multitrj | awk '{N=split($0,v," "); print N}'`
	for ((i=0; i<$N_start_dir; i++)); do
		start_dir[$i]=`echo $root_multitrj | awk -v i=$(($i+1)) '{N=split($0,v," "); print v[i]}'`
		check_DIR ${start_dir[$i]}
	done
else
	check_DIR $root
fi

# MD variables 
set_variable_default "protein_alone" "n";

set_variable_default "name_xtc" "npt";
set_variable_default "name_tpr" "npt";

set_variable "complex";

if [ $protein_alone == "n" ]; then
	set_variable "receptor";
	set_variable "ligand";
fi

set_variable_default "skip" "1";
set_variable_default "min" "n";

set_variable_default "use_topology" "n";
#set_variable_default "NO_topol_ff" "n";
NO_topol_ff="n"

if [ $NO_topol_ff == "y" ]; then
	cas=$(echo n); ffield="n"; use_nonstd_ff="n"; use_topology="n";
	echo -e "\nYou are not providing neither forcefield nor topology to GMXPBSA.\nWith this option you can not perform alanine scanning." | tee -a REPORTFILE0
	if [ $min == "y" ]; then echo -e "WARNING! With this option you can not perform energy minimization. Setting \"min\" to \"n\".\n" | tee -a REPORTFILE0; fi
	min="n";
else
	if [ $use_topology == "y" ]; then
		if [ $protein_alone == "n" ]; then
			read_topology "itp_receptor";
			set_variable "itp_ligand";
			set_variable_default "water_mol" "0";
		else
			read_topology2 "itp_protein" "itp_protein_check";
		fi
		cas=$(echo n); ffield="n"; use_nonstd_ff="n"; Ltopology_Pff="n";
		echo -e "\nYou are using the option \"use_topology\".\n" | tee -a REPORTFILE0
	else
		set_variable_default "Ltopology_Pff" "n";
		if [ $Ltopology_Pff == "y" ]; then
			set_variable_default "use_nonstd_ff" "n";
			if [ $use_nonstd_ff == "n" ]; then 
				set_variable "ffield";
			        echo -e "\nYou are using the option \"Ltopology_Pff\", using custom topology (itp file) for the ligand and a std forcefield for the protein.\n" | tee -a REPORTFILE0
			else 
				ffield="1"; 
				 echo -e "\nYou are using the option \"Ltopology_Pff\", using custom topology (itp file) for the ligand and a non-std forcefield for the protein.\n" | tee -a REPORTFILE0
			fi
			set_variable "itp_ligand";
			set_variable_multiple_default "Histidine" "";	
		else
			set_variable_default "use_nonstd_ff" "n";
			if [ $use_nonstd_ff == "n" ]; then 
				set_variable "ffield";
			        echo -e "\nYou are using a standard forcefield.\n" | tee -a REPORTFILE0
			else 
				ffield="1"; 
				echo -e "\nYou are using the option \"use_nonstd_ff\".\n" | tee -a REPORTFILE0
			fi
		fi
		set_variable_default "cas" "n";
	fi

fi


set_variable_default "multichain" "n";
#multichain=n

# Gromacs variables 

 # double precision? 
#set_variable_default "double_p" "n";

set_variable_default2 "gmx_suffix" "";
set_variable_default2 "gmx_prefix" "";
set_variable_default "read_vdw_radii" "n";

#################################
#if [ $double_p == "y" ]
#then
	 pdb2gmx=${gmx_prefix}pdb2gmx${gmx_suffix}; trjconv=${gmx_prefix}trjconv${gmx_suffix}; mdrun=${gmx_prefix}mdrun${gmx_suffix}; grompp=${gmx_prefix}grompp${gmx_suffix}; editconf=${gmx_prefix}editconf${gmx_suffix}; tpbconv=${gmx_prefix}tpbconv${gmx_suffix}; gmx=${gmx_prefix}gmx${gmx_suffix}
#else
#	 pdb2gmx=pdb2gmx; trjconv=trjconv; mdrun=mdrun; grompp=grompp; editconf=editconf; tpbconv=tpbconv;
#fi
# pdb2gmx  trjconv mdrun grompp editconf tpbconv
############################################


  # what is Gromacs path? (Gpath)
nf=$(which $editconf 2>/dev/null | awk -F / '{print NF-1 }') 
if [ $nf ]; then 
	gmx_path=$(which $editconf | cut -d / -f -$nf); 
else
	nf=$(which $gmx 2>/dev/null | awk -F / '{print NF-1 }') 
	if [ $nf ]; then 
		gmx_path=$(which $editconf | cut -d / -f -$nf);
	fi
fi
set_variable_default "Gpath" "$gmx_path";

 # is Gromacs installed? 
if [ -z $Gpath ]; then 
	echo -e "\n"$(date +%H:%M:%S)" \n ERROR: I could not find Gromacs Path. Exiting... \n" >> REPORTFILE0
	echo "Exiting -- please read the REPORTFILE0"
	exit
else
	control0=`find $Gpath -maxdepth  1 -name $gmx 2>/dev/null | rev| cut -d / -f 1`
	if [ -z $control0 ]; then
	       control1=`find $Gpath -maxdepth  1 -name $editconf 2>/dev/null | rev| cut -d / -f 1`
		if [ -z $control1 ]; then 
			echo "The variable Gpath is not set correctly. Please double-check it. Exiting..."; exit;
		else
			control1=`find $Gpath -maxdepth  1 -name $editconf 2>/dev/null | rev| cut -d / -f 1 | rev | awk '{if ($1~"editconf") {print "ok"} else {print "no"} }'`
			if [ $control1 == "no" ]; then 
				echo "The variable Gpath is not set correctly. Please double-check it. Exiting..."; exit;
			else
				Gversion="4"; 
			fi
		fi
	else
		control0=`find $Gpath -maxdepth  1 -name $gmx 2>/dev/null | rev| cut -d / -f 1 | rev | awk '{if ($1~"gmx") {print "ok"} else {print "no"} }'`
		if [ $control0 == "no" ]; then 
			echo "The variable Gpath is not set correctly. Please double-check it. Exiting..."; exit; 
		else 
			Gversion="5"; 
		fi
	fi

fi


 # what Gromacs version is installed? (GVersion)
if [ $Gversion -eq 4 ]; then 
	$Gpath\/$editconf -h 2> out 1> /dev/null
	GVersion=$(grep VERSION out | awk '{print $3}' | sort -u)
else
	$Gpath\/$gmx -h 2> out 1> /dev/null
	GVersion=$(grep VERSION out | awk '{print $NF}'| sort -u)
	pdb2gmx="${gmx} pdb2gmx"; trjconv="${gmx} trjconv"; mdrun="${gmx} mdrun"; grompp="${gmx} grompp"; editconf="${gmx} editconf"; tpbconv="${gmx} convert-tpr";

fi
echo -e "\nUsing GROMACS version $GVersion"
rm -f out


# APBS Variables

set_variable_default "coulomb" "gmx";
if [ $coulomb == "coul" ]; then 
	nf=$(which coulomb 2>/dev/null | awk -F / '{print NF-1 }') 
	if [ $nf ]; then coul_path=$(which coulomb| cut -d / -f -$nf); fi
	set_variable_default "Cpath" "$coul_path"; 
	if [ -z $Cpath ]; then 
		echo -e "\n"$(date +%H:%M:%S)" \n ERROR: I could not find coulomb Path. Exiting... \n" >> REPORTFILE0
		echo "Exiting -- please read the REPORTFILE0"
		exit
	else
		control=`find $Cpath -maxdepth  1 -name coulomb 2>/dev/null | rev| cut -d / -f 1`
		if [ -z $control ]; then 
			echo "The variable Cpath is not set correctly. Please double-check it. Exiting..."; exit;
		else
			control=`find $Cpath -maxdepth  1 -name coulomb 2>/dev/null | rev| cut -d / -f 1 | rev | awk '{if ($1=="coulomb") {print "ok"} else {print "no"} }'`
			if [ $control == "no" ]; then echo "The variable Cpath is not set correctly. Please double-check it. Exiting..."; exit; fi
		fi
	fi
fi

nf=$(which apbs 2>/dev/null | awk -F / '{print NF-1 }') 
if [ $nf ]; then apbs_path=$(which apbs| cut -d / -f -$nf); fi
set_variable_default "Apath" "$apbs_path";
if [ -z $Apath ]; then 
	echo -e "\n"$(date +%H:%M:%S)" \n ERROR: I could not find apbs Path. Exiting... \n" >> REPORTFILE0
	echo "Exiting -- please read the REPORTFILE0"
	exit
else
	control=`find $Apath -maxdepth  1 -name apbs 2>/dev/null | rev| cut -d / -f 1`
	if [ -z $control ]; then 
		echo "The variable Apath is not set correctly. Please double-check it. Exiting..."; exit;
	else
		control=`find $Apath -maxdepth  1 -name apbs 2>/dev/null | rev| cut -d / -f 1 | rev | awk '{if ($1=="apbs") {print "ok"} else {print "no"} }'`
		if [ $control == "no" ]; then echo "The variable Apath is not set correctly. Please double-check it. Exiting..."; exit; fi
	fi
fi

echo -e "\nSetting the APBS variables\n"

set_variable_default "precF" "0";
set_variable_default "extraspace" "5";
set_variable_default "coarsefactor" "1.7";
set_variable_default "grid_spacing" "0.5";

set_variable_default "linearized" "y";
set_variable_default "temp" "293";
set_variable_default "bcfl" "mdh";
set_variable_default "pdie" "2";
set_variable_default "sdie" "80";
set_variable_default "chgm" "spl2";
set_variable_default "srfm" "smol";
set_variable_default "srad" "1.4";
set_variable_default "swin" "0.3";
set_variable_default "sdens" "10.0";
set_variable_default "calcforce" "no";
set_variable_default "ion_ch_pos" "1";
set_variable_default "ion_rad_pos" "2.000";
set_variable_default "ion_conc_pos" "0.1500";
set_variable_default "ion_ch_neg" "-1";
set_variable_default "ion_rad_neg" "2.000";
set_variable_default "ion_conc_neg" "0.1500";

set_variable_default "Hsrfm" "sacc";
set_variable_default "Hpress" "0.000";
set_variable_default "Hgamma" "0.0227";
#set_variable_default "Hbconc" "0.000";
set_variable_default "Hdpos" "0.20";
set_variable_default "Hcalcforce" "total";
set_variable_default "Hxgrid" "0.1";
set_variable_default "Hygrid" "0.1";
set_variable_default "Hzgrid" "0.1";

calcenergy="total"
Hbconc="0.00"

# PBS queque system variables 
echo -e "\nSetting the PBS queque variables\n"
set_variable_default "cluster" "y";
set_variable_default "mnp" "1"; 
if [ $cluster == "y" ]
then
	set_variable "Q";
	set_variable_default2 "budget_name" ""; 
	set_variable_default2 "walltime" "";
        #set_variable_default "nodes" "1"; 
	#set_variable_default "mem" "5GB"; 
	set_variable_default "option_clu" "select=$mnp:ncpus=1:mem=5GB ";
	set_variable_default2 "option_clu2" "";
fi


# output variables
set_variable_default "pdf" "n";



#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (3) initialization of the procedure #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#

if [ $multitrj == "y" ]; then
	FolderFile=$root_multitrj
else
	FolderFile=$root
fi


RUN=RUN${run}_$root
check_run "$RUN"

PRINT_WELCOME >> REPORTFILE0

for FoLdeR in $FolderFile; do

#entering in each folder... 
cd $FoLdeR
rm -f \#* *~

# check the existence of the trajectory, topology and index files
check $name_xtc.xtc ../REPORTFILE0; check $name_tpr.tpr ../REPORTFILE0; check index.ndx ../REPORTFILE0;


if [ $use_topology = "y" ]; then
	# the topology files for the receptor and the ligand are created and their existence is checked
       	check topol.top ../REPORTFILE0; 
	if [ $protein_alone == "n" ]; then
	 	check "$itp_ligand" ../REPORTFILE0;
		topology "$itp_receptor" "$itp_ligand" "$receptor" "$ligand" "comp" "${water_mol}"
		check topol_comp.top ../REPORTFILE0; check topol_$receptor.top ../REPORTFILE0; check topol_$ligand.top ../REPORTFILE0;
	else
		if [ $itp_protein_check == "NO" ]; then
			cp topol.top topol_comp.top
		else
		        topology2 "$itp_protein" "comp"
			check topol_comp.top ../REPORTFILE0;
		fi

	fi
else
	
	if [ $Ltopology_Pff == "y" ]; then
		check "$itp_ligand" ../REPORTFILE0;
		#altro? creo qui topologia o dopo?
	fi
	if [ $use_nonstd_ff == "y" ]; then
		check residuetypes.dat ../REPORTFILE0
		check "*.ff" ../REPORTFILE0
	else
		check_NOdir "*.ff"
	fi
fi


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (4) generation of complex, receptor and ligand centered PDB files #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# Here it generates the centered complex PDB files...
echo -e " \n"$(date +%H:%M:%S)" Generating the centered PDB structures in "$FoLdeR"..." | tee -a ../REPORTFILE0


if [ $protein_alone == "n" ]; then
 	echo "$complex"| $Gpath\/$trjconv -f $name_xtc.xtc -o ${name_xtc}_out.xtc -s $name_tpr.tpr -pbc whole -n index.ndx  >>STD_ERR0 2>&1
	new_xtc=${name_xtc}_out
else 
	new_xtc=${name_xtc}
fi

 echo "$complex" "$complex" "$complex" | $Gpath\/$trjconv -f ${new_xtc}.xtc -o _comp.pdb -s $name_tpr.tpr -fit rot+trans -n index.ndx -sep -center -skip $skip  >>STD_ERR0 2>&1
 if [ "$min" = "y" ]; then
	echo "$complex" "$complex" "$complex" | $Gpath\/$trjconv -f ${new_xtc}.xtc -o _comp.gro -s $name_tpr.tpr -fit rot+trans -n index.ndx -sep -center -skip $skip  >>STD_ERR0 2>&1
 fi
 
 if [ $protein_alone == "n" ]; then
 	rm -f ${new_xtc}.xtc
fi

 check2 _comp0.pdb ../REPORTFILE0

# ... and here it generates the receptor and ligand PDB files

if [ $protein_alone == "n" ]; then

 let "fin=$(ls _comp*.pdb | wc | awk '{print $1}')"
 let "fin=$fin-1"
 
 for (( counter=0; counter<=$fin; counter++ )) ; do
  fakeprot=$(echo $receptor$counter)
  fakeliga=$(echo $ligand$counter)
  echo "$receptor" | $Gpath\/$editconf -f _comp$counter.pdb -o _$fakeprot.pdb -n index.ndx >>STD_ERR0 2>&1
  echo "$ligand" | $Gpath\/$editconf -f _comp$counter.pdb -o _$fakeliga.pdb -n index.ndx >>STD_ERR0 2>&1
#  Update "$counter"
 done

 check2 _$receptor\0.pdb ../REPORTFILE0
 check2 _$ligand\0.pdb ../REPORTFILE0
fi

 rm -f STD_ERR0
cd ..
done

mkdir $RUN
cp INPUT.dat $RUN/run${run}_parameters.in
mv REPORTFILE0 $RUN
for FoLdeR in $FolderFile; do
	mkdir $RUN/$FoLdeR
	cd $FoLdeR
		for file in _*.pdb
		do
			mv $file ../$RUN/$FoLdeR
		done
	        cp index.ndx ../$RUN/$FoLdeR
	
		if [ $NO_topol_ff == "y" ]; then
			cp ${name_tpr}.tpr ../$RUN/$FoLdeR
		else
			if [ $cas == "n" ] && [ $min == "n" ]; then
				cp ${name_tpr}.tpr ../$RUN/$FoLdeR
			fi
		fi

		if [ "$min" == "y" ]; then
			for file in _comp*.gro
			do
				mv $file ../$RUN/$FoLdeR
			done
		fi
		
		if [ $use_nonstd_ff == "y" ]; then
			cp -r *.ff ../$RUN/$FoLdeR
			cp residuetypes.dat ../$RUN/$FoLdeR
		fi
		if [ $use_topology == "y" ]; then
			cp *.top ../$RUN/$FoLdeR
			cp *.itp ../$RUN/$FoLdeR
			rm -f topol_comp.top topol_$receptor.top topol_$ligand.top
		fi
		if [ $Ltopology_Pff == "y" ]; then
			cp *.itp ../$RUN/$FoLdeR
		fi
		
	cd ..
done


#find box-minimization dimension reading the pdb files..
if [ "$min" == "y" ]; then
	for FoLdeR in $FolderFile; do
		cd $RUN/$FoLdeR
		let "fin2=$(ls _comp*.gro | wc | awk '{print $1}')"
		let "fin2=$fin2-1"
		find_box "$fin2" "bX" "bY" "bZ" 
		rm -f _comp*.gro
		cd ../..
	done
fi


#@@@@@@@@ò@@@@@@@@@@@@@@@@@@@@@@@@@@#
#  CAS: Mutants' folders generation #		
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#

cd $RUN
if [ "$cas" = "y" ]; then

  echo -e "\n"$(date +%H:%M:%S)" These calculations will be performed with the CAS approach!\nGenerating the Mutants' folders...\n" | tee -a REPORTFILE0;


  # The file deleteSC.pl is generated...
  PRINT_DELETESC > deleteSC.pl
  chmod 700 deleteSC.pl

  # read the mutations to perform from the input file. 
  # There are "N_Mut_folder" folders on which perform the mutations. On the folder j, named "FOLDER[$j]" (with j belonging to [1,...,N_Mut_folder]), 
  # are performed "count_FOLDER[$j]" mutations


  N_MUTATION_TOT=`grep "^MUTATION" ../INPUT.dat | wc -l`
  N_Mut_folder=0
  if [ $N_MUTATION_TOT -eq 0 ]; then echo -e "\n\nWARNING!!!! No mutation can be read!! \n\n" | tee -a REPORTFILE0 WARNINGS_gmxpbsa0.dat; fi


  # calculate N_Mut_folder and count_$root
  for ((i=0;i<$N_MUTATION_TOT;i++))
  do
	dir[$i]=`grep "^MUTATION" ../INPUT.dat|head -n $(($i+1)) |tail -n 1| awk '{print $2}'`
	control=0
	for ((j=0;j<$N_Mut_folder;j++))
	do
		ref=${FOLDER[$j]}
		if [ "${dir[$i]}" == "$ref"  ]
		then
			control=$(($control+1))
			jREF=$j
		fi
	done		
	if [ $control -eq 0 ]
	then
		FOLDER[$N_Mut_folder]=${dir[$i]}
		count_FOLDER[$N_Mut_folder]=1
		N_Mut_folder=$(($N_Mut_folder+1))
	else
		count_FOLDER[$jREF]=$((${count_FOLDER[$jREF]}+1))	
	fi
  done


 for ((i=0;i<$N_Mut_folder ;i++))
 do

# calculate Ngroups for each Folder
 
	 Ngroups=0
	for ((j=0;j<${count_FOLDER[$i]} ;j++))
	do
		gr[$j]=`grep "^MUTATION[[:blank:]]*${FOLDER[$i]}[[:blank:]]" ../INPUT.dat|head -n $(($j+1)) |tail -n 1| awk '{print $6}'`
		control=0
		for ((k=0;k<${Ngroups};k++))
		do
			ref=${Group_name[$k]}
			if [ "${gr[$j]}" == "$ref"  ]
			then
				control=$(($control+1))
				kREF=$k
			fi
		done		
		
		if [ $control -eq 0 ]
		then
			Group_name[${Ngroups}]=${gr[$j]}
			Nmut[${Ngroups}]=1
			Ngroups=$((${Ngroups}+1))
		else
			Nmut[$kREF]=$((${Nmut[$kREF]}+1))	
		fi
        done


# Some controls..

	# control 1. Does "FOLDER[$i]" correspond to a existing folder?
  	if ! [ -r ${FOLDER[$i]} ]
	then
		echo -e "\n\""${FOLDER[$i]}"\"\tis not a directory!! In the section CAS of your INPUT.dat file you asked to perform a mutation on ${FOLDER[$i]}, please check your \"INPUT.dat\" file.\nExiting......\n" | tee -a REPORTFILE0
		cd ..
	#	rm -rf $RUN
		exit
	fi

	# control 2. Does the directory "FOLDER[$i]_Mutation_Group_name" already exist? If yes..please displace or remove this directory.
	for (( k=0; k<$Ngroups; k++ ))
 	do
		if [ -r ${FOLDER[$i]}_Mutation_${Group_name[$k]} ]
		then
			echo  -e "\n"$(date +%H:%M:%S)"\nThe directories ${FOLDER[$i]}_Mutation_${Group_name[$k]} already exist!\nPlease remove or displace these directories.\nExiting.." | tee -a REPORTFILE0;
			echo "Exiting -- please read the REPORTFILE0"
 			exit
		fi
		mkdir ${FOLDER[$i]}_Mutation_${Group_name[$k]}
	done





 #read 'RESname', 'RESid' and 'prot_lig' from the file INPUT.dat
 	for (( k=0; k<$Ngroups; k++ ))
 	do
		for (( l=0; l<${Nmut[$k]}; l++ ))
 		do
			a=0;
			for ((z=0;z<k;z++)); do a=$(($a+${Nmut[$(($z))]})); done
			a=$(($a+$l))
			RESnumber[$a]=`egrep "^MUTATION[[:blank:]]*${FOLDER[$i]}[[:blank:]]" ../INPUT.dat| awk '{if ($6==group) print $0}' group=${Group_name[$k]}| head -n $(($l+1))|tail -n 1 | awk '{if($1=="MUTATION") print $3}'`
			REStype[$a]=`egrep "^MUTATION[[:blank:]]*${FOLDER[$i]}[[:blank:]]" ../INPUT.dat | awk '{if ($6==group) print $0}' group=${Group_name[$k]}| head -n $(($l+1))|tail -n 1 | awk '{if($1=="MUTATION") print $4}'`
			prot_lig[$a]=`egrep "^MUTATION[[:blank:]]*${FOLDER[$i]}[[:blank:]]" ../INPUT.dat | awk '{if ($6==group) print $0}' group=${Group_name[$k]}| head -n $(($l+1))|tail -n 1 | awk '{if($1=="MUTATION") print $5}'`
		
			
			# control 5. If I use "Ltopology_Pff" option I can not perform alanine mutation on the ligand...check!
			if [ $Ltopology_Pff == "y" ]; then
				if [ ! ${prot_lig[$a]} == "receptor" ]; then 
					echo "You are trying to perform an alanine mutation on the ligand in ${FOLDER[$i]}. With the option \"Ltopology_Pff\" you can perform mutation only on the receptor! Exiting.." | tee -a REPORTFILE0 WARNINGS_gmxpbsa0.dat; 
					exit; 
				fi
			fi

			
			
			# control 3. is REStype = "ALA", "GLY" or "PRO"? --> WARNING
			if [ "${REStype[$a]}" == "ALA" ]; then 
			echo "You are trying to perform an alanine mutation on alanine in ${FOLDER[$i]}. Exiting.." | tee -a REPORTFILE0 WARNINGS_gmxpbsa0.dat; exit; fi
			if [ "${REStype[$a]}" == "PRO" ]; then 
			echo "You are trying to perform an alanine mutation on proline in ${FOLDER[$i]}. Exiting.." | tee -a REPORTFILE0 WARNINGS_gmxpbsa0.dat; exit; fi
			if [ "${REStype[$a]}" == "GLY" ]; then 
			echo "You are trying to perform an alanine mutation on glycine in ${FOLDER[$i]}. Exiting.." | tee -a REPORTFILE0 WARNINGS_gmxpbsa0.dat; exit; fi

			# control 4. Does 'RESname', 'RESid' and 'prot_lig' match each other?	
			if [ $protein_alone == "n" ]; then

				if [ ${prot_lig[$a]} == "receptor" ]; then
					match=`awk 'BEGIN{tot=0};
					{
						if( ($6==RESnumber && $4==REStype) || ($5~RESnumber && $4==REStype) ) tot=tot+1;
					};
					END{print tot}' RESnumber=${RESnumber[$a]} REStype=${REStype[$a]} ${FOLDER[$i]}/_$receptor\0.pdb`;
				else
					match=`awk 'BEGIN{tot=0};
					{
						if( ($6==RESnumber && $4==REStype) || ($5~RESnumber && $4==REStype) ) tot=tot+1;
					};
					END{print tot}' RESnumber=${RESnumber[$a]} REStype=${REStype[$a]} ${FOLDER[$i]}/_$ligand\0.pdb`;	
				fi

			else
					match=`awk 'BEGIN{tot=0};
					{
						if( ($6==RESnumber && $4==REStype) || ($5~RESnumber && $4==REStype) ) tot=tot+1;
					};
					END{print tot}' RESnumber=${RESnumber[$a]} REStype=${REStype[$a]} ${FOLDER[$i]}/_comp0.pdb`;
			fi
			
			if [ $match -eq 0 ] 
			then
	       			echo -e "WARNING!!! The RESnumber " ${RESnumber[$a]} " and the REStype " ${REStype[$a]} " do not match in the " ${prot_lig[$a]} " of the directory " ${FOLDER[$i]} "\nExiting.." | tee -a REPORTFILE0 WARNINGS_gmxpbsa0.dat;
				exit; 	
			fi

		
		done
	done


       
# Finally delete the sidechain of the required residues

	cd ${FOLDER[$i]};

	if [ $protein_alone == "n" ]; then

	#	declare -A first
		#find the order: in complex file is receptor after/before ligand?

		complex_line=`grep -n '^\[ '${complex}' \]' index.ndx | cut -d: -f1`
		complex_line=$((${complex_line} + 1));
		first_c=`head -n ${complex_line} index.ndx | tail -n 1 | awk '{print $1}'`

		ligand_line=`grep -n '^\[ '${ligand}' \]' index.ndx | cut -d: -f1`
		ligand_line=$((${ligand_line} + 1));
		first_l=`head -n ${ligand_line} index.ndx | tail -n 1 | awk '{print $1}'`		

	
	#	for indexk in $complex $receptor $ligand; do
	#		index_line=`grep -n '^\[ '${indexk}' \]' index.ndx | cut -d: -f1`
	#		index_line=$(($index_line + 1));
	#		first[$indexk]=`head -n ${index_line} index.ndx | tail -n 1 | awk '{print $1}'`
	#	done
	
		if [ ${first_c} -eq ${first_l} ]; then
			rec_position=after
			limit=`wc -l _$ligand\0.pdb | awk '{print $1}'`
		else
			rec_position=before
			limit=`wc -l _$receptor\0.pdb | awk '{print $1}'`
		fi
	else
		rec_position=n
		limit=`wc -l _comp\0.pdb | awk '{print $1}'`
	fi

	
	for ((k=0;k<$Ngroups ;k++))
	do

		for (( l=0; l<${Nmut[$k]}; l++ ))
 		do
			a=0;
			for ((z=0;z<k;z++)); do a=$(($a+${Nmut[$(($z))]})); done;
			a=$(($a+$l));

			if [ $l -eq 0 ]; then
				Nfile=`ls _comp*.pdb | wc -l`
				for (( b=0; b<$Nfile ; b++ )); do
				#	cp _comp${b}.pdb _comp${b}.pdb@iteration$l
				#	cp _${receptor}${b}.pdb _${receptor}${b}.pdb@iteration$l
				#	cp _${ligand}${b}.pdb _${ligand}${b}.pdb@iteration$l
					cp _comp${b}.pdb _comp${b}@iteration$l.pdb
					cp _${receptor}${b}.pdb _${receptor}${b}@iteration$l.pdb
					cp _${ligand}${b}.pdb _${ligand}${b}@iteration$l.pdb

				done
			fi

			if [ $l -gt 0 ]; then
				rm -f *@iteration$(($l-1)).pdb
			fi
			

			for (( b=0; b<$Nfile ; b++ )); do
				
				#complex

				fileC=`echo _comp${b}@iteration$l.pdb`
				out=`echo _comp${b}@iteration$(($l+1)).pdb`
				OUTPUT=./$out
				perl ../deleteSC.pl $fileC ${REStype[$a]} ${RESnumber[$a]} ${prot_lig[$a]} ALA $OUTPUT $limit $rec_position

				
				if [ $protein_alone == "n" ]; then

					#receptor
					fileR=`echo _${receptor}${b}@iteration${l}.pdb`
					out=`echo _${receptor}${b}@iteration$(($l+1)).pdb`
					OUTPUT=./$out
				
					if [ ${prot_lig[$a]} == "receptor" ] 
					then
						perl ../deleteSC.pl $fileR ${REStype[$a]} ${RESnumber[$a]} ${prot_lig[$a]} ALA $OUTPUT $limit n
					else				
						grep "ATOM" $fileR > $OUTPUT
					fi
					fileCnew=`echo _comp${b}@iteration$(($l+1)).pdb`
					fileRnew=`echo _${receptor}${b}@iteration$(($l+1)).pdb`

					###################################################################
					if [ $Ltopology_Pff == "y" ]; then
						#generate file gro with the HB of mutated Alanine
						echo "$ffield" | $Gpath\/$pdb2gmx -f $fileRnew -p tmp.top -i tmp.itp -o tmp.gro -water tip3p -ignh >>STD_ERR0 2>&1
						#find HB lines and x-y-z coordinate for each HB
						mutation=`echo ${RESnumber[$a]}ALA`
						HB[1]=`more tmp.gro  | awk '{if($1==NNa){if($2~/HB1/){print $4, $5, $6}} }' NNa=$mutation`
						HB[2]=`more tmp.gro  | awk '{if($1==NNa){if($2~/HB2/){print $4, $5, $6}} }' NNa=$mutation`
						HB[3]=`more tmp.gro  | awk '{if($1==NNa){if($2~/HB3/){print $4, $5, $6}} }' NNa=$mutation`
						xhb1=`echo ${HB[1]} | awk '{printf "%-2.3f", $1*10}'`
						yhb1=`echo ${HB[1]} | awk '{printf "%-2.3f", $2*10}'`
						zhb1=`echo ${HB[1]} | awk '{printf "%-2.3f", $3*10}'`
						xhb2=`echo ${HB[2]} | awk '{printf "%-2.3f", $1*10}'`
						yhb2=`echo ${HB[2]} | awk '{printf "%-2.3f", $2*10}'`
						zhb2=`echo ${HB[2]} | awk '{printf "%-2.3f", $3*10}'`
						xhb3=`echo ${HB[3]} | awk '{printf "%-2.3f", $1*10}'`
						yhb3=`echo ${HB[3]} | awk '{printf "%-2.3f", $2*10}'`
						zhb3=`echo ${HB[3]} | awk '{printf "%-2.3f", $3*10}'`
						rm -f tmp*

						#find ALA CB postion in receptor/complex pdb (depends on pdb format)
						for fileF in $fileRnew $fileCnew; do
							R1="";R2="";
							R1=`more $fileF | awk '{if($4=="ALA" && $6==RN && $3=="CB"){print NR}}' RN="${RESnumber[$a]}"`
							R2=`more $fileF | awk '{if($4=="ALA" && $5~RN && $3=="CB"){print NR}}' RN=${RESnumber[$a]}`
							Rtot=`more $fileF | wc -l`
							if [ $R1 ]; then
								xold=`more $fileF | awk '{if(NR==R1) print $7}' R1=$R1`
								yold=`more $fileF | awk '{if(NR==R1) print $8}' R1=$R1`
								zold=`more $fileF | awk '{if(NR==R1) print $9}' R1=$R1`
								lll=$R1													
							else
								if [ $R2 ]; then
									xold=`more $fileF | awk '{if(NR==R1) print $6}' R1=$R2`
									yold=`more $fileF | awk '{if(NR==R1) print $7}' R1=$R2`
									zold=`more $fileF | awk '{if(NR==R1) print $8}' R1=$R2`
									lll=$R2
								fi
							fi
							Natm=`more $fileF | awk '{if(NR==R1) print $2}' R1=$lll`
							more $fileF | sed -n '1',$lll'p' > ${fileF}2
							more $fileF | sed -n $lll'p' >> ${fileF}2
							more $fileF | sed -n $lll'p' >> ${fileF}2
							more $fileF | sed -n $lll'p' >> ${fileF}2
							more $fileF | sed -n $(($lll+1)),$Rtot'p' >> ${fileF}2
							
							sed -i -e $(($lll+1))'s/CB /HB1/'  -e $(($lll+1))'s/'$Natm'/'$(($Natm+1))'/' -e $(($lll+1))'s/'$xold'/'$xhb1'/' -e $(($lll+1))'s/'$yold'/'$yhb1'/' -e $(($lll+1))'s/'$zold'/'$zhb1'/' ${fileF}2
							sed -i -e $(($lll+2))'s/CB /HB2/'  -e $(($lll+2))'s/'$Natm'/'$(($Natm+2))'/' -e $(($lll+2))'s/'$xold'/'$xhb2'/' -e $(($lll+2))'s/'$yold'/'$yhb2'/' -e $(($lll+2))'s/'$zold'/'$zhb2'/' ${fileF}2
							sed -i -e $(($lll+3))'s/CB /HB3/'  -e $(($lll+3))'s/'$Natm'/'$(($Natm+3))'/' -e $(($lll+3))'s/'$xold'/'$xhb3'/' -e $(($lll+3))'s/'$yold'/'$yhb3'/' -e $(($lll+3))'s/'$zold'/'$zhb3'/' ${fileF}2
						
							#replace correct file
							rm -f $fileF
							mv ${fileF}2 $fileF
						done

					fi
					###################################################################

					#ligand
					fileL=`echo _${ligand}${b}@iteration$l.pdb`
					out=`echo _${ligand}${b}@iteration$(($l+1)).pdb`
					OUTPUT=./$out
				
					if [ ${prot_lig[$a]} == "lig" ] 
					then
						perl ../deleteSC.pl $fileL ${REStype[$a]} ${RESnumber[$a]} ${prot_lig[$a]} ALA $OUTPUT $limit n
					else				
						grep "ATOM" $fileL > $OUTPUT
					fi
				fi
				if [ $l -eq $((${Nmut[$k]}-1)) ]; then
					cp _comp${b}@iteration$(($l+1)).pdb ../${FOLDER[$i]}_Mutation_${Group_name[$k]}/_comp${b}.pdb
					cp _${receptor}${b}@iteration$(($l+1)).pdb ../${FOLDER[$i]}_Mutation_${Group_name[$k]}/_${receptor}${b}.pdb
					cp _${ligand}${b}@iteration$(($l+1)).pdb ../${FOLDER[$i]}_Mutation_${Group_name[$k]}/_${ligand}${b}.pdb
				fi
			done
		done
		rm -f *@iteration*
		if [ $use_nonstd_ff == "y" ]; then
			cp -r *.ff ../${FOLDER[$i]}_Mutation_${Group_name[$k]}/
			cp residuetypes.dat ../${FOLDER[$i]}_Mutation_${Group_name[$k]}/
		fi
		if [ "$min" = "y" ]; then cp box_dimension.dat ../${FOLDER[$i]}_Mutation_${Group_name[$k]}/box_dimension.dat; fi
		if [ $Ltopology_Pff == "y" ]; then
			cp *.itp ../${FOLDER[$i]}_Mutation_${Group_name[$k]}/
			cp index.ndx ../${FOLDER[$i]}_Mutation_${Group_name[$k]}/			
		fi

	done

	cd ..

	#PRINT SUMMARY
	echo -e "From the WT-folder ${FOLDER[$i]} the following MUTANTS-folders have been created:" | tee -a REPORTFILE0 
	for ((k=0;k<$Ngroups ;k++)); do
		echo -e "\t${FOLDER[$i]}_Mutation_${Group_name[$k]} where the residues mutated are:\t" | tee -a REPORTFILE0 
		for (( l=0; l<${Nmut[$k]}; l++ ))
		do
			a=0;
			for ((z=0;z<k;z++)); do a=$(($a+${Nmut[$(($z))]})); done;
			a=$(($a+$l));
			echo -e "\t\t" ${REStype[$a]}${RESnumber[$a]}ALA "\t" ${prot_lig[$a]} | tee -a REPORTFILE0 
		done
	done
	echo -e "" | tee -a REPORTFILE0 

 done

rm -f deleteSC.pl

fi
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (5) complex, receptor and ligand PDB EM #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# The file Mm.mdp is generated 
#	if the user prefers to perform a thorough minimization, the box sizes of the structures are checked and stored in the b[XYZ] variables

if [ $multitrj == "y" ]; then
	FolderFile2=$(for ((i=0;i<$N_start_dir; i++)); do ls -1| grep "^${start_dir[$i]}"; done | sed s/" "/"\n"/g | sort -u)
else
	FolderFile2=$(ls -1 | grep "^$root")
fi


for FoLdeR in $FolderFile2; do

#entering in each folder... 
cd $FoLdeR
rm -f \#* *~


let "fin=$(ls _comp*.pdb | wc | awk '{print $1}')"
let "fin=$fin-1"

# if [ $multichain == "y" ] && [ $use_nonstd_ff == "y" ]; then
 if [ $multichain == "y" ]; then

	 echo -e "\n"$(date +%H:%M:%S)" Modifying the PDB files in order to use multiple chains in "$FoLdeR"...\n" | tee -a ../REPORTFILE0
	 for file in _*.pdb; do
		mv $file a$file
		nOC2=`grep "OC2" a${file} | wc -l`;
		for (( i = 1; i < $nOC2; i++ )); do
			ln=`grep -n "OC2" a$file | head -n $i | tail -n 1 | cut -d : -f1`
			more a$file | awk '{if (NR == ln) {printf "TER\n"$0"\n"} else {print $0}  }' ln=$(($ln+1)) > $file
			mv $file a$file
		done
		mv a$file $file	
	done
 fi





if [ -f Mm.mdp ]; then rm Mm.mdp; fi 
if [ $NO_topol_ff == "n" ]; then touch Mm.mdp; fi

if [ $protein_alone == "y" ]; then
	receptor="";
	ligand="";
fi

if [ $Ltopology_Pff == "y" ]; then
	name=`echo ${receptor}0`
	#Att: to avoid confusion HISTIDINE must be called "HIE", "HID" or "HIP". If "HIS" is found in "_${name}.pdb" they are replaced by the correct name.
	# PROBLEMA: per amber funziona. con charmm si chiamano HSE, HSD, HSP... non si può fare
	IsHis=`echo $Histidine | cut -d " " -f1`
	if [ -z $IsHis ]; then
		echo "$ffield" | $Gpath\/$pdb2gmx -f _${name}.pdb -p topol_${receptor}.top -i posre_${receptor}.itp -o _${name}.gro -water tip3p -ignh >>STD_ERR0 2>&1
	else
		echo -e "$ffield\n$Histidine" | $Gpath\/$pdb2gmx -f _${name}.pdb -p topol_${receptor}.top -i posre_${receptor}.itp -o _${name}.gro -water tip3p -ignh -his >>STD_ERR0 2>&1
	fi
	rm -f _${name}.gro
	lineB=`grep -n '\[ moleculetype \]' topol_${receptor}.top | cut -d : -f1`
	lineE=`grep -n '^#ifdef POSRES$' topol_${receptor}.top | head -2 | tail -1 | cut -d : -f1`; lineE=$(($lineE+3));
	lineTOT=`wc -l topol_${receptor}.top | awk '{print $1}'`
	more topol_${receptor}.top | sed -n $lineB,$lineE'p' > ${receptor}.itp
	mv topol_${receptor}.top tmp.top
	more tmp.top | sed -n '1,'$(($lineB-1))'p' > topol.top
	sed -i '/^$/d' topol.top
	echo -e "#include \"${itp_ligand}\"" >> topol.top
	echo -e "#include \"${receptor}.itp\"\n" >> topol.top
	more tmp.top | sed -n $(($lineE+1)),$lineTOT'p' >> topol.top
	# add ligand-line under section [ molecule ]
	nr_lig=$( echo $(( $(grep -n "moleculetype" ${itp_ligand} | cut -d: -f1 ) + 2 )));
	keywordLig=$( echo $(sed -n $nr_lig'p' ${itp_ligand} | awk '{print $1}') );
	echo -e "$keywordLig\t1" >> topol.top
	#use function topology (as in the case use_topology=y)
	topology "${receptor}.itp" "$itp_ligand" "$receptor" "$ligand" "comp" "${water_mol}"
	check topol_comp.top ../REPORTFILE0; check topol_$receptor.top ../REPORTFILE0; check topol_$ligand.top ../REPORTFILE0;
	# set use_topology=y 
	use_topology="y";
fi


if [ "$min" = "y" ]; then
  
  bX=`awk '{if(NR==1) print $1}' box_dimension.dat`
  bY=`awk '{if(NR==1) print $2}' box_dimension.dat`
  bZ=`awk '{if(NR==1) print $3}' box_dimension.dat`
  PRINT_MINfile_y;
  
  echo -e " \n\n"$(date +%H:%M:%S)" Started performing the energy minimization of the PDB files in "$FoLdeR"..." | tee -a ../REPORTFILE0 

  # The EM step is performed for each complex, receptor and ligand structure 
	for  (( counter=0; counter<=$fin; counter++ )); do 
		for molec in comp $receptor $ligand; do
			EnergyMin_y "$molec" "$counter" "$Gpath" "$ffield" "$bX" "$bY" "$bZ" "$use_topology" "$editconf" "$pdb2gmx" "$grompp" "$mdrun" 
		done
	done 
else

  echo -e " \n\n"$(date +%H:%M:%S)" Started the recovery of the Coulomb/VdW energy contributions from the PDB files in "$FoLdeR"..." | tee -a ../REPORTFILE0 

  if [ $NO_topol_ff == "y" ]; then 
 	echo "$complex" | $Gpath\/$tpbconv -s ${name_tpr}.tpr -n index.ndx -o comp.tpr >>STD_ERR0 2>&1 
	if [ $protein_alone == "n" ]; then
		echo "$ligand" | $Gpath\/$tpbconv -s ${name_tpr}.tpr -n index.ndx -o ${ligand}.tpr >>STD_ERR0 2>&1 
		echo "$receptor" | $Gpath\/$tpbconv -s ${name_tpr}.tpr -n index.ndx -o ${receptor}.tpr >>STD_ERR0 2>&1
	fi
	for  (( counter=0; counter<=$fin; counter++ )); do 
		for molec in comp $receptor $ligand; do
			EnergyMin_n_NOcas "$molec" "$counter" "$Gpath" "$mdrun" 
		done
	done 
	#rm -f comp.tpr ${ligand}.tpr ${receptor}.tpr

  else  
	
	PRINT_MINfile_n;

	# The step is performed for each complex, receptor and ligand structure 
	  use_tpbcon=n
          
	  #if [ $cas == "n" ] && [ $min == "n" ]; then 
	#	use_tpbcon=y;
	 # 	echo "$complex" | $Gpath\/$tpbconv -s ${name_tpr}.tpr -n index.ndx -o comp.tpr >>STD_ERR0 2>&1 
	#	echo "$ligand" | $Gpath\/$tpbconv -s ${name_tpr}.tpr -n index.ndx -o ${ligand}.tpr >>STD_ERR0 2>&1 
	#	echo "$receptor" | $Gpath\/$tpbconv -s ${name_tpr}.tpr -n index.ndx -o ${receptor}.tpr >>STD_ERR0 2>&1
	 # fi 
	  for  (( counter=0; counter<=$fin; counter++ )); do 
		for molec in comp $receptor $ligand; do
			EnergyMin_n "$molec" "$counter" "$Gpath" "$ffield" "$use_topology" "$use_tpbcon" "$editconf" "$pdb2gmx" "$grompp" "$mdrun"  
		done
	  done
	  #if [ $use_tpbcon == "y" ]; then rm -f comp.tpr ${ligand}.tpr ${receptor}.tpr;fi 
  fi
fi 

# The topology files generated during EM are deleted 
if [ $NO_topol_ff == "n" ]; then
	rm -f topol_comp*.top topol_$ligand*.top topol_$receptor* posre*
fi



#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (6) generation of the PQR files #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
echo -e $(date +%H:%M:%S)" Started generating the PQR files from the corresponding "$FoLdeR" PDB files..." | tee -a  ../REPORTFILE0

if [ $NO_topol_ff == "y" ]; then 

	for molec in comp $receptor $ligand; do
		
		# generate pqr template
		#if [ $molec == "comp" ]; then group=complex; else group=$molec; fi
		#echo "$group" | $Gpath\/$editconf -f ${name_tpr}.tpr -n index.ndx -mead ${molec}.pqr >>STD_ERR0 2>&1 && check2 ${molec}.pqr ../REPORTFILE0
		check2 ${molec}.tpr ../REPORTFILE0 && $Gpath\/$editconf -f ${molec}.tpr -mead ${molec}.pqr >>STD_ERR0 2>&1 && check2 ${molec}.pqr ../REPORTFILE0

		#generate common files	
		awk '{if ($1 == "REMARK" || $1== "TITLE" || $1 ~ "MODEL" || $1 ~ "CRYST1" ) print $0}' ${molec}.pqr > front.txt
		echo -e "TER\nENDMDL" > end.txt
	
		nCOLUMN_pqr=`grep "ATOM" ${molec}.pqr | head -n 1| awk '{ print NF }' `
		awk '{if ($1 == "ATOM" || $1 == "HETATM") {printf ("%5.5f\t%5.5f\n", $A, $B)}}' A=$(($nCOLUMN_pqr-1)) B=$nCOLUMN_pqr ${molec}.pqr > second_lines.txt	
	

		#generating pqrs
		for  (( counter=0; counter<=$fin; counter++ )); do
			name=${molec}${counter}
		
			#delete chain id from pdb and check if it has 10 columns
			awk '{ if ($1 == "ATOM" || $1 == "HETATM") { printf( "%s%s%s\n", substr($0,1,21), " ", substr($0,23,45) ) } }' _${name}.pdb > A_${name}.pdb
			nCOLUMN_pdb=`grep "ATOM" A_${name}.pdb | head -n 1| awk '{ print NF }' `
			if [ $nCOLUMN_pdb -ne 10 ]; then echo -e "ERROR: Difficulties were found in converting pdb to pqr, since the pdb files are not in a standard format!\nCheck it or change the option \"NO_topol_ff\" to \"n\".\n"; exit; fi
			
		
			#create the pqr files
			awk '{if ($1 == "ATOM") print $1"\t" $2"\t" $3"\t" $4"\t" $5"\t" $6"\t" $7"\t" $8"\t"}' A_${name}.pdb > first_lines.txt

			paste first_lines.txt second_lines.txt > int.txt
			cat front.txt int.txt end.txt > ${name}.pqr
			
			#check
			checkpqr=`grep "ATOM" ${name}.pqr | head -n 1| awk '{ print NF }' `
			if ! [ $checkpqr -eq 10 ]; then echo -e "ERROR: We found some problems while generating the pqr files. Exiting...."; exit; fi
			
			#delete useless files
			rm -f int.txt first_lines.txt
		        tar cfz PDBfiles1_${name}.tar.gz _${name}.pdb && rm -f _${name}.pdb && rm -f A_${name}.pdb	
		done
		
		rm -f front.txt second_lines.txt end.txt ${molec}.pqr
	done
	rm -f comp.tpr ${ligand}.tpr ${receptor}.tpr
else

	if [ $read_vdw_radii == "y" ]; then
		editconf1="$editconf -vdwread";
	else
		editconf1="$editconf";
	fi

	for (( counter=0; counter<=$fin; counter++ )); do
		for molec in comp $receptor $ligand; do
			name=${molec}${counter}
			check2 ${name}.tpr ../REPORTFILE0 && $Gpath\/$editconf1 -f ${name}.tpr -mead ${name}.pqr >>STD_ERR0 2>&1 && check2 ${name}.pqr ../REPORTFILE0
			#PDB2PQR "comp" "$receptor" "$ligand" "$counter" "$Gpath" "$editconf1"
		done
	done

fi

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (7) PDB and GRO files definitive storage #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
mkdir PDBstructures
if [ -f PDBfiles_comp0.tar.gz ]; then mv PDBfiles_* PDBstructures; fi
if [ -f GROfiles_comp0.tar.gz ]; then mv GROfiles_* PDBstructures; fi
if [ -f PDBfiles1_comp0.tar.gz ]; then mv PDBfiles1_* PDBstructures; fi

tar cfz PDBs.tar.gz PDBstructures && rm -rf PDBstructures
rm -f *comp*.tpr
if [ $protein_alone == "n" ]; then
	rm -f *$receptor*.tpr *$ligand*.tpr 
fi
rm -f STD_ERR0

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (8) generation of a REP files #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
for (( counter=0; counter<=$fin; counter++ )); do
	if [ $protein_alone == "n" ]; then
		generate_STRUfiles "$counter" "comp" "$receptor" "$ligand"
	else
		generate_STRUfiles_protein "$counter" "comp"
	fi
done


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (9) Lennard-Jones contributions #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
echo -e $(date +%H:%M:%S)" Started calculating the LJ parameters for $FoLdeR..." | tee -a ../REPORTFILE0

# The potential energy values of the minimized structures are stored into PotEn.PotEn.
if [ -f PotEn.PotEn ]  ; then rm PotEn.PotEn; fi 
touch PotEn.PotEn

for (( counter=0; counter<=$fin; counter++ )); do

# let's get rid of the unwanted spaces first...
 check2 comp$counter.log ../REPORTFILE0 && sed -e 's/ (/\_(/g' -e 's/ D/\_D/g' -e 's/\. r/.r/g' -e 's/\. c/.c/g' -e 's/ E/_E/g' comp$counter.log > Pcomp$counter.log
 
# Complex values are taken,...   
  ReadEnergy "Pcomp$counter.log" "Coulomb-14" "C14CC";
  ReadEnergy "Pcomp$counter.log" "LJ-14" "L14CC";
  ReadEnergy "Pcomp$counter.log" "Coulomb_" "CSRCC";
  ReadEnergy "Pcomp$counter.log" "LJ_" "LSRCC";
  ReadEnergy_special "Pcomp$counter.log" "Coul.recip." "CReCC";


if [ $protein_alone == "y" ]; then
  
  echo -n > Co; echo -e "$L14CC \t $LSRCC" >> Co; Com=$(awk '{print $1+$2}' Co)
  if ! [ $CReCC == "X" ]; then
 	echo -n > co; echo -e "$C14CC \t $CSRCC \t $CReCC" >> co; com=$(awk '{print $1+$2+$3}' co)
  else
	echo -n > co; echo -e "$C14CC \t $CSRCC" >> co; com=$(awk '{print $1+$2}' co)
  fi
       
  printf "%-30s %-3s %-f \n"  "Lenn-Jon overall" "=" $Com >>stru$counter.rep
  printf "%-30s %-3s %-f \n"  "Lenn-Jon 1-4 net" "=" $L14CC >>stru$counter.rep
  printf "%-30s %-3s %-f \n"  "Lenn-Jon ShortRange net" "=" $LSRCC >>stru$counter.rep
  printf "%-30s %-3s %-f \n"  "GMX-coul overall" "=" $com >>stru$counter.rep
  printf "%-30s %-3s %-f \n"  "GMX-coul 1-4 net" "=" $C14CC >>stru$counter.rep
  printf "%-30s %-3s %-f \n"  "GMX-coul ShortRange net" "=" $CSRCC >>stru$counter.rep
  if ! [ $CReCC == "X" ]; then
	printf "%-30s %-3s %-f \n"  "GMX-coul Recip net" "=" $CReCC >>stru$counter.rep
  fi

  rm -f Co co \#*

else

 check2 $receptor$counter.log ../REPORTFILE0 && sed -e 's/ (/\_(/g' -e 's/ D/\_D/g' -e 's/\. r/.r/g' -e 's/\. c/.c/g' -e 's/ E/_E/g' $receptor$counter.log > P$receptor$counter.log
 check2 $ligand$counter.log ../REPORTFILE0 && sed -e 's/ (/\_(/g' -e 's/ D/\_D/g' -e 's/\. r/.r/g' -e 's/\. c/.c/g' -e 's/ E/_E/g' $ligand$counter.log > P$ligand$counter.log

#... and so are receptor values...
  ReadEnergy "P$receptor$counter.log" "Coulomb-14" "C14PP";
  ReadEnergy "P$receptor$counter.log" "LJ-14" "L14PP";
  ReadEnergy "P$receptor$counter.log" "Coulomb_" "CSRPP";
  ReadEnergy "P$receptor$counter.log" "LJ_" "LSRPP";
  ReadEnergy_special "P$receptor$counter.log" "Coul.recip." "CRePP";
  
#... and so are ligand.
  ReadEnergy "P$ligand$counter.log" "Coulomb-14" "C14TT";
  ReadEnergy "P$ligand$counter.log" "LJ-14" "L14TT";
  ReadEnergy "P$ligand$counter.log" "Coulomb_" "CSRTT";
  ReadEnergy "P$ligand$counter.log" "LJ_" "LSRTT";
  ReadEnergy_special "P$ligand$counter.log" "Coul.recip." "CReTT";

# The overall Lennard-Jones values are calculated... 
 echo -n > OF; echo -e "$L14CC \t $L14PP \t $L14TT" >> OF ; L14=$(awk '{print $1-$2-$3}' OF)
 echo -n > SR; echo -e "$LSRCC \t $LSRPP \t $LSRTT" >> SR ; LSR=$(awk '{print $1-$2-$3}' SR)
 echo -n > OA; echo -e "$LSR \t $L14" >> OA; Loa=$(awk '{print $1+$2}' OA)
 echo -n > Co; echo -e "$L14CC \t $LSRCC" >> Co; Com=$(awk '{print $1+$2}' Co)
 echo -n > Pr; echo -e "$L14PP \t $LSRPP" >> Pr; Pro=$(awk '{print $1+$2}' Pr)
 echo -n > Li; echo -e "$L14TT \t $LSRTT" >> Li; Lig=$(awk '{print $1+$2}' Li)

# ... and stored in the REP file.
printf "%-30s %-3s %-f \n"  "Lenn-Jon overall" "=" $Loa >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "Lenn-Jon complex overall" "=" $Com >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "Lenn-Jon $receptor overall" "=" $Pro >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "Lenn-Jon $ligand overall" "=" $Lig >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "Lenn-Jon 1-4 net" "=" $L14 >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "Lenn-Jon 1-4 $complex" "=" $L14CC >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "Lenn-Jon 1-4 $receptor" "=" $L14PP >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "Lenn-Jon 1-4 $ligand" "=" $L14TT >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "Lenn-Jon ShortRange net" "=" $LSR >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "Lenn-Jon ShortRange $complex" "=" $LSRCC >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "Lenn-Jon ShortRange $receptor" "=" $LSRPP >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "Lenn-Jon ShortRange $ligand" "=" $LSRTT >>stru$counter.rep
# Finally, useless files are deleted.
  rm -f OF SR OA Co Pr Li \#*

# The overall GMX coulombic values are also calculated...
if [ $CReCC == "X" ]; then
  echo -n > co; echo -e "$C14CC \t $CSRCC" >> co; com=$(awk '{print $1+$2}' co)
  echo -n > pr; echo -e "$C14PP \t $CSRPP" >> pr; pro=$(awk '{print $1+$2}' pr)
  echo -n > li; echo -e "$C14TT \t $CSRTT" >> li; lig=$(awk '{print $1+$2}' li)
  echo -n > of; echo -e "$C14CC \t $C14PP \t $C14TT" >> of; c14=$(awk '{print $1-$2-$3}' of)
  echo -n > sr; echo -e "$CSRCC \t $CSRPP \t $CSRTT" >> sr; csr=$(awk '{print $1-$2-$3}' sr)
  echo -n > oa; echo -e "$c14 \t $csr" >> oa; loa=$(awk '{print $1+$2}' oa)
else
  echo -n > co; echo -e "$C14CC \t $CSRCC \t $CReCC" >> co; com=$(awk '{print $1+$2+$3}' co)
  echo -n > pr; echo -e "$C14PP \t $CSRPP \t $CRePP" >> pr; pro=$(awk '{print $1+$2+$3}' pr)
  echo -n > li; echo -e "$C14TT \t $CSRTT \t $CReTT" >> li; lig=$(awk '{print $1+$2+$3}' li)
  echo -n > of; echo -e "$C14CC \t $C14PP \t $C14TT" >> of; c14=$(awk '{print $1-$2-$3}' of)
  echo -n > sr; echo -e "$CSRCC \t $CSRPP \t $CSRTT" >> sr; csr=$(awk '{print $1-$2-$3}' sr)
  echo -n > rec; echo -e "$CReCC \t $CRePP \t $CReTT" >> rec; crec=$(awk '{print $1-$2-$3}' rec)
  echo -n > oa; echo -e "$c14 \t $csr \t $crec" >> oa; loa=$(awk '{print $1+$2+$3}' oa)
fi
# ... and stored in the REP file.
printf "%-30s %-3s %-f \n"  "GMX-coul overall" "=" $loa >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "GMX-coul complex overall" "=" $com >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "GMX-coul $receptor overall" "=" $pro >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "GMX-coul $ligand overall" "=" $lig >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "GMX-coul 1-4 net" "=" $c14 >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "GMX-coul 1-4 $complex" "=" $C14CC >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "GMX-coul 1-4 $receptor" "=" $C14PP >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "GMX-coul 1-4 $ligand" "=" $C14TT >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "GMX-coul ShortRange net" "=" $csr >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "GMX-coul ShortRange $complex" "=" $CSRCC >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "GMX-coul ShortRange $receptor" "=" $CSRPP >>stru$counter.rep
printf "%-30s %-3s %-f \n"  "GMX-coul ShortRange $ligand" "=" $CSRTT >>stru$counter.rep
if ! [ $CReCC == "X" ]; then
	printf "%-30s %-3s %-f \n"  "GMX-coul Recip net" "=" $crec >>stru$counter.rep
	printf "%-30s %-3s %-f \n"  "GMX-coul Recip $complex" "=" $CReCC >>stru$counter.rep
	printf "%-30s %-3s %-f \n"  "GMX-coul Recip $receptor" "=" $CRePP >>stru$counter.rep
	printf "%-30s %-3s %-f \n"  "GMX-coul Recip $ligand" "=" $CReTT >>stru$counter.rep
fi
# Finally, useless files are deleted.
  rm -f of sr oa co pr li
  if [ -f rec ]; then rm -f rec; fi 

fi

 # Potential energy values of the structures under consideration are stored into the file PotEn.PotEn
  ReadEnergy_Pot "Pcomp$counter.log" "Potential" "potent_energC";
  tar cfz LOG_file_comp$counter.tar.gz comp$counter.log  && rm comp$counter.log; rm Pcomp$counter.log

if [ $protein_alone == "y" ]; then
  echo -e "\t $potent_energC \t # kJ/mol\t$counter " >> PotEn.PotEn
else
 
  ReadEnergy_Pot "P$receptor$counter.log" "Potential" "potent_energP";
  ReadEnergy_Pot "P$ligand$counter.log" "Potential" "potent_energT";
  tar cfz LOG_file_$receptor$counter.tar.gz $receptor$counter.log && rm $receptor$counter.log; rm P$receptor$counter.log
  tar cfz LOG_file_$ligand$counter.tar.gz $ligand$counter.log && rm $ligand$counter.log; rm P$ligand$counter.log
  
  echo -e "\t $potent_energC \t $potent_energP \t $potent_energT \t # kJ/mol\t$counter " >> PotEn.PotEn

fi

done
tar cfz LOGfiles.tar.gz LOG_file_* && rm -f LOG_file_*

# Once everything's been calculated, the PotEn.PotEn mean and StDev are calculated for each species
 cmpMN=$(awk '{sum+=$1; array[NR]=$1} END {for(x=1;x<=NR;x++){sumsq+=((array[x]-(sum/NR))^2);}print sum/NR}' PotEn.PotEn)
 cmpSD=$(awk '{sum+=$1; array[NR]=$1} END {for(x=1;x<=NR;x++){sumsq+=((array[x]-(sum/NR))^2);}print sqrt(sumsq)/NR}' PotEn.PotEn)

 if [ $protein_alone == "y" ]; then
 	echo -e "\n \t complex \t \t \t $cmpMN +/- $cmpSD kJ/mol\n" >> PotEn.PotEn
 else
 	prtMN=$(awk '{sum+=$2; array[NR]=$2} END {for(x=1;x<=NR;x++){sumsq+=((array[x]-(sum/NR))^2);}print sum/NR}' PotEn.PotEn)
 	prtSD=$(awk '{sum+=$2; array[NR]=$2} END {for(x=1;x<=NR;x++){sumsq+=((array[x]-(sum/NR))^2);}print sqrt(sumsq)/NR}' PotEn.PotEn)
 	lgnMN=$(awk '{sum+=$3; array[NR]=$3} END {for(x=1;x<=NR;x++){sumsq+=((array[x]-(sum/NR))^2);}print sum/NR}' PotEn.PotEn)
 	lgnSD=$(awk '{sum+=$3; array[NR]=$3} END {for(x=1;x<=NR;x++){sumsq+=((array[x]-(sum/NR))^2);}print sqrt(sumsq)/NR}' PotEn.PotEn)
 	echo -e "\n \t complex \t \t \t $cmpMN +/- $cmpSD kJ/mol\n \t receptor \t \t \t $prtMN +/- $prtSD kJ/mol\n\t ligand \t \t \t $lgnMN +/- $lgnSD kJ/mol" >> PotEn.PotEn
 fi


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (10) Coulombic contribution #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#

if [ $coulomb == "coul" ];
then
  echo -e $(date +%H:%M:%S)" Started calculating with the coulomb tool the Coulomb parameters for $FoLdeR..." | tee -a ../REPORTFILE0

  for (( counter=0; counter<=$fin; counter++ )); do

# The coulomb calculation is performed for the three molecular species... 
  check2 comp$counter.pqr ../REPORTFILE0 && CoulC=$( $Cpath\/coulomb comp$counter.pqr | grep "^Total energy" | awk '{print $4}')
  if [ -z $CoulC ]; then echo -e "\nThe script failed in calculating the Coulomb Energy contributions. Check the correct installation of the coulomb tool and your pqr files! If you want you can set the \"coulomb\" option to \"gmx\" in INPUT.dat, in order to calculate the coulomb energy contributions with Gromacs.\nExiting..."; exit ; fi

 if [ $protein_alone == "y" ]; then
	 printf "%-30s %-3s %-f \n"  "Coulomb overall" "=" $CoulC >>stru$counter.rep

 else
  check2 $receptor$counter.pqr ../REPORTFILE0 && CoulP=`$Cpath\/coulomb $receptor$counter.pqr | grep "^Total energy" | awk '{print $4}'`
  check2 $ligand$counter.pqr ../REPORTFILE0 && CoulL=`$Cpath\/coulomb $ligand$counter.pqr | grep "^Total energy" | awk '{print $4}'`
  if [ -z $CoulP ]; then echo -e "\nThe script failed in calculating the Coulomb Energy contributions. Check the correct installation of the coulomb tool and your pqr files! If you want you can set the \"coulomb\" option to \"gmx\" in INPUT.dat, in order to calculate the coulomb energy contributions with Gromacs.\nExiting..."; exit ; fi
  if [ -z $CoulL ]; then echo -e "\nThe script failed in calculating the Coulomb Energy contributions. Check the correct installation of the coulomb tool and your pqr files! If you want you can set the \"coulomb\" option to \"gmx\" in INPUT.dat, in order to calculate the coulomb energy contributions with Gromacs.\nExiting..."; exit ; fi

 # ... and the final value is calculated
  echo "  $CoulC  $CoulP  $CoulL" > coulomb$counter
  Coulo=$(awk '{print $1-$2-$3}' coulomb$counter); CoulC=$(awk '{print $1}' coulomb$counter)
  CoulP=$(awk '{print $2}' coulomb$counter); CoulL=$(awk '{print $3}' coulomb$counter)
  
# ... and the values are reported to the REP file
  printf "%-30s %-3s %-f \n"  "Coulomb overall" "=" $Coulo >>stru$counter.rep
  printf "%-30s %-3s %-f \n"  "Coulomb $complex" "=" $CoulC >>stru$counter.rep
  printf "%-30s %-3s %-f \n"  "Coulomb $receptor" "=" $CoulP >>stru$counter.rep
  printf "%-30s %-3s %-f \n"  "Coulomb $ligand" "=" $CoulL >>stru$counter.rep
 
# COU files are stored and deleted
  tar cfz COU_file_coulomb$counter.tar.gz coulomb$counter && rm coulomb$counter
  tar cfz COUfiles.tar.gz COU_file_* && rm -f COU_file_*

  fi

 done

 rm -f io.mc

fi

cd ..
done


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (11) PQR files data retrieval #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
echo -e " \n\n"$(date +%H:%M:%S)" Starting parsing the PQR files' coordinates..." | tee -a REPORTFILE0


for Folder in $FolderFile2; do
 cd $Folder
 tot=$(ls comp*.pqr | wc | awk '{print $1}'); let "tot=$tot-1";
	
 # The m[ai][XYZ] files are created
 touch maX miX maY miY maZ miZ

 #the positions of the [XYZ]cooridnate in the .pqr file are determined
  nCOLUMN=`grep "ATOM" comp0.pqr | head -n 1| awk '{ print NF }' `
  if [ $nCOLUMN -gt 10 ] ; then Xcol=7; Ycol=8; Zcol=9;
  else  Xcol=6; Ycol=7; Zcol=8; fi

 for (( j=0; j<=$tot; j++ )); do
  if [ -e comp$j.pqr ]; then 
   # The values of the coordinates are sorted from the PQR files: highest and lowest values are taken  [ma mi][XYZ] variables...
   grep -e "ATOM" -e "HETATM" comp$j.pqr | awk '{print $col}' col=$Xcol | sort -g | head -n 1 >>miX
   grep -e "ATOM" -e "HETATM" comp$j.pqr | awk '{print $col}' col=$Xcol | sort -g | tail -n 1 >>maX
   grep -e "ATOM" -e "HETATM" comp$j.pqr | awk '{print $col}' col=$Ycol | sort -g | head -n 1 >>miY
   grep -e "ATOM" -e "HETATM" comp$j.pqr | awk '{print $col}' col=$Ycol | sort -g | tail -n 1 >>maY
   grep -e "ATOM" -e "HETATM" comp$j.pqr | awk '{print $col}' col=$Zcol | sort -g | head -n 1 >>miZ
   grep -e "ATOM" -e "HETATM" comp$j.pqr | awk '{print $col}' col=$Zcol | sort -g | tail -n 1 >>maZ
  fi
 done

sort -g maX | tail -n 1 >> ../maX
sort -g miX | head -n 1 >> ../miX
sort -g maY | tail -n 1 >> ../maY
sort -g miY | head -n 1 >> ../miY
sort -g maZ | tail -n 1 >> ../maZ
sort -g miZ | head -n 1 >> ../miZ

rm -f m??

 cd ..
done
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (12) Grid mesh calculations #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#

# The grid mesh calculations are started
echo -e "\n"$(date +%H:%M:%S)" Started performing the grid mesh calculations...\n" | tee -a REPORTFILE0

XGrid=0; YGrid=0; ZGrid=0;

Calculate_GRID "miX" "maX" "UpX" "LoX" "uPX" "lOX" "XLEn" "XLeN" "XCeN" "upX" "loX" "XGrid" "$precF" "$extraspace" "$coarsefactor" "$grid_spacing" 
Calculate_GRID "miY" "maY" "UpY" "LoY" "uPY" "lOY" "YLEn" "YLeN" "YCeN" "upY" "loY" "YGrid" "$precF" "$extraspace" "$coarsefactor" "$grid_spacing"  
Calculate_GRID "miZ" "maZ" "UpZ" "LoZ" "uPZ" "lOZ" "ZLEn" "ZLeN" "ZCeN" "upZ" "loZ" "ZGrid" "$precF" "$extraspace" "$coarsefactor" "$grid_spacing" 

rm -f m??


touch grid.grid

printf "%s \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n\n" "Maximal and minimal values in each direction" "max X = " "$UpX" "max Y = " "$UpY" "max Z = " "$UpZ" "min X = " "$LoX" "min Y = " "$LoY" "min Z = " "$LoZ" >grid.grid
printf "%s \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n\n" "Fine grid vertices in each direction" "max Xf = " "$uPX" "max Yf = " "$uPY" "max Zf = " "$uPZ" "min Xf = " "$lOX" "min Yf = " "$lOY" "min Zf = " "$lOZ" >>grid.grid
printf "%s \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n\n" "Coarse grid vertices in each direction" "max Xc = " "$upX" "max Yc = " "$upY" "max Zc = " "$upZ" "min Xc = " "$loX" "min Yc = " "$loY" "min Zc = " "$loZ" >>grid.grid
printf "%s \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n%-12s %-2.4f \n\n%-12s %-2.0f \n%-12s %-2.0f \n%-12s %-2.0f \n\n" "Final values" "XCeN = " "$XCeN" "YCeN = " "$YCeN" "ZCeN = " "$ZCeN" "XLeN = " "$XLeN" "YLeN = " "$YLeN" "ZLeN = " "$ZLeN" "XLEn = " "$XLEn" "YLEn = " "$YLEn" "ZLEn = " "$ZLEn" "XGrid = " "$XGrid" "YGrid = " "$YGrid" "ZGrid = " "$ZGrid">>grid.grid



#=======================================================================================================================================#
#=======================================================================================================================================#
# variable	how many					what does it contain?				how is it		#
#		values?												  calculated?		#
#=======================================================================================================================================#
# a[XYZ]	1/PQR		contains the extreme maximum values for X, Y, Z coordinates of each 					#
#						PQR file in each directory	 							#
# i[XYZ]	1/PQR		contains the extreme minimum values for X, Y, Z coordinates of each 					#
#						PQR file in each directory	 							#
# Up[XYZ]	1		contains the extreme overall maximum value for X, Y, Z coordinates					#
# Lo[XYZ]	1		contains the extreme overall minimum value for X, Y, Z coordinates					#
# uP[XYZ]	3		contains the fine grid maximum values for X, Y, Z coordinates			Up[XYZ]+10	 	#
# lO[XYZ]	3		contains the fine grid minimum values for X, Y, Z coordinates			Lo[XYZ]-10	 	#
# up[XYZ]	3		contains the coarse grid maximum values for X, Y, Z coordinates					 	#
# lo[XYZ]	3		contains the coarse grid minimum values for X, Y, Z coordinates					 	#
# [XYZ]LEn	1		X, Y, Z fine grid size lengths							uP[XYZ]-lO[XYZ]	 	#
# [XYZ]LeN	1		X, Y, Z coarse grid size lengths								 	#
# [XYZ]CeN	1		X, Y, Z grid centers								(Up[XYZ]-Lo[XYZ])/2	#
# [XYZ]LeNb	1		X, Y, Z real number of grid points required at least				([XYZ]LEn*2)+1		#
# [xyz]gRID	1		X, Y, Z integer number of grid points required at least				([XYZ]LeNb./*)		#
# [XYZ]Grid	1		actual X, Y, Z number of grid points									#
#=======================================================================================================================================#
#=======================================================================================================================================#

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
# (13) Generation of input and SH files #
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#
for Folder in $FolderFile2; do
 cd $Folder
 tot=$(ls comp*.pqr | wc | awk '{print $1}'); let "tot=$tot-1";


if [ "$linearized" == "y" ]; then 
 pb=$(echo lpbe)
else
 pb=$(echo npbe)
fi

 let "C=$(ls comp*.pqr | wc | awk '{print $1-1}')"

 #@@@@ INPUT APBS FILE @@@@#
 echo -e $(date +%H:%M:%S)" Started generating the input files for solvation energy calculations in "$Folder"..." | tee -a ../REPORTFILE0

 for (( count=0; count<=$C; count++ )); do
 
if [ $protein_alone == "y" ]; then

 check2 comp$count.pqr ../REPORTFILE0;
 # APBS polar and nonpolar solvation calculations
 PRINT_APBS_POLAR_IN_protein "$count" "$complex" "$XGrid" "$YGrid" "$ZGrid" "$XLeN" "$YLeN" "$ZLeN" "$XLEn" "$YLEn" "$ZLEn" "$XCeN" "$YCeN" "$ZCeN" "$pb" "$pdie" "$sdie" "$srad" "$temp" "$bcfl" "$chgm" "$srfm" "$swin" "$sdens" "$calcforce" "$ion_ch_pos" "$ion_rad_pos" "$ion_conc_pos" "$ion_ch_neg" "$ion_rad_neg" "$ion_conc_neg" "$calcenergy" > stru$count.in
  PRINT_APBS_NONPOLAR_IN_protein  "$count" "$complex" "$srad" "$temp" "$swin" "$sdens" "$Hsrfm" "$Hpress" "$Hgamma" "$Hbconc" "$Hdpos" "$Hcalcforce" "$calcenergy" "$Hxgrid" "$Hygrid" "$Hzgrid" > Hstru$count.in

else
 
  check2 comp$count.pqr ../REPORTFILE0; check2 $receptor$count.pqr ../REPORTFILE0; check2 $ligand$count.pqr ../REPORTFILE0;
  # APBS polar and nonpolar solvation calculations
  PRINT_APBS_POLAR_IN "$count" "$complex" "$receptor" "$ligand" "$XGrid" "$YGrid" "$ZGrid" "$XLeN" "$YLeN" "$ZLeN" "$XLEn" "$YLEn" "$ZLEn" "$XCeN" "$YCeN" "$ZCeN" "$pb" "$pdie" "$sdie" "$srad" "$temp" "$bcfl" "$chgm" "$srfm" "$swin" "$sdens" "$calcforce" "$ion_ch_pos" "$ion_rad_pos" "$ion_conc_pos" "$ion_ch_neg" "$ion_rad_neg" "$ion_conc_neg" "$calcenergy" > stru$count.in
  PRINT_APBS_NONPOLAR_IN  "$count" "$complex" "$receptor" "$ligand" "$srad" "$temp" "$swin" "$sdens" "$Hsrfm" "$Hpress" "$Hgamma" "$Hbconc" "$Hdpos" "$Hcalcforce" "$calcenergy" "$Hxgrid" "$Hygrid" "$Hzgrid" > Hstru$count.in

fi
 

done

 #@@@@ SH APBS FILE @@@@#
 echo -e $(date +%H:%M:%S)" Started generating the SH files for solvation energy calculations in "$Folder"..." | tee -a ../REPORTFILE0


 # SH files for polar and nonpolar calculations are created
calc=$(ls comp*.pqr | wc | awk '{print $1}')
let "D=$calc/$mnp"
let "R=$calc%$mnp"
if [ $R -eq 0 ]; then let "D=$D-1" ; fi


if [ $calc -lt $mnp ]
then
	let "D=0"
	let "proc=$calc"
else
	let "proc=$mnp"
fi

 if [ $cluster == "y" ]
 then
	for ((count=0; count<=$D; count++)); do
		 PRINT_POLAR_SH_cluster "$count" "$proc" "$Apath" "$Q" "$D" "$C" "$budget_name" "$walltime" "$option_clu" "$option_clu2"> apbs$count.sh
		 PRINT_NONPOLAR_SH_cluster "$count" "$proc" "$Apath" "$Q" "$D" "$C" "$budget_name" "$walltime" "$option_clu" "$option_clu2"> Hapbs$count.sh
		 chmod 700 apbs$count.sh Hapbs$count.sh
 	done
 else
	for (( count=0; count<=$C; count++ )); do
	 	PRINT_POLAR_SH "$count" "$Apath" > apbs$count.sh
	 	PRINT_NONPOLAR_SH "$count" "$Apath" > Hapbs$count.sh 
		chmod 700 apbs$count.sh Hapbs$count.sh
	done
 fi



#@@@@@@@@@@@@@@@@@@@@@@@@@#
# (14) Cleaning procedure #
#@@@@@@@@@@@@@@@@@@@@@@@@@#


mkdir STORED_FILES
for file in  LOGfiles.tar.gz PDBs.tar.gz Mm.mdp mdout.mdp; do
	if [ -f $file ]; then 
		mv $file STORED_FILES
	fi
done
if [ $coulomb == "coul" ]; then 
	if [ $protein_alone == "n" ]; then
		mv COUfiles.tar.gz STORED_FILES; 
	fi
fi

mkdir APBS_CALCULATIONS  
mv Hapbs*.sh apbs*.sh Hstru*.in stru*.in *.pqr APBS_CALCULATIONS

mkdir SUMMARY_FILES
mv PotEn.PotEn stru*.rep SUMMARY_FILES

rm -f io.mc
rm -f \#* *~


#Check in all the stru files that the values for LJ_overall and Coulomb_overall are written. If ok it generates the file DONE0
cd SUMMARY_FILES
	if [ $coulomb == "coul" ]; then Coul_keyword="Coulomb overall"; else Coul_keyword="GMX-coul overall"; fi;
	N_rep_file=`ls stru*rep | wc -l`;
	count=0;
	for file in stru*rep; do
		a=`grep "Lenn-Jon overall" $file | cut -d " " -f1`
		b=`grep "$Coul_keyword" $file | cut -d " " -f1`
		if [ ! -z $a ] && [ ! -z $b ]; then count=$(($count+1)); fi
	done
	if [ $N_rep_file -eq $count ]; then 
		touch ../../DONE0_$Folder; 
	fi
	N_files=`ls stru*.rep | wc -l | awk '{print $1}'`
	echo -e "In the directory $Folder $N_files PQR/PDB files have been generated to perform the APBS calculations.\n" | tee -a ../../REPORTFILE0


cd ../..
done
AaaaA=5
for  Folder in $FolderFile2; do
	if ! [ -f DONE0_$Folder ]; then
		AaaaA=0;
		echo -e "Something went wrong with the calculations in the Folder $Folder. Please check it." | tee -a REPORTFILE0
	fi
done
if [ $AaaaA -eq 5 ]; then
       echo -e "\n"$(date +%H:%M:%S)" All successfully DONE \nRun gmxpbsa1.sh to perform APBS\n"| tee -a REPORTFILE0
       stde=`find ./* -name STD_ERR0`
       for s in $stde; do rm -f $s; done
fi

cd ..


