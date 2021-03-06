# required parameters :
# $buildNumber

Framework "4.0"

properties {

    $baseDir                  = resolve-path .\..
    $sourceDir                = "$baseDir\src"
    $buildDir                 = "$baseDir\..\build"
    $outputDir                = "$baseDir\output"
    $testDir                  = "$outputDir\test-results"
    $packageDir               = "$outputDir\packages"
    $companyName              = "Medidata"
    $solutionName             = "mmsquare.Betmax"
       
    $solutionConfig           = "Release"

    # if not provided, default to 1.0.0.0
    if(!$version)
    {
        $version              = "1.0.0.0"
    }

    # tools
    $testExecutable           = "$sourceDir\packages\NUnit.Runners.2.6.3\tools\nunit-console-x86.exe"
    $nuget                    = "$sourceDir\packages\NuGet.CommandLine.2.7.3\tools\NuGet.exe"

    # if not provided, default to Dev
    if (!$nuGetSuffix)
    {
        $nuGetSuffix          = "Dev"
    }
        
    #tests
    $unitTestProjectDir1      = "Integration.Tests"
    $unitTestProjectDir2      = "Interception.Test"
    $unitTestProjectDir3      = "Unity.Integration.Tests"
	
	$unitTestProjectLib1      = "mmSquare.Betamax.Integration.Tests"
    $unitTestProjectLib2      = "mmSquare.Betamax.Interception.Tests"
    $unitTestProjectLib3      = "Unity.Integration.Tests"
    
    #deploy projects
    $coreProject              = "mmSquare.Betamax"
    $UnityProject             = "mmSquare.Betamax.Unity"

    # source locations
    $projectSourceDir         = "$sourceDir\$solutionName\"

    # package locations
    $projectPackageDir        = "$packageDir\$solutionName\"

    # nuspec files
    $projectNuspec            = "$projectPackageDir\$solutionName.nuspec"
    $projectNuspecTitle       = "$solutionName title"
    $projectNuspecDescription = "$solutionName description"

    # deploy scripts
    $projectDeployFile        = "$buildDir\Deploy-$solutionName.ps1"
}

task default -depends UnitTest, PackageNuGet

# Initialize the build, delete any existing package or test folders
task Init {

    Write-Host "Deleting the package directory"
    CreateDirectory $packageDir
    DeleteFile $packageDir
        
    Write-Host "Deleting the test directory"
    CreateDirectory $testDir
    DeleteFile $testDir
        
    Write-Host "Deleting the output directory"
    DeleteFile $outputDir
    CreateDirectory $packageDir   
}

# Compile the Project solution and any other solutions necessary
task Compile -depends Init {
    
	Write-Host "Cleaning the solution"
    exec { msbuild /t:clean /v:q /nologo /p:Configuration=$solutionConfig $sourceDir\$solutionName.sln }
    DeleteFile $error_dir
    
	Write-Host "Building the solution"
    exec { msbuild /t:build /v:q /nologo /p:Configuration=$solutionConfig $sourceDir\$solutionName.sln }
}

task UnitTest -depends UnitTest1, UnitTest2, UnitTest3

# Execute unit tests
task UnitTest1 -depends Compile {
    exec { & $testExecutable "$sourceDir\$unitTestProjectDir1\bin\$solutionConfig\$unitTestProjectLib1.dll" }# /output "$testDir\1.xml" }
}

task UnitTest2 -depends Compile {
    exec { & $testExecutable "$sourceDir\$unitTestProjectDir2\bin\$solutionConfig\$unitTestProjectLib2.dll"}# /output "$testDir\2.xml" }
}

task UnitTest3 -depends Compile {
    exec { & $testExecutable "$sourceDir\$unitTestProjectDir3\bin\$solutionConfig\$unitTestProjectLib3.dll"}# /output "$testDir\2.xml" }
}

# TODO
# Create a common assembly info file to be shared by all projects with the provided version number
task CommonAssemblyInfo {
    $version = "1.0.0.0"
    CreateCommonAssemblyInfo "$version" $solutionName "$source_dir\CommonAssemblyInfo.cs"
}

# PackageNuGet creates the NuGet packages for each package needed to deploy the solution
task PackageNuGet -depends Compile, PackageCoreNuget, PackageUnityNuget

task PackageCoreNuget {

    Write-Host "Create $coreProject nuget manifest"
    $tempFile = "$sourceDir\$coreProject\temp.nuspec"
    TransformNuGetManifest "$sourceDir\$coreProject\template.nuspec" $version $solutionConfig $tempFile
    
	Write-Host "Package $projectNuspec with base path $projectPackageDir and package dir $packageDir"
    exec { & $nuget pack $tempFile -OutputDirectory $packageDir }
    DeleteFile $tempFile
}

task PackageUnityNuget {

    Write-Host "Create $UnityProject nuget manifest"
    $tempFile = "$sourceDir\$UnityProject\temp.nuspec"
    TransformNuGetManifest "$sourceDir\$UnityProject\template.nuspec" $version $solutionConfig $tempFile
    
	Write-Host "Package $UnityProject with base path $projectPackageDir and package dir $packageDir"
    exec { & $nuget pack $tempFile -OutputDirectory $packageDir }
    DeleteFile $tempFile
}

# Deploy the project locally
task DeployProject -depends PackageProject {
    cd $projectPackageDir
    & ".\Deploy.ps1"
    cd $baseDir
}

# ------------------------------------------------------------------------------------#
# Utility methods
# ------------------------------------------------------------------------------------#

# copy files to a destination
# create the directory if it does not exist
function global:CopyFiles($source, $destination, $exclude = @()){
    CreateDirectory $destination
    Get-ChildItem $source -Recurse -Exclude $exclude | Copy-Item -Destination { Join-Path $destination $_.FullName.Substring($source.length); }
}

# Create a directory
function global:CreateDirectory($directoryName)
{
    mkdir $directoryName -ErrorAction SilentlyContinue | Out-Null
}

# Delete a directory
function global:DeleteDirectory($directory_name)
{
    rd $directory_name -recurse -force -ErrorAction SilentlyContinue | Out-Null
}

# Delete a file if it exists
function global:DeleteFile($file) {
    if ($file){
        Remove-Item $file -force -recurse -ErrorAction SilentlyContinue | Out-Null
    }
}

# Transform the NuGet manifest file
function global:TransformNuGetManifest($source, $version, $config, $filename)
{
    $val = Get-Content $source
    $val = $val.Replace("||VERSION||", $version ).Replace("||CONFIG||", $config )
    $val | Out-File $filename -encoding "ASCII"
}