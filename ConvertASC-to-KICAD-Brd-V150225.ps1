Set-PSDebug -Trace 0


$defaultfilename="test" #change output file
$fileextension=".kicad_pcb"
$outfile="$defaultpath$defaultfilename$fileextension"    

$defaultpadsize="0.6 0.6"  #change this to change the size of the pads output
$defaultholesize="0.4" #change this to change the size of the pins output
#$bomfile=".\60-M7A660-A0.BOM"   #change this for different boards
$upsidedown="Yes"      #asc files are usually from the bottom perspective
######

[decimal]$global:unitconversionx=1
[decimal]$global:unitconversiony=1
$filecontents=$null
$global:boardname=$null
$global:boardunits=$null
$global:boarddate=$null

[decimal]$InchToMM=25.4
[decimal]$MMtoMM=1                       #not sure if there are other unit conversions

$newline="`r`n"



#ASC file details defs
$path=".\"
    $formatfile="FORMAT.ASC"
    $formatheaderlines=4
    $formatheaderstring="Board Outline Contour"
    $partsfile="Parts.ASC"
    $partsheaderlines=4
    $partsheaderstring="Parts List"
    $netsfile="nets.ASC"
    $netsheaderlines=4
    $netsheaderstring="Net Listing"
    $pinsfile="pins.ASC"
    $pinsheaderlines=7
    $pinsheaderstring="Part Pins List"
#ASC file details





########################################################################################################################################################
########################################################################################################################################################
function checkheader {
    param (
        [string[]]$ascfile,
        [string[]]$headerstring
    )
    Write-Host Checking $ascfile
   # $exists=Test-Path $ascfile
    if ((Test-Path $ascfile) -eq "True") {
       # Set-PSDebug -Trace 2 -verbose
        $fileheader=( get-content $ascfile |select-object -first 5) |ForEach-Object {$_.TrimStart() -replace "\s{2,}" ,";"}
        #$temp=convertfrom-csv $filex -header a,b,c,d,e,f,g,h
        $global:temp=convertfrom-csv $fileheader -delimiter ";" -header a,b,c,d,e,f,g,h 
        if (($temp.b[0] -like "*FABMASTER*" -or $temp.b[0] -like "*eM-Test*") -and $temp.a[1] -eq "$headerstring"){
            If ($boardname -eq $null){ 
                $global:boardname=$temp.a[0] 
            }
            if ($boardunits -eq $null){ 
                $global:boardunits,$junk=($temp.b[1]).split() 
            }
            if ($boarddate -eq $null){ 
                $global:boarddate=$temp.c[1] 
            }
            If ($boardunits -like "*inch*") {
                $global:unitconversionx=$inchtomm
                $global:unitconversiony=$inchtomm
            }
            IF ($upsidedown -eq "yes") {
                $global:unitconversiony=$global:unitconversiony*-1
            }
            write-host -ForegroundColor green   $ascfile "Valid"
         #   $global:filecontents=( get-content $ascfile |select-object) |ForEach-Object {$_.TrimStart() -replace "\s{1,}" ,";"}
            return "Valid"
         } else {
            write-host -ForegroundColor red $ascfile "Unrecognised"
            return "Unrecognised"
        }
     } else {
            write-host -ForegroundColor red $ascfile "missing"

            return "Unrecognised"
     }
}
########################################################################################################################################################
########################################################################################################################################################

function Is-Numeric ($Value) {
    return $Value -match "^[\d\.]+$"
}
########################################################################################################################################################
########################################################################################################################################################

function checkBOMheader {
    param ($file)
    #check is ASUS Computer-Backup Data BOM
    $fileheader=( get-content $file |select-object -first 1).trim()
    If ($fileheader -eq "µØºÓ¹q¸£-³Æ¥÷¸ê®Æ" -or $fileheader -eq "µØºÓ¹q¸£ªÑ¥÷¦³­­¤½¥q") { # gibberish = 華碩電腦-備份資料 /華碩電腦股份有限公司
        write-host -ForegroundColor green $file.name "Valid"
        return "Valid"
    } else {
        write-host -ForegroundColor red $file.name "Unrecognised"
        return "Unrecognised"
    }
}
########################################################################################################################################################
########################################################################################################################################################

function convertx {
    Param([decimal]$num)
    $num=($num * $unitconversionx)   # convert units
    return $num
}
########################################################################################################################################################
########################################################################################################################################################

function converty {
    Param([decimal]$num)
    $num=($num * $unitconversiony)   # convert units
    return $num
}
########################################################################################################################################################
########################################################################################################################################################


#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM
 # For "ASUS Computer-Backup Data" (華碩電腦-備份資料 o) BOM files from approximately y2k
 # Unlikely to work with others. Might not even work with other versions of this
function readbom {
    Param(
        $bomfile
    )
    # Step 1, skip all the headers leaving mostly just the data
    $bom1=@()
    $skip="on"
    $bomcontents=(gc $bomfile ) 
    # Skip everything between a line containing one space, and the dashed header line. Last 2 ifs must be in that order. Skip is off to start with to skip the first header.
    foreach ($line in $bomcontents) {
        if ($line -eq " ") { 
            $skip2="on"
        }
        if ($line -eq "---- ----------------------- -- ---- ----------- -------- ----------------------") {
            $skip2="next"
        }
        if ($skip2 -eq "off" -and $line -ne ""){ #skip blanks too
            $bom1 +=$line
        }
        if ($skip2 -eq "next"){
            $skip2 = "off"
        }
    }

    # step 2...
    # it would be easy to just take the 3 lines after a number header, but of course some take many lines to list the component names.
    $count=0
    $UnitDetails=$null
    $unit=$null
    $ComponentType=$null
    $ListNumber=$null
    $skip2="off"
    $bom2=@()
    $line2="ListNumber;ComponentType;ComponentCount;UnitDetails;UnitID"
    $bom2 +=$line2
    $line2=$null

    foreach ($line in $bom1) {
            # if first 4 chars = integer, start a new line
            if ("true" -eq (Is-Numeric ($line.SubString(0,4).trim()))) {
                $bom2 +=$line2
                $count=1
            }
            # if hit qvl/marking line end the line until next in the list
            if ($count -eq 3 ) {
                if ($line.Substring(0,9)  -eq "     QVL:" -or $line.Substring(0,13)  -eq "     MARKING:") { 
                    $count=0
                    $skip2="on"
                } else {
                    #Get the details if they're on this line
                    $len=$line.length
                    If ($len -gt 41) {
                        $UnitDetails=($line.SubString(4,40).trim())
                        $unit=($line.SubString(41).trim())
                    }
                    $UnitDetails=$UnitDetails.Trim() 
                    $unit=$unit.trim()
                    #If ( $UnitDetails -ne "") {
                    #    $UnitDetails="$UnitDetails"
                    #}
                    $line2="$line2;$UnitDetails;"#;x$unit"
                    $count=$count+1
                }
            }
            #I probably should have put this above the last one, but it's working for whatever reason
            if ($count -gt 3 ) {
                if ($line.Substring(0,9)  -eq "     QVL:" -or $line.Substring(0,13)  -eq "     MARKING:") { 
                        $count=0
                        $skip2="on"
                } else { 
                    $len=$line.length
                    If ($len -gt 41) {
                        $UnitDetails=($line.SubString(4,40).trim())
                        $unit=($line.SubString(41).trim())
                    }
                    #$UnitDetails=$UnitDetails.Trim() 
                    $unit=$unit.trim()
                    #If ( $UnitDetails -ne "") {
                    #    $UnitDetails="$UnitDetails"
                    #}
                    $line2="$line2$unit"
                    $count=$count+1
                }               
                            
            }
            if ($count -eq 2 -and $skip2 -eq "off") {
                $ComponentType=($line.SubString(5,30).trim())
                $line2="$ListNumber;$ComponentType;$ComponentCount"
                $count=3
            }
            if ($count -eq 1 ) { 
                $skip2="off"
                $ListNumber = ($line.SubString(0,4).trim())
                $data2= ($line.SubString(5,24).trim())
                $data3 =($line.SubString(30,6).trim())
                $ComponentCount= ($line.SubString(36,7).trim())
                $count=2
            }
    
    }
    #write last line
    $bom2 +=$line2
    #fix unicode +/-
    $bom2=$bom2 |ForEach-Object { $_ -replace "¡Ó" ,"+/-"}
        #Uncomment for fil;e
        #$bom2 | Out-File .\bom2.txt

    #step3
    $bom2= $bom2 |convertfrom-csv -Delimiter ";" #|Format-Table
    $bom3=@()
    $outline="UnitID;ListNumber;ComponentType;UnitDetails"
    $bom3+=$outline

    #$bom2 |convertfrom-csv -Delimiter ";"|Format-Table
    Foreach ($line in $bom2) {
        $col1=$line.listnumber
        $col2=$line.componenttype
        # $col3=$line.ComponentCount
        $col4=$line.unitdetails
        $units =$line.unitid.split(",")
         
        Foreach ($unit in $units) {
            if ($unit -ne ""){
            #add 0 to parts not ending in a number because kicad requires a number
                $part=$unit
                $plength=$part.length
                if (-not ("true" -eq (Is-Numeric ($part.substring(($plength-1),1))))) {
                    $unit=$part+"0"
                }
                $outline= "$unit;$col1;$col2;$col4"
                $bom3+=$outline

            }
        }
        
    }
    $bom3= $bom3 |convertfrom-csv -Delimiter ";"
    return $bom3
    
}  #BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM#BOM
########################################################################################################################################################
########################################################################################################################################################


#nettable#nettable#nettable#nettable#nettable#nettable#nettable#nettable#nettable
Function GetNettable {
    Param(
        $ascfile,
        $headerlines
    )
    #get the file directly, replace multiple spaces with commas
    $netslist= (gc $ascfile |select-object -skip $headerlines )  |ForEach-Object {$_.TrimStart() -replace "\s{1,}" ,","}
    # set up a table for all the nets. No real idea if we need it this way, but it should be easier...
    $table=@()
    #Populate the table
    foreach ($line in $netslist) {
       If ($line -like '#*') {
            # take the header line
            $Netnumtemp,$Nettypetemp,$netnametemp=($line).split(",").trim()
            #get rid of hash
            $netnumtemp=$Netnumtemp -replace ("#","")
            #replace (S) / (p) with signal/power
            If ($nettypetemp -eq "(P)") { $nettypetemp="power_in"}
            If ($nettypetemp -eq "(S)") { $nettypetemp="bidirectional"}
        } Else {
         #write the header and details to table - ignoring blanks
           if ($line -ne ""){
               $unitpintemp=($line).trim()
               #add 0 to parts not ending in a number because kicad requires a number 
               $part,$pin = ($unitpintemp).split(".")
               $ulength=$part.length
               #add 0 to unnumbered parts because kicad can only work with soemthign ending in a digit
               if (-not ("true" -eq (Is-Numeric ($part.substring(($ulength-1),1))))) {
                    $unitpintemp="$part"+"0."+$pin
               }
               $row = New-Object PSObject -Property @{
                    'Netnum'=$netnumtemp;
                    'UnitAndPin'=$unitpintemp;
                    'Nettype'=$nettypetemp;
                    'netname'=$netnametemp;
                } 
           $table += $row
           }
        }   #endir
    }   #endforeach
    return $table
}
########################################################################################################################################################
########################################################################################################################################################

#if the nets file is missing, we have the technology, we can rebuild it
Function Buildnettable {
    $pinslist= (gc $pinsfile |select-object -skip $pinsheaderlines )  |ForEach-Object {$_.TrimStart() -replace "\s{1,}" ,";"}
    #make pinstable
    #fill pintable
    $count=0
    $lastnet=$null
    $table=@()
    foreach ($line in $pinslist) {
        if ($line.trim() -ne "" ) {
           If ($line -like 'Part*') {
                # take the header line
                $junk,$Part,$FrontOrBack=($line).split(";").trim()
                #add 0 to parts not ending in a number because kicad requires a number
                $plength=$part.length
                if (-not ("true" -eq (Is-Numeric ($part.substring(($plength-1),1))))) {
                    $part="$part"+"0"
                }
            } Else {
                #write the header and details to table - ignoring blanks
                if (($line.trim()) -ne $null){
                    $Pintemp,$nametemp,[decimal]$x,[decimal]$y,$layertemp,$nettemp,$junk=($line).split(";").trim()
                    $row = New-Object PSObject -Property @{
                        'Netnum'=[string]$count;
                        'UnitAndPin'=$part+"."+$pintemp;
                        'Nettype'="unspecified";
                        'netname'=$nettemp;
                    } 
                    $table+=$row
                    $count=$count+1    
                }
            }
        }
    }
    return $table
}
########################################################################################################################################################
########################################################################################################################################################


#get a rectangle from the format file
function GetBoardOutline {
    param ($file, 
    $headerlines)
    #write-host $ascfile
    #pause
    $filecontents=( get-content $file |select-object) |ForEach-Object {$_.TrimStart() -replace "\s{1,}" ,";"}
    # turn the xy data into csv table
    $boardoutline=convertfrom-csv $filecontents -header X,Y,Rot -Delimiter ";" |select-object -skip $headerlines
    #ASC uses 5 points to draw a rectangle. kicad uses rectangles with 2 points
    #convert to mm if req'd while we're here
    $boardMaxX=convertx(($boardoutline.x |measure -Maximum).Maximum)
    $boardMaxY=converty(($boardoutline.y |measure -Maximum).Maximum)
    $boardMinX=convertx(($boardoutline.x |measure -Minimum).Minimum)
    $boardMinY=converty(($boardoutline.y |measure -Minimum).Minimum)
    return '(gr_rect(start ' + $boardMaxX+' '+$boardMaxY + ') (end ' +$boardMinX+' '+$boardMinY +')(stroke(width 0.2)(type default))(fill none)(layer "Edge.Cuts")))'
}
########################################################################################################################################################
########################################################################################################################################################


function Getpartslist {
    param ($file, 
        $headerlines)
    #Write-host Reading $file
    $filecontents=( get-content $file |select-object) |ForEach-Object {$_.TrimStart() -replace "\s{1,}" ,";"}
    # turn the xy data into csv table
    $Partslist=convertfrom-csv $filecontents -delimiter ";"  -header Part,X,Y,Rot,Grid,FrontOrBack,Device, Outline |select-object -skip $headerlines | ForEach {
        [pscustomobject]@{
            part=$_.part -as [string]
            x = (convertx( $_.x )) -as [decimal]
            y =  (converty($_.y )) -as [decimal]       
            rot = $_.rot -as [int]
            Grid=$_.Grid  -as [string]
            FrontOrBack=$_.FrontOrBack -as [string]
            Device=$_.Device  -as [string]
            Outline=$_.Outline -as [string]
            Type="unknown" -as [string]
            Reference="U" -as [string]
            symbol="" -as [string]
             symbol2="" -as [string]
            Size=0 -as [int]
            Symboldata=""
            unitcount=""
            Guid=New-Guid
            pincount=0
        }
    }
    foreach ($line in $partslist) {
        #add 0 to parts not ending in a number because kicad requires a number
        $part=$line.part
        $plength=$part.length
        if (-not ("true" -eq (Is-Numeric ($part.substring(($plength-1),1))))) {
            $line.part="$part"+"0"
        }

        If ($line.Outline -eq $null){
            $line.device,$line.outline=$line.device.split(",").trim()
        }
        $line.device=$line.device -replace "'", "" -replace ",",""
        $line.outline=$line.outline -replace "'", "" -replace ",",""
        If ($line.FrontOrBack -eq "(T)") { 
            $line.FrontOrBack="F"
        }
        If ($line.FrontOrBack -eq "(B)") { 
            $line.FrontOrBack="B"
        }
    }
    return $partslist
}
########################################################################################################################################################
########################################################################################################################################################

Function GetPinsTable {
    param (
        $file,
        $headerlines,
        $nettable
    )
    #Write-host Reading $file
    $pinslist= (gc $file |select-object -skip $headerlines )  |ForEach-Object {$_.TrimStart() -replace "\s{1,}" ,";"}
    #make pinstable
    $pinstable=@() 
  
    #fill pintable
    foreach ($line in $pinslist) {
        If ($line -like 'Part*') {
            # take the header line
            $junk,$Part,$FrontOrBack=($line).split(";").trim()
            #add 0 to parts not ending in a number because kicad requires a number
            $plength=$part.length
            if (-not ("true" -eq (Is-Numeric ($part.substring(($plength-1),1))))) {
                $part="$part"+"0"
            }
            #replace (T) / (B) with f or b
            If ($FrontOrBack -eq "(T)") { $FrontOrBack="F"}
            If ($FrontOrBack -eq "(B)") { $FrontOrBack="B"}
        } Else {
        #write the header and details to table - ignoring blanks
        if ($line -ne $null){
            $Pintemp,$nametemp,[decimal]$x,[decimal]$y,$layertemp,$nettemp,$junk=($line).split(";").trim()
            $x = (convertx($x))
            $y = (converty($y))
           # $nettemp=$nettemp -replace ("#","")
            #create a new kicad compatible net for NC parts
            if ($nettemp -eq "(NC)" ) {
                $nettemp="NC-"+$part+"."+$pintemp
                
                $nettablecount=((($nettable.netnum |measure -Maximum).Maximum)+1)
                $netupdate = New-Object PSObject -Property @{
                    'UnitAndPin'=$part+"."+$pintemp;
                    'Netnum'=$nettablecount;
                    'Nettype'="unconnected";
                    'netname'=$nettemp;
                } 
                $nettable+= $netupdate
            }

            $row = New-Object PSObject -Property ([ordered]@{
                'pinid'="$part.$Pintemp"
                'Part'=$Part
                'FrontOrBack'=$FrontOrBack
                'Pin'=$Pintemp;
                'Name'=$nametemp;
                'X'=$x ;
                'Y'=$y ;
                'layer'=$layertemp
                'net'=$nettemp;
                'GUID'=New-Guid
            } )
            #skip partial lines
            if ($Pintemp -ne "") {
                $pinstable += $row
            }
        }
    }
}
    return $pinstable, $nettable
}

########################################################################################################################################################
########################################################################################################################################################


function checkallheaders {
    param (
        $formatfile, 
        $formatheaderstring, 
        $partsfile, 
        $partsheaderstring,
        $netsfile, 
        $netsheaderstring,
        $pinsfile, 
        $pinsheaderstring
    )
       #format
    $formatok=(checkheader $formatfile $formatheaderstring)
    #parts
    $partsok=(checkheader $partsfile $partsheaderstring)
    #nets
    $netsok=(checkheader $netsfile $netsheaderstring)
    #pins
    $pinsok=(checkheader $pinsfile $pinsheaderstring)
    #bom
    $bomfile=$null
    Write-Host "Finding BOM"
    foreach ($file in Get-ChildItem .\*.bom) {
        $BOMok=(checkBOMheader $file)
        if ($bomok -eq "Valid") {
            $bomfile=$file
        } 
    }
    return $formatok, $partsok, $netsok, $pinsok, $BOMok, $bomfile
}
########################################################################################################################################################
########################################################################################################################################################


Function AddNetsToPinstable {
    Param (
        $nettable,
        $Pinstable
    )
    $netMap = @{}; foreach ($nets in $nettable) { $netMap[$nets.netname] = $nets }

    Foreach ($pin in $pinstable) {
           #$owner = $ownerMap[$pet.Owner]
            $netid = $netMap[$pin.net]
            if ($netid) {
                Add-Member -InputObject $pin netnum $netid.Netnum -force
                Add-Member -InputObject $pin pwr $netid.nettype -force
          <#  } else {
                Write-Host $netid failed
                pause
                $nettable
                pause
                $pinstable
                pause #>
            }
    }
    return $pinstable
}

########################################################################################################################################################
########################################################################################################################################################

function BuildUnitTable {
    #the individual kicad symbols
    param ($pinstable, $partid)
    $unit=@()
    foreach ($pin in $pinstable) {
        $pinpart=$pin.part
        if ($pinpart -eq $partid) {
            $pinname=$pin.name
            $pinnum=$pin.pin
            $net=$pin.net
            $pwr=$pin.pwr
            $row = New-Object PSObject -Property ([ordered]@{
                'net'=$net;
                'pinname'=$pinname;
                'pinnum'=[int]$pinnum
                'Part'=$pinpart;
                'pwr'=$pwr
                'side'=$null
                'sidecount'=$null
                'x'=$null
                'y'=$null
                # 'sortingnet'=$sortingnet
                } )
            $unit+=$row
        }
    }
    #11/2 net v pinnum
    #$unit=$unit| Sort-Object -Property net
    $unit=$unit| Sort-Object -Property pinnum

    Return $unit
}

########################################################################################################################################################
########################################################################################################################################################



Write-Host Checking file headers
$formatok, $partsok, $netsok, $pinsok, $BOMok, $bomfile=(checkallheaders $formatfile $formatheaderstring $partsfile $partsheaderstring $netsfile $netsheaderstring $pinsfile $pinsheaderstring)


Write-Host
Write-Host ----------------------------------------
Write-Host "Board name:   $boardname"
Write-Host "Board Date:   $boarddate"
Write-Host "Board Units:  $boardunits"
Write-Host ----------------------------------------
Write-Host 
Write-Host $formatfile $formatok
Write-Host $partsfile $partsok
Write-Host $netsfile $netsok
Write-Host $pinsfile $pinsok
Write-Host $bomfile.name  $bomok
Write-Host





##PATH##PATH##PATH##PATH##PATH##PATH##PATH##PATH##PATH##PATH##PATH##PATH##PATH

$outfile=$null
$curdir = Get-Location 
$curdir="$curdir\"
if ($global:boardname -ne "") {
    $defaultoutfile=$curdir+$global:boardname+$fileextension
    $footprintpath=$curdir+$global:boardname+"-extracts.pretty"
} else {
    $defaultoutfile=$curdir+"UnknownBoard"+$fileextension 
    $footprintpath=$curdir+"UnknownBoard-extracts.pretty"
}

$symbolpath=$curdir+"Symbols"


Write-host "Output path            : " $curdir
Write-host "Output Footprint path  : " $footprintpath
Write-host "Output symbol path     : " $symbolpath
Write-host "Output PCB filename    : " $global:boardname$fileextension
Write-host
if (-not (Test-Path ("$footprintpath"))) {
    New-Item -Path "$footprintpath" -ItemType directory 
}
if (-not (Test-Path ("$symbolpath"))) {
    New-Item -Path "$symbolpath" -ItemType directory 
}
$outfile=$defaultoutfile


# Format.asc to kicad_pcb ie the edge cuts outline
if ($formatok -eq "Valid") {
    Write-Host Reading $formatfile
    $pcbedge=(GetBoardOutline $formatfile $formatheaderlines)
}else {
    Write-Host -ForegroundColor red "Unrecognised format.asc"
}


#bom
if ($bomok -eq "Valid") {
    Write-Host Reading $bomfile.name
    $bom=(readbom $bomfile)
} else {
    Write-Host -ForegroundColor red "It will work without a BOM file, but no component values will exist"
    Write-host "No BOM file. Skipping BOM"
}
 

########################################################################
#parts
if ($partsok -eq "Valid") {
    Write-Host Reading $Partsfile
    $Partslist=(getpartslist $partsfile $partsheaderlines)
} else {
    Write-Host -ForegroundColor red "FATAL. Unrecognised $partsfile"
    exit
}


########################################################################
#nets

if ($netsok -ne "Valid" ) {
        Write-Host -ForegroundColor red "Invalid $netfile. Rebuilding."
        $nettable=(Buildnettable)
       # write-host blah$nettable
       # pause
} else {
    Write-host Reading $netsfile
    $nettable=(GetNettable $netsfile $netsheaderlines)
}


#pins
if ($pinsok -ne "Valid") {
  Write-Host -ForegroundColor red "FATAL. Unrecognised $pinsok"
  pause
  exit
} else {
    #make the pinstable and update the nettable for NC pins
    Write-Host Reading $pinsfile
    $pinstable, $nettable=(GetPinstable $pinsfile $pinsheaderlines $nettable)
}


#add net details to pinstable
$pinstable=(AddNetsToPinstable $nettable $Pinstable)



#######################


#update partslist with bom details
Foreach ($part in $Partslist) {
    $id=$part.part
    Foreach ($item in $bom) {
        $value=$item.componenttype
        $Uid=$item.unitid
        if ($id -eq $uid) {
            $part.device=$value
        }
    }
}


#remove things not found in BOM
$notinbom=@()
Foreach ($part in $Partslist) {
    if ($part.device.trim() -eq $part.Outline.trim()) {
        $part.device="NotInBom"
        $notinbom +=$Part
    }
}

$notinbom |Format-Table

Write-host "The above were not found in the BOM."
Write-host "They may be missing or not installed on this model"

#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD
#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD
#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD#KICAD

Write-host  "Writing PCB and footprints"

$kicadpcbheader='(kicad_pcb(version 20240108)(generator "pcbnew")(generator_version "8.0")(paper "A2" portrait)'
$kicadfontboilerplate="(effects(font(size 1.27 1.27)(thickness 0.15))))"
$devicefooter=")"
$devicesout=@()
$kicadNetslist=@()


foreach ($net in $nettable) {
    $exists=0
    $netno=$net.netnum
    $netno=$netno -replace("#","")
    $netname=$net.netname
    foreach ($item in $kicadNetslist){
        $templine='(net '+$netno+ ' "'+$netname+'")'
        if ($item -eq $templine) {
            $Exists=1
            continue
        }
    }
    if ($exists -eq 0 -and $netno -ne "") {
        $outline='(net '+$netno+ ' "'+$netname+'")'
        $kicadNetslist +=$outline
    }
}


<#might disable this...
function updatesymbols {
    param ($partslist)
#might not be needed
    foreach ($item in $partslist) {
        $id, $junk=$item.part -split '(?<=\D)(?=\d)',2
            Switch ($id) {
            "R" {  $item.type="Resistor"
                $item.reference=$id 
            #    $item.symbol='(symbol "Device:R"(pin_numbers hide)(pin_names(offset 0))(exclude_from_sim no)(in_bom yes)(on_board yes)(property "Reference" "R"(at 2.032 0 90)(effects(font(size 1.27 1.27))))(property "Value" "R"(at 0 0 90)(effects(font(size 1.27 1.27))))(property "Footprint" ""(at -1.778 0 90)(effects(font(size 1.27 1.27))(hide yes)))(property "Datasheet" "~"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "Description" "Resistor"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_keywords" "R res resistor"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_fp_filters" "R_*"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(symbol "R_0_1"(rectangle(start -1.016 -2.54)(end 1.016 2.54)(stroke(width 0.254)(type default))(fill(type none))))(symbol "R_1_1"(pin passive line(at 0 3.81 270)(length 1.27)(name "~"(effects(font(size 1.27 1.27))))(number "1"(effects(font(size 1.27 1.27)))))(pin passive line(at 0 -3.81 90)(length 1.27)(name "~"(effects(font(size 1.27 1.27))))(number "2"(effects(font(size 1.27 1.27)))))))'
                $item.symbol2="Device:R"
            }
            "C" {  $item.type="Capacitor"
                $item.reference=$id 
              #  $item.symbol='(symbol "Device:C"(pin_numbers hide)(pin_names(offset 0.254))(exclude_from_sim no)(in_bom yes)(on_board yes)(property "Reference" "C"(at 0.635 2.54 90)(effects(font(size 1.27 1.27))(justify left)))(property "Value" "C"(at 0.635 -2.54 90)(effects(font(size 1.27 1.27))(justify left)))(property "Footprint" ""(at 0.9652 -3.81 90)(effects(font(size 1.27 1.27))(hide yes)))(property "Datasheet" "~"(at 0 0 90)(effects(font(size 1.27 1.27))(hide yes)))(property "Description" "Unpolarized capacitor"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_keywords" "cap capacitor"(at 0 0 90)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_fp_filters" "C_*"(at 0 0 90)(effects(font(size 1.27 1.27))(hide yes)))(symbol "C_0_1"(polyline(pts(xy -2.032 -0.762) (xy 2.032 -0.762))(stroke(width 0.508)(type default))(fill(type none)))(polyline(pts(xy -2.032 0.762) (xy 2.032 0.762))(stroke(width 0.508)(type default))(fill(type none))))(symbol "C_1_1"(pin passive line(at 0 3.81 270)(length 2.794)(name "~"(effects(font(size 1.27 1.27))))(number "1"(effects(font(size 1.27 1.27)))))(pin passive line(at 0 -3.81 90)(length 2.794)(name "~"(effects(font(size 1.27 1.27))))(number "2"(effects(font(size 1.27 1.27)))))))' 
                $item.symbol2="Device:C"
            }
            "U" {  $item.type="Unit";$item.reference=$id }
            "D" {  $item.type="Diode";$item.reference=$id }#; $item.symbol2="Device:R" }
            "Q" {  $item.type="Transistor";$item.reference=$id }
            "L" {  $item.type="Ferrite" ;$item.reference=$id ; $item.symbol2="Device:L_Ferrite" }
            "Fuse" {  $item.type="Fuse" ;$item.reference=$id ; $item.symbol2="Device:Fuse" }
       
                   "RV" {  $item.type="Resistor";$item.reference=$id                 
              #  $item.symbol='(symbol "Device:R"(pin_numbers hide)(pin_names(offset 0))(exclude_from_sim no)(in_bom yes)(on_board yes)(property "Reference" "R"(at 2.032 0 90)(effects(font(size 1.27 1.27))))(property "Value" "R"(at 0 0 90)(effects(font(size 1.27 1.27))))(property "Footprint" ""(at -1.778 0 90)(effects(font(size 1.27 1.27))(hide yes)))(property "Datasheet" "~"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "Description" "Resistor"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_keywords" "R res resistor"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_fp_filters" "R_*"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(symbol "R_0_1"(rectangle(start -1.016 -2.54)(end 1.016 2.54)(stroke(width 0.254)(type default))(fill(type none))))(symbol "R_1_1"(pin passive line(at 0 3.81 270)(length 1.27)(name "~"(effects(font(size 1.27 1.27))))(number "1"(effects(font(size 1.27 1.27)))))(pin passive line(at 0 -3.81 90)(length 1.27)(name "~"(effects(font(size 1.27 1.27))))(number "2"(effects(font(size 1.27 1.27)))))))'
                $item.symbol2="Device:R"
            }
            "TP" {  $item.type="Test Point" ;$item.reference=$id }
            "CN" {  $item.type="Capacitor Network" ;$item.reference=$id }
     #       "BC" {  $item.type="Capacitor" ;$item.reference=$id ; $item.footprint="Device:C_Polarised" }
          #  "LU" {  $item.type="Ferrite" ;$item.reference=$id }

            "CB" {  $item.type="Capacitor" ;$item.reference=$id  
             #   $item.symbol='(symbol "Device:C"(pin_numbers hide)(pin_names(offset 0.254))(exclude_from_sim no)(in_bom yes)(on_board yes)(property "Reference" "C"(at 0.635 2.54 0)(effects(font(size 1.27 1.27))(justify left)))(property "Value" "C"(at 0.635 -2.54 0)(effects(font(size 1.27 1.27))(justify left)))(property "Footprint" ""(at 0.9652 -3.81 0)(effects(font(size 1.27 1.27))(hide yes)))(property "Datasheet" "~"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "Description" "Unpolarized capacitor"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_keywords" "cap capacitor"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_fp_filters" "C_*"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(symbol "C_0_1"(polyline(pts(xy -2.032 -0.762) (xy 2.032 -0.762))(stroke(width 0.508)(type default))(fill(type none)))(polyline(pts(xy -2.032 0.762) (xy 2.032 0.762))(stroke(width 0.508)(type default))(fill(type none))))(symbol "C_1_1"(pin passive line(at 0 3.81 270)(length 2.794)(name "~"(effects(font(size 1.27 1.27))))(number "1"(effects(font(size 1.27 1.27)))))(pin passive line(at 0 -3.81 90)(length 2.794)(name "~"(effects(font(size 1.27 1.27))))(number "2"(effects(font(size 1.27 1.27)))))))' 
                $item.symbol2="Device:C"
            }
            "CC" {  $item.type="Capacitor" ;$item.reference=$id  
              #  $item.symbol='(symbol "Device:C"(pin_numbers hide)(pin_names(offset 0.254))(exclude_from_sim no)(in_bom yes)(on_board yes)(property "Reference" "C"(at 0.635 2.54 0)(effects(font(size 1.27 1.27))(justify left)))(property "Value" "C"(at 0.635 -2.54 0)(effects(font(size 1.27 1.27))(justify left)))(property "Footprint" ""(at 0.9652 -3.81 0)(effects(font(size 1.27 1.27))(hide yes)))(property "Datasheet" "~"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "Description" "Unpolarized capacitor"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_keywords" "cap capacitor"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_fp_filters" "C_*"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(symbol "C_0_1"(polyline(pts(xy -2.032 -0.762) (xy 2.032 -0.762))(stroke(width 0.508)(type default))(fill(type none)))(polyline(pts(xy -2.032 0.762) (xy 2.032 0.762))(stroke(width 0.508)(type default))(fill(type none))))(symbol "C_1_1"(pin passive line(at 0 3.81 270)(length 2.794)(name "~"(effects(font(size 1.27 1.27))))(number "1"(effects(font(size 1.27 1.27)))))(pin passive line(at 0 -3.81 90)(length 2.794)(name "~"(effects(font(size 1.27 1.27))))(number "2"(effects(font(size 1.27 1.27)))))))' 
                $item.symbol2="Device:C"
            }
            "CT" {  $item.type="Capacitor" ;$item.reference=$id  
               # $item.symbol='(symbol "Device:C"(pin_numbers hide)(pin_names(offset 0.254))(exclude_from_sim no)(in_bom yes)(on_board yes)(property "Reference" "C"(at 0.635 2.54 0)(effects(font(size 1.27 1.27))(justify left)))(property "Value" "C"(at 0.635 -2.54 0)(effects(font(size 1.27 1.27))(justify left)))(property "Footprint" ""(at 0.9652 -3.81 0)(effects(font(size 1.27 1.27))(hide yes)))(property "Datasheet" "~"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "Description" "Unpolarized capacitor"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_keywords" "cap capacitor"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "ki_fp_filters" "C_*"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(symbol "C_0_1"(polyline(pts(xy -2.032 -0.762) (xy 2.032 -0.762))(stroke(width 0.508)(type default))(fill(type none)))(polyline(pts(xy -2.032 0.762) (xy 2.032 0.762))(stroke(width 0.508)(type default))(fill(type none))))(symbol "C_1_1"(pin passive line(at 0 3.81 270)(length 2.794)(name "~"(effects(font(size 1.27 1.27))))(number "1"(effects(font(size 1.27 1.27)))))(pin passive line(at 0 -3.81 90)(length 2.794)(name "~"(effects(font(size 1.27 1.27))))(number "2"(effects(font(size 1.27 1.27)))))))' 
                $item.symbol2="Device:C"
            }
            "CE" {  $item.type="Capacitor Electrolytic" ;$item.reference=$id ; $item.symbol2="Device:C_Polarized" }

            "RN" {  $item.type="Resistor Network" ;$item.reference=$id }
            "RP" {  $item.type="Resistor Pack" ;$item.reference=$id 
           # write-host blah $item.pincount
          #  pause 
                switch ($item.pincount) {
                    "8" { $item.symbol2="Device:R_Pack04"}
                    "10" { $item.symbol2="Device:R_Pack05"}
                }
                        
    }
        } 

    }
return $partslist
}#>


#Write!#Write!#Write!#Write!#Write!#Write!#Write!#Write!#Write!#Write!#Write!#Write!#Write!

#Write PCB and footprints#Write PCB and footprints#Write PCB and footprints#Write PCB and footprints#Write PCB and footprints
#Write PCB and footprints#Write PCB and footprints#Write PCB and footprints#Write PCB and footprints#Write PCB and footprints
$Writtenfootprints=@()
$libraryout=$null
[decimal]$bordersize=.6

foreach ($item in $partslist) {
    $PARTID=$item.part
    $partxraw=[decimal]$item.x
    $partyraw=[decimal]$item.y
    $partx=$partxraw
    $party=$partyraw
    $PartRotation=$item.rot
    $type=$item.type
    $FrontOrBack=$item.FrontOrBack
    $pdevice=$item.device
    $poutline=$item.outline

    $Footprintfile="\"+$poutline+".kicad_mod"

        #kicad isn't like a compass. if zero is up, 90degrees is anticlockwise -90 is clockwise - but we still need the original value
    switch ($PartRotation) {
        "0" {$PartRotation2=$PartRotation }
        "90" {$PartRotation2="-90"}
        "180"{$PartRotation2=$PartRotation}
        "270" { $PartRotation2="90" }
    }

    #Apparently the first at coordinate is the DEVICE centroid. All the pins in the footprint are relative to it.
    $deviceheader='(footprint "' +$poutline+ '"(layer "'+$frontorback+'.Cu")(at ' +$partX+ ' ' +$partY+ ' '+$PartRotation2+')(descr "' +$pdevice+ '")(property "Reference" "' +$PARTID+ '"(at 0 0 '+$PartRotation2+')(layer "'+$frontorback+'.SilkS")' +$kicadfontboilerplate+ '(property "Value" "' +$pdevice+ '"(at 0 0 '+$PartRotation2+')(layer "'+$frontorback+'.Fab")' +$kicadfontboilerplate+ '(property "Footprint" "' +$poutline+ '"(at 0 0 '+$PartRotation2+')(unlocked yes)(layer "'+$frontorback+'.Fab")(hide yes)' +$kicadfontboilerplate+'(property "Datasheet" "Extracted from'+$boardname +'"(at 0 0 0)(effects(font	(size 1.27 1.27))(hide yes)))(property "Description" "'+$pdevice+'"(at 0 0 '+$PartRotation2+')(unlocked yes)(layer "'+$frontorback+'.Fab")(hide yes)'+$kicadfontboilerplate
    $footprintheader='(footprint "' +$poutline+ '"(layer F.Cu")(at 0 0 0)(descr "' +$pdevice+ '")(property "Reference" "REF**"(at 0 0 0)(layer F.SilkS")' +$kicadfontboilerplate+ '(property "Value" "' +$poutline+ '"(at 0 0 0)(layer F.Fab")' +$kicadfontboilerplate+ '(property "Footprint" "' +$poutline+ '"(at 0 0 0)(unlocked yes)(layer "'+$frontorback+'.Fab")(hide yes)' +$kicadfontboilerplate+'(property "Datasheet" "Extracted from'+$boardname +'"(at 0 0 0)(effects(font	(size 1.27 1.27))(hide yes)))(property "Description" "'+$pdevice+'"(at 0 0 0)(unlocked yes)(layer F.Fab")(hide yes)'+$kicadfontboilerplate

    $devicesout+=$deviceheader#+$newline
    $footprintout=$footprintheader
    [decimal]$minx =500000.0
    [decimal]$miny =500000.0
    [decimal]$maxx =-500000.0
    [decimal]$maxy =-500000.0

    foreach ($pin in $pinstable) {
        $pinpart=$pin.part
        If ($PARTID -eq $pinpart) {
            #the pins are already rotated. We have to unrotate them to zero so they can be rotated again automatically by kicad.
            #why bother? So footprints can be changed!
            #kicad does things weird. if zero is up, 90degrees is anticlockwise -90 is clockwise
            #We're also subtracting the device coordinates from the pin coordinates, which centers the pins around the device.
            switch ($PartRotation) {
                "0" {
                        $pinx=$pin.x-$partXraw
                        $piny=$pin.y-$partyraw
                }
                "90" { #swap x/y invertx
                        $piny=$pin.x-$partXraw
                        $pinx=$pin.y-$partyraw
                        $piny=$piny*-1
                }
                "180" { #invert x/y
                        $pinx=$pin.x-$partXraw
                        $piny=$pin.y-$partyraw
                        $pinx=$pinx*-1
                        $piny=$piny*-1
                }
                "270" { #swap x/y invertx
                        $piny=$pin.x-$partXraw
                        $pinx=$pin.y-$partyraw
                        $pinx=$pinx*-1
                }
            } #end switch ($PartRotation) {
            #Create boundary around pins, get bounds first
            if ($pinx -lt $minx) { $minx =$pinx }#; Write-Host minx  $id $x }
            if ($piny -lt $miny) { $miny =$piny }#; Write-Host miny $id $y  }
            if ($pinx -gt $maxx) { $maxx =$pinx }#; Write-Host maxx $id $x  }
            if ($piny -gt $maxy) { $maxy =$piny }#; Write-Host maxxy $id $y }

            # $pintopbot=$pin.FrontOrBack
            $pinno=$pin.pin
            $pinname=$pin.Name
            $layer=$pin.layer #smd/throughhole
            
            $pinnet=$pin.net
            $pinnetnum=$pin.netnum
            $pwr=$pin.pwr

            if ($layer -eq 0){ #throughhole
                $ICedge='    (attr through_hole)'+$newline
                $PAdsout='    (pad "'+$pinname+'" thru_hole circle (at '+$pinx+' '+$piny+')(size '+$defaultpadsize+')(drill '+$defaultholesize+')(layers "*.Cu" "*.Mask")(net '+$pinnetnum+' "'+$pinnet+'")(pinfunction "'+$pinnet+'")(pintype "'+$pwr+'"))'#+$newline

            }else{ #smd
                $ICedge='(attr smd)'
                $PAdsout='    (pad "'+$pinname+'" smd circle (at '+$pinx+' '+$piny+')(size '+$defaultpadsize+')(property pad_prop_bga)(layers "'+$frontorback+'.Cu" "'+$frontorback+'.Mask")(net '+$pinnetnum+' "'+$pinnet+'")(pinfunction "'+$pinnet+'")(pintype "'+$pwr+'"))'#+$newline
            }
            $pinsused+=$PARTID;
            $devicesout+=$padsout
            $footprintout+=$padsout
            continue
        } #end If ($PARTID -eq $pinpart) {
    } #end foreach ($pin in $pinstable) {

    #add a border to the boundary so it looks better
    $minx=$minx-$bordersize
    $miny=$miny-$bordersize
    $maxx=$maxx+$bordersize
    $maxy=$maxy+$bordersize

    $ICedge+='    (fp_rect (start '+$minx+' '+$maxy +  ') (end ' + $maxx+ ' '+$miny + ')(stroke(width 0.1)(type default))(fill none)(layer "'+$frontorback+'.CrtYd"))'

    $devicesout+=$icedge
    $devicesout+=$devicefooter

    $footprintout+=$padsout+ $newline+ $icedge+ $newline+ $devicefooter

    if ($Writtenfootprints -notcontains $poutline) {  #only write if it's not already written
        #Write-host "Writing $poutline $type footprint" 
         write-host Footprint $footprintfile
     #   write-host fpf $footprintpath
        $Footprintout | out-file ("$footprintpath"+"$Footprintfile") -encoding ascii
        $writtenfootprints+=$poutline
    }

} #end for





#$wholefile=$kicadpcbheader+$kicadNetslist+$devicesout+$pcbedge

$kicadpcbheader | out-file $outfile -encoding ascii
$kicadNetslist |Add-Content -Path $outfile
$devicesout|Add-Content -Path $outfile
$pcbedge |Add-Content -Path $outfile


#########Export symbols#############
#########Export symbols#############



Write-host "Exporting Symbols"
$Writtensymbols=@()
#$unitheader=$NULL
$unitfooter=")))"
$libheader='(kicad_symbol_lib(version 20231120)(generator "myne")(generator_version "8.0")'
$schematicheader='(kicad_sch(version 20231120)(generator "eeschema")(generator_version "8.0")(paper "A0")(lib_symbols'
$schematic=$schematicheader
$libraryout=$libheader
$kicadspacing=2.54

foreach ($item in $partslist) {
    $PARTID=$item.part
    $footprint=$item.footprint
            #    If ($footprint -eq "") { #if we haven't assigned a generic footprint, export it
            #    $type=$item.Type
            #    If ($type -like "U*") {
        
        $outline=$item.outline
        if ($Writtensymbols -notcontains $outline) {  #only write if it's not already written
            $partdesc=$item.device
            $reference=$item.reference
            
            $unitheader='(symbol "'+$outline +'"(pin_names(offset 1.016))(exclude_from_sim no)(in_bom yes)(on_board yes)(property "Reference" "'+$reference+'"(at 0 0 0)'+$kicadfontboilerplate+'(property "Value" "'+$partdesc +'"(at 0 0 0)'+$kicadfontboilerplate+'(property "Footprint" "'+$outline+  '"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))(property "Description" "'+$partdesc +'"(at 0 0 0)(effects(font(size 1.27 1.27))(hide yes)))'
            $unitout=$unitheader+$newline
            $libraryout+=$newline+$unitheader
            $schematic+=$newline+$unitheader
            $unit=(buildunittable $pinstable $partid)



            $ucount=$unit.count
            if ($ucount -gt 150) {
                [int]$persidecount=1+$ucount/4 #the +1 is just to avoid rounding too low
              } else {
                    $persidecount=1+$ucount/2
            }
  
            $pinlength=3.81
            $sidelength=$persidecount*$kicadspacing
            $disttozero=$sidelength/2
            $leftx=$disttozero*-1-($kicadspacing*6)
            $Rightx=$disttozero+($kicadspacing*6)
            $Righty=$disttozero
            $lefty=$disttozero
            $topx=$disttozero
            $bottomx=$disttozero
            <#10/2 off
            $topy=$disttozero+($kicadspacing*6)
            $bottomy=$disttozero*-1-($kicadspacing*6)#>
            #10/2 on
            if ($ucount -gt 150) {
                    $topy=$disttozero+($kicadspacing*6)
                    $bottomy=$topy*-1
                    #10/2 on
              } else {
                                    #10/2 on
                    $topy=12.7
                    $bottomy=-12.7
                    #10/2 on
            }            
            $ucount=$unit.Count
            $item.pincount=$ucount
            if ($ucount -gt 150) {
                [int]$persidecount=1+$ucount/4 #the +1 is just to avoid rounding too low
                #10/2 on
                $topy=$disttozero+($kicadspacing*6)
                #10/2 on
            } else {
                $persidecount=1+$ucount/2
                #10/2 on
                $topy=25.4+($kicadspacing*6)
                #10/2 on
            }

            $pinlength=3.81
            $sidelength=$persidecount*$kicadspacing
            $disttozero=$sidelength/2
            $leftx=$disttozero*-1-($kicadspacing*6)
            $lefty=$disttozero
            $Rightx=$disttozero+($kicadspacing*6)
            $Righty=$disttozero
            $topx=$disttozero
<#10/2 off
            $topy=$disttozero+($kicadspacing*6)
#>
            $bottomx=$disttozero
            $bottomy=$disttozero*-1-($kicadspacing*6)
            $leftcount=1
            $bottomcount=1
            $topcount=1
            $rightcount=1
            $rowcount=1

            $part.size=($sidelength+($kicadspacing*10))


            $rect='    (symbol "'+$outline+'_0_1"(rectangle(start ' +($Rightx-$pinlength)+' '+($topy-$pinlength)+')(end '+ ($leftx+$pinlength)+' '+($bottomy+$pinlength) +')(stroke(width 0)(type default))(fill(type background))))'

            $unitout+=$newline+$rect
            $libraryout+=$newline+$rect

            foreach ($row in $unit) {
                    $net=$row.net
                    $pinname=$row.pinname
                    #$pinnum=
                  #  $x=$row.x
                   # $y=$row.y
                    $net=$row.net
                    $pwr=$row.pwr
                if ($ucount -gt 150) {
                    switch ($rowcount) {
                        {$PSItem -le $persidecount} { 
                            $row.side="left"
                            $row.sidecount=$leftcount
                            $leftcount=$leftcount+1 
                            $sideorientation=0
                            [decimal]$row.x=$leftx
                            [decimal]$row.y=$lefty-($kicadspacing*$leftcount)
                        }
                        {$PSItem -gt $persidecount}{ 
                            $row.side="bottom"
                            $row.sidecount=$bottomcount
                            $bottomcount=$bottomcount+1
                            $sideorientation=90 
                            [decimal]$row.x=$bottomx-($kicadspacing*$bottomcount)
                            [decimal]$row.y=$bottomy
                        }
                        {$PSItem -gt $persidecount*2}
                            { $row.side="right"
                            $row.sidecount=$rightcount
                            $rightcount=$rightcount+1
                            $sideorientation=180 
                            [decimal]$row.x=$rightx
                            [decimal]$row.y=$righty-($kicadspacing*$rightcount)
                        }
                        {$PSItem -gt $persidecount*3} { 
                            $row.side="top"
                            $row.sidecount=$topcount
                            $topcount=$topcount+1
                            $sideorientation=270 
                            [decimal]$row.x=$topx-($kicadspacing*$topcount)
                            [decimal]$row.y=$topy
                        }
                    }
                } else {
                    switch ($rowcount) {
                        {$PSItem -le $persidecount} { 
                            $row.side="top"
                            $row.sidecount=$topcount
                            $topcount=$topcount+1
                            $sideorientation=90 
                            [decimal]$row.x=$topx-($kicadspacing*$topcount)
                            [decimal]$row.y=$topy
                            }
                        {$PSItem -gt $persidecount} { 
                            $row.side="bottom"
                            $row.sidecount=$bottomcount
                            $bottomcount=$bottomcount+1
                            $sideorientation=270 
                            [decimal]$row.x=$bottomx-($kicadspacing*$bottomcount)
                            [decimal]$row.y=$bottomy
                        }
                    }
                }

                if ($unit.count -eq 370 -and $row.pinnum -eq 370) {
                    $row
                    pause
                }

                $rowcount++
                $LINE=$newline+'    (pin '+$PWR+ ' line (at '+$row.x+' '+$row.y+' '+$sideorientation+')(length '+$pinlength+' )(name "'+ $pinname +'"(effects (font(size 1.27 1.27))))(number "'+$pinnum +'"(effects(font(size 1.27 1.27)))))'
                
                $unitout+=$line
                $libraryout+=$line
                $schematic+=$line

         }  

        $unitout+=$unitfooter
        $libraryout+=$newline+")"
        $schematic+=$newline+")"
        $writtensymbols+=$outline
                                    # uncomment for individual symbols
                                    # $fileout=$symbolpath+"\"+$boardname+"-"+$outline+'.kicad_sym'
                                    # write-host "Exporting $outline"
                                    # $unitout | out-file $fileout -encoding ascii
          # }
    }
}


############################################################################################################
############################################################################################################
############################################################################################################

function CreateSymbolBody {
    param (
    $unit,
    $outline,
    $refno
    )
    #11/2 test
    $unit=$unit| Sort-Object -Property pin
    #
    $ucount=$unit.count
        if ($ucount -gt 150) {
            [int]$persidecount=1+$ucount/4 #the +1 is just to avoid rounding too low
          } else {
                $persidecount=1+$ucount/2
        }
  
        $pinlength=3.81
        $sidelength=$persidecount*$kicadspacing
        $disttozero=$sidelength/2
        $leftx=$disttozero*-1-($kicadspacing*6)
        $Rightx=$disttozero+($kicadspacing*6)
        $Righty=$disttozero
        $lefty=$disttozero
        $topx=$disttozero
        $bottomx=$disttozero
        <#10/2 off
        $topy=$disttozero+($kicadspacing*6)
        $bottomy=$disttozero*-1-($kicadspacing*6)#>
        #10/2 on
        if ($ucount -gt 150) {
                $topy=$disttozero+($kicadspacing*6)
                $bottomy=$topy*-1
                #10/2 on
          } else {
                                #10/2 on
                $topy=12.7
                $bottomy=-12.7
                #10/2 on
        }
        $leftcount=1
        $bottomcount=1
        $topcount=1
        $rightcount=1
        $rowcount=1

        $size=($sidelength+($kicadspacing*10))

        if (($rightx-$pinlength) -eq ($leftx+$pinlength)) {$leftx-=1}
        if (($topy-$pinlength) -eq ($bottomy+$pinlength)) {$bottomy-=1}
        $rect='    (symbol "'+$outline+'_0_1"(rectangle(start ' +($Rightx-$pinlength)+' '+($topy-$pinlength)+')(end '+ ($leftx+$pinlength)+' '+($bottomy+$pinlength) +')(stroke(width 0)(type default))(fill(type background))))'
       # $unitout+=$newline+$rect

        foreach ($row in $unit) {
            $net=$row.net
            $pinname=$row.pinname
            $pinnum=$row.pinnum
         #   $pinnum=
            $net=$row.net
            $pwr=$row.pwr
            if ($ucount -gt 150) {
                switch ($rowcount) {
                    {$PSItem -le $persidecount} { 
                        $row.side="left"
                        $row.sidecount=$leftcount
                        $leftcount=$leftcount+1 
                        $sideorientation=0
                        $row.x=$leftx
                        $row.y=$lefty-($kicadspacing*$leftcount)
                    }
                    {$PSItem -gt $persidecount}{ 
                        $row.side="bottom"
                        $row.sidecount=$bottomcount
                        $bottomcount=$bottomcount+1
                        $sideorientation=90 
                        $row.x=$bottomx-($kicadspacing*$bottomcount)
                        $row.y=$bottomy
                    }
                    {$PSItem -gt $persidecount*2}
                        { $row.side="right"
                        $row.sidecount=$rightcount
                        $rightcount=$rightcount+1
                        $sideorientation=180 
                        $row.x=$rightx
                        $row.y=$righty-($kicadspacing*$rightcount)
                    }
                    {$PSItem -gt $persidecount*3} { 
                        $row.side="top"
                        $row.sidecount=$topcount
                        $topcount=$topcount+1
                        $sideorientation=270 
                        $row.x=$topx-($kicadspacing*$topcount)
                        $row.y=$topy
                    }
                        }
            } else {
                switch ($rowcount) {
                    {$PSItem -le $persidecount} { 
                        $row.side="top"
                        $row.sidecount=$topcount
                        $topcount=$topcount+1
                        $sideorientation=270 
                        $row.x=$topx-($kicadspacing*$topcount)
                        $row.y=$topy
                        }
                    {$PSItem -gt $persidecount} { 
                        $row.side="bottom"
                        $row.sidecount=$bottomcount
                        $bottomcount=$bottomcount+1
                        $sideorientation=90 
                        $row.x=$bottomx-($kicadspacing*$bottomcount)
                        $row.y=$bottomy
                    }
                }
            }
                $rowcount++
                $unitout+='    (pin '+$PWR+ ' line (at '+$row.x+' '+$row.y+' '+$sideorientation+')(length '+$pinlength+' )(name "'+ $pinname +'"'+$kicadfont2+'))(number "'+$pinnum +'"'+$kicadfont2+')))'+$newline
         }
         $unitout+=$rect+$newline+")"
      #   write-host $ucount
         return $unitout, $size, $ucount
    }

##############

    $kicadfont="(effects(font(size 1.27 1.27))(justify left)))"
    $kicadfont2="(effects(font(size 1.27 1.27))"

$all=""
$lastpart=""
#$partslist=$partslist | Sort-Object -Property outline
foreach ($part in $Partslist) {
    $outline=$part.Outline
    $partid=$part.part
    if ($lastpart -eq $outline) { $refno=$refno+1 } else {$refno=0}
    $lastpart=$outline
    $unit=(buildunittable $pinstable $partid)
    $part.unitcount=$refno

    $unitdata,$size,$pincount=(CreateSymbolBody $unit $outline $refno)
    $part.symboldata=$unitdata #+$newline+")"
    $part.size=$size
    $part.pincount=$pincount
}
#$partslist=$partslist | Sort-Object -Descending -Property pincount
#$partslist=$partslist | Sort-Object -Property grid

#$schematiclocationx=-500
#$schematiclocationy=-500

$pgguid=New-Guid
$pgguid=$pgguid.Guid

$libraryfileheader='(kicad_symbol_lib(version 20231120)(generator "myne")(generator_version "8.0")'+$newline
$schematicfileheader='(kicad_sch(version 20231120)(generator "eeschema")(generator_version "8.0")(paper "A3")(uuid "'+$pgguid+'")(lib_symbols'+$newline
$schematicout=$schematicfileheader
$schematic2out=""
$libout=$libraryfileheader
$lastsize=0
foreach ($part in $partslist) {
    $grid=$part.grid
    $partdesc=$part.device
    $libref=$part.Reference
    $reference=$part.part
    $outline=$part.Outline
    $partid=$part.part
    $data=$part.Symboldata
    $size=$part.size
    $partguid=$part.guid
    $symbol=$part.symbol
    $symbol2=$part.symbol2
   # if ($refno -eq 0) {

<#   if ($schematiclocationy -gt 500) {
    $schematiclocationy=-500
    $schematiclocationx+=100
    }#>
#new col = new grid

<#10/2 off 
    if ($grid -ne $lastgrid) {
    $schematiclocationy=-500
    $schematiclocationx+=100
    }#>
#10/2 test
    $schematiclocationy=($part.y * 10)
    $schematiclocationx=($part.x * 10)


    $lastgrid=$grid
    if ($symbol2 -ne "") {
       # $LibSymheader=$symbol
        $schematicout+=$symbol+$newline
        $LibSymheader2=$newline+'(symbol(lib_id "'+$boardname+':'+$symbol2+ '")(at '+$schematiclocationx+' ' +$schematiclocationy +' 90)(unit 1)(exclude_from_sim no)(in_bom yes)(on_board yes)(dnp no)(uuid "'+$partguid+'")'
    }else {
        $LibSymheader='(symbol "'+$boardname+':'+$outline +'"(pin_names(offset 1.016))(exclude_from_sim no)(in_bom yes)(on_board yes)'+$newline+'    (property "Reference" "'+$libref+'"(at 0 0 0)' +$kicadfont +$newline+ '    (property "Value" "'+$partdesc +'"(at 0 0 0)' +$kicadfont+ $newline+'    (property "Footprint" "'+$outline+  '"(at 0 0 0)'+$kicadfont2+'(hide yes)))'+$newline+'    (property "Description" "'+$partdesc +'"(at 0 0 0)'+$kicadfont2+'(hide yes)))'
   #     $LibSymheader2=$newline+'(symbol(lib_id "
        $libout+=$LibSymheader+$newline+ $data +$newline
        $schematicout+=$LibSymheader+$newline+ $data +$newline
    $LibSymheader2=$newline+'(symbol(lib_id "'+$boardname+':'+$outline+ '")(at '+$schematiclocationx+' ' +$schematiclocationy +' 0)(unit 1)(exclude_from_sim no)(in_bom yes)(on_board yes)(dnp no)(uuid "'+$partguid+'")'
    }

<# 10/2 off
    $lastgrid=$grid
    if ($symbol2 -ne "") {
       # $LibSymheader=$symbol
        $schematicout+=$symbol+$newline
        $LibSymheader2=$newline+'(symbol(lib_id "'+$symbol2+ '")(at '+$schematiclocationx+' ' +$schematiclocationy +' 90)(unit 1)(exclude_from_sim no)(in_bom yes)(on_board yes)(dnp no)(uuid "'+$partguid+'")'
    }else {
        $LibSymheader='(symbol "'+$outline +'"(pin_names(offset 1.016))(exclude_from_sim no)(in_bom yes)(on_board yes)'+$newline+'    (property "Reference" "'+$libref+'"(at 0 0 0)' +$kicadfont +$newline+ '    (property "Value" "'+$partdesc +'"(at 0 0 0)' +$kicadfont+ $newline+'    (property "Footprint" "'+$outline+  '"(at 0 0 0)'+$kicadfont2+'(hide yes)))'+$newline+'    (property "Description" "'+$partdesc +'"(at 0 0 0)'+$kicadfont2+'(hide yes)))'
   #     $LibSymheader2=$newline+'(symbol(lib_id "
        $libout+=$LibSymheader+$newline+ $data +$newline
        $schematicout+=$LibSymheader+$newline+ $data +$newline
    $LibSymheader2=$newline+'(symbol(lib_id "'+$outline+ '")(at '+$schematiclocationx+' ' +$schematiclocationy +' 0)(unit 1)(exclude_from_sim no)(in_bom yes)(on_board yes)(dnp no)(uuid "'+$partguid+'")'
    }
     
#>
    
    $guid=new-guid
    $guid=$guid.Guid

  #  $schematic1out+=$LibSymheader+$part.Symboldata+$newline
    $schematic2out+=$LibSymheader2
<#10/2 off 
    $schematic2out+='   (property "Reference" "'+$partid + '"(at '  +($schematiclocationx+2.54)+' ' +($schematiclocationy+2.54) + ' 90)' + $kicadfont +$newline
    $schematic2out+='   (property "Value" "'+ $partdesc+ '" (at ' +($schematiclocationx-2.54)+' ' +($schematiclocationy-2.54) + ' 90)' + $kicadfont +$newline
#>
    $schematic2out+='   (property "Reference" "'+$partid + '"(at '  +($schematiclocationx)+' ' +($schematiclocationy) + ' 90)' + $kicadfont +$newline
    $schematic2out+='   (property "Value" "'+ $partdesc+ '" (at ' +($schematiclocationx)+' ' +($schematiclocationy) + ' 90)' + $kicadfont +$newline


    #$schematic2out+=$data+')'+$newline
 #   $schematic2out+='(instances(project "'+$boardname +'"(path "/' +$pgguid +'/'+$partguid+'"(reference "'+ $partid + '")(unit 1)))))'
    $schematic2out+='(instances(project "'+$boardname +'"(path "/' +$pgguid +'"(reference "'+ $partid + '")(unit 1)))))'
    #$schematic2out+='(instances(project "'+$boardname +'"(path "/' +$pguid +'/"(reference "'+ $partid + '")(unit 1)))))'    
    #$schematicout+=
    $schematiclocationy+=50
    
 #   write-host $size $lastsize
 #   pause
    $lastsize=$size
}

<#$libout| out-file lib.txt -encoding ascii
$schout=$schematicout
$schout| out-file sch.txt -encoding ascii

$sch2out=$schematic2out
$sch2out| out-file sch2.txt -encoding ascii#>


#$filler='(instances(project "'+$boardname +'"(path "/' + '(reference "'+ +'")(unit 1)))))'

$sch3out=$schematicout+")"+$schematic2out +")"
$sch3out| out-file "$boardname.kicad_sch" -encoding ascii

Write-Host Done.
Write-Host Note that the schematic relative locations are the same as the pcb.
