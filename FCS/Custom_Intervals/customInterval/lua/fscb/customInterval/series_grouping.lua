local util = require("fscb.common.util")

--[[
NAME:           series_grouping

DESCRIPTION:    run demand classification and pattern clustering on a given data
                
INPUTS:         args
                --required in args
                  inData
                  idVar
                  idInterval
                  demandVar
                  hierByVars
                  outData
                  outSum

                --optional in args
                  processLib
                  
                  processByVars
                  lowByVar
                  highByVar
                  
                  setMissing
                  zeroDemandThresholdPct
                  zeroDemandThreshold
                  gapPeriodThreshold
                  
                  shortReclass
                  horizontalReclassMeasure
                  classifyDeactive
                  shortSeriesPeriod
                  lowVolumePeriodInterval
                  lowVolumePeriodMaxTot
                  lowVolumePeriodMaxOccur
                  ltsMinDemandCycLen
                  deactiveThreshold
                  deactiveBufferPeriod
                  calendarCycPeriod
                  currentDate
                  profileType
                  
                  clusteringMethod
                  hiIndistanceFlag
                  hiDistanceMeasure
                  clusterWeight
                  hiClusterMethod
                  numOfClusters
                  minNumOfCluster
                  maxNumOfCluster
                  hiNosquare
                  nclCutoffPct1
                  nclCutoffPct2
                  cccCutoff
                  hiRsqMin
                  hiRsqMethod
                  hiRsqChangerate
                  hiRsqModelcomplexity
                  hiNclSelection
                  kmNomiss
                  kmStd

OUTPUTS:        outData


USAGE:          
                
]]

function series_grouping(args)

  local rc   
  local dccArgs={} 

  -- print out input arguments if in debug
  local tdebug = sas.symget("DEBUG")
  local debug = 0
  local debugFile = sas.symget("DEBUG_FILE")
  if util.check_value(tdebug) then
    debug = tonumber(tdebug)
  end
  dccArgs.debug = debug
  if debug == 1 then 
    local r="********INPUT ARGUMENT VALUE INTO SERIES_GROUPING:********"
    local s=table.tostring(args)
    if util.check_value(debugFile) then
      util.dump_to_file(r, debugFile)
      local a = "args="..string.gsub(s, '00000000.-=', '')
      util.dump_to_file(a, debugFile)
    else 
      print(r.."\n")
      print("args=", s)                    
    end
  end  
  
  for k, v in pairs(args) do    
    dccArgs[k] = v   
  end
  
  -- call dcc job wrapper to generate season group
  rc = sas.submit([[    
      %let syscc=0;    
      %dcc_job_ci(
          process_lib=@processLib@,
          cmp_lib=@processLib@.timefnc,
          use_package=1,
          need_sort=1,
          indata_table=@inData@,
          time_id_var=@idVar@,
          demand_var=@demandVar@,
          hier_by_vars=@hierByVars@,
          process_by_vars=@processByVars@,
          low_by_var=@lowByVar@,
          high_by_var=@highByVar@,   
          time_interval=@idInterval@, 
          run_classification=1,
          run_pclustering=1,
          run_vgrouping=0,
          exclude_class_from_pc=%str(SHORT LOW_VOLUME LTS_SEASON LTS_NON_SEASON LTS_SEASON_INTERMIT LTS_INTERMIT DEACTIVE LTS_UNCLASS UNCLASS),
          setmissing=@setMissing@,
          zero_demand_flg=1,
          zero_demand_threshold_pct=@zeroDemandThresholdPct@,    
          zero_demand_threshold=@zeroDemandThreshold@,
          gap_period_threshold=@gapPeriodThreshold@,
              
          /*classfication arguments*/
          class_input_vars=,
          
          short_reclass=@shortReclass@,
          horizontal_reclass_measure=@horizontalReclassMeasure@,
          classify_deactive=@classifyDeactive@,
          short_series_period=@shortSeriesPeriod@,
          low_volume_period_interval=@lowVolumePeriodInterval@,
          low_volume_period_max_tot=@lowVolumePeriodMaxTot@,
          low_volume_period_max_occur=@lowVolumePeriodMaxOccur@,
          lts_min_demand_cyc_len=@ltsMinDemandCycLen@,
          lts_seasontest_siglevel=,
          intermit_measure=MEDIAN,
          intermit_threshold=40000000,
          deactive_threshold=@deactiveThreshold@,
          deactive_buffer_period=@deactiveBufferPeriod@,
          calendar_cyc_period=@calendarCycPeriod@,
          current_date=@currentDate@,
          out_class=DEFAULT,
          out_stats=NONE,
          out_profile=1,
          profile_type=@profileType@,
          class_logic_file=,
          
          _class_result_table=,
          _class_statistics_table=,
      
          /*pattern clustering arguments*/
          clustering_method=@clusteringMethod@,
          hi_indistance_flag=@hiIndistanceFlag@,
          hi_distance_measure=@hiDistanceMeasure@,
          cluster_weight=@clusterWeight@,
          hi_cluster_method =@hiClusterMethod@,
          num_of_clusters =@numOfClusters@,
          min_num_of_cluster=@minNumOfCluster@,
          max_num_of_cluster=@maxNumOfCluster@,
          hi_nosquare =@hiNosquare@,
          ncl_cutoff_pct_1 =@nclCutoffPct1@,
          ncl_cutoff_pct_2 =@nclCutoffPct2@,
          ccc_cutoff =@cccCutoff@,
          hi_rsq_min =@hiRsqMin@,
          hi_rsq_method =@hiRsqMethod@,
          hi_rsq_changerate =@hiRsqChangerate@,
          hi_rsq_modelcomplexity =@hiRsqModelcomplexity@,
          hi_ncl_selection=@hiNclSelection@,
          hi_max_obs_threshold=15000, /*hidden spec: always use KMEANS if the number of observations > 15000 to avoid performance issue in PROC CLUSTER*/
          km_nomiss =@kmNomiss@,
          km_std =@kmStd@,
         
          _cluster_result_table =,
          _cluster_quality_table =,
          
          /*volume grouping arguments*/
          grouping_method=,                       
          avg_demand_threshold=,
          min_frequency_threshold=,                 
          min_unqualified_volume_pct=,        
          min_unqualified_node_count_pct=,    
          vg_by_var_length=,
               
          _vg_result_table=,                       
          _vg_statistics_table=,
          
          _job_meta_res_table=@outSum@,
          _job_merge_res_table=@outData@,
          
          debug=@debug@,
          _rc=
      );
      
      data @outSum@;
        set @outSum@;
        if DC_BY ne "STS" then DC_BY="OTHERS";
      run;
      data @outData@;
        set @outData@;
        if DC_BY ne "STS" then DC_BY="OTHERS";
      run;
          ]], dccArgs)    
          

end



return{series_grouping=series_grouping}
