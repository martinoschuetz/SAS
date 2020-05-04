
-- setup a logger for local use
local log = {
  error = function(msg) sas.print("%1z" .. msg) end,
  warn  = function(msg) sas.print("%2z" .. msg) end,
  note  = function(msg) sas.print("%3z" .. msg) end
}
--[[
NAME:           my_assert

DESCRIPTION:    print error message and assert if the condition is not met
                
INPUTS:         condition 
                msg

OUTPUTS:        if condition is met, print out error message and assert

USAGE:          
                my_assert(rc<0,"COMPUTATION ERROR")
                
]]

function my_assert(condition, msg)
  if not condition then
    log.error(msg)
    error(msg)
  end
end

--[[
NAME:           my_warning

DESCRIPTION:    print warning message and if the condition is not met
                
INPUTS:         condition 
                msg

OUTPUTS:        if condition is met, print out warning message

USAGE:          
                my_warning(rc==1,"COMPUTATION WARNING")
                
]]

function my_warning(condition, msg)
  if not condition then
    log.warn(msg)
  end
end

--[[
NAME:           dump_to_file

DESCRIPTION:    function to append information to a destination file 

INPUTS:         data  - information to be writen out
                dest  - destination file

OUTPUTS:        the information will be written into the desination file

USAGE:          
                local t = "TEST"
                dump_to_file(t,"c:/public/test.txt")
]]
function dump_to_file(data, dest) 
   if data ~= nil then
     local logical = sasxx.assign(dest)
     local file = logical:open("a")
     file:write(data)
     file:flush()
     file:close()
     logical:deassign()
  end
end

--[[
NAME:           dir_exists

DESCRIPTION:    Tests whether the given directory path exists or not 
                This differs from the sas.fileexist() function in that this function ensures that the path
                is to a directory and not to a file

INPUTS:         dirPath  - directory path in question

OUTPUTS:        boolean value

USAGE:          
                dir_exists("c:\public\test")
]]

function dir_exists(dirPath)
   local rc = false
   local fileref_rc = sas.filename("_tdir", dirPath)  -- assign the fileref
   if fileref_rc==0 then                              -- if successful
      local did = sas.dopen("_tdir")    -- try to open the fileref as a directory
      if did > 0 then                   -- if successful
         sas.dclose(did)                -- close the directory
         rc = true
      end
      sas.filename("_tdir")  -- deassign the fileref
   end
   return rc
end

--[[
NAME:           create_folder

DESCRIPTION:    creates a new directory relative to the directory passed.
                if the directory already exists it will directly return and will not 
                create a new directory

INPUTS:         parentDir  - parent directory path, which already exists
                dirName    - relative directory with respect to parent that needs to be created

OUTPUTS:        

USAGE:          
                create_folder("c:\public\test","test1")
]]
function create_folder(parentDir, dirName)
   
   local path = string.gsub(parentDir, "\\","/")
   local fullPath = path.."/"..dirName
   if (not dir_exists(fullPath)) then
     local new_path = sasxx.mkdir(dirName, path)
     my_assert(new_path ~= nil, "Failed to create directory: " .. fullPath)
   end
   
end

--[[
NAME:           check_ds_non_empty

DESCRIPTION:    check if the data set is empty or not
                
INPUTS:         ds -- sas data set

OUTPUTS:        if data set not exist or empty then return false
                else return true

USAGE:          
                local rc =  check_file_non_empty(data)
                
]]

function check_file_non_empty(ds)
  local rc = false
  if ds then 
    if sas.exists(ds, "DATA") then 
      local dsid = sas.open(ds, "i")
      assert(dsid, "Failed to open " .. ds)
      local nobs = sas.nobs(dsid) 
      if nobs>0 then
        rc = true
      end
      sas.close(dsid)
    end
  end
  return rc
end

--[[
NAME:           check_value

DESCRIPTION:    check if the value is assigned
                
INPUTS:         var -- variable to be checked

OUTPUTS:        if nil or "" then return false
                else return true

USAGE:          
                local var=XYZ
                if check_value(var) then ***use the var***
                
]]

function check_value(var)
  local rc = false
  if var then 
    if not (var=="") then 
      rc = true
    end
  end
  return rc
end

--[[
  Given a dataset and an attribute name in the data
  return "C" if the variable is a character variable
  return "N" if the variable is a numeric variable
]]
--[[
NAME:           check_vartype

DESCRIPTION:      Given a dataset and a variable name in the data, return the vartype

INPUTS:         inData
                varName 

OUTPUTS:        varType
                  return "C" if the variable is a character variable
                  return "N" if the variable is a numeric variable

USAGE:          
                local varType
                varType = check_vartype("sashelp.air, "air")
]]
function check_vartype(inData, varName)
  local varType = ""
  if sas.exists(inData) then --check the existence of the data set
    local dsid = sas.open(inData)
    local varNum = sas.varnum(dsid, varName)
    if varNum > 0 then
      varType = dsid:vartype(varName)
    else
      print("ERROR: The variable does not exist in given dataset. Exit with error")
    end
    sas.close(dsid)
  else --exit with error msg indicating the dataset does not exist
    print("ERROR: The given dataset does not exist. Exit with error")
  end
  
  return varType
end

--[[
NAME:           get_libname_tablename

DESCRIPTION:    get libname and tablename of a sas table
                
INPUTS:         inTable

OUTPUTS:        libname, tablename


USAGE:          libname,tablename = get_libname_tablename("_tmp.table1")
    
]]
function get_libname_tablename(inTable)
  if not check_value(inTable) then
    return nil
  end
  local i = 0
  local pos1 = ""
  local pos2 = ""
  local libname = ""
  local tablename = ""
  for v in inTable:gmatch("([^.]+)") do --iterate through all words delimited by .
    i = i + 1
    if i == 1 then
      pos1 = v
    else 
      pos2 = v
    end
  end
  
  if i == 1 then
    libname = "work"
    tablename = pos1
  else
    libname = pos1
    tablename = pos2
  end
   
  return libname,tablename
end

--[[
NAME:           check_sub_string

DESCRIPTION:    test whether testStr is a substring of origStr, will take space or * as delimiter, case insensitive
                
INPUTS:         origStr
                testStr

OUTPUTS:        rc: true or false


USAGE:          is_substr = check_sub_string(origStr, testStr)
    
]]
function check_sub_string(origStr, testStr)
  local rc
  if not check_value(origStr) or not check_value(testStr) then
    return nil
  end
  rc = false
  for v in origStr:gmatch("([^ ]+)") do --iterate through all words delimited by space
    for subv in v:gmatch("([^*]+)") do --iterate through all words delimited by *
      if (string.upper(testStr) == string.upper(subv)) then
        rc = true
        return rc
      end
    end
  end
  return rc
end

--[[
NAME:           create_index_for_table

DESCRIPTION:    create index for a given table

INPUTS:         tableNm
                indexVar 

OUTPUTS:        create index for the table

USAGE:          
                ***a table lib.test contains columns X Y ***
                local byVar = "X Y"
                create_index_for_table(lib.test, byVar)
]]

function create_index_for_table(tableNm, indexVar)

    if check_value(tableNm) and check_value(indexVar)  then 
      local tablelibNm = tableNm:find("%.") 
                       and string.sub(tableNm,1,string.find(tableNm,"%.")-1) 
                       or "work" 
      local tablefileNm = tableNm:find("%.") 
                        and string.sub(tableNm,string.find(tableNm,"%.")+1,-1) 
                        or tableNm 
                        
      local dsid = sas.open(tableNm)
      local indexFlag = sas.attr(dsid,"isindex")
      print(indexFlag)
      sas.close(dsid)
      local deleteArg = ""

      if indexFlag == 1 then 
        deleteArg="index delete @indexVar@ ;"
      end

      local rc = sas.submit([[
        proc datasets library=@tablelibNm@ nolist;
          modify @tablefileNm@;
          @deleteArg@
          index create @indexVar@;
        quit;
      ]])
      my_assert(rc<4, "ERROR occurred when creating index for table "..tablelibNm..", exit.")
    end
end

--[[
NAME:           invar_check

DESCRIPTION:    scan a table for the availability of a stream of variables

INPUTS:         indata
                check_stream 

OUTPUTS:        all_matched
                match
                unmatch

USAGE:          
                local all_matched
                local match
                local unmatch
                all_matched, match, unmatch = invar_check("sashelp.air", "AIR XYZ")
]]

function invar_check(indata, check_stream)

  --initialize the return all_matched flag and match/unmatch lists
  local all_matched = false
  local matched_stream = nil
  local unmatched_stream = nil

  --open the sas dataset
  local dsid = sas.open(indata, "i")
  
  --iterate over the variables in the data set and concat to variable VARS
  local vars = ""
  for var in sas.vars(dsid) do
    vars = vars.." "..var.name:upper()
  end  

  --close the sas dataset
  sas.close(dsid)

  if (vars ~= "") and check_value(check_stream) then

    --loop through the input_stream to check the matched/unmatched stream
    local i
    local stream = split_string(check_stream)
    for i=1, #stream do
       local v=stream[i]
       if check_sub_string(vars, v) then
          if check_value(matched_stream) then
            matched_stream = matched_stream.." "..v
          else
            matched_stream = v
          end
       else
          if check_value(unmatched_stream) then
            unmatched_stream = unmatched_stream.." "..v
          else
            unmatched_stream = v
          end
       end
    end
  else
     return nil, nil, nil
  end
  
  --set all_matched flag
  if (not check_value(unmatched_stream)) then
    all_matched = true 
  end
  
  --return the all_matched as a flag and the matched and unmatched stream as a string
  return all_matched, matched_stream, unmatched_stream
  
end

--[[
NAME:           validate_sym

DESCRIPTION:    Check non-fatally if a variable is defined and has a value assigned
                Will give an error message and assign a default value if default= being specified
                or does not have valid values.

INPUTS:         symbol            - value of the symbol to be checked
                name              - name of the symbol to be checked
                cval              - table with valid values for character symbols
                nval_u            - upper bound of the numeric symbols
                nval_l            - lower bound of the numeric symbols
                default_value     - default value

OUTPUTS:        valid value

USAGE:          
                local spec = 5
                spec = validate_sym(spec, "mean", nil, 4, 1, 3) 
]]
function validate_sym(symbol, name, cval, nval_u, nval_l, default_value)
  --logic for numeric symbol. either cval or (nval_u, nval_l) can be used to validate the spec value
  --if cval is specified, (nval_u, nval_l) values will be ignored
  local use_default = false
  if not check_value(symbol) then
    log.warn("symbol "..name.." is not specified")
    if check_value(default_value) then
      log.warn("    default value "..default_value.." is used")
    else
      log.warn("    ignored")
    end
    return default_value
  end
  if (type(symbol) == 'number') then
    if (cval) then
      local found = false
      --loop through the cval values to see if there is a match
      for k, v in pairs(cval) do
        if (type(v) == 'number' and symbol == v) then
          found = true
          break
        end
      end
      if (not found) then
        log.warn("symbol "..name.." value "..symbol.." is invalid.")
        use_default = true
      else
        return symbol
      end
    else
      --check the upper and lower bounds if (nval_u, nval_l) is used for spec validation
      --the following logic also checks if (nval_u, nval_l) values are of type number
      if (nval_u and type(nval_u) == 'number') then
        if (symbol > nval_u) then
          log.warn("symbol "..name.." value "..symbol.." should be no greater than "..nval_u..".") 
          use_default = true 
        end
      end
      if (nval_l and type(nval_l) == 'number') then
        if (symbol < nval_l) then
          log.warn("symbol "..name.." value "..symbol.." should be no less than "..nval_l..".")  
          use_default = true 
        end
      end
      if not use_default then 
        return symbol 
      end
    end

  --logic for string symbol. only cval can be used to validate the spec value
  elseif (type(symbol) == 'string') then
    if (cval) then
      local found = false
      --loop through the cval values to see if there is a match
      for k, v in pairs(cval) do
        --the following logic also checks if cval[] values are of type string
        if (symbol==v) then
          found = true
          break
        end
      end
      if (not found) then
        log.warn("symbol "..name.." value "..symbol.." is invalid.")
        use_default = true
      else
        return symbol
      end
    else
      return symbol
    end
  else
    log.warn("symbol "..name.." does not have the supported data type.")
    use_default = true
  end
  
  if use_default then
    if check_value(default_value) then
      log.warn("    default value "..default_value.." is used")
    else
      log.warn("    ignored")
    end
    return default_value
  end
  
end


--[[
NAME:           split_string

DESCRIPTION:    function to split a string and put each word in the string into a table
                and return the table. If the input string is nil, a nil will be returned 

INPUTS:         str

OUTPUTS:        t - table stores each word of the input string

USAGE:          
                local str = "a b c d"
                t = split_string(str) 
]]

function split_string(str)
  if not str then
    return nil
  end
  local t = {}
  local i = 1
  for v in str:gmatch("([^ ]+)") do
    t[i] = v
    i = i + 1
  end
  return t
end

--[[
NAME:           get_string_from_table

DESCRIPTION:    function to merge elements in an array table into a string separated by space
                and return the string. If the input table is nil, a nil will be returned 

INPUTS:         tbl

OUTPUTS:        str - string merges table entries

USAGE:          
                local t = {}
                t[1]="region"
                t[2]="category"
                t[3]="product"
                
                str = split_string(t)   -- str="region category product"
]]
function get_string_from_table(t)
  if not t then
    return nil
  end
  local numLevel = #t
  local str = ""
  local i
  for i = 1, numLevel do
    if i == 1 then
      str = t[i]
    else
      str = str..' '..t[i]
    end
  end
  return str
end

--[[
NAME:           get_delim_string

DESCRIPTION:    function to insert delimiter into the string

INPUTS:         str

OUTPUTS:        string - string with delim inserted
                delim  - delimiter to be inserted

USAGE:          
                local t = "A B C"
                str = get_delim_string(t)   -- str="A,B,C"
]]
function get_delim_string(str, delim)
  local comma = ""
  if check_value(str) and check_value(delim) then
    local Tbl       = split_string(str)
    local i
    for i=1, #Tbl do
      if i<#Tbl then 
        comma       = comma..Tbl[i]..delim
      else
        comma       = comma..Tbl[i]
      end
    end
  end
  return comma
end

--[[
NAME:           string_to_boolean

DESCRIPTION:    function to convert a string with boolean value to a boolean

INPUTS:         str            - value of the str to be checked
                name           - name of the str to be checked

OUTPUTS:        boolean

USAGE:          
                local t = "False"
                if not string_to_boolean(t) then
                  print("FALSE")
                end
]]
function string_to_boolean(str, name)
  if check_value(str) then
    local t=string.upper(str)
    if (t == "TRUE") then
      return true
    elseif (t == "FALSE") then
        return false
    else
      log.warn("symbol "..name.." has an invalid value "..str.." , should be a boolean.")
    end
  end
  return false
  
end

--[[
NAME:           add_to_string

DESCRIPTION:    function to add a string into a resulting string separated by space

INPUTS:         res_str        - result string
                str            - string needs to be added into res_str

OUTPUTS:        res_str

USAGE:          
                local t = {} t[1]="A" t[2]="B"
                local c
                for i=1, 2 do
                  c=add_to_string(c,t[i])
                end
                print(c)  -- A B
]]
function add_to_string(res_str, str)
  if check_value(res_str) then
    res_str = res_str.." "..str
  else
    res_str = str
  end
  return res_str
end

--[[
NAME:           value_to_date

DESCRIPTION:    function to covert a sas date value to sas date or datetime

INPUTS:         args
                  value
                  format (optional)

OUTPUTS:        sas date/datetime

USAGE:          
                local date=value_to_date("17510","MONYY7.")
                print(date)  -- '10DEC2007'd
]]
function value_to_date(value, format)
  
  res_str = ""
  if check_value(value) then
    local num = tonumber(value)
    local type = 1 -- default is sas date
    if check_value(format) then
     -- if there is a given format
      sas.submit[[
        data _NULL_;
           if index("@format@", "TIME")>0 or index("@format@", "AMPM")>0 
              or index("@format@", "TOD")>0 or index("@format@", "HH")>0 then do;
              call symputx("local_type", "2");
           end;
           else do;
              call symputx("local_type", "1");
           end;
        run;]]
        
      type = tonumber(sas.symget("local_type"))
    else
     --[[Since SAS represents both dates and datetimes as numbers, 
         there is no way to tell, just given a numeric value, 
         whether it is intended as a date (number of days since Jan. 1, 1960)
         or a datetime (number of seconds since midnight, Jan. 1, 1960). 
         If the variable has a format, you can use it to tell.  
         Otherwise, an often used rule of thumb is 86400 (number of seconds in a day).  
         If the value is less than this, it almost certainly a date 
         (unless you can have datetimes all within the one day Jan 1st, 1960). 
         If it is larger than this, it is almost certainly a datetime (unless you might have dates after the year 2196).]]
       if num>=86400 then
        type = 2
       end
    end
    if type==1 then
      sas.submit[[
        data _NULL_;
           call symputx("local_date", cats("'",put(@num@, date9.),"'","d"));
        run;]]
                
    else
      sas.submit[[
        data _NULL_;
           call symputx("local_date", cats("'",put(@num@, datetime20.),"'","dt"));
        run;]]
    end
    res_str = sas.symget("local_date")
  end

  return res_str
end

--[[
NAME:           remove_dir

DESCRIPTION:    function to remove a folder and its contents (including subfolders)

INPUTS:         dir

OUTPUTS:        

USAGE:          remove_dir("c:/public/temp")
                
]]

local function dir_tree_walk_p(dir, level, dir_id, parent_dir_id, maxdepth, callback)
   
   -- Open the directory given
   local fref = "rsk" .. tostring(level)
   sas.filename(fref, dir)

   local did = sas.dopen(fref)   
   
   if did == 0 then
      -- could not open, so release the fileref
      sas.filename(fref)     
      return
   end


   -- Iterate over all the directory entries
   local dnum = sas.dnum(did);
   for i=1,dnum do
      local memname = sas.dread(did, i)
      
      if memname ~= "" then
         if dir_exists(dir .. "/" .. memname) then
            parent_dir_id = dir_id
            dir_id = dir_id+1       
            
            if maxdepth > level then
               -- recurse further down
               dir_tree_walk_p(dir .. "/" .. memname, level+1, dir_id, parent_dir_id, maxdepth, callback)
               print("condition 1 "..dnum)
            end     
   
            callback(dir_id, "D", memname, level, parent_dir_id, dir)
         else
            callback(nil   , "F", memname, level, parent_dir_id, dir)
            print("condition 2 "..dnum)
         end
      end 
   end

   -- Close the directory
   sas.dclose(did)
   sas.filename(fref)     
end


local function rm_file_or_empty_dir(path)
    local fref = "_T"
    
    sas.filename(fref, path);
    local rc = sas.fdelete(fref) 
    sas.filename(fref) -- clear the fileref

end

local function rm_file_cb(dir_id, type, memname, level, parent, context)
   rm_file_or_empty_dir(context .. "/" .. memname)
end


function remove_dir(dir)
   if dir_exists(dir) then
      dir_tree_walk_p(dir, 1, 0, nil, 9999999, rm_file_cb)  -- delete all dir contents first
      rm_file_or_empty_dir(dir)       -- then delete the dir itself

   end
end

return{
  my_assert=my_assert,
  my_warning=my_warning,
  dump_to_file=dump_to_file,
  dir_exists=dir_exists,
  create_folder=create_folder,
  check_file_non_empty=check_file_non_empty,
  check_value=check_value,
  check_vartype=check_vartype, 
  get_libname_tablename=get_libname_tablename,
  check_sub_string=check_sub_string,
  create_index_for_table=create_index_for_table,
  invar_check=invar_check,
  validate_sym=validate_sym,
  split_string=split_string,
  get_string_from_table=get_string_from_table,
  get_delim_string=get_delim_string,
  string_to_boolean=string_to_boolean,
  add_to_string=add_to_string,
  value_to_date=value_to_date,
  remove_dir=remove_dir
}