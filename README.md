# gmxpbsa
MM/PBSA binding free energy calculation
MM/PBSA binding free energy calculation 

################ INSTALLATION ###################

The user can extract the source code in some location, i.e. /home/myprogram/, by typing

tar zxvf GMXPBSAtool.tar.gz;

set the GMXPBSAHOME environment variable in bash:

export GMXPBSAHOME=/home/myprogram/GMXPBSAtool

Change the /home/myprogram to whatever directory is appropriate for your machine, verify that you have write permissions in the directory tree, and that the gmxpbsa0.sh, gmxpbsa1.sh and gmxpbsa2.sh scripts have execute permissions. $GMXPBSAHOME should be also added to the PATH. GMXPBSAtool uses bash environment. So make sure that you are in the bash shell (echo $SHELL should give /bin/bash). To use bash shell just type

bash

Ubuntu and Debian derived make use of dash shell rather than bash. We force GMXPBSAtool to use bash but if you encounter problem in running the tool check whether bash shell is installed.

################ APBS and GROMACS ###################

In order to perform the MM/PBSA calculation, APBS program (http://www.poissonboltzmann.org/apbs/) and GROMACS tool (www.gromacs.org) must be installed and working. In Ubuntu/Xubuntu/Kubuntu and Debian derived you can install them by:

sudo apt-get install apbs sudo apt-get install gromacs

Make sure that you are using the latest updated version of APBS and GROMACS version 4.5 and later. Both programs can be installed by compiling the source code too, without root permission.

################ HOW TO RUN GMXPBSAtool ###################

In order to perform the MM/PBSA calculation,the user has to run the tool by typing $GMXPBSAHOME/<script>, where <script> can be either gmxpbsa0.sh, or gmxpbsa1.sh or gmxpbsa2.sh depending on stage of the calculation that will be performed (see section 2.4 of the paper). Each script will read the INPUT.dat file to perform the MM/PBSA calculation. For instance, if the INPUT.dat file and the simulations are located in /home/mysimulations, in this directory the user can run the tool typing $GMXPBSAHOME/<script>. See section 3 of the paper for further details or the DEMO examples
