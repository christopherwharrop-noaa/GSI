#!/bin/sh
#--------------------------------------------------------------------
#
#  Plot.sh
#
#  Plot a data source.
#  
#    calling sequence:  Plot.sh suffix start_date end_date 
#     	suffix	   -- data source identifier that matches data in the 
#		      $TANKDIR/stats directory
#       start_date -- format YYYYMMDDHH, first cycle the plot is to 
#                     include
#       end_date   -- format YYYYMMDDHH, last cycle the plot is to 
#                     include.  This must be at least 2 cycles after
#                     the start date.
#
#  Note:  this does not generate any data files.  Those must be 
#  already created for this script to function correctly.
#
#--------------------------------------------------------------------

function usage {
  echo "Usage:  Plot_glbl.sh suffix start_date end_date"
  echo "            File name for CkPlt_glbl.sh may be full or relative path"
  echo "            Suffix is data source identifier that matches data in "
  echo "              the $TANKDIR/stats directory."
  echo "            start_date and end_date are in the format YYYYMMDDHH."
  echo "              The start_date must be at least 2 cycles before end_date."
}

set -ax
echo start Plot.sh
echo
echo $PATH
echo

nargs=$#
if [[ $nargs -ne 3 ]]; then
   usage
   exit 1
fi

this_file=`basename $0`
this_dir=`dirname $0`

SUFFIX=$1
start_dt=$2
end_dt=$3

echo SUFFIX    = ${SUFFIX}
echo start_dt  = ${start_dt}
echo end_dt    = ${end_dt}

#--------------------------------------------------------------------
#  Verify start_dt and end_dt are the correct length.   
#--------------------------------------------------------------------

if [[ ${#start_dt} -ne 10 ]]; then
   echo ERROR:  start_date is not in YYYYMMDDHH format, exiting.
   exit 2
elif [[ ${#end_dt} -ne 10 ]]; then
   echo ERROR:  end_date is not in YYYYMMDDHH format, exiting.
   exit 3
fi

 
#--------------------------------------------------------------------
# Run config files to load environment variables, 
# set default plot conditions
#--------------------------------------------------------------------

top_parm=${this_dir}/../../parm

if [[ -s ${top_parm}/RadMon_config ]]; then
   . ${top_parm}/RadMon_config
else
   echo "Unable to source ${top_parm}/RadMon_config"
   exit 4
fi
if [[ -s ${top_parm}/RadMon_user_settings ]]; then
   . ${top_parm}/RadMon_user_settings
else
   echo "Unable to source ${top_parm}/RadMon_user_settings"
   exit 6
fi

. ${RADMON_IMAGE_GEN}/parm/plot_rad_conf

if [[ $RAD_AREA = "glb" ]]; then
   . ${RADMON_IMAGE_GEN}/parm/glbl_conf
elif [[ $RAD_AREA = "rgn" ]]; then
   . ${RADMON_IMAGE_GEN}/parm/rgnl_conf
else
   echo "ERROR:  unable to determine RAD_AREA for $SUFFIX"
   exit 7
fi


#--------------------------------------------------------------------
#  Deterine the number of cycles between start_dt and end_dt.
#--------------------------------------------------------------------
export NUM_CYCLES=`${SCRIPTS}/cycle_delta.pl ${start_dt} ${end_dt}`
echo NUM_CYCLES = $NUM_CYCLES

if [[ $NUM_CYCLES -le 0 ]]; then
   echo "ERROR:  check input dates -- number of cycles is $NUM_CYCLES"
   exit 5
else 
   export NUM_CYCLES=`expr $NUM_CYCLES + 1`
fi


#--------------------------------------------------------------------
#  Determine the last processed cycle.  At a minimum this must 
#  have a cycle delta of 1 from $start_dt.  (Two cycles are necessary
#  for grads to plot.)
#--------------------------------------------------------------------
proc_dt=`${SCRIPTS}/find_last_cycle.pl ${TANKDIR}`
echo proc_date = $proc_dt
delta_proc_start=`${SCRIPTS}/cycle_delta.pl ${start_dt} ${proc_dt}`
if [[ $delta_proc_start -le 0 ]]; then
   echo "ERROR:  no data available -- last processed date is ${proc_dt}"
   echo "        requested plot start date is ${start_dt}"
   exit 6
fi


export PLOT=1
export PLOT_HORIZ=0
#--------------------------------------------------------------------
# Check status of plot jobs. If any are still running then exit
# this script. If none are running then remove any old job records 
# in the $LOADLQ directory.
#
# Also need to check verf jobs for suffix. Don't want to run until
# all verf jobs have been completed.
#--------------------------------------------------------------------

if [[ $MY_MACHINE = "ccs" ]]; then
   running=`llq -u ${LOGNAME} -f %jn | grep ${plot} | grep $SUFFIX | wc -l`
elif [[ $MY_MACHINE = "wcoss" ]]; then
   running=`bjobs -l | grep plot_${SUFFIX} | wc -l` 
else
   running=`showq -n -u ${LOGNAME} | grep plot_${SUFFIX} | wc -l`
fi

if [[ $running -ne 0 ]]; then
   echo "Plot jobs still running for $SUFFIX, must exit"
   exit
fi


#--------------------------------------------------------------------
#  Create tmpdir and LOGDIR
#--------------------------------------------------------------------

tmpdir=${STMP_USER}/plot_rad${SUFFIX}
rm -rf $tmpdir
mkdir -p $tmpdir
cd $tmpdir

mkdir -p $LOGDIR


#--------------------------------------------------------------------
# Set up processing dates and data directories.
#--------------------------------------------------------------------
export PDATE=${end_dt}
sdate=`echo $PDATE|cut -c1-8`
export CYA=`echo $PDATE|cut -c9-10`
export PDY=`echo $PDATE|cut -c1-8`


#--------------------------------------------------------------------
# Make horizontal plots only on 00z cycle.  All other plotting
# is done with each cycle. 
#--------------------------------------------------------------------
if [[ "$CYA" = "00" ]];then
   export PLOT_HORIZ=1
fi

#echo plot = $PLOT, plot_horiz = $PLOT_HORIZ

if [[ -d $PLOT_WORK_DIR ]]; then
   rm -rf $PLOT_WORK_DIR
fi
mkdir $PLOT_WORK_DIR
cd $PLOT_WORK_DIR


#-------------------------------------------------------------
#  If USE_STATIC_SATYPE == 0 then assemble the SATYPE list from
#  available data files in $TANKDIR/angle
#  If USE_STATIC_SATYPE == 1 then load SATYPE from the SATYPE.txt 
#  file.
#-------------------------------------------------------------
if [[ $USE_STATIC_SATYPE -eq 0 ]]; then

   ctr=$(($NUM_CYCLES))
   tdate=$end_dt
   tdy=$PDY  

   while [[ $ctr -ge 0 ]]; do
      if [[ -d ${TANKDIR}/radmon.${tdy} ]]; then
         test_list=`ls ${TANKDIR}/radmon.${tdy}/angle.*${tdate}.ieee_d*`
      else
         test_list=`ls ${TANKDIR}/angle/*.${tdate}.ieee_d*`
      fi

      if [[ ${#test_list} -gt 0 ]]; then
         for test in ${test_list}; do
            this_file=`basename $test`
            tmp=`echo "$this_file" | cut -d. -f2`
            echo $tmp
            SATYPE_LIST="$SATYPE_LIST $tmp"
         done

         break
      fi

      tdate=`$NDATE -06 ${tdate}` 
      tdy=`echo $tdate|cut -c1-8`
      ctr=$(($ctr-1))
   done

   SATYPE=$SATYPE_LIST
   echo $SATYPE

else 
   TANKDIR_INFO=${TANKDIR}/info
   STATIC_SATYPE_FILE=${TANKDIR_INFO}/SATYPE.txt

   #-------------------------------------------------------------
   #  Load the SATYPE list from the STATIC_SATYPE_FILE or exit 
   #  if unable to locate it.
   #-------------------------------------------------------------
   if [[ -s $STATIC_SATYPE_FILE ]]; then
      SATYPE=""
      SATYPE=`cat ${STATIC_SATYPE_FILE}`
      echo $SATYPE
   else
      echo Unable to locate $STATIC_SATYPE_FILE, must exit.
      cd $tmpdir
      cd ../
      rm -rf $tmpdir
      exit 7
   fi
fi


#------------------------------------------------------------------
# Export variables
#------------------------------------------------------------------
export START_DATE=${start_dt}
export listvar=RAD_AREA,PDATE,START_DATE,NUM_CYCLES,NDATE,TANKDIR,IMGNDIR,LOADLQ,EXEDIR,LOGDIR,SCRIPTS,GSCRIPTS,STNMAP,GRADS,USER,PTMP_USER,STMP_USER,USER_CLASS,SUB,SUFFIX,SATYPE,NCP,PLOT_WORK_DIR,ACCOUNT,DATA_MAP,Z,COMPRESS,UNCOMPRESS,PTMP,STMP,TIMEX,LITTLE_ENDIAN,PLOT_ALL_REGIONS,SUB_AVG,listvar


#------------------------------------------------------------------
#   Start image plotting jobs.
#------------------------------------------------------------------
${SCRIPTS}/mk_angle_plots.sh

${SCRIPTS}/mk_bcoef_plots.sh

${SCRIPTS}/mk_bcor_plots.sh

if [[ ${PLOT_HORIZ} -eq 1 ]] ; then
   export datdir=$RADSTAT_LOCATION

   export listvar=PARM,RAD_AREA,PDATE,NDATE,TANKDIR,IMGNDIR,LOADLQ,LLQ,EXEDIR,LOGDIR,SCRIPTS,GSCRIPTS,STNMAP,GRADS,USER,PTMP_USER,STMP_USER,USER_CLASS,SUB,SUFFIX,SATYPE,NCP,PLOT_WORK_DIR,ACCOUNT,RADMON_PARM,DATA_MAP,Z,COMPRESS,UNCOMPRESS,PTMP,STMP,TIMEX,LITTLE_ENDIAN,PLOT_ALL_REGIONS,SUB_AVG,datdir,MY_MACHINE,listvar
   jobname="plot_horiz_${SUFFIX}"
   logfile="${LOGDIR}/horiz.log"
   if [[ $MY_MACHINE = "ccs" ]]; then
      $SUB -a $ACCOUNT -e $listvar -j ${jobname} -q dev -g ${USER_CLASS} -t 0:20:00 -o ${logfile} ${SCRIPTS}/mk_horiz_plots.sh
   elif [[ $MY_MACHINE = "wcoss" ]]; then
      $SUB -q dev -o ${logfile} -W 0:45 -J ${jobname} ${SCRIPTS}/mk_horiz_plots.sh
   else
      $SUB -A $ACCOUNT -l procs=1,walltime=0:20:00 -N ${jobname} -v $listvar -j oe -o ${logfile} $SCRIPTS/mk_horiz_plots.sh
   fi
fi

${SCRIPTS}/mk_time_plots.sh


#--------------------------------------------------------------------
#  Check for log file and extract data for error report there
#--------------------------------------------------------------------
do_diag_rpt=$DO_DIAG_RPT
do_data_rpt=$DO_DATA_RPT

if [[ $do_data_rpt -eq 1 || $do_diag_rpt -eq 1 ]]; then

   logfile_dir=${LOGSverf_rad}/rad${SUFFIX}
   logfile=`ls ${logfile_dir}/${PDY}/gdas_verfrad_${CYA}.*`
   if [[ ! -s $logfile ]]; then
      logfile=${LOGDIR}/data_extract.${sdate}.${CYA}.log
   fi
  
   if [[ -s $logfile ]]; then
      ${SCRIPTS}/extract_err_rpts.sh $sdate $CYA $logfile
   fi
fi

#--------------------------------------------------------------------
# Clean up and exit
#--------------------------------------------------------------------
cd $tmpdir
cd ../
rm -rf $tmpdir

echo end Plot.sh
exit
