#!/usr/local/bin/perl
# ========================================================================
#                Q M I _ I D L _ C O M P I L E R . P L
#
# DESCRIPTION
#  This program takes input from a QMI IDL File and generates marshalling
#  code to automate the encoding and sending of QMI messages.
# 
#  This Tool relies on Perl Modules that are not released by Qualcomm. Please ensure
#  your Perl distribution has the following packages installed
#  If you see the error Can't locate <Module>.pm in @INC your Perl install is missing 
#  that Module.
#
# REFERENCE
# 
# Copyright (c) 2011 by QUALCOMM Incorporated. All Rights Reserved.
# ========================================================================
# 
# $Header: //source/qcom/qct/core/mproc/tools_crm/idl_compiler/main/latest/customer/qmi_idl_compiler.pl#13 $
#
# ========================================================================
#===========================================#
#===============Function List===============#
#===========================================#
# TEST_WRITE_ACCESS
# P4_EDIT_FILES
# FIND_P4_CONFIG
# PRINT_USAGE
# MAIN
#===========================================#

use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use Getopt::Long;
use FindBin;
use File::Find;
use File::Spec;
use Cwd;

#==============================================#
#==================Constants===================#
#==============================================#
my $FALSE = 0;
my $TRUE = 1;
my $USES_XML_LIBS = eval { require XML::Simple; require XML::Writer; };
if (defined($USES_XML_LIBS))
{
  $USES_XML_LIBS = $TRUE;
}else
{
  $USES_XML_LIBS = $FALSE;
}

my $USES_JSON_LIBS = eval 'require JSON';
if ( defined($USES_JSON_LIBS))
{
   $USES_JSON_LIBS = $TRUE;
}
else
{
   $USES_JSON_LIBS = $FALSE;
}

#Set the path to the local modules used by qmi_idl_compiler.pl
use lib "$FindBin::Bin";

use qmi_idl_c_output qw(:all);
use qmi_idl_xml_output qw(:all);
use qmi_idl_parser qw(:all);
use qmi_idl_xml_parser qw(:all);
use qmi_idl_msg_xml qw(:all);
use qmi_idl_wire_html_docgen qw(:all);


#===========================================================================
#
#FUNCTION TEST_WRITE_ACCESS
#
#DESCRIPTION
#  Checks whether or not the files in the argument list have write access
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  Boolean for success/failure
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub test_write_access 
{
   my @file_list = @_;
   my $write_error = $FALSE;
   
   foreach(@file_list)
   {
     #Check that the output directories exist
     my $out_dir = dirname($_);
     unless (-d $out_dir) 
     {
       print STDERR "ERROR: Directory $out_dir does not exist.\n";
       $write_error = $TRUE;
       next;
     }
     #Check if the files exist and are writable
     if (-e $_) 
     {
       unless(-w $_)
       {
         print STDERR "ERROR: File $_ not writable\n";
         $write_error = $TRUE;
       }
     }else
     {
       print STDERR "File $_ does not exist, creating.\n";
       #deeeeed
       unless(open(FILE,">$_"))
       {
          print STDERR "ERROR: Unable to create file $_\n";
          $write_error = $TRUE;
       }
       close(FILE);
     }
   }
   return $write_error;
}#  test_write_access

#===========================================================================
#
#FUNCTION PRINT_USAGE
#
#DESCRIPTION
#  Prints the Usage statement
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  
#
#SIDE EFFECTS
#  
#
#===========================================================================
sub print_usage 
{
   my $env_list = shift;
   my $maj_vers = shift;
   my $min_vers = shift;
   my $spin_vers = shift;
   my $prog_name = $0;
   $prog_name =~ s/.*\\//;
   $prog_name =~ s/.*\///;
   print STDERR <<"EOF";
$prog_name: Version $maj_vers\.$min_vers\.$spin_vers

usage: $prog_name [OPTION] <IDLFILE>
  -a / --all
    Runs the tool on all IDL Files in the current directory.

  -b / --bwc
    Prints the BWC file that contains all information parsed from the IDL
    and is used for backwards compatibility checks.

  -f / --force
    Forces overwrite of nonwritable output files.  Note, this only means that 
    the tool will attempt to overwrite the files regardless of permissions, but 
    it may still fail.

  --out-version <VERSION>
    Runs the tool in a mode that allows the output files to be written
    according to older versions of the encode/decode library.

  --parse-only
    Runs the tool in parse-only mode, checks IDL syntax without requiring
    write access to output files.  Still checks backwards compatibility.

  -v / --version 
    Displays the major version of the tool and the output with regards to
    the encode/decode libraries.

  -x / --xml
    Prints the XML file that contains all information parsed from the IDL
    and can be used with QMI Test Pro.

  --remove-msgs <FILENAME>
     Enable conditional compilation tags for the removal of messages defined in the input file
     from the generated .h files.

  --ipath <PATH>
    Path to input files directory.

  --opath <PATH>
    Path to output files directory.

  --json
    Generates a parsed JSON output file along with other output formats.

  -h / --help / -u / --usage
    Print this usage statement.

EOF
   exit(0);
}#  print_usage

#===========================================#
#===============Main Function===============#
#===========================================#
sub main 
{
  my $filename;
  my $outfilename;
  my $bwc_message;
  my $DOTHFILE = "";              #Populated with information for the .h file
  my $DOTCFILE = "";              #Populated with information for the .c file
  my $OUTFILES = "";              #The basename of the .h .c and .xml output files
  my $DIRSLASH = "";              #The direction directory slashes, for running on linux 
                                  # vs Windows
  my $PARSE_ALL_IDL = $FALSE;     #Set to true if the -a/--all flag is set
  my $NO_MINOR_UPDATE = $TRUE;
  my $FORCE_WRITE = $FALSE;
  my $OUTPUT_VERSION = $FALSE;
  my $PARSE_ONLY = $FALSE;
  my $PRINT_VERSION = $FALSE;
  my $PRINT_USAGE = $FALSE;       #Set in GetOptions if usage statement should be output
  my @INCLUDE_PATH;               #String to hold passed in include path information
  my $PARSING_ERROR = $FALSE;
  my $PRINT_XML = $FALSE;
  my $REMOVE_MSGS_FILE = "";
  my $PRINT_BWC = $FALSE;
  my $JSON = $FALSE;
  my $IP_PATH = "";
  my $OUT_PATH = "";
  my $out_maj_vers = hex($IDL_COMPILER_MAJ_VERS);
  my $out_min_vers = hex($IDL_COMPILER_MIN_VERS);
  my $out_spin_vers = hex($IDL_COMPILER_SPIN_VERS);
  my %config_hash;
  my $env_list = "";
  my $separator = "---------------------------------------------------\n";

  my $timestamp = time();
  #handle_args(\$OUTFILES,\$TERMINAL_OUT,\$DEBUG_MODE,\$INCLUDE_PATH,\$DIROUT);
  GetOptions('all' => \$PARSE_ALL_IDL,
             'bwc' => \$PRINT_BWC,
             'force' => \$FORCE_WRITE,
             'out-version=s' => \$OUTPUT_VERSION,
             'parse-only' => \$PARSE_ONLY,
             'version' => \$PRINT_VERSION,
             'help|usage' => \$PRINT_USAGE,
             'xml' => \$PRINT_XML,
             'remove-msgs=s' => \$REMOVE_MSGS_FILE,
             'json' => \$JSON,
             'ipath=s' => \$IP_PATH,
             'opath=s'=> \$OUT_PATH,);

  if ($PRINT_VERSION == $TRUE) 
  {
     print "qmi_idl_compiler: Version $out_maj_vers\.$out_min_vers\.$out_spin_vers\n\n";
     exit;
  }

  if ((@ARGV == 0 && $PARSE_ALL_IDL == $FALSE) || $PRINT_USAGE) 
  {
     print_usage($env_list,$out_maj_vers,$out_min_vers,$out_spin_vers);
  }

  if ($USES_XML_LIBS == $FALSE)
  {
    print STDERR "Warning: Perl XML Libraries not installed, no XML files can be written\n";
    print STDERR "         and no backwards compatibiliy checks can be done.\n";
    print STDERR "         Install XML modules XML::Simple and XML::Writer to remove this warning.\n";
    if ($PRINT_XML || $PRINT_BWC)
    {
      print STDERR "Error:  --xml or --bwc flag invalid without Perl XML Libraries.\n";
      exit 1;
    }
  }

  if ($USES_JSON_LIBS == $FALSE)
  {
     print STDERR "\nWarning: Perl JSON Libraries not installed, no JSON files can be written/parsed\n";
     print STDERR "         Install JSON modules to remove this warning.\n";
     if ($JSON)
     {   
        print STDERR "Error:  --json flag invalid without Perl JSON Libraries.\n";
        exit 1;
     }
  }   

  # verify that -all option and remove-msgs option are not invoked toegther
  if ($PARSE_ALL_IDL && $REMOVE_MSGS_FILE)
  {
     print STDERR " Option --remove-msgs cannot be invoked with --all option.\n";
     exit 1;
  }
  
  if ($IP_PATH ne "")
  {
     push(@INCLUDE_PATH, $IP_PATH);
  }

  #If the --all option was passed, set the @ARGV variable to all IDL files in the current
  #directory
  if ($PARSE_ALL_IDL) 
  {
     undef @ARGV;
     my $DIR;
     if ($IP_PATH ne "")
     {
        eval
        {
           opendir($DIR,$IP_PATH);
        };
        if ($!)
        {
           print "\n $IP_PATH directory does not exist, Exiting\n";
           exit 1;
        }
     }
     else
     {
        opendir($DIR,".");
     }
     @ARGV = grep (/.*\_v\d\d\.(idl$|json$)/,readdir($DIR));
     closedir($DIR);
  }
  #Iterate throuh all supplied IDL Files
  while (@ARGV) 
  {
     %type_hash = ();
     $filename = shift @ARGV;
     print "\n$separator" . "Parsing File: $filename\n";
     print "Compiler version: $out_maj_vers\.$out_min_vers\.$out_spin_vers \n$separator";
     my $service_name;
     my $service_version;
     my $dotcout;
     my $dothout;
     my $wirehtmlout;
     my $stylesheetout;
     my $jsonout;
     my $base_name;
     if ( $filename =~ /\.idl$/)
     {
        $base_name = basename($filename,".idl");
     }
     elsif( $filename =~ /\.json$/)
     {
        $base_name = basename($filename,".json");
     }
     else
     {
        print "\n Unrecognized file extension $filename \n";
        $PARSING_ERROR = $TRUE;
        next;
     }

     my $msgxmlout;
     my $goldenxmlout;
     my $copyright = "";
     my $p4info = "";
     if ($filename =~ /\.json$/)
     {
        if ($USES_JSON_LIBS == $FALSE)
        {
           print STDERR "Error: Cannot parse .json files without installing Perl JSON Libraries.\n"; 
           $PARSING_ERROR = $TRUE;
           next;
        }
        local $/;
        my $json = JSON->new;
        if (-e "$IP_PATH\/$filename") 
        {
           $filename = "$IP_PATH\/$filename";
        }
        open( my $fh, '<',$filename) or die "Unable to open file $filename";
        my $new_hash = "";
        my $json_text   = <$fh>;
        close($fh);
        $new_hash = $json->utf8->decode($json_text);
        %type_hash = %$new_hash;
     }
     else
     {
        parse_idl_file($filename,\@INCLUDE_PATH,\%type_hash,$NO_MINOR_UPDATE,$FALSE,$FALSE,$USES_XML_LIBS,$TRUE,$USES_JSON_LIBS);
        #If there were errors in parsing the IDL File, type_hash will be undefined
        #Exit or parse the next IDL file in this case
     }
     unless (%type_hash)
     {
        print "\n$separator\n$filename NOT parsed successfully.\n$separator";
        $PARSING_ERROR = $TRUE;
        next;
     }

     if ($PARSE_ONLY) 
     {
        print "\n$separator\n$filename parsed successfully.\n$separator";
        next;
     }

     $service_name = $type_hash{"service_hash"}{"identifier"};
     $service_version = "version_v" . $type_hash{"service_hash"}{"version"};

     #Now that the IDL has been parsed, set the output locations
     if ($OUT_PATH ne "" )
     {
        $dotcout = $OUT_PATH . "/";
        $dothout = $OUT_PATH . "/";
        $wirehtmlout = $OUT_PATH . "/";
        $stylesheetout = $OUT_PATH . "/";
        $jsonout = $OUT_PATH . "/";
     }
     else
     {
        $dotcout = "./";
        $dothout = "./";
        $wirehtmlout = "./";
        $stylesheetout = "./";
        $jsonout = "./";
     }
     #Add the filenames to the output directories
     $dotcout .= $base_name . ".c";
     $dothout .= $base_name . ".h";
     $msgxmlout .= $base_name . ".xml";
     $jsonout .= $base_name . ".json";
     $msgxmlout =~ s/(\_v\d\d)/_msg_xml$1/;
     $wirehtmlout .= $base_name . ".html";
     $wirehtmlout =~ s/(\_v\d\d)/_wireformat$1/;
     $stylesheetout .= "qmi_idl_wiredoc.css";
     $goldenxmlout .= $base_name . ".bwc";
     my $DOTHOUTSTRING = "";
     my $DOTCOUTSTRING = "";
     my $WIREDOCHTMLSTRING = "";
     my $STYLESHEETSTRING = "";
     my $JSONOUTSTRING = "";

     my @file_array = ($dotcout,$dothout);

     push(@file_array,$stylesheetout);
     if (test_write_access(@file_array) == $TRUE && $FORCE_WRITE == $FALSE)
     {
        print "\n$separator\nERROR: File permission issues when attempting to parse $filename.\n$separator";
        $PARSING_ERROR = $TRUE;
        next;
     }
     
     my @new_array = ();
     my @doc_cmd_array = ();
     delete $type_hash{"command_documentation"}{""};
     foreach (@{$type_hash{"command_order"}})
     {
       push(@new_array, $_) if defined($type_hash{"command_documentation"}{$_}{"commandid"});
     }

     my $array_len = @new_array;
     my $temp;
     my $i = 0;
     my $j = 0;
     my $flag = $TRUE;
     for($i=1;($i <= $array_len) && $flag == $TRUE; $i++)
     {
       $flag = $FALSE;
       for ($j=0; $j < ($array_len - 1); $j++)
       {
         if(hex($type_hash{"command_documentation"}{$new_array[$j+1]}{"commandid"}) <
            hex($type_hash{"command_documentation"}{$new_array[$j]}{"commandid"}))
         {
           $temp = $new_array[$j];
           $new_array[$j] = $new_array[$j+1];
           $new_array[$j+1] = $temp;
           $flag = $TRUE;
         }
       }
     }
     foreach (@{$type_hash{"command_order"}})
     {
       if (defined($type_hash{"command_documentation"}{$_}{"DOCUMENT_CMD"}))
       {
         push(@doc_cmd_array,$_);
       }
     }
     unshift(@new_array, @doc_cmd_array);
     @{$type_hash{"command_order"}} = @new_array;
     $type_hash{"remove_msgs_file"} = $REMOVE_MSGS_FILE;
     populate_h_file($OUTPUT_VERSION,\$DOTHOUTSTRING,$base_name,\%type_hash,$copyright,$p4info);
     populate_c_file($OUTPUT_VERSION,\$DOTCOUTSTRING,$base_name,\%type_hash,$copyright,$p4info);
     write_wire_html_docgen(\%type_hash,\$WIREDOCHTMLSTRING, \$STYLESHEETSTRING);

     xml_print_doc($filename,$goldenxmlout,\%type_hash) if ($PRINT_BWC && $USES_XML_LIBS);
     print_msg_xml($filename,$msgxmlout,\%type_hash) if ($PRINT_XML && $USES_XML_LIBS);
     #Write out the files
     open (HFILE,">$dothout") or die "Cannot open file $dothout";
     open (CFILE,">$dotcout") or die "Cannot open file $dotcout";
     open (WIREHTMLFILE,">$wirehtmlout") or die "Cannot open file $wirehtmlout";
     open (STYLESHEETFILE,">$stylesheetout") or die "Cannot open file $stylesheetout";
     if ($JSON)
     {
        open (JSONFILE, ">$jsonout") or die "Cannot open file $jsonout";
        my $json = JSON->new;
        $json = $json->pretty([$TRUE]);
        $JSONOUTSTRING = $json->utf8->encode(\%type_hash); 
        print JSONFILE $JSONOUTSTRING; 
        close(JSONFILE);
     }
     print HFILE $DOTHOUTSTRING;
     print CFILE $DOTCOUTSTRING;
     print WIREHTMLFILE $WIREDOCHTMLSTRING;
     print STYLESHEETFILE $STYLESHEETSTRING;
     close(HFILE);close(CFILE);
     close(WIREHTMLFILE);close(STYLESHEETFILE);
     print "\n$separator\n$filename parsed successfully.\n$separator";
  }#End of parsing loop
  print "Errors encountered during processing, not all files were parsed successfully.\n" if($PARSING_ERROR);

  #Output the run time
  $timestamp = time - $timestamp;
  printf("\n\nTotal running time: %02d:%02d:%02d\n", int($timestamp / 3600), int(($timestamp % 3600) / 60), 
         int($timestamp % 60));
  if($PARSING_ERROR)
  {
     exit($PARSING_ERROR);
  }
}#  main

main();
1;
