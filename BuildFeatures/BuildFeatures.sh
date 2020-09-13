#!/bin/sh

if [[ -z "${ModelingHome}" ]]; then
        echo "ERROR: Please set environmental variable ModelingHome to the installation folder of the RaptorX-3DModeling package"
        exit 1
fi

if [[ -z "${DistFeatureHome}" ]]; then
        echo "ERROR: Please set the environmental variable DistFeatureHome to the installation directory of BuildFeatures, e.g., $HOME/RaptorX-3DModeling/BuildFeatures/"
        exit 1
fi

ResDir=`pwd`
gpu=-1
GPUmode=4
#GPUMachineFile=$DistFeatureHome/params/GPUMachines.txt
GPUMachineFile=$ModelingHome/params/GPUMachines.txt
MSAmethod=25

function Usage
{
	echo $0 "[ -o outfolder | -g gpu | -r machineMode | -h MachineFile | -m MSAmethod ] inputFile"
	echo "	This script builds all needed features for local structure property prediction and contact/distance/orientation prediction for one protein"
	echo "	inputFile: a protein sequence file in FASTA format or a multiple sequence alignment (MSA) in a3m format"
	echo "	-o: the folder for output, default current work directory. The results will be saved to a subfolder outfolder/proteinName_OUT/"
	echo "	-g: -1 (default), 0-3. if -1, automatically select one GPU"
	echo " "
	echo "	-m: an integer indicating MSA generation methods formed by combining 1, 2, 4, 8 and 16, default $MSAmethod"
        echo "		1: run HHblits to generate MSAs for local structure property prediction and for threading"
	echo "		2: run HHblits 2.0 to generate MSA for contact (obsolete)"
        echo "		4: run Jackhmmer to generate MSA for contact and distance prediction (slow)"
	echo "		8: run HHblits 3.0 to generate MSA for contact and distance prediction"
        echo "		16: search MetaGenome data for each MSA generated by above methods"
        echo "		By default, building MSA for threading and contact/distance using HHblits 3.2, Jackhmmer and metagenome data"
 	echo " "
        echo "		NOTE that if 0, inputFile shall be an MSA in a3m format, i.e., no new MSA will be generated"
        echo " "
	echo "	-r: specifiy what kind of CPUs and GPUs to use, default $GPUmode"
        echo "		1: use local GPUs if available"
        echo "		2: use local GPUs and CPUs"
        echo "		3: use local GPUs and GPUs of machines defined by the -h option"
        echo "		4: use local GPUs/CPUs and GPUs of machines defined by the -h option"
        echo "	-h: a file specifying remote machines with GPUs, default $GPUMachineFile"
	echo "		No remote GPUs will be used if this file and the default file do not exist"
}

while getopts ":o:g:r:h:m:" opt; do
        case $opt in
        o)
                ResDir=$OPTARG
                ;;
        g)
                gpu=$OPTARG
                ;;
	m)
		MSAmethod=$OPTARG
		;;
	h )
                GPUMachineFile=$OPTARG
                ;;
        r )
                GPUmode=$OPTARG
                ;;
        #-> help
        \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        :)
                echo "Option -$OPTARG requires an argument." >&2
                exit 1
                ;;
        esac
done
shift $((OPTIND -1))

if [ $# -ne 1 ]; then
	Usage
	exit 1
fi

seqFile=$1
if [ ! -f $seqFile ]; then
	echo "ERROR: invalid input file: $seqFile"
	exit 1
fi

inputIsMSA=0
if [[ "$seqFile" == *.a3m ]]; then
	inputIsMSA=1
fi

cmd=`readlink -f $0`
cmdDir=`dirname $cmd`

if [ $MSAmethod -eq 0 -o $inputIsMSA -eq 1 ]; then
	$cmdDir/HandleUserA3M.sh $seqFile $ResDir
	if [ $? -ne 0 ]; then
		echo "ERROR: failed to run $cmdDir/HandleUserA3M.sh $seqFile $ResDir "
		exit 1
	fi
else
	$cmdDir/BuildMSAs.sh -d $ResDir -m $MSAmethod $seqFile
	if [ $? -ne 0 ]; then
		echo "ERROR: failed to run $cmdDir/BuildMSAs.sh -d $ResDir -m $MSAmethod $seqFile"
		exit 1
	fi
fi

fulnam=`basename $seqFile `
target=${fulnam%.*}
contactDir=$ResDir/${target}_OUT/${target}_contact

$cmdDir/GenDistFeatures4OneProtein.sh -g $gpu -r $GPUmode -h $GPUMachineFile $target $contactDir
if [ $? -ne 0 ]; then
	echo "ERROR: failed to run $cmdDir/GenDistFeatures4OneProtein.sh -g $gpu -r 4 $target $contactDir"
	exit 1
fi
