local util = require("fscb.common.util")

--[[
NAME:           fcmp_functions

DESCRIPTION:    generate custom interval's own fcmp functions that can be called later
                
INPUTS:         cmpLib

OUTPUTS:        @cmpLib@.funcs if it does not already exist

USAGE:          
                
]]

function fcmp_functions(cmpLib)

  local rc   
  local localCmpLib
  if util.check_value(cmpLib) then
    localCmpLib = cmpLib
  else
    localCmpLib = "work.customIntervalFunc"
  end 

  -- call proc fcmp to generate fcmp functions if it does not exist
  rc = sas.submit([[
  %macro ci_fcmp_functions(cmpLib=work.ciFuncs);
      %if not %sysfunc(exist(&cmpLib)) %then %do;
      
          proc fcmp ENCRYPT HIDE outlib=&cmpLib..funcs; 
          
          
          /***********************************************************************************************************
              API:
                          ci_compute_sum(timedata[*], sum, count);
              Type:
                          Subroutine
              Purpose: 
                          compute the summation of the elements of the time series array and count the total number of non-missing elements
              Input:   
                          timedata[*] : time series array 
                          
              Output: 
                          sum         : the summation of the non-missing elements
                          count       : count of the total number of non-missing elements
          ***********************************************************************************************************/
              subroutine ci_compute_sum(timedata[*], sum, count);
                  outargs sum, count;
                  sum = .;
                  count=0;
                  length=dim(timedata);
                  if length>0 then do;
                      sum=0;
                      do i=1 to length;
                          if timedata[i] ne . then do;
                              sum = sum + timedata[i];
                              count = count+1;
                          end;
                      end;
                      if count=0 then sum=.;
                  end;
              endsub;
          /***********************************************************************************************************
              API:
                          ci_compute_mean(timedata[*], mean, count);
              Type:
                          Subroutine
              Purpose: 
                          compute the mean of the time series array
              Input:   
                          timedata[*] : time series array 
              Output: 
                          sum            : the mean of the non-missing elements
                          count          : count of the total number of non-missing elements
          ***********************************************************************************************************/
              subroutine ci_compute_mean(timedata[*], mean, count);
                  outargs mean, count;
                  mean = .;
                  count=0;
                  length=dim(timedata);
                  if length>0 then do;
                      call ci_compute_sum(timedata, sum, count);
                      if count>0 and sum ne . then mean = sum / count;
                  end;
              endsub;
          
          /***********************************************************************************************************
              API:
                          ci_compute_order_stats(timedata[*], min, median, max);
              Type:
                          Subroutine
              Purpose: 
                          compute the min, median and max of the non-missing elements of the time series array 
              Input:   
                          timedata[*] : time series array 
              Output: 
                          min         : float value as the mininum of the obervations
                          median      : float value as the median of the obervations
                          max         : float value as the maxinum of the obervations
          
          ***********************************************************************************************************/
              subroutine ci_compute_order_stats(timedata[*], min, median, max);
                  outargs min, median, max;
                  array order[1]/NOSYMBOLS;
                  min = .;
                  median = .;
                  max = .;
                  length=dim(timedata);
                  if length>0 then do;
                      /*sort the array by ascending order*/
                      call dynamic_array(order, length);
                      count=0;
                      do i=1 to length;
                          if timedata[i] ne . then do;
                              count = count+1;
                              order[count]=timedata[i];
                          end;
                      end;
                      if count>0 then do;
                          if count=1 then do;
                              min = order[1];
                              median = order[1];
                              max = order[1];
                          end;
                          else do;  /*case count > 1*/
                              do i=1 to count-1;
                                  do j=1 to count-1;
                                      if order[j]>order[j+1] then do;
                                          temp = order[j];
                                          order[j]=order[j+1];
                                          order[j+1]=temp;
                                      end;
                                  end;
                              end;
                              min=order[1];
                              max=order[count];
                              index=floor(count/2);
                              if index*2<count then median = order[index+1];
                              else median = (order[index]+order[index+1])/2;
                          end;
                      end;
                  end;
              endsub;
              
          /***********************************************************************************************************
              API:
                          ci_compute_basic_freq(timedata[*], count, min, median, max, mean, mode);
              Type:
                          Subroutine
              Purpose: 
                          compute the count, min, median, max, mean, mode of the non-missing elements of the time series array 
              Input:   
                          timedata[*] : time series array 
              Output: 
                          count       : integer as the total number of non-missing elements of the time series array
                          min         : float value as the mininum of the non-missing elements of the time series array
                          median      : float value as the median of the non-missing elements of the time series array
                          max         : float value as the maxinum of the non-missing elements of the time series array
                          mean        : float value as the mean of the non-missing elements of the time series array
                          mode        : float value as the mode of the non-missing elements of the time series array
          
          ***********************************************************************************************************/
              subroutine ci_compute_basic_freq(timedata[*], count, min, median, max, mean, mode);
                  outargs count, min, median, max, mean, mode;
                  count=0;
                  min=.;
                  median=.;
                  max=.;
                  mean=.;
                  mode=.;
                  call ci_compute_order_stats(timedata, min, median, max);
                  call ci_compute_mean(timedata, mean, count);
                  array freq[1,1]/NOSYMBOLS;
                  call dynamic_array(freq, count,2);
                  fcount=0;
                  do i=1 to dim(timedata);
                    if timedata[i] ne . then do;
                      if fcount=0 then do;
                        fcount=fcount+1;
                        freq[fcount,1]=timedata[i];
                        freq[fcount,2]=1;
                      end;
                      else do;
                        found=0;
                        do j=1 to fcount;
                          if freq[j,1]=timedata[i] then do;
                            found=1;
                            freq[j,2]=freq[j,2]+1;
                          end;
                        end;
                        if found eq 0 then do;
                          fcount=fcount+1;
                          freq[fcount,1]=timedata[i];
                          freq[fcount,2]=1;                        
                        end;
                      end;
                    end;
                  end;
                  if fcount>0 then do;
                    modeC=freq[1,2];
                    mode = freq[1,1];
                    if fcount>1 then do;
                      do i=2 to fcount;
                        if freq[i,2]>=modeC then do;
                          modeC=freq[i,2];
                          mode = freq[i,1];
                        end;
                      end;
                    end;
                  end;
                  
              endsub;          
          
          /***********************************************************************************************************
              API:
                          ci_find_active_period_range(activeDemand[*], firstPartialFlag, lastPartialFlag, 
                                                      periodStart[*], periodEnd[*], periodCount, rc);
              Type:
                          Subroutine
              Purpose: 
                          Loop through the active demand series, identify the start/end index for each active demand period
              Input:   
                          activeDemand      : active demand array (non-active periods are filled with .)
                          firstPartialFlag  : 0/1 flag indicating if the first period is included or not if the first period is partial
                          lastPartialFlag   : 0/1 flag indicating if the last period is included or not if the last period is partial
                          
              Output: 
                          periodStart       : array that stores the period start index value
                          periodEnd         : array that stores the period end index value
                          periodCount       : number of valid elements in periodStart and periodEnd
                          rc                : return code : 0: success; 1: periodStart and periodEnd have different sizes; 
                                                            2: others
                          
          ***********************************************************************************************************/
              subroutine ci_find_active_period_range(activeDemand[*],firstPartialFlag, lastPartialFlag, 
                                                      periodStart[*], periodEnd[*], periodCount, rc);
                  outargs periodStart, periodEnd, periodCount, rc;
                  rc=2;
                  periodCount=0;
                  do i=1 to dim(periodStart);
                    periodStart[i]=.;
                  end;
                  do i=1 to dim(periodEnd);
                    periodEnd[i]=.;
                  end;
                  rc = 1;
                  if dim(periodStart) eq dim(periodEnd) then do;
                    rc = 2;
                    size=dim(activeDemand);
                    if activeDemand[1] ne . and firstPartialFlag=1 then do;
                      periodCount=periodCount+1;
                      periodStart[periodCount]=1;
                      if activeDemand[2] eq . then do;
                        periodEnd[periodCount]=1;
                      end;
                    end;
                    do i=1+1 to size-1;
                      if activeDemand[i] ne . and activeDemand[i-1] eq . then do;
                        periodCount=periodCount+1;
                        periodStart[periodCount]=i;
                      end;
                      if activeDemand[i] ne . and activeDemand[i+1] eq . then do;
                        periodEnd[periodCount]=i;
                      end;
                    end;
                    if activeDemand[size] ne . then do;
                      i=size;
                      if periodCount eq 0 then do;
                        periodCount = periodCount+1;
                        periodStart[periodCount]=i;
                        periodEnd[periodCount]=i;
                      end;
                      else do;
                        if activeDemand[i-1] eq . then do;
                          periodCount=periodCount+1;
                          periodStart[periodCount]=i;
                        end;
                        periodEnd[periodCount]=i;                  
                      end;
                      if lastPartialFlag ne 1 then do;
                        periodEnd[periodCount]=.;
                        periodStart[periodCount]=.;
                        periodCount=periodCount-1;
                      end;
                    end; 
                    rc = 0;
                  end;/*if dim(periodStart) eq dim(periodEnd) then do;*/

              endsub;

          /***********************************************************************************************************
              API:
                          ci_find_offseason_period_range(periodStart[*], periodEnd[*], periodCount, demandSize, firstPartialFlag, lastPartialFlag, 
                                                         offStart[*], offEnd[*], offCount, rc);
              Type:
                          Subroutine
              Purpose: 
                          Loop through the active demand series start/end, identify the start/end index for each off season period
              Input:   
                          periodStart       : array that stores the period start index value
                          periodEnd         : array that stores the period end index value
                          periodCount       : number of valid elements in periodStart and periodEnd
                          demandSize        : total number of demand obs
                          firstPartialFlag  : 0/1 flag indicating if the first period is included or not if the first period is partial
                          lastPartialFlag   : 0/1 flag indicating if the last period is included or not if the last period is partial
                          
              Output: 
                          offStart          : array that stores the off season period start index value
                          offEnd            : array that stores the off season period end index value
                          offCount          : number of valid elements in offStart and offEnd
                          rc                : return code : 0: success; 1: offStart and offEnd have different sizes; 
                                                            2: others
                          
          ***********************************************************************************************************/
              subroutine ci_find_offseason_period_range(periodStart[*], periodEnd[*], periodCount, demandSize, firstPartialFlag, lastPartialFlag, 
                                                        offStart[*], offEnd[*], offCount, rc);
                  outargs offStart, offEnd, offCount, rc;
                  rc=2;
                  offCount=0;
                  do i=1 to dim(offStart);
                    offStart[i]=.;
                  end;
                  do i=1 to dim(offEnd);
                    offEnd[i]=.;
                  end;
                  rc = 1;
                  if dim(offStart) eq dim(offEnd) then do;
                    rc = 2;
                    offCount = 0;
                    if periodCount=0 then do;
                      if firstPartialFlag eq 1 or lastPartialFlag eq 1 then do;
                        offCount = offCount+1;
                        offStart[offCount]=1;
                        offEnd[offCount]=demandSize;
                      end;
                    end;
                    else do;
                      tmpIndex = 1;
                      if periodStart[1] eq 1 then do;
                        offCount = offCount+1;
                        offStart[offCount]= periodEnd[1]+1;
                        tmpIndex=2;
                      end;
                      else do;
                        if firstPartialFlag eq 1 then do;
                          offCount = offCount+1;
                          offStart[offCount]= 1;
                        end;                     
                      end;
                      if periodCount>=tmpIndex then do;
                        do i=tmpIndex to periodCount;
                          if offCount>0 then offEnd[offCount]=periodStart[i]-1;
                          offCount = offCount+1;
                          offStart[offCount]=periodEnd[i]+1;
                        end;
                      end;
                      if periodEnd[periodCount] lt demandSize and lastPartialFlag eq 1 then do;
                        if offCount>0 then offEnd[offCount]=demandSize;
                      end;
                      else do;
                        if offCount>0 then do;
                          offStart[offCount]=.;
                          offCount = offCount-1;
                        end;
                      end;
                    end;/*else do for if periodCount=0 then do;*/
                    rc = 0;
                  end;/*if dim(offStart) eq dim(offEnd) then do;*/

              endsub;

                        
          /***********************************************************************************************************
              API:
                          ci_find_active_event(activeDemand[*], timeID[*], eventFile $, eventSize, interval $, eventDefBufferLen, eventIdx, rc);
              Type:
                          Subroutine
              Purpose: 
                          Loop through all events defined in eventFile and compare with activeDemand patterns, to find 
                          the event that the the activeDemand always occur within or close to
              Input:   
                          activeDemand      : active demand array (non-active periods are filled with .)
                          timeID            : timeID series (should have the same size as activeDemand)
                          eventFile         : sas data set that stores the event definition information
                                              the eventFile contains the following columns: event_idx , event_name, year, event_date, weight
                          eventSize         : the number of observations in the data set eventFile
                          interval          : time interval
                          eventDefBufferLen : a buffer length that defines "within or close to"
                          
              Output: 
                          eventIdx          : the index for the found event (missing if no event is found)
                          rc                : return code : 0: success; 1: eventSize<=0; 2: activeDemand and timeID have different sizes; 3: error in read_array;
                                                            4: no active periods; 5: others
                          
          ***********************************************************************************************************/
              subroutine ci_find_active_event(activeDemand[*], timeID[*], eventFile $, eventSize, interval $, eventDefBufferLen, eventIdx, rc);
                  outargs eventIdx, rc;
                  eventIdx = .;
                  rc = 1;
                  if eventSize>0 then do;
                    rc=5;
                    demandSize = dim(activeDemand);
                    if demandSize ne dim(timeID) then rc=2;
                    else do;
                      /*copy array from eventFile*/
                      array tmp[1,1] / nosymbols;
                      call dynamic_array(tmp, eventSize, 3);
                      do t=1 to eventSize;
                        tmp[t,1]=.; tmp[t,2]=.; tmp[t,3]=.;
                      end;
                      temp_rc = read_array(eventFile, tmp, 'event_idx' , 'event_date', 'weight');
                      
                      if temp_rc=0 then do;
                      
                        /*identify active period range*/
                        array periodStart[1] / nosymbols;
                        array periodEnd[1] / nosymbols;
                        call dynamic_array(periodStart, demandSize);
                        call dynamic_array(periodEnd, demandSize);
                        array offStart[1] / nosymbols;
                        array offEnd[1] / nosymbols;
                        call ci_find_active_period_range(activeDemand, 1, 1, periodStart, periodEnd, periodCount, tmp_rc);

                        if periodCount >0 then do;

                          /*get unique list of event*/
                          array eventList[1] / nosymbols;
                          call dynamic_array(eventList, eventSize);
                          eventCount = 0;
                          do i=1 to eventSize;
                            if eventCount>0 then do;
                              if tmp[i,1] ne . then do;
                                found=0;
                                do j=1 to eventCount;
                                  if tmp[i,1] eq eventList[j] then found=1;
                                end;
                                if found eq 0 then do;
                                  eventCount = eventCount+1;
                                  eventList[eventCount]=tmp[i,1];
                                end;
                              end;
                            end;
                            else do; /*if eventCount>0 then do;*/
                              if tmp[i,1] ne . then do;
                                eventCount = 1;
                                eventList[eventCount]=tmp[i,1];
                              end;
                            end;
                          end;

                          /*candidate rule: for each full cycle active period, the event should be fall into the buffer range */                        
                          array candiList[1] / nosymbols;
                          call dynamic_array(candiList, eventCount);
                          candiSize=0;
                          do i=1 to eventCount;
                            candiList[i]=.;
                          end;
                          do i=1 to eventCount;
                            event=eventList[i];
                            out=0;
                            do k=1 to periodCount;
                              found=0;
                              do j=1 to eventSize;
                                if tmp[j,1] eq event then do;
                                  s=periodStart[k];
                                  e=periodEnd[k];
                                  bc = INTCK( interval, timeID[s], tmp[j,2]);
                                  ac = INTCK( interval, tmp[j,2], timeID[e]);
                                  if bc>=-eventDefBufferLen and ac>=-eventDefBufferLen then found=1;
                                end;
                              end;
                              if found eq 0 and not ((k=1 and periodStart[k]=1) or (k=periodCount and periodEnd[k]=demandSize)) then out=1;
                            end;                         
                            if out eq 0 then do;
                              candiSize=candiSize+1;
                              candiList[candiSize]=event;
                            end;
                          end;
                          
                          if candiSize eq 1 then eventIdx=candiList[1];
                          else if candiSize > 1 then do;

                            /*compare weight and distance stability*/
                            array weightList[1] / nosymbols;
                            call dynamic_array(weightList, candiSize);
                            maxWeight=.;
                            array distList[1] / nosymbols;
                            call dynamic_array(distList, candiSize);
                            array beforeDist[1] / nosymbols;
                            array afterDist[1] / nosymbols;
                            call dynamic_array(beforeDist, eventSize);
                            call dynamic_array(afterDist, eventSize);
                            minDist=.;
                            do i=1 to candiSize;
                              event=candiList[i];
                              weightList[i]=.;
                              distList[i]=.; 
                              do j=1 to eventSize;
                                beforeDist[j]=.;
                                afterDist[j]=.;
                              end;
                              dCount=0;
                              beforeDistMean=.;
                              afterDistMean=.;
                              do j=1 to eventSize;
                                if tmp[j,1] eq event then do;
                                  do k=1 to periodCount;
                                    s=periodStart[k];
                                    e=periodEnd[k];
                                    bc = INTCK( interval, timeID[s], tmp[j,2]);
                                    ac = INTCK( interval, tmp[j,2], timeID[e]);
                                    if bc>=-eventDefBufferLen and ac>=-eventDefBufferLen then do;
                                      if weightList[i] ne . then weightList[i]=weightList[i]+tmp[j,3];
                                      else weightList[i]=weightList[i];
                                      dCount=dCount+1;
                                      beforeDist[dCount]=bc;
                                      afterDist[dCount]=ac;
                                      if beforeDistMean ne . then beforeDistMean=beforeDistMean+beforeDist[dCount];
                                      else beforeDistMean=beforeDist[dCount];
                                      if afterDistMean ne . then afterDistMean=afterDistMean+afterDist[dCount];
                                      else afterDistMean=afterDist[dCount];
                                    end;
                                  end;
                                end;
                              end;
                              if weightList[i] ne . then do; 
                                weightList[i]=weightList[i]/dCount;
                                if maxWeight eq . then maxWeight=weightList[i];
                                else do;
                                  if weightList[i]>maxWeight then maxWeight=weightList[i];
                                end;
                              end; 
                              if dCount>0 then do;
                                beforeDistMean=beforeDistMean/dCount;
                                afterDistMean=afterDistMean/dCount;
                                distList[i]=0;
                                do j=1 to dCount;
                                  distList[i]=distList[i]+(beforeDist[j]-beforeDistMean)**2+(afterDist[j]-afterDistMean)**2;
                                end;
                                distList[i]=sqrt (distList[i] / (dCount-1));
                              end;                            
                            end;/*do i=1 to candiSize;*/
                            
                            
                            array candiList2[1] / nosymbols;
                            call dynamic_array(candiList2, candiSize);
                            candiSize2=0;
                            if maxWeight ne . then do;
                              do i=1 to candiSize;
                                if weightList[i] eq maxWeight then do;
                                  candiSize2=candiSize2+1;
                                  candiList2[candiSize2]=candiList[i];
                                  if minDist eq . then minDist=distList[i];
                                  else if distList[i]<minDist then minDist=distList[i];
                                end;
                              end;
                            end;
                            else do;
                              candiSize2=candiSize;
                              do i=1 to candiSize;
                                candiList2[i]=candiList[i];
                                if minDist eq . then minDist=distList[i];
                                else if distList[i]<minDist then minDist=distList[i];
                              end;
                            end;
                            
                            /*more than one candidate, break the tie*/
                            if candiSize2 eq 1 then eventIdx=candiList2[1];
                            else if candiSize2 > 1 then do;
                              if minDist ne . then do;
                                array candiList3[1] / nosymbols;
                                call dynamic_array(candiList3, candiSize2);
                                candiSize3=0;
                                do i=1 to candiSize2;
                                  if distList[i] eq minDist then do;
                                    candiSize3=candiSize3+1;
                                    candiList3[candiSize3]=candiList2[i];
                                  end;
                                end; 
                                eventIdx=candiList3[1];
                              end;
                              else do;
                                eventIdx=candiList2[1];
                              end;                             
                            end;
                
                          end;/*else if candiSize > 1 then do;*/
                          rc=0;
                          
                        end;/*if periodCount >0 then do;*/
                        else rc=4;/*else for if periodCount >0 then do;*/
                      end;/*if temp_rc=0 then do;*/
                      else rc=3;/*if temp_rc=0 then do;*/
                    end;/*else do for 'if demandSize ne dim(timeID) then rc=2;'*/
                  end;/*if eventSize>0 then do;*/
              endsub;
              
          /***********************************************************************************************************
              API:
                          ci_get_event_date(eventFile $, eventSize, eventIdx, eventDate[*], rc);
              Type:
                          Subroutine
              Purpose: 
                          get a list of event dates for a particular eventIdx
              Input:   
                          eventFile         : sas data set that stores the event definition information
                                              the eventFile contains the following columns: event_idx , event_name, year, event_date, weight
                          eventSize         : the number of observations in the data set eventFile
                          eventIdx          : the index for the event           
              Output: 
                          eventDate         : array that stores the event dates for eventIdx
                          eventCount        : number of event occurence
                          rc                : return code : 0: success; 1: error in read_array; 2: others
                          
          ***********************************************************************************************************/
              subroutine ci_get_event_date(eventFile $, eventSize, eventIdx, eventDate[*], eventCount, rc);
                  outargs eventDate, eventCount, rc;
                  
                  rc=2;
                  size= dim(eventDate);
                  do i=1 to size;
                    eventDate[i]=.;
                  end;
                  eventCount=0;
                  array tmp[1,1] / nosymbols;
                  call dynamic_array(tmp, eventSize, 2);
                  do t=1 to eventSize;
                    tmp[t,1]=.; tmp[t,2]=.; 
                  end;
                  rc=1;
                  temp_rc = read_array(eventFile, tmp, 'event_idx' , 'event_date');
                  if temp_rc=0 then do;
                    do t=1 to eventSize;
                      if tmp[t,1] eq eventIdx and tmp[t,2] ne . and eventCount<size then do;
                        eventCount = eventCount+1;
                        eventDate[eventCount]=tmp[t,2];
                      end;
                    end;
                    rc=0;
                  end;

              endsub; 
                        
          /***********************************************************************************************************
              API:
                          ci_compute_event_distance(periodStart[*], periodEnd[*], periodCount, timeID[*], demandSize, 
                                                    eventDate[*], eventCount, interval $, eventDefBufferLen, eventIdx,
                                                    beforeDist[*], afterDist[*], rc);
              Type:
                          Subroutine
              Purpose: 
                          Loop through the period information and event information, identify the event dates and period-event distance
              Input:   
                          periodStart       : array that stores the period start index value
                          periodEnd         : array that stores the period end index value
                          periodCount       : number of valid elements in periodStart and periodEnd
                          timeID            : timeID series (should have the same size as activeDemand)
                          demandSize        : total number of timeID size
                          eventDate         : array that stores the event dates for eventIdx
                          eventCount        : number of event occurence
                          interval          : time interval
                          eventDefBufferLen : a buffer length that defines "within or close to"  
                          eventIdx          : the index for the event           
                          
              Output: 
                          beforeDist        : array that stores the periodStart-event distance
                          afterDist         : array that stores the event-periodEnd distance
                          rc                : return code : 0: success; 1: eventCount=0 or periodCount=0 2: output array size does not match;
                                                            3: others
                          
          ***********************************************************************************************************/
              subroutine ci_compute_event_distance(periodStart[*], periodEnd[*], periodCount, timeID[*], demandSize, 
                                                    eventDate[*], eventCount, interval $, eventDefBufferLen, eventIdx,
                                                    beforeDist[*], afterDist[*], rc);
                  outargs beforeDist, afterDist, rc;

                  rc= 3;
                  do t=1 to dim(beforeDist); beforeDist[t]=.; end;
                  do t=1 to dim(afterDist); afterDist[t]=.; end;
                  rc=1;
                  if eventCount>0 and periodCount>0 then do;
                    rc=2;
                    if dim(beforeDist) eq dim(afterDist) then do;
                      rc=3;
                      count=0;
                      do j=1 to eventCount;
                        do k=1 to periodCount;
                          s=periodStart[k];
                          e=periodEnd[k];
                          bc = INTCK( interval, timeID[s], eventDate[j]);
                          ac = INTCK( interval, eventDate[j], timeID[e]);
                          if bc>=-eventDefBufferLen and ac>=-eventDefBufferLen then do;
                            count=count+1;
                            beforeDist[count]=bc;
                            afterDist[count]=ac;
                          end;
                        end;
                      end;                      
                      rc=0;
                    end;
                  end;
                  
              endsub;
              
             /***********************************************************************************************************
              API:
                          ci_event_compute_next_period_distance(eventDate[*], eventCount, interval $, date, beforeDist);
              Type:
                          function
              Purpose: 
                          Loop through the event list, and compute the distance to the next event
              Input:   
                          eventDate         : array that stores the event dates for eventIdx
                          eventCount        : number of event occurence
                          interval          : time interval
                          date              : the current date
                          beforeDist        : the number of periods each in-season periods starts compared with event date          
                          
              Output: 
                          dist
                          
          ***********************************************************************************************************/
              function ci_event_compute_next_period_distance(eventDate[*], eventCount, interval $, date, beforeDist);
                  dist=.;
                  do i=1 to eventCount;
                    bc = INTCK( interval, date, eventDate[i]);
                    if bc>beforeDist then do;
                      if dist eq . then dist=bc;
                      else if bc<dist then dist=bc;
                    end;
                  end;
                  if dist ne . then dist=dist-beforeDist;
                  return(dist);
              endsub;
              

          /***********************************************************************************************************
              API:
                          ci_run_forecast(demand[*], timeID[*], seriesID[*], interval $, seasonality, lead, sign $,
                                          criterion $, repositoryNm $, diagEstNm $, indataset $, outdataset $, 
                                          forecast[*], fTimeID[*], rc);
              Type:
                          Subroutine
              Purpose: 
                          get forecast for a given data
              Input:   
                          demand            : array that stores the demand series
                          timeID            : timeID series (should have the same size as demand)
                          interval          : time interval 
                          seasonality       : season cycle length
                          lead              : number of periods forecast out
                          sign              : the sign for forecast values, possible values are "MIXED", "NONNEGATIVE", "NONPOSITIVE"
                          criterion         : criterion used to select the forecast model
                          repositoryNm      : name of the modeling repository
                          diagEstNm         : name of the diag estimation results should be written to
                          indataset         : name of the dataset that the series are going to be written and used for forecast call
                          outdataset        : name of the dataset the forecast results should be written out
                          
              Output: 
                          forecast          : array that stores the forecast results 
                          fTimeID           : array that stores the forecast time id
                          rc                : return code : 0: success; 1: input array sizes do not match;  
                                                            2: error in write_array; 3: error in calling macro; 
                                                            4: error in read_array; 5: others
                          
          ***********************************************************************************************************/
              subroutine ci_run_forecast(demand[*], timeID[*], interval $, seasonality, lead, sign $,
                                          criterion $, repositoryNm $, diagEstNm $, indataset $, outdataset $, 
                                          forecast[*], fTimeID[*], rc);
                  outargs forecast, fTimeID, rc;

                  rc= 1;
                  do i=1 to dim(fTimeID);
                    fTimeID[i]=.;
                  end;
                  do i=1 to dim(forecast);
                    forecast[i]=.;
                  end;
                  if dim(demand) eq dim(timeID) then do;
                    size=dim(demand);
                    rc=5;
                    array series[1,2] / nosymbols;
                    call dynamic_array(series, size, 2);
                    do t=1 to size;
                       series[t,1]=timeID[t];
                       series[t,2]=demand[t];
                    end;
                    
                    temp_rc = write_array(indataset, series, 'time_id', 'demand');      
                    rc = 2;
                    if temp_rc=0 then do;
                      rc = 3;
                      temp_rc = run_macro('ci_run_hpf', indataset, outdataset, interval, criterion, repositoryNm, diagEstNm, seasonality, lead);
                      if temp_rc = 0 then do;
                        rc=4;
                        array fcst[1,2] / nosymbols;
                        call dynamic_array(fcst, size+lead,2);
                        temp_rc = read_array(outdataset, fcst, 'time_id', 'predict');
                        if temp_rc = 0 then do;
                          outsize=dim(fTimeID);
                          if outsize>size+lead then outsize=size+lead;
                          do i=1 to outsize;
                            fTimeID[i]=fcst[i, 1];
                          end;
                          outsize=dim(forecast);
                          if outsize>size+lead then outsize=size+lead;
                          do i=1 to outsize;
                            forecast[i]=fcst[i, 2];
                            if forecast[i] ne . then do;
                              if sign eq "NONNEGATIVE" and forecast[i]<0 then forecast[i]=0;
                              if sign eq "NONPOSITIVE" and forecast[i]>0 then forecast[i]=0; 
                            end;
                          end;
                          rc=0;
                        end;
                      end;
                    end; 
                         
                  end;/*if dim(demand) eq dim(timeID) then do;*/

              endsub;   
              
          /***********************************************************************************************************
              API:
                          ci_stretch_squeeze_series(origSeries[*], origPeriodStart[*], origPeriodEnd[*], origPeriodCount, newLen,
                                                   newPeriodStart[*], newPeriodEnd[*], newSeries[*], newCount, rc);
              Type:
                          Subroutine
              Purpose: 
                          generate a new series in which each period defined should be squeezed/stretch to the length of newLen
              Input:   
                          origSeries        : array that stores the original demand series
                          origPeriodStart   : array that stores the period start index values in the original series
                          origPeriodEnd     : array that stores the period end index value in the original series
                          origPeriodCount   : number of valid elements in origPeriodStart and origPeriodEnd
                          newLen            : the new length each original period should squeenze/stretch into
                          
              Output: 
                          newPeriodStart    : array that stores the period start index values in the new series, which matches each origPeriodStart index
                          newPeriodEnd      : array that stores the period end index value in the new series, which matches each origPeriodEnd index
                          newSeries         : array that stores the new series
                          newCount          : size of the new series
                          rc                : return code : 0: success; 1: origPeriodCount=0; 2: newLen<=0
                                                            3: others
                          
          ***********************************************************************************************************/              
              subroutine ci_stretch_squeeze_series(origSeries[*], origPeriodStart[*], origPeriodEnd[*], origPeriodCount, newLen,
                                                   newPeriodStart[*], newPeriodEnd[*], newSeries[*], newCount, rc);
                outargs newPeriodStart, newPeriodEnd, newSeries, newCount, rc;
                
                rc=1;
                newCount=0;
                do i=1 to dim(newPeriodStart); newPeriodStart[i]=.; end;
                do i=1 to dim(newPeriodEnd); newPeriodEnd[i]=.; end;
                do i=1 to dim(newSeries); newSeries[i]=.; end;
                if origPeriodCount>0 then do;
                  rc=2;
                  if newLen>=1 then do;
                    rc=3;
                    size=dim(origSeries);
                    lastIndex=0;
                    
                    do i=1 to origPeriodCount;
                      if origPeriodStart[i]>lastIndex+1 then do;
                        do j=lastIndex+1 to origPeriodStart[i]-1;
                          newCount = newCount+1;
                          newSeries[newCount]=origSeries[j];
                        end;
                        lastIndex = origPeriodStart[i]-1;
                      end;                  
                      
                      origLen = origPeriodEnd[i]-origPeriodStart[i]+1;
                      newPeriodStart[i]=newCount+1;
  
                      if origLen eq newLen then do;
                        do j=origPeriodStart[i] to origPeriodEnd[i];
                          newCount = newCount+1;
                          newSeries[newCount]=origSeries[j];
                        end;                      
                      end;
                      else if origLen eq 1 then do;
                        k = origPeriodStart[i];
                        do j=1 to newLen;
                          newCount = newCount+1;
                          newSeries[newCount]=origSeries[k];
                        end;
                      end;
                      else do;
                        do j=1 to newLen;
                          newCount = newCount+1;
                          if newLen eq 1 then pos=(origPeriodStart[i] +origPeriodEnd[i])/2;
                          else pos=origPeriodStart[i] +(j-1)*(origLen-1)/(newLen-1);
                          k=floor(pos);
                          if pos eq k then newSeries[newCount]=origSeries[k];
                          else do;
                            if origSeries[k] ne . and origSeries[k+1] ne . then 
                              newSeries[newCount]=(k+1-pos)*origSeries[k]+(pos-k)*origSeries[k+1];
                            else newSeries[newCount]=.;
                          end;
                        end;
                      end;
                      lastIndex = origPeriodEnd[i];
                      newPeriodEnd[i]=newCount;
                    end;/*do i=1 to origPeriodCount;*/
                    
                    if lastIndex lt size then do;
                      do i=lastIndex+1 to size;
                        newCount = newCount+1;
                        newSeries[newCount]=origSeries[i];
                      end;
                    end;
                    rc=0;
                  end;/*if newLen>=1 then do;*/
                end;/*if origPeriodCount>0 then do;*/
             endsub;

              
          /***********************************************************************************************************
              API:
                          ci_recover_stretch_squeeze_series(newPeriodStart[*], newPeriodEnd[*], newSeries[*], newCount,newLen,
                                                            origPeriodStart[*], origPeriodEnd[*], origPeriodCount
                                                            origSeries[*], origCount, rc);
              Type:
                          Subroutine
              Purpose: 
                          recover the original series stretch or squeezed by ci_stretch_squeeze_series
              Input:   
                          newPeriodStart    : array that stores the period start index values in the new series, which matches each origPeriodStart index
                          newPeriodEnd      : array that stores the period end index value in the new series, which matches each origPeriodEnd index
                          newSeries         : array that stores the new series
                          newCount          : size of the new series
                          newLen            : the new length each original period should squeenze/stretch into
                          origPeriodStart   : array that stores the period start index values in the original series
                          origPeriodEnd     : array that stores the period end index value in the original series
                          origPeriodCount   : number of valid elements in origPeriodStart and origPeriodEnd
                          
              Output: 
                          origSeries        : array that stores the original demand series
                          origCount         : size of the original series
                          rc                : return code : 0: success; 1: origPeriodCount=0; 2: newLen<=0
                                                            3: others
                          
          ***********************************************************************************************************/              
              subroutine ci_recover_stretch_squeeze_series(newPeriodStart[*], newPeriodEnd[*], newSeries[*], newCount,newLen,
                                                            origPeriodStart[*], origPeriodEnd[*], origPeriodCount,
                                                            origSeries[*], origCount, rc);
                outargs origSeries, origCount, rc;
                
                rc=1;
                origCount=0;
                do i=1 to dim(origSeries); origSeries[i]=.; end;
                if origPeriodCount>0 then do;
                  rc=2;
                  if newLen>=1 then do;
                    rc=3;
                    
                    lastIndex=0;
                    do i=1 to origPeriodCount;
                      if newPeriodStart[i]>lastIndex+1 then do;
                        do j=lastIndex+1 to newPeriodStart[i]-1;
                          origCount = origCount+1;
                          origSeries[origCount]=newSeries[j];
                        end;
                        lastIndex = newPeriodStart[i]-1;
                      end;                  
                      
                      origLen = origPeriodEnd[i]-origPeriodStart[i]+1;
  
                      if origLen eq newLen then do;
                        do j=newPeriodStart[i] to newPeriodEnd[i];
                          origCount = origCount+1;
                          origSeries[origCount]=newSeries[j];
                        end;                      
                      end;
                      else if newLen eq 1 then do;
                        k = newPeriodStart[i];
                        do j=1 to origLen;
                          origCount = origCount+1;
                          origSeries[origCount]=newSeries[k];
                        end;
                      end;
                      else do;
                        do j=1 to origLen;
                          origCount = origCount+1;
                          if origLen eq 1 then pos=(newPeriodStart[i] +newPeriodEnd[i])/2;
                          else pos=newPeriodStart[i] +(j-1)*(newLen-1)/(origLen-1);
                          k=floor(pos);
                          if pos eq k then origSeries[origCount]=newSeries[k];
                          else do;
                            if newSeries[k] ne . and newSeries[k+1] ne . then
                              origSeries[origCount]=(k+1-pos)*newSeries[k]+(pos-k)*newSeries[k+1];
                            else origSeries[origCount]=.;
                          end;
                        end;
                      end;
                      lastIndex = newPeriodEnd[i];
                    end;/*do i=1 to origPeriodCount;*/
                    
                    if lastIndex lt newCount then do;
                      do i=lastIndex+1 to newCount;
                        origCount = origCount+1;
                        origSeries[origCount]=newSeries[i];
                      end;
                    end;
                    rc=0;
                  end;/*if newLen>=1 then do;*/
                end;/*if origPeriodCount>0 then do;*/
             endsub;

              
          /***********************************************************************************************************
              API:
                          ci_run_forecast2(demand[*], seasonality, lead, sign $, forecast[*]);
              Type:
                          Subroutine
              Purpose: 
                          get a average forecast for a given series
              Input:   
                          demand            : array that stores the demand series
                          seasonality       : season cycle length
                          lead              : number of periods forecast out
                          sign              : the sign for forecast values, possible values are "MIXED", "NONNEGATIVE", "NONPOSITIVE"
                          
              Output: 
                          forecast          : array that stores the forecast results 
                          
          ***********************************************************************************************************/
              subroutine ci_run_forecast2(demand[*], seasonality, lead, sign $, forecast[*]);
                  outargs forecast;
                  
                  do i=1 to dim(forecast);
                    forecast[i]=.;
                  end;
                  size=dim(demand);
                  trailMissLen=ci_compute_trail_missing_length(demand, size);
                  if trailMissLen>0 then size=size-trailMissLen;
                  array avg[1,1] / nosymbols;
                  call dynamic_array(avg, seasonality, 2);
                  do j=1 to seasonality;
                    avg[j,1]=.;
                    avg[j,2]=0;
                  end;
                  do i=1 to size;
                    if demand[i] ne . then do;
                      j= mod(i,seasonality);
                      if j eq 0 then j=seasonality;
                      if avg[j,1] ne . then avg[j,1]=avg[j,1]+demand[i];
                      else avg[j,1]=demand[i];
                      avg[j,2]=avg[j,2]+1;
                    end;
                  end;
                  do j=1 to seasonality;
                    if avg[j,2] ne 0 then avg[j,1]=avg[j,1]/avg[j,2];
                  end;
                  outsize=dim(forecast);
                  if outsize>size+lead then outsize=size+lead;
                  cycCount=ceil(outsize/seasonality);
                  array cycTot[1,2] / nosymbols;
                  call dynamic_array(cycTot, cycCount,2);
                  do i=1 to cycCount;
                    cycTot[i,1]=0;
                    cycTot[i,2]=0;
                  end;
                  do i=1 to size;
                    j= mod(i,seasonality);
                    if j eq 0 then j=seasonality;
                    k=ceil(i/seasonality);
                    if demand[i] ne . then do;
                      cycTot[k,1]=cycTot[k,1]+abs(demand[i]);
                      cycTot[k,2]=cycTot[k,2]+abs(avg[j,1]);
                    end;
                  end;
                  do i=1 to outsize;
                    j= mod(i,seasonality);
                    if j eq 0 then j=seasonality;
                    k=ceil(i/seasonality);
                    if cycTot[k,1] ne 0 and cycTot[k,2] ne 0 then
                      forecast[i]=avg[j,1]*cycTot[k,1]/cycTot[k,2];
                    else forecast[i]=avg[j,1];
                    if forecast[i] ne . then do;
                      if sign eq "NONNEGATIVE" and forecast[i]<0 then forecast[i]=0;
                      if sign eq "NONPOSITIVE" and forecast[i]>0 then forecast[i]=0; 
                    end;
                  end;
                  

              endsub;                 
              
          /***********************************************************************************************************
              API:
                          ci_compute_forecast_measure(demand[*], forecast[*], size, measure $, score, count);
              Type:
                          Subroutine
              Purpose: 
                          get a average forecast for a given series
              Input:   
                          demand            : array that stores the demand series
                          forecast          : array that stores the forecast results 
                          size              : the size of the arrays that will be taken into consideration
                          measure           : name of the measurement, could be "MAPE", "MAE", "MSE" 
              Output: 
                          score             : the measurement score
                          count             : the number of observations used to scoring the results
                          
          ***********************************************************************************************************/
              subroutine ci_compute_forecast_measure(demand[*], forecast[*], size, measure $, score, count);
                  outargs score, count;
                  
                  score=.;
                  count=0;
                  msize = size;
                  if dim(demand)<msize then msize=dim(demand);
                  if dim(forecast)<msize then msize=dim(forecast);
                  array avg[1] / nosymbols;
                  call dynamic_array(avg, msize);
                  do i=1 to msize;
                    avg[i]=.;
                  end;
                  do i=1 to msize;
                    if demand[i] ne . and forecast[i] ne . then do;
                      count=count+1;
                      if measure="MAPE" then do;
                        if demand[i] ne 0 then avg[count]=abs((demand[i]-forecast[i])/demand[i]);
                        else if forecast[i] ne 0 then avg[count]=abs((demand[i]-forecast[i])/forecast[i]);
                        else avg[count]=0;
                      end;
                      else if measure="MAE" then avg[count]=abs(demand[i]-forecast[i]);
                      else if measure="MSE" then avg[count]=(demand[i]-forecast[i])**2;
                    end;
                  end;
                  if count>0 then do;
                    score=0;
                    do i=1 to msize;
                      if avg[i] ne . then score=score+avg[i];
                    end;
                    score=score/count;
                  end;

              endsub;                
          /***********************************************************************************************************
              API:
                          ci_find_event_series_seasons(timeID[*], eventDate[*], eventCount, interval $, beforeDist, afterDist, 
                                                       seasonCode[*], inSeasonLen, rc);
              Type:
                          Subroutine
              Purpose: 
                          Generate season code for a particular event series on a given beforeDist and afterDist
              Input:   
                          timeID            : timeID series (should have the same size as activeDemand)
                          eventDate         : array that stores the event dates for eventIdx
                          eventCount        : number of event occurence
                          interval          : time interval
                          beforeDist        : a number indicates the distance between in-season start period and event date period
                          afterDist         : a number indicates the distance between event date period and in-season end period    
                          
              Output: 
                          seasonCode        : array that stores the season code for each observation in the demand series
                          inSeasonLen       : in-season period length
                          rc                : return code : 0: success; 1: eventCount=0; 2: others
                          
          ***********************************************************************************************************/
              subroutine ci_find_event_series_seasons(timeID[*], eventDate[*], eventCount, interval $, beforeDist, afterDist, 
                                                      seasonCode[*], inSeasonLen, rc);
                  outargs seasonCode, inSeasonLen, rc;

                  rc= 2;
                  inSeasonLen=0;
                  do t=1 to dim(seasonCode); seasonCode[t]=.; end;
                  rc=1;
                  if eventCount>0 then do;
                    rc=2;
                    count=0;
                    do t=1 to dim(timeID);
                      found=0;
                      do j=1 to eventCount;
                        bc = INTCK( interval, timeID[t], eventDate[j]);
                        ac = INTCK( interval, eventDate[j], timeID[t]);
                        if bc<=beforeDist and ac<=afterDist then do;
                          found=1;
                          seasonCode[t]=beforeDist-bc+1;
                          if seasonCode[t]>inSeasonLen then inSeasonLen=seasonCode[t];
                        end;
                      end;
                      if found=0 then seasonCode[t]=0;
                    end;             
                    rc=0;
                  end;
                  
              endsub;              

          /***********************************************************************************************************
              API:
                          ci_find_off_periods_by_code(seasonCode[*], firstPartialFlag, lastPartialFlag,
                                                      offStart[*], offEnd[*], offCount);
              Type:
                          Subroutine
              Purpose: 
                          Find the off season periods based on season code
              Input:   
                          seasonCode        : array that stores the season code for each observation in the demand series
                          firstPartialFlag  : 0/1 flag indicating if the first period is included or not if the first period is partial
                          lastPartialFlag   : 0/1 flag indicating if the last period is included or not if the last period is partial
                          
              Output: 
                          offStart          : array that stores the off season period start index value
                          offEnd            : array that stores the off season period end index value
                          offCount          : number of valid elements in offStart and offEnd
                          
          ***********************************************************************************************************/
              subroutine ci_find_off_periods_by_code(seasonCode[*], firstPartialFlag, lastPartialFlag,
                                                      offStart[*], offEnd[*], offCount);
                  outargs offStart, offEnd, offCount;

                  offCount=0;
                  do t=1 to dim(offStart); offStart[t]=.; end;
                  do t=1 to dim(offEnd); offEnd[t]=.; end;
                  msize=dim(seasonCode);
                  do t=1 to dim(seasonCode);
                    if seasonCode[t] eq . and t<=msize then msize=t-1;
                  end;
                  
                  do t=1 to msize;
                    if seasonCode[t] eq 0 then do;
                      if t eq 1 then do;
                        if firstPartialFlag eq 1 then do;
                          offCount=offCount+1;
                          offStart[offCount]=1;
                        end;
                      end;
                      else if seasonCode[t-1] ne 0 then do;
                        offCount=offCount+1;
                        offStart[offCount]=t;
                      end;
                      if offCount>0 then do;
                        if t eq msize then offEnd[offCount]=t;
                        else if seasonCode[t+1] ne 0 then offEnd[offCount]=t;
                      end;
                    end;
                  end;
                  if offCount>0 then do;
                    if offEnd[offCount] ne . and offEnd[offCount] eq msize and lastPartialFlag eq 0 then do;
                      offStart[offCount]=.;
                      offEnd[offCount]=.;
                      offCount=offCount-1;
                    end;
                  end;

              endsub;

          /***********************************************************************************************************
              API:
                          ci_find_inseason_periods_by_code(seasonCode[*], firstPartialFlag, lastPartialFlag,
                                                           periodStart[*], periodEnd[*], periodCount);
              Type:
                          Subroutine
              Purpose: 
                          Find the in season periods based on season code
              Input:   
                          seasonCode        : array that stores the season code for each observation in the demand series
                          firstPartialFlag  : 0/1 flag indicating if the first period is included or not if the first period is partial
                          lastPartialFlag   : 0/1 flag indicating if the last period is included or not if the last period is partial
                          
              Output: 
                          periodStart       : array that stores the in season period start index value
                          periodEnd         : array that stores the in season period end index value
                          periodCount       : number of valid elements in periodStart and periodEnd
                          
          ***********************************************************************************************************/
              subroutine ci_find_inseason_periods_by_code(seasonCode[*], firstPartialFlag, lastPartialFlag,
                                                          periodStart[*], periodEnd[*], periodCount);
                  outargs periodStart, periodEnd, periodCount;

                  periodCount=0;
                  do t=1 to dim(periodStart); periodStart[t]=.; end;
                  do t=1 to dim(periodEnd); periodEnd[t]=.; end;
                  msize=dim(seasonCode);
                  do t=1 to dim(seasonCode);
                    if seasonCode[t] eq . and t<=msize then msize=t-1;
                  end;
                  
                  if seasonCode[1] >1 and firstPartialFlag=1 then do;
                    periodCount=periodCount+1;
                    periodStart[periodCount]=1;
                  end;
                  do t=1 to msize;
                    if seasonCode[t] eq 1 then do;
                      periodCount=periodCount+1;
                      periodStart[periodCount]=t;
                    end;
                    if t<msize then do;
                      if seasonCode[t] ne 0 and seasonCode[t+1] <=1 then do;
                        periodEnd[periodCount]=t;
                      end;
                    end;
                    else if seasonCode[t] >1 then periodEnd[periodCount]=t;
                  end;
                  if periodCount>0 and periodEnd[periodCount]=msize and lastPartialFlag eq 0 then do;
                    call ci_compute_order_stats(seasonCode, min, median, max);
                    if seasonCode[msize]<max then do;
                      periodStart[periodCount]=.;
                      periodEnd[periodCount]=.;
                      periodCount=periodCount-1;
                    end;
                  end;

              endsub;

                                   
          /***********************************************************************************************************
              API:
                          ci_find_off_periods_length(offStart[*], offEnd[*], offCount, offSeasonRule $, totObs);
              Type:
                          function
              Purpose: 
                          Find the expected off periods length based on period information and rule
              Input:   
                          offStart          : array that stores the off season period start index value
                          offEnd            : array that stores the off season period end index value
                          offCount          : number of valid elements in offStart and offEnd
                          offSeasonRule     : rule used to find off season length, possible values are MIN, MAX, MEAN, MODE, MEDIAN, LAST
                          totObs            : total number of observations in the demand series
              Output: 
                          newLen
                          
          ***********************************************************************************************************/
              function ci_find_off_periods_length(offStart[*], offEnd[*], offCount, offSeasonRule $, totObs);

                  newLen=0;
                  if offCount>0 then do;
                    array offRange[1]/NOSYMBOLS; 
                    call dynamic_array(offRange, offCount); 
                    
                    do k=1 to offCount;
                      if offEnd[k]<=totObs then offRange[k]=offEnd[k]-offStart[k]+1;
                      else offRange[k]=.;
                    end;
                    call ci_compute_basic_freq(offRange, _OFF_RANGE_COUNT, _OFF_RANGE_MIN, _OFF_RANGE_MEDIAN, _OFF_RANGE_MAX,
                                               _OFF_RANGE_MEAN, _OFF_RANGE_MODE);
                    if _OFF_RANGE_COUNT>0 then do;
                      if offSeasonRule eq "MIN" then newLen=_OFF_RANGE_MIN;
                      else if offSeasonRule eq "MAX" then newLen=_OFF_RANGE_MAX;
                      else if offSeasonRule eq "MEAN" then newLen=ceil(_OFF_RANGE_MEAN);
                      else if offSeasonRule eq "MODE" then newLen=_OFF_RANGE_MODE;
                      else if offSeasonRule eq "MED" then newLen=ceil(_OFF_RANGE_MEDIAN);
                      else do;
                        if offEnd[_OFF_RANGE_COUNT]>=totObs and _OFF_RANGE_COUNT>2 then newLen=offEnd[_OFF_RANGE_COUNT-1]-offStart[_OFF_RANGE_COUNT-1]+1;
                        else newLen=offEnd[_OFF_RANGE_COUNT]-offStart[_OFF_RANGE_COUNT]+1;
                      end;
                    end;
                  end;
                  return(newLen);
              endsub;


              
          /***********************************************************************************************************
              API:
                          ci_split_series_by_period(origSeries[*],  totObs, PeriodStart[*], PeriodEnd[*], periodCount,
                                                     _inSeries[*], _offSeries[*], inIndex, offIndex);
              Type:
                          Subroutine
              Purpose: 
                          Find the off periods based on season code
              Input:   
                          origSeries        : array that stores the original series
                          totObs            : total number of observations
                          PeriodStart       : array that stores the off season period start index value
                          PeriodEnd         : array that stores the off season period end index value
                          periodCount       : number of valid elements in PeriodStart and PeriodEnd
                          
              Output: 
                          _inSeries         : array that stores the in season series
                          _offSeries        : array that stores the off season series
                          inIndex           : number of observations in _inSeries
                          offIndex          : number of observations in _offSeries
                          
          ***********************************************************************************************************/
              subroutine ci_split_series_by_period(origSeries[*], totObs, PeriodStart[*], PeriodEnd[*], periodCount,
                                                     _inSeries[*], _offSeries[*], inIndex, offIndex);
                  outargs _inSeries, _offSeries, inIndex, offIndex;

                  offIndex=0; inIndex=0;
                  if PeriodStart[1]>1 then do;
                    do j=1 to PeriodStart[1]-1;
                      if j<=totObs then do;
                        inIndex=inIndex+1;
                        _inSeries[inIndex]=origSeries[j];
                      end;
                    end;
                  end;
                  do i=1 to periodCount;
                    do j=PeriodStart[i] to PeriodEnd[i];
                      if j<=totObs then do;
                        offIndex=offIndex+1;
                        _offSeries[offIndex]=origSeries[j];
                      end;
                    end;
                    
                    if i<periodCount then endIndex=PeriodStart[i+1]-1;
                    else endIndex=totObs;
                    if PeriodEnd[i]<endIndex then do;
                      do j=PeriodEnd[i]+1 to endIndex;
                        if j<=totObs then do;
                          inIndex=inIndex+1;
                          _inSeries[inIndex]=origSeries[j];
                        end;
                      end;
                    end;
                  end;

              endsub;     
              
          /***********************************************************************************************************
              API:
                          ci_combine_two_series_by_period(inSeries[*], offSeries[*], totObs, PeriodStart[*], PeriodEnd[*], periodCount,
                                                          _combSeries[*], inIndex, offIndex, combIndex);
              Type:
                          Subroutine
              Purpose: 
                          Combine the in-season series and off season series togetheer
              Input:   
                         
                          inSeries          : array that stores the in season series
                          offSeries         : array that stores the off season series
                          totObs            : total number of observations
                          PeriodStart       : array that stores the off season period start index value
                          PeriodEnd         : array that stores the off season period end index value
                          periodCount       : number of valid elements in PeriodStart and PeriodEnd
                          
              Output: 
                          _combSeries       : array that stores the combined series
                          inIndex           : number of observations found in inSeries
                          offIndex          : number of observations found in offSeries
                          combIndex         : number of observations in the combined series
                          
          ***********************************************************************************************************/
              subroutine ci_combine_two_series_by_period(inSeries[*], offSeries[*], totObs, PeriodStart[*], PeriodEnd[*], periodCount,
                                                         _combSeries[*], inIndex, offIndex, combIndex);
                  outargs _combSeries, inIndex, offIndex, combIndex;

                  combIndex=0;inIndex=0; offIndex=0;
                  if PeriodStart[1]>1 then do;
                    do j=1 to PeriodStart[1]-1;
                      combIndex=combIndex+1;
                      inIndex=inIndex+1;
                      _combSeries[combIndex]=inSeries[inIndex];
                    end;
                  end;
                  do i=1 to periodCount;
                    do j=PeriodStart[i] to PeriodEnd[i];
                      combIndex=combIndex+1;
                      offIndex=offIndex+1;
                      _combSeries[combIndex]=offSeries[offIndex];
                    end;
                    
                    if i<periodCount then endIndex=PeriodStart[i+1]-1;
                    else endIndex=totObs;
                    if PeriodEnd[i]<endIndex then do;
                      do j=PeriodEnd[i]+1 to endIndex;
                        combIndex=combIndex+1;
                        inIndex=inIndex+1;
                        _combSeries[combIndex]=inSeries[inIndex];
                      end;
                    end;
                  end; /*do i=1 to periodCount;*/

              endsub;              
              
          /***********************************************************************************************************
              API:
                          ci_combine_series_season(demand[*], seasonCode[*], accumulate $, comb[*], combCount[*], size, rc);
              Type:
                          Subroutine
              Purpose: 
                          Combine the series based on season code
              Input:   
                          demand            : array that stores the demand series
                          seasonCode        : array that stores the season code for each observation in the demand series
                          accumulate        : off season period accumulate method, could be TOTAL, AVG, MAX, MED, MIN, FIRST, LAST, MODE
                          
              Output: 
                          comb              : array that stores combined series results
                          combCount         : array that stores the number of observations corresponding to each element in the combined series
                          size              : valid size of the combined series length
                          rc                : return code : 0: success; 1: invalid accumulate; 2: others
                          
          ***********************************************************************************************************/
              subroutine ci_combine_series_season(demand[*], seasonCode[*], accumulate $, comb[*], combCount[*], size, rc);
                  outargs comb, combCount, size, rc;

                  rc= 2;
                  size=0;
                  do t=1 to dim(comb); comb[t]=.; end;
                  do t=1 to dim(combCount); combCount[t]=.; end;
                  
                  msize=dim(demand);
                  do t=1 to dim(demand);
                    if seasonCode[t] eq . and t<=msize then msize=t-1;
                  end;
                  
                  array tmp[1] / nosymbols;
                  array offStart[1] / nosymbols;
                  array offEnd[1] / nosymbols;
                  call dynamic_array(tmp,msize);
                  call dynamic_array(offStart,msize);
                  call dynamic_array(offEnd,msize);
                  call ci_find_off_periods_by_code(seasonCode, 1, 1, offStart, offEnd, offCount);

                  if offCount>0 then do;
                    array eva[1] / nosymbols;
                    call dynamic_array(eva,offCount);
                    
                    do i=1 to offCount;
                      s=offStart[i];
                      ec=offEnd[i]-offStart[i]+1;
                      array off[1] / nosymbols;
                      call dynamic_array(off,ec);
                      do j=1 to msize;
                        off[j]=.;
                      end;
                      missFlag=0;
                      do j=1 to ec;
                        off[j]=demand[s+j-1];
                        if off[j] eq . then missFlag=1;
                      end;
                      eva[i]=.;
                      value=.;
                      if missFlag ne 1 then do;
                        if accumulate eq "TOTAL" then call ci_compute_sum(off, value, count);
                        else if accumulate eq "AVG" then call ci_compute_mean(off, value, count);
                        else if accumulate eq "MIN" then call ci_compute_order_stats(off, value, median, max);
                        else if accumulate eq "MED" then call ci_compute_order_stats(off, min, value, max);
                        else if accumulate eq "MAX" then call ci_compute_order_stats(off, min, median, value);
                        else if accumulate eq "FIRST" then value=off[1];
                        else if accumulate eq "LAST" then value=off[ec];
                        else if accumulate eq "MODE" then call ci_compute_basic_freq(off, count, min, median, max, mean, value);
                        else rc=1;
                        if rc ne 1 then eva[i]=value;
                      end;
                    end;
                                           
                    if rc ne 1 then do;
                      rc=3;
                      if offStart[1]>1 then do;
                        do i=1 to offStart[1]-1;
                          size=size+1;
                          comb[size]=demand[i];
                          combCount[size]=1;
                        end;
                      end;
                      do i=1 to offCount;
                        size=size+1;
                        comb[size]=eva[i];
                        combCount[size]=offEnd[i]-offStart[i]+1;
                        if i<offCount then do;
                          do t=offEnd[i]+1 to offStart[i+1]-1;
                            size=size+1;
                            comb[size]=demand[t];
                            combCount[size]=1;
                          end;
                        end;
                      end;
                      if offEnd[offCount]<msize then do;
                        do i=offEnd[offCount]+1 to msize;
                          size=size+1;
                          comb[size]=demand[i];
                          combCount[size]=1;
                        end;
                      end;                      
                      rc=0;
                    end;

                  end;  /*if offCount>0 then do;*/
                  else do;
                    do t=1 to msize;
                      comb[t]=demand[t];
                      combCount[t]=1;
                    end;
                    size=msize;
                  end;                                
                  rc=0;

                  
              endsub;  
              
          /***********************************************************************************************************
              API:
                          ci_compute_profile(demand[*], PeriodStart[*], PeriodEnd[*], periodCount, newLen, profile[*]);
              Type:
                          Subroutine
              Purpose: 
                          generate a profile for periods adjusted to the newLen
              Input:   
                         
                          demand            : array that stores the demand series
                          PeriodStart       : array that stores the off season period start index value
                          PeriodEnd         : array that stores the off season period end index value
                          periodCount       : number of valid elements in PeriodStart and PeriodEnd
                          newLen            : the profile length
                          
              Output: 
                          profile           : array that stores the profile

                          
          ***********************************************************************************************************/
              subroutine ci_compute_profile(demand[*], PeriodStart[*], PeriodEnd[*], periodCount, newLen, profile[*]);
                  outargs profile;

                  do i=1 to dim(profile); profile[i]=.; end;
                  array newSeries[1] / nosymbols; call dynamic_array(newSeries, newLen);
                  array profileCount[1] / nosymbols; call dynamic_array(profileCount, newLen);
                  do i=1 to newLen; profileCount[i]=0; end;
                  if periodCount>0 then do;
                    do i=1 to periodCount;
                      origLen=PeriodEnd[i]-PeriodStart[i]+1;
                      if origLen ne newLen then do;
                        do j=1 to newLen;
                          newSeries[j]=.;
                          if newLen eq 1 then pos=(PeriodStart[i] +PeriodEnd[i])/2;
                          else pos=PeriodStart[i] +(j-1)*(origLen-1)/(newLen-1);
                          k=floor(pos);
                          if pos eq k then newSeries[j]=demand[k];
                          else newSeries[j]=(k+1-pos)*demand[k]+(pos-k)*demand[k+1];
                        end;
                      end;
                      else do;
                        do j=1 to newLen;
                          k=PeriodStart[i]+j-1;
                          newSeries[j]=demand[k];
                        end;
                      end;
                      do j=1 to newLen;
                        if newSeries[j] ne . then do;
                          profileCount[j]=profileCount[j]+1;
                          if profile[j] ne . then profile[j]=profile[j]+newSeries[j];
                          else profile[j]=newSeries[j];
                        end;
                      end;
                    end;/*do i=1 to periodCount;*/
                    do j=1 to newLen;
                      if profileCount[j]>0 then profile[j]=profile[j]/profileCount[j];
                      else profile[j]=0;
                    end;
                  end;/*if periodCount>0 then do;*/
              endsub;                   

          /***********************************************************************************************************
              API:
                          ci_recover_combine_series(comb[*], combCount[*], combSize, accumulate $, profile[*],
                                                    orig[*], origSize, rc);
              Type:
                          Subroutine
              Purpose: 
                          Recover the combined series back
              Input:   
                          comb              : array that stores combined series results
                          combCount         : array that stores the number of observations corresponding to each element in the combined series
                          combSize          : valid size of the combined series length
                          accumulate        : off season period accumulate method, could be TOTAL, AVG, MAX, MED, MIN, FIRST, LAST, MODE
                          profile           : profile for off season periods
                          
              Output: 
                          orig              : recovered original series
                          origSize          : valid size of the recovered original series
                          rc                : return code : 0: success; 1: input array size not right; 2: invalid accumulate; 3: others
                          
          ***********************************************************************************************************/
              subroutine ci_recover_combine_series(comb[*], combCount[*], combSize, accumulate $, profile[*],
                                                   orig[*], origSize, rc);
                  outargs orig, origSize, rc;
                  do i=1 to dim(orig); orig[i]=.; end;
                  origSize=0;
                  pLen=dim(profile);
                  rc=1;
                  if pLen>0 and combSize>0 then do;
                    rc=3;
                    do i=1 to combSize;
                      if combCount[i]=1 then do;
                        origSize=origSize+1;
                        orig[origSize]=comb[i];
                      end;
                      else do;
                        array newSeries[1] / nosymbols; call dynamic_array(newSeries, combCount[i]);
                        total=0;
                        do j=1 to combCount[i];
                          newSeries[j]=.;
                          pos=1 +(j-1)*(pLen-1)/(combCount[i]-1);
                          k=floor(pos);
                          if pos eq k then newSeries[j]=profile[k];
                          else newSeries[j]=(k+1-pos)*profile[k]+(pos-k)*profile[k+1];
                          total=total+newSeries[j];
                        end;
                        if total=0 then do;
                          do j=1 to combCount[i];
                            newSeries[j]=1/combCount[i];
                          end;
                          total=combCount[i];
                        end;
                        call ci_compute_basic_freq(newSeries, count, min, median, max, mean, mode);
                        if accumulate = "TOTAL" then do;
                          do j=1 to combCount[i];
                            origSize=origSize+1;
                            orig[origSize]=comb[i]*newSeries[j]/total;
                          end;
                        end;
                        else if accumulate = "AVG" then do;
                          do j=1 to combCount[i];
                            origSize=origSize+1;
                            orig[origSize]=comb[i]+(newSeries[j]-mean);
                          end;                        
                        end;
                        else if accumulate = "MAX" then do;
                          do j=1 to combCount[i];
                            origSize=origSize+1;
                            orig[origSize]=comb[i]+(newSeries[j]-max);
                          end;                        
                        end;
                        else if accumulate = "MED" then do;
                          do j=1 to combCount[i];
                            origSize=origSize+1;
                            orig[origSize]=comb[i]+(newSeries[j]-median);
                          end;                        
                        end;
                        else if accumulate = "MIN" then do;
                          do j=1 to combCount[i];
                            origSize=origSize+1;
                            orig[origSize]=comb[i]+(newSeries[j]-min);
                          end;                        
                        end;
                        else if accumulate = "FIRST" then do;
                          do j=1 to combCount[i];
                            origSize=origSize+1;
                            orig[origSize]=comb[i]+(newSeries[j]-newSeries[1]);
                          end;                        
                        end;
                        else if accumulate = "LAST" then do;
                          k=combCount[i];
                          do j=1 to combCount[i];
                            origSize=origSize+1;
                            orig[origSize]=comb[i]+(newSeries[j]-newSeries[k]);
                          end;                        
                        end;
                        else if accumulate = "MODE" then do;
                          do j=1 to combCount[i];
                            origSize=origSize+1;
                            orig[origSize]=comb[i]+(newSeries[j]-mode);
                          end;                        
                        end;
                        else do;
                          rc=2;
                        end;
                        if rc ne 2 then rc=0;
                      end;/*else do for if combCount[i]=1 then do;*/
                    end;/*do i=1 to combSize;*/
                  end;/*if pLen>0 and combSize>0 then do;*/
              endsub;

          /***********************************************************************************************************
              API:
                          ci_find_season_series_seasons(periodStart[*], periodEnd[*], periodCount, totObs, inSeasonLen, ssIndex,
                                                        seasonCode[*], rc);
              Type:
                          Subroutine
              Purpose: 
                          Generate season code for a particular event series on a given beforeDist and afterDist
              Input:   
                          periodStart       : array that stores the period start index value
                          periodEnd         : array that stores the period end index value
                          periodCount       : number of valid elements in periodStart and periodEnd
                          totObs            : total number of observations
                          inSeasonLen       : in-season period length
                          ssIndex           : relative season start index
                          
              Output: 
                          seasonCode        : array that stores the season code for each observation in the demand series
                          rc                : return code : 0: success; 1: periodCount=0; 2: invalid ssIndex
                                                            3: invalid periods definition for ssIndex; 4: others
                          
          ***********************************************************************************************************/
              subroutine ci_find_season_series_seasons(periodStart[*], periodEnd[*], periodCount, totObs, inSeasonLen, ssIndex,
                                                        seasonCode[*], rc);
                  outargs seasonCode, rc;

                  do t=1 to dim(seasonCode); seasonCode[t]=.; end;
                  rc=1;
                  if periodCount>0 then do;
                    rc= 4;
                    array periodPos[1] / nosymbols; call dynamic_array(periodPos, periodCount);
                    array newPeriod[1,2] / nosymbols; call dynamic_array(newPeriod, periodCount,2);
                    
                    accM=1;
                    do i=1 to periodCount;
                      options= ci_season_compute_option_count(periodStart, periodEnd, periodCount, totObs, inSeasonLen, i);
                      periodPos[i]=mod(ceil(ssIndex/accM), options);
                      if periodPos[i]=0 then periodPos[i]=options;
                      accM=accM*options;
                    end;
                    if ssIndex<=0 or ssIndex>accM then rc=2;
                    else do;
                      rc=4;
                      invalid=0;
                      do i=1 to periodCount;
                        newPeriod[i,1]=.; newPeriod[i,2]=.;
                        if periodEnd[i]<periodStart[i] then invalid=1;
                        if periodEnd[i]-periodStart[i]+1>=inSeasonLen then do;
                          newPeriod[i,1]=periodStart[i]+periodPos[i]-1;
                          newPeriod[i,2]=newPeriod[i,1]+inSeasonLen-1;
                        end;
                        else do;
                          if i>1 then do;
                            newPeriod[i,1]=periodStart[i]-periodPos[i]+1;
                            newPeriod[i,2]=newPeriod[i,1]+inSeasonLen-1;                            
                          end;
                          else do;
                            newPeriod[i,2]=periodEnd[i]+periodPos[i]-1;
                            newPeriod[i,1]=newPeriod[i,2]-inSeasonLen+1;
                          end;
                        end;
                        if i>1 then do;
                          if newPeriod[i,1]<=newPeriod[i-1,2]+1 then invalid=1;
                        end;
                      end;
                      if invalid = 1 then rc=3;
                      else do;
                        do i=1 to totObs;
                          seasonCode[i]=0;
                        end;
                        do i=1 to periodCount;
                          do j=newPeriod[i,1] to newPeriod[i,2];
                            if j>0 and j<=totObs then seasonCode[j]=j-newPeriod[i,1]+1;
                          end;
                        end;
                        rc=0;
                      end; /*else for if invalid = 1*/
                    end; /*else for if ssIndex<=0 or ssIndex>accM */
                  end;/*if periodCount>0 then do;*/
                  

                  
              endsub;              

          /***********************************************************************************************************
              API:
                          ci_find_season_start_index(periodStart[*], periodCount, seasonIndex[*], inSeasonRule $);
              Type:
                          function
              Purpose: 
                          Derive in-season start index based on previous history and rule
              Input:   
                          periodStart       : array that stores the period start index value
                          periodCount       : number of valid elements in periodStart and periodEnd
                          seasonIndex       : array that stores the season indices
                          inSeasonRule      : rule used to find in season start index, possible values are MIN, MAX, MEAN, MODE, MED, LAST
              Output: 
                          the expected season start index
                          
          ***********************************************************************************************************/
              function ci_find_season_start_index(periodStart[*], periodCount, seasonIndex[*], inSeasonRule $);
                  start=.;
                  if periodCount>0 then do;
                    off=0;
                    call ci_compute_order_stats(seasonIndex, _INDEX_MIN, _INDEX_MED, _INDEX_MAX);
                    array periodSIndex[1] / nosymbols; call dynamic_array(periodSIndex, periodCount);
                    do i=1 to periodCount;
                      j=periodStart[i];
                      periodSIndex[i]=seasonIndex[j];
                    end;
                    call ci_compute_basic_freq(periodSIndex, _START_COUNT, _START_MIN, _START_MEDIAN, _START_MAX,
                                               _START_MEAN, _START_MODE);
                    /*adjustment for going across cycles*/
                    if _START_MAX-_START_MIN>_START_MIN+_INDEX_MAX-_START_MAX then do;
                      off=1;
                      array newPeriodStart[1] / nosymbols; 
                      call dynamic_array(newPeriodStart, periodCount);
                      do i=1 to periodCount;
                        if periodSIndex[i]-_START_MIN>=_START_MAX-periodSIndex[i] then do;
                          newPeriodStart[i]=periodSIndex[i];
                        end;
                        else newPeriodStart[i]=periodSIndex[i]+_INDEX_MAX;
                      end;
                      call ci_compute_basic_freq(newPeriodStart, _START_COUNT, _START_MIN, _START_MEDIAN, _START_MAX,
                                                 _START_MEAN, _START_MODE);
                    end;
                    if inSeasonRule eq "MIN" then start=_START_MIN;
                    else if inSeasonRule eq "MAX" then start=_START_MAX;
                    else if inSeasonRule eq "MEAN" then start=floor(_START_MEAN);
                    else if inSeasonRule eq "MODE" then start=_START_MODE;
                    else if inSeasonRule eq "MED" then start=floor(_START_MEDIAN);
                    else do;
                      start=periodSIndex[periodCount];
                    end;
                    if start>_INDEX_MAX then start=start-_INDEX_MAX;
                  end;
                  return(start);
                  
              endsub;  
                          
              
              /***********************************************************************************************************
              API:
                          ci_season_compute_next_period_distance(interval $, currentDate, currentIndex, startIndex, seasonality);
              Type:
                          function
              Purpose: 
                          compute the distance to the next inseason period
              Input:   
                          interval          : time interval
                          currentDate       : the current date
                          currentIndex      : the season index for the last(current) observation
                          startIndex        : the next season starting index      
                          seasonality       : season cycle length  
                          
              Output: 
                          dist
                          
          ***********************************************************************************************************/
              function ci_season_compute_next_period_distance(interval $, currentDate, currentIndex, startIndex, seasonality);
                  dist=.;
                  if startIndex> currentIndex then temp_dist=startIndex-currentIndex;
                  else temp_dist=startIndex-currentIndex+seasonality;
                  
                  if interval ne "" and INTSEAS(interval)=seasonality then do;
                    do i=-2 to 2;
                      nextDate=INTNX(interval,currentDate,temp_dist+i);
                      if INTINDEX(interval, nextDate, seasonality) eq startIndex then dist=INTCK(interval, currentDate, nextDate); 
                    end;
                  end;
                  else dist=temp_dist;

                  return(dist);
              endsub;
              
          /***********************************************************************************************************
              API:
                          ci_compute_trail_missing_length(series[*], totObs);
              Type:
                          function
              Purpose: 
                          compute the trailing missing period length
              Input:   
                          series            : array that stores the series
                          totObs            : total number of observations need to consider 
              Output: 
                          len
                          
          ***********************************************************************************************************/
              function ci_compute_trail_missing_length(series[*], totObs);
                  len=0;
                  if series[totObs] eq . then do;
                    flag=0;
                    do i=1 to totObs;
                      j=totObs-i+1;
                      if series[j] ne . and flag eq 0 then do;
                        flag =1;
                        len=i-1;
                      end;
                    end;
                  end;

                  return(len);
              endsub;              

          /***********************************************************************************************************
              API:
                          ci_generate_forecast_one(demand[*], season_code[*], totObs, leadLen, trailLen, expectTrailLen, inLen, 
                                                   offSeasonRule $, idForecastMethod $, idForecastAccum $, idForecastMode $, sign $,
                                                   forecastCriterion $, repositoryNm $, diagEstNm $, indataset $, outdataset $,
                                                   _outForecast[*], outsize, rc);
              Type:
                          Subroutine
              Purpose: 
                          Generate forecast for a given series with season code, etc information available
              Input:   
                          demand            : array that stores the series for forecast
                          season_code       : array that stores the season code for the demand series
                          totObs            : total number of observations
                          leadLen           : leading off-season period length
                          trailLen          : trailing off-season period length
                          expectTrailLen    : expected trailing off-season whole period length
                          inLen             : in-season period length
                          offSeasonRule     : rule used to find off season length, possible values are MIN, MAX, MEAN, MODE, MEDIAN, LAST
                          idForecastMethod  : method used for forecast, possible values are ACCUMULATE or SEPARATE
                          idForecastAccum:  : accumulation method used to accumulate the off-season period observations when forecast method is ACCUMULATE, 
                                              possible values are "TOTAL", "AVG", "MIN", "MED", "MAX", "FIRST", "LAST", "MODE"
                          idForecastMode    : mode used for generating forecast, possible values are "ALL" (for HPF), "AVG" (for using average profile forecast)
                          sign              : the sign for forecast values, possible values are "MIXED", "NONNEGATIVE", "NONPOSITIVE"
                          forecastCriterion : criterion for selecting forecast model, possible values are "MAPE", "MAE", "MSE"
                          repositoryNm      : catalog location and name for the model repository, only used when idForecastMode is "ALL"
                          diagEstNm         : location and name for the diagnose estimation results, only used when idForecastMode is "ALL"
                          indataset         : location and name the to-forecast series should be written to, only used when idForecastMode is "ALL"
                          outdataset        : location and name the HPF forecast results should be written to, only used when idForecastMode is "ALL"
                          
              Output: 
                          _outForecast      : array that stores the forecast results
                          outsize           : size of valid forecast elements
                          rc                : return code : 0: success; 
                          
          ***********************************************************************************************************/
              subroutine ci_generate_forecast_one(demand[*], season_code[*], totObs, leadLen, trailLen, expectTrailLen, inLen, 
                                                  offSeasonRule $, idForecastMethod $, idForecastAccum $, idForecastMode $, sign $,
                                                  forecastCriterion $, repositoryNm $, diagEstNm $, indataset $, outdataset $,
                                                  _outForecast[*], outsize, rc);

                  outargs _outForecast, outsize, rc;
                  
                  rc=0;
                  outsize=dim(_outForecast);
                  do i=1 to outsize; _outForecast[i]=.; end;

                  array offStart[1]/NOSYMBOLS; call dynamic_array(offStart, totObs); 
                  array offEnd[1]/NOSYMBOLS; call dynamic_array(offEnd, totObs); 
                 
                  if expectTrailLen>0 and expectTrailLen ne trailLen then do;
                    removeTrail=1;
                    call ci_find_off_periods_by_code(season_code, 0, 0, offStart, offEnd, offCount);
                    trimObs=totObs-trailLen;
                    newTotObs=totObs+expectTrailLen-trailLen;
                  end;
                  else do;
                    removeTrail=0;
                    call ci_find_off_periods_by_code(season_code, 0, 1, offStart, offEnd, offCount);
                    trimObs=totObs;
                    newTotObs=totObs;
                  end;
                  array trimDemand[1]/NOSYMBOLS; call dynamic_array(trimDemand, trimObs); 
                  do i=1 to trimObs;
                    if i<=leadLen then trimDemand[i]=.;
                    else trimDemand[i]=demand[i];
                  end;   
                  trailMissLen=ci_compute_trail_missing_length(demand, totObs);           
                  newLen=ci_find_off_periods_length(offStart, offEnd, offCount, offSeasonRule, totObs-trailMissLen);
                  array _combOrigFSeries[1]/NOSYMBOLS; call dynamic_array(_combOrigFSeries, newTotObs);

                  if idForecastMethod = "ACCUMULATE" then do;
                    array _combSeries[1]/NOSYMBOLS; call dynamic_array(_combSeries, trimObs);
                    array _combCount[1]/NOSYMBOLS; call dynamic_array(_combCount, trimObs);
                    call ci_combine_series_season(trimDemand, season_code, idForecastAccum, _combSeries, _combCount, combTotCount, tmp_rc);
                    if removeTrail=1 then lead=1;
                    else lead=0;
                    trailMissLen=ci_compute_trail_missing_length(_combSeries, combTotCount);
                    newCount=combTotCount-trailMissLen;
                    array _toForecast[1]/NOSYMBOLS; call dynamic_array(_toForecast, newCount); 
                    do i=1 to newCount; _toForecast[i]=_combSeries[i]; end;
                    array _fcst[1]/NOSYMBOLS; call dynamic_array(_fcst, combTotCount); 
                    array _fcstCount[1]/NOSYMBOLS; call dynamic_array(_fcstCount, combTotCount);
                    do i=1 to combTotCount; _fcstCount[i]=_combCount[i]; end;
                    if removeTrail=1 then _fcstCount[combTotCount] = expectTrailLen;
                    lead=lead+trailMissLen;

                    if idForecastMode = "ALL" then do;
                      array _toTimeID[1]/NOSYMBOLS; call dynamic_array(_toTimeID, newCount); 
                      array _fTimeID[1]/NOSYMBOLS; call dynamic_array(_fTimeID, newCount+lead); 
                      do i=1 to newCount; _toTimeID[i]=i; end;
                      
                      call ci_run_forecast(_toForecast, _toTimeID, "DAY", inLen+1, lead, sign, forecastCriterion, 
                                           repositoryNm, diagEstNm, indataset, outdataset,_fcst,_fTimeID, tmp_rc);
                    end; 
                    else do;
                      call ci_run_forecast2(_toForecast, inLen+1, lead, sign, _fcst);
                      if leadLen>0 then _fcst[1]=.;
                    end;

                    array offProfile[1]/NOSYMBOLS; call dynamic_array(offProfile, newLen); 
                    call ci_compute_profile(trimDemand, offStart, offEnd, offCount, newLen, offProfile);
                    call ci_recover_combine_series(_fcst, _fcstCount, combTotCount, idForecastAccum, offProfile,
                                                   _combOrigFSeries, origSize, tmp_rc);
                    if origSize<outsize then outsize=origSize;
                    do i=1 to outsize;
                      if i<=leadLen then _outForecast[i]=.;
                      else _outForecast[i]=_combOrigFSeries[i];
                    end;
                  end; /*if idForecastMethod = "ACCUMULATE" then do;*/
                  else do;
                    array newSeries[1]/NOSYMBOLS; call dynamic_array(newSeries, totObs+(offCount+1)*newLen); 
                    array newPeriodStart[1]/NOSYMBOLS; call dynamic_array(newPeriodStart, offCount+2); 
                    array newPeriodEnd[1]/NOSYMBOLS; call dynamic_array(newPeriodEnd, offCount+2); 
                    
                    if leadLen>0 then do;
                      if removeTrail=1 then call ci_find_off_periods_by_code(season_code, 1, 0, offStart, offEnd, offCount);
                      else call ci_find_off_periods_by_code(season_code, 1, 1, offStart, offEnd, offCount);
                    end;
                    call ci_stretch_squeeze_series(trimDemand, offStart, offEnd, offCount, newLen, 
                                                   newPeriodStart, newPeriodEnd, newSeries, newCount, tmp_rc);
                    offTotObs=newLen*offCount;                               
                    if removeTrail = 1 then offLead=newLen;
                    else offLead=0;
                    combTotObs=newCount+offLead;
                    inLead=0;
                    inTotObs=newCount-offTotObs;
                    trailMissLen=ci_compute_trail_missing_length(newSeries, newCount);
                    if trailMissLen>0 then do;
                      offMissCount=0;
                      do i=1 to offCount;
                        do j=newPeriodStart[i] to newPeriodEnd[i];
                          if j>newCount-trailMissLen then offMissCount=offMissCount+1;
                        end;
                      end;
                      inLead=trailMissLen-offMissCount;
                      offLead=offLead+offMissCount;
                      inTotObs=inTotObs-inLead;
                      offTotObs=offTotObs-offMissCount;
                    end;

                    array _inSeries[1]/NOSYMBOLS; call dynamic_array(_inSeries, inTotObs);
                    array _inFcst[1]/NOSYMBOLS; call dynamic_array(_inFcst, inTotObs+inLead); 
                    array _offSeries[1]/NOSYMBOLS; call dynamic_array(_offSeries, offTotObs); 
                    array _offFcst[1]/NOSYMBOLS; call dynamic_array(_offFcst, offTotObs+offLead); 
                    
                    call ci_split_series_by_period(newSeries, newCount-trailMissLen, newPeriodStart, newPeriodEnd, offCount,
                                                   _inSeries, _offSeries, inIndex, offIndex);                                  
                    if idForecastMode = "ALL" then do;
                      array _inTimeID[1]/NOSYMBOLS; call dynamic_array(_inTimeID, inTotObs); 
                      array _inFTimeID[1]/NOSYMBOLS; call dynamic_array(_inFTimeID, inTotObs); 
                      array _offTimeID[1]/NOSYMBOLS; call dynamic_array(_offTimeID, offTotObs); 
                      array _offFTimeID[1]/NOSYMBOLS; call dynamic_array(_offFTimeID, offTotObs); 
                      do i=1 to inTotObs; _inTimeID[i]=i; end;
                      do i=1 to offTotObs; _offTimeID[i]=i; end;
                      call ci_run_forecast(_inSeries, _inTimeID, "DAY", inLen, inLead, sign, forecastCriterion, 
                                           repositoryNm, diagEstNm, indataset, outdataset,_inFcst,_inFTimeID, tmp_rc);
                      call ci_run_forecast(_offSeries, _offTimeID, "DAY", newLen, offLead, sign, forecastCriterion, 
                                           repositoryNm, diagEstNm, indataset, outdataset,_offFcst,_offFTimeID, tmp_rc);                           
                    end; 
                    else do;
                      call ci_run_forecast2(_inSeries, inLen, inLead, sign, _inFcst);
                      call ci_run_forecast2(_offSeries, newLen, offLead, sign, _offFcst);
                      if leadLen>0 then do;
                        do i=1 to newLen;
                          _offFcst[i]=.;
                        end;
                      end;
                    end;

                    if removeTrail = 1 then do; 
                      offCount=offCount+1;
                      newPeriodStart[offCount]=newCount+1;
                      newPeriodEnd[offCount]=combTotObs;
                      offStart[offCount]=totObs-trailLen+1;
                      offEnd[offCount]=offStart[offCount]+expectTrailLen-1;
                    end;

                    array _combSeries[1]/NOSYMBOLS; call dynamic_array(_combSeries, combTotObs);
                    call ci_combine_two_series_by_period(_inFcst, _offFcst, combTotObs, newPeriodStart, newPeriodEnd, offCount,
                                                         _combSeries, inIndex, offIndex, combIndex);

                    call ci_recover_stretch_squeeze_series(newPeriodStart, newPeriodEnd, _combSeries, combTotObs,newLen,
                                                           offStart, offEnd, offCount, _combOrigFSeries, origSize, tmp_rc);
                    if origSize<outsize then outsize=origSize;
                    lastMissId=0;
                    do i=1 to outsize;
                      if i<=leadLen then _outForecast[i]=.;
                      else _outForecast[i]=_combOrigFSeries[i];
                      if _outForecast[i] eq . and i>lastMissId then lastMissId=i;
                    end;
                    if lastMissId>0 then do;
                      do i=1 to lastMissId;
                        _outForecast[i]=.;
                      end;
                    end; 
                  end; /*else do for if idForecastMethod = "ACCUMULATE" then do;*/

                  
              endsub;              

          /***********************************************************************************************************
              API:
                          ci_season_find_trim_info(timeID[*], season_code[*], season_index[*], totObs, interval $, seasonality, seasonStart, 
                                                   leadLen, trailLen, expectTrailLen, rc);
              Type:
                          subroutine
              Purpose: 
                          find the leading trailing information about the seasonal series
              Input:   
                          timeID            : array that stores the time ID series
                          season_code       : array that stores the season code for the demand series
                          season_index      : array that stores the season index for each observations
                          totObs            : total number of observations
                          interval          : time interval
                          seasonality       : seasonal cycle length
                          seasonStart       : in-season start index   
              Output: 
                          leadLen           : leading off-season period length
                          trailLen          : trailing off-season period length
                          expectTrailLen    : expected trailing off-season whole period length  
                          rc                : return code : 0: success; 1: input arrays size incorrect                     
                          
          ***********************************************************************************************************/
              subroutine ci_season_find_trim_info(timeID[*], season_code[*], season_index[*], totObs, interval $, seasonality, seasonStart, 
                                                  leadLen, trailLen, expectTrailLen, rc);
                  outargs leadLen, trailLen, expectTrailLen, rc;
                  leadLen=0;
                  trailLen=0;
                  expectTrailLen=0;
                  rc=0;
                  if dim(timeID)<totObs or dim(season_code)<totObs or dim(season_index)<totObs then rc=1;
                  else do;
                  
                    if season_code[1]=0 or season_code[totObs]=0 then do;
                      array offStart[1]/NOSYMBOLS; call dynamic_array(offStart, totObs); 
                      array offEnd[1]/NOSYMBOLS; call dynamic_array(offEnd, totObs); 
                      call ci_find_off_periods_by_code(season_code, 1, 1, offStart, offEnd, offCount);
                      if offStart[1]=1 then leadLen=offEnd[1];
                      if offEnd[offCount]=totObs then trailLen=offEnd[offCount]-offStart[offCount]+1;
                      if trailLen>0 then do;
                        expectTrailLen=ci_season_compute_next_period_distance(interval, timeID[totObs-trailLen+1], season_index[totObs-trailLen+1], seasonStart, seasonality);
                        if expectTrailLen eq . then expectTrailLen=trailLen;
                      end;
                    end;
                  end;
                  
              endsub; 

          /***********************************************************************************************************
              API:
                          ci_event_find_trim_info(timeID[*], season_code[*], eventDate[*], totObs, eventCount, interval $, beforeDist, 
                                                  leadLen, trailLen, expectTrailLen, rc);
              Type:
                          subroutine
              Purpose: 
                          find the leading trailing information about the event series
              Input:   
                          timeID            : array that stores the time ID series
                          season_code       : array that stores the season code for the demand series
                          eventDate         : array that stores the event dates for the particular eventIdx that matters
                          totObs            : total number of observations
                          eventCount        : number of observations in the eventDate
                          interval          : time interval
                          beforeDist        : the number of periods each in-season periods starts compared with event date
              Output: 
                          leadLen           : leading off-season period length
                          trailLen          : trailing off-season period length
                          expectTrailLen    : expected trailing off-season whole period length 
                          rc                : return code : 0: success; 1: input arrays size incorrect; eventCount=0;                     
                          
          ***********************************************************************************************************/
              subroutine ci_event_find_trim_info(timeID[*], season_code[*], eventDate[*], totObs, eventCount, interval $, beforeDist, 
                                                 leadLen, trailLen, expectTrailLen, rc);
                  outargs leadLen, trailLen, expectTrailLen, rc;
                  leadLen=0;
                  trailLen=0;
                  expectTrailLen=0;
                  rc=0;
                  if eventCount<1 then rc=2;
                  else if dim(timeID)<totObs or dim(season_code)<totObs then rc=1;
                  else do;
                    if season_code[1]=0 or season_code[totObs]=0 then do;
                      array offStart[1]/NOSYMBOLS; call dynamic_array(offStart, totObs); 
                      array offEnd[1]/NOSYMBOLS; call dynamic_array(offEnd, totObs); 
                      call ci_find_off_periods_by_code(season_code, 1, 1, offStart, offEnd, offCount);
                      if offStart[1]=1 then leadLen=offEnd[1];
                      if offEnd[offCount]=totObs then trailLen=offEnd[offCount]-offStart[offCount]+1;
                      if trailLen>0 then do;
                        expectTrailLen=ci_event_compute_next_period_distance(eventDate, eventCount, interval, timeID[totObs-trailLen+1], beforeDist);
                        if expectTrailLen eq . then expectTrailLen=trailLen;
                      end;
                    end;
                  end; 
                  
              endsub;  
              
              
              /***********************************************************************************************************
              API:
                          ci_season_compute_option_count(allPeriodStart[*], allPeriodEnd[*], allPeriodCount, totObs, sl, t);
              Type:
                          function
              Purpose: 
                          compute the number of candidate options for the current period (t)
              Input:   
                          allPeriodStart    : array that stores the period start index
                          allPeriodEnd      : array that stores the period end index
                          allPeriodCount    : count of valid element size in both allPeriodStart and allPeriodEnd
                          totObs            : total number of observations
                          sl                : season length   
                          t                 : current period index
                          
              Output: 
                          options
                          
          ***********************************************************************************************************/
              function ci_season_compute_option_count(allPeriodStart[*], allPeriodEnd[*], allPeriodCount, totObs, sl, t);
              
                  options=1;
                  array allPeriodRange[1]/NOSYMBOLS; call dynamic_array(allPeriodRange, allPeriodCount); 
                  do i=1 to allPeriodCount;
                    allPeriodRange[i]=allPeriodEnd[i]-allPeriodStart[i]+1; 
                  end;
                  options = abs(allPeriodRange[t]-sl)+1;
                  if allPeriodRange[t]<sl then do;
                    if t>1 then do;
                      if allPeriodRange[t-1]<=sl then minEnd=allPeriodEnd[t-1];
                      else minEnd=allPeriodStart[t-1]+sl-1;
                      if allPeriodStart[t]-minEnd-1<options then options=allPeriodStart[t]-minEnd-1;
                      if t eq allPeriodCount and t>2 and allPeriodEnd[t] eq totObs then do;
                        /*for partial trailing cycle, only keep the reasonable solutions, not comprehensive ones*/
                        minOff=allPeriodEnd[t];
                        do i=1 to t-1; 
                          if allPeriodStart[i+1]-allPeriodEnd[i]<minOff then minOff=allPeriodStart[i+1]-allPeriodEnd[i];
                        end;
                        if options>allPeriodStart[t]-(allPeriodEnd[t-1]+minOff)+1 then do;
                          options=allPeriodStart[t]-(allPeriodEnd[t-1]+minOff)+1;
                        end;
                      end;
                    end;
                    else if allPeriodCount>2 and allPeriodStart[1]=1 then do;
                      if allPeriodRange[2]>sl then maxStart=allPeriodEnd[2]-sl+1;
                      else maxStart=allPeriodStart[2];
                      if maxStart-allPeriodEnd[1]-1<options then options=maxStart-allPeriodEnd[1]-1;
                      minOff=allPeriodEnd[allPeriodCount];;
                      do i=2 to allPeriodCount;
                        if allPeriodStart[i]-allPeriodEnd[i-1]<minOff then minOff=allPeriodStart[i]-allPeriodEnd[i-1];
                      end;
                      /*for partial leading cycle, only keep the reasonable solutions, not comprehensive ones*/
                      if options>allPeriodStart[2]-minOff-allPeriodEnd[1]+1 then do;
                        options=allPeriodStart[2]-minOff-allPeriodEnd[1]+1;
                      end;
                    end;
                  end;
                  if options<1 then options=1;

                  return(options);
              endsub;              
                                                                                   
          run; 
          quit;
      %end; 
  %mend;
  %ci_fcmp_functions(cmpLib=@localCmpLib@);         
      ]])    
          

end



return{fcmp_functions=fcmp_functions}
