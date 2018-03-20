#!/usr/local/bin/perl
# ========================================================================
#                Q M I _ I D L _ P A R S E R . P M
#
# DESCRIPTION
# Parses a QMI IDL file, storing information in a hash that is returned
#  to the calling function
# REFERENCE
#
# Copyright (c) 2011 by QUALCOMM Incorporated. All Rights Reserved.
# ========================================================================
#
# $Header: //source/qcom/qct/core/mproc/tools_crm/idl_compiler/main/latest/common/qmi_idl_parser.pm#19 $
#
# ========================================================================
#===========================================#
#===============Function List===============#
#===========================================#
# RESET_GLOBAL_VALUES
# GET_NUM_VALUE
# CALC_OFFSET
# CHECK_IDENTIFIER
# CHECK_NUMBER
# HANDLE_COMMENTS
# HANDLE_DOC_COMMENTS
# HANDLE_CONST
# HANDLE_ENUM
# INCREMENT_ENUM_VALUE
# HANDLE_ERRORS
# HANDLE_INCLUDE
# HANDLE_MESSAGE
# HANDLE_PRIMITIVES
# HANDLE_SERVICE
# HANDLE_SERVICE_MESSAGES
# HANDLE_STRUCT
# HANDLE_TYPEDEF
# HANDLE_VERSION
# READ_GOLDEN_XML
# PARSE_IDL_FILE
# READ_TOKEN
# PRINT_ERROR
# FIND_FILE
# SET_INCLUDE_PATH
# FORMAT_DOC_OUTPUT
#===========================================#
package qmi_idl_parser;


use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use Getopt::Long;
use FindBin;
use Storable qw(dclone);
no warnings 'portable';  # Support for 64-bit ints required
#use lib "$FindBin::Bin/../lib";

our @ISA = qw(Exporter);

#Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration       use IDLCompiler::IDLOutput ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(parse_idl_file
                                  ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

#==============================================#
#==================Constants===================#
#==============================================#
my $FALSE = 0;
my $TRUE = 1;
my $NOT_INTEGER = 2;
my $SET_16_BIT_VALUE = 255;
my $MAX_TYPE_SIZE = 65536;
my $MAX_INT_VALUE = 2147483647;
my $MIN_ENUM_SIZE = -2147483647;
my %ALLOWED_DOC_MODES = (
  "FILE" => 1,
  "MSG" => 1,
  "COMMAND" => 1,
  "FOOTER" => 1,
  "APPENDIX" =>1,
);
#The following values index into the golden XML hash
my $XMLFILEDOC = 0;
my $XMLCOMDOC = 1;
my $XMLINCFILES = 2;
my $XMLCONSTS = 3;
my $XMLTYPES = 4;
my $XMLSERVICE = 5;
my $XMLFOOTER = 6;

my $SECURITY_COMMAND_DOC_VALS = "USAGE|SECURITY\_LEVEL|REQUIRED\_ACTION|" .
                                "SECURITY\_SUBLEVEL|SECURITY\_SUBLEVEL\_OTHER|REQUIRED\_ACTION\_OTHER";

#==============================================#
#===============Global Variables===============#
#==============================================#
my $INCLUDE_MODE = $FALSE;        #Mode when parsing an included .idl file
my $IDLFILE;                      #File Handle for reading in the idl
my $IDLFILENAME;                  #File name of the IDL
my $INCLUDEFILE;                  #File Handle of included .idl file
my $INCLUDEFILENAME;              #Name of included .idl file
my $INCLUDEFILE2;
my $INCLUDEFILENAME2;
my @IDL_FILENAMES = ();
my @IDL_FILES = ();
my $INCLUDE_LEVEL = 0;
my $VERSION_NUMBER = -1;          #Version number to append to struct and message types
my $INCLUDE_VERSION = -1;         #Version number to append to included struct and message types
my @INCLUDE_VERSION_QUEUE = ();   #Holds version to handle multiple include levels
my $MINOR_VERSION = -1;           #Minor Version Number
my $INCLUDE_MINOR_VERSION = -1;   #Minor Version Number of the include file
my $DEP_MODE = $FALSE;            #Dev mode for debugging purposes, allows runs on local copies of golden XML files
my $CONST_STATE = $FALSE;
my $GOLDEN_MODE = "golden";
my $NO_MINOR_UPDATE = $FALSE;
my $REVERSE_SERVICE = 0;
my $NO_BWC_CHECKS = $FALSE;
my $MSG_CHECK_ERRORS = $FALSE;
my $USE_XML_LIBS = $FALSE;
my $USE_JSON_LIBS = $FALSE;
my $ERROR_FLAG = $FALSE;          #Flag is set to true when errors are encountered, certain operations are skipped if there has been an error
my $CUSTOMER_ENV = $FALSE;        #Flag to indicate who is invoking the IDL parser

#==============================================#
#===========Documentation Variables============#
#==============================================#
my $DOCUMENTATION_MODE = "";        #Determines what hash documentation comments should be associated with
my $DOCUMENTATION_NAME = "";        #Determines what hash documentation comments should be associated with
my $COMMAND_NAME = "";              #Used to associate @ERROR and @DESCRIPTION documentation keywords
my $PREV_COMMAND_NAME = "";         #Used to associate @ERROR and @DESCRIPTION keywords w/ previous command
my $PREV_CONST_NAME = "";           #
my $MSG_NAME = "";                  #Used to associate message with their names in documentation comments
my $DOCUMENTATION_KEYWORD = "";     #Used to determine what state the documentation comments are in
my $CURRENT_DESCRIPTION = "";       #Used for documentation comments describing fields
my $PREV_DESCRIPTION = "";          #Used for documentation comments describing fields
my %TLV_DOCUMENTATION = (); #Tracks the version a TLV was introduced to a message
my %FOOTER_HASH = ();               #Keeps the text associated with the @FOOTER documentation keyword
my @FOOTER_ORDER = ();              #Allows users to declare multiple FOOTERS
my %FILE_DOCUMENTATION = ();        #Hash to hold all of the file documentation
my %MSG_DOCUMENTATION = ();         #Hash to hold all of the message documentation
my @MSG_ORDER = ();                 #Array to keep the order of message documentation
my %COMMAND_DOCUMENTATION = ();     #Hash to hold all of the command documentation
my %COMMON_COMMAND_LINKS = ();      #Hash to hold links between common commands defined in service IDLs
my @COMMAND_ORDER = ();             #Array to keep the order of command documentation

#==============================================#
#===============Type Structures================#
#==============================================#
my @error_msgs = ();            #Array of error messages encountered during parsing
my %used_enum_mask_ids = ();    #Hash to hold enum and mask identifiers to prevent duplicates
my %include = ();
my %golden = ();
my %golden_xml_hash = ("include" => \%include,
                       "golden" => \%golden);

#Set the path to the local modules used by idl_compiler.pl
use lib "$FindBin::Bin";

use qmi_idl_xml_parser qw(:all);
use qmi_idl_c_output qw(:all);
use qmi_idl_bwc qw(:all);

#Type keywords hash contains all keywords that are recognized by the compiler and have a corresponding handler function
my %type_keywords = ();

#forbidden_keywords hash enumerates the keywords that cannot be used as identifiers
#in an IDL
my %forbidden_keywords = ();
my %valid_typedefs = ();
# service types allowed
my %service_types = ();

#===========================================================================
#
#FUNCTION RESET_GLOBAL_VALUES
#
#DESCRIPTION
#  Resets the global variables to their default values.  This function is necessary
#  for instances where the parse_idl_file function is called multiple times on different
#  IDL files.
#
#DEPENDENCIES
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  All global values set to their defaults.
#
#===========================================================================
sub reset_global_values
{
   $INCLUDE_MODE = $FALSE;
   $VERSION_NUMBER = -1;
   $INCLUDE_VERSION = -1;
   $DEP_MODE = $FALSE;
   $GOLDEN_MODE = "golden";
   $NO_MINOR_UPDATE = $FALSE;
   $NO_BWC_CHECKS = $FALSE;
   $USE_XML_LIBS = $FALSE;
   $USE_JSON_LIBS = $FALSE;
   $REVERSE_SERVICE = 0;
   $ERROR_FLAG = $FALSE;
   $DOCUMENTATION_MODE = "";
   $DOCUMENTATION_NAME = "";
   $COMMAND_NAME = "";
   $PREV_COMMAND_NAME = "";
   $PREV_CONST_NAME = "";
   $MSG_NAME = "";
   $DOCUMENTATION_KEYWORD = "";
   $CURRENT_DESCRIPTION = "";
   $PREV_DESCRIPTION = "";
   $CUSTOMER_ENV = $FALSE;
   %FOOTER_HASH = ();
   @FOOTER_ORDER = ();
   %FILE_DOCUMENTATION = ();
   %MSG_DOCUMENTATION = ();
   @MSG_ORDER = ();
   %COMMAND_DOCUMENTATION = ();
   %COMMON_COMMAND_LINKS = ();
   @COMMAND_ORDER = ();
   @error_msgs = ();
   %type_hash = (
   "idltype_to_ctype" => \%idltype_to_ctype_map,
   "idltype_to_wiresize" => \%idltype_to_wiresize_map,
   "idltype_to_csize" => \%idltype_to_csize_map,
   "idltype_to_type_array" => \%idltype_to_type_array_map,
   "idltype_to_alignment" => \%idltype_to_alignment_map,
   );
   $type_hash{"service_hash"}{"tool_major_version"} = hex($IDL_COMPILER_MAJ_VERS);
   $type_hash{"service_hash"}{"tool_minor_version"} = hex($IDL_COMPILER_MIN_VERS);
   $type_hash{"service_hash"}{"tool_spin_version"} = hex($IDL_COMPILER_SPIN_VERS);
   $type_hash{"max_msg_size"} = 0;
   $type_hash{"lastMsgId"} = "0x01";
   $type_hash{"inherited"} =$FALSE;
   $type_hash{"struct_seq_num"} = 0;
   $type_hash{"msg_seq_num"} = 0;
   $type_hash{"removed_msgs"}="";
   $type_hash{"common_file"} =1;
   %used_enum_mask_ids = ();
   %include = ();
   %golden = ();
   %golden_xml_hash = ("include" => \%include,
                       "golden" => \%golden);
   %type_keywords = (
                     "struct" => \&handle_struct,
                     "enum" => \&handle_enum,
                     "enum8" => \&handle_enum,
                     "enum16" => \&handle_enum,
                     "uenum8" => \&handle_enum,
                     "uenum16" => \&handle_enum,
                     "const" => \&handle_const,
                     "string" => \&handle_primitives,
                     "string16" => \&handle_primitives,
                     "char" => \&handle_primitives,
                     "int8" => \&handle_primitives,
                     "int16" => \&handle_primitives,
                     "int32" => \&handle_primitives,
                     "int64" => \&handle_primitives,
                     "uint8" => \&handle_primitives,
                     "uint16" => \&handle_primitives,
                     "uint32" => \&handle_primitives,
                     "uint64" => \&handle_primitives,
                     "float" => \&handle_primitives,
                     "double" => \&handle_primitives,
                     "opaque" => \&handle_primitives,
                     "boolean" => \&handle_primitives,
                     "service" => \&handle_service,
                     "service_type" => \&handle_service_type,
                     "message" => \&handle_message,
                     "include" => \&handle_include,
                     "inherit" => \&handle_inherit,
                     "mask" => \&handle_mask,
                     "mask32" => \&handle_mask,
                     "mask16" => \&handle_mask,
                     "mask8" => \&handle_mask,
                     "__DUPLICATE__" => \&handle_duplicate,
                     "revision" => \&handle_version,
                     "typedef" => \&handle_typedef,
                     "remove_msgs" => \&handle_remove_msgs,
                     );
   %forbidden_keywords = (
                          "__dup__" => 1,
                          "auto" => 1,
                          "boolean" => 1,
                          "break" => 1,
                          "case" => 1,
                          "char" => 1,
                          "const" => 1,
                          "continue" => 1,
                          "default" => 1,
                          "do" => 1,
                          "double" => 1,
                          "else" => 1,
                          "enum" => 1,
                          "enum8" => 1,
                          "enum16" => 1,
                          "uenum8" => 1,
                          "uenum16" => 1,
                          "extern" => 1,
                          "for" => 1,
                          "float" => 1,
                          "goto" => 1,
                          "if" => 1,
                          "include" => 1,
                          "int" => 1,
                          "int8" => 1,
                          "int16" => 1,
                          "int32" => 1,
                          "int64" => 1,
                          "lengthless" => 1,
                          "long" => 1,
#                          "mask" => 1,
#                          "mask32" => 1,
#                          "mask16" => 1,
#                          "mask8" => 1,
                          "mandatory" => 1,
                          "message" => 1,
                          "opaque" => 1,
                          "optional" => 1,
                          "register" => 1,
                          "return" => 1,
                          "service" => 1,
                          "short" => 1,
                          "signed" => 1,
                          "sizeof" => 1,
                          "static" => 1,
                          "string" => 1,
                          "string16" => 1,
                          "struct" => 1,
                          "switch" => 1,
                          "typedef" => 1,
                          "uint8" => 1,
                          "uint16" => 1,
                          "uint32" => 1,
                          "uint64" => 1,
                          "union" => 1,
                          "unsigned" => 1,
                          "version" => 1,
                          "void" => 1,
                          "volatile" => 1,
                          "while" => 1,
                          "INF" => 1,
                          "QMB" => 1,
                          "inherit" => 1,
                          "extends" => 1,
                          "remove_msgs" => 1,
                          );
   %valid_typedefs = (
                      "boolean" => 1,
                      "char" => 1,
                      "double" => 1,
                      "float" => 1,
                      "int" => 1,
                      "int8" => 1,
                      "int16" => 1,
                      "int32" => 1,
                      "int64" => 1,
                      "uint8" => 1,
                      "uint16" => 1,
                      "uint32" => 1,
                      "uint64" => 1,
                      "string" => 1,
                      "string16" => 1,
                      "opaque" => 1,
                      );
   %service_types = (
                     "QMB" =>1,
                     "QMI" =>1,
                    );
}

#===========================================================================
#
#FUNCTION GET_NUM_VALUE
#
#DESCRIPTION
#  Gets the numeric value of a passed in argument
#
#DEPENDENCIES
#  argument must be numeric or a value that is defined in $const_hash
#
#RETURN VALUE
#  The numeric value of the passed in argument
#
#SIDE EFFECTS
#  None.
#
#===========================================================================
sub get_num_value
{
   my $value = shift;
   if (defined($type_hash{"const_hash"}{$value}))
   {
     if($type_hash{"const_hash"}{$value}{"value"} =~ m/^0x/)
     {
       return hex($type_hash{"const_hash"}{$value}{"value"});
     }else
     {
       return $type_hash{"const_hash"}{$value}{"value"};
     }
   }
   return $value;
}#  get_num_value

#===========================================================================
#
#FUNCTION CALC_OFFSET
#
#DESCRIPTION
#  Calculates offset based on alignment rules
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  Returns the new calculated offset
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub calc_offset
{
   my $offset = shift;
   my $align = shift;
   #If there has been a parsing error these values may be invalid
   $offset = 1 if($offset == 0 && $ERROR_FLAG);
   $align = 1 if($align == 0 && $ERROR_FLAG);

   return $offset + (($align - ($offset % $align)) % $align);
}#  calc_offset

#===========================================================================
#
#FUNCTION CHECK_IDENTIFIER
#
#DESCRIPTION
#  Determines if an identifier has been reused, or is one of the forbidden keywords
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the
#  error conditions.
#
#RETURN VALUE
#  Returns the identifier if it is valid.
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub check_identifier
{
  my $identifier = shift;
  my $version = shift;
  my $token;
  # SK : Might have to come up with a better idea than having !$type_hash{"inherited"}
  if(defined($type_hash{"user_types"}{$identifier}) &&
     $type_hash{"user_types"}{$identifier}{"version"} == $version && !$type_hash{"inherited"})
  {
    print_error("Line $. - Identifier \'$identifier\' already used\n");
    while(defined($token = read_token()) and $token ne ";")
    {
      next;
    }
    return;
  }
  if(defined($type_hash{"const_hash"}{$identifier}) &&
     $type_hash{"const_hash"}{$identifier}{"version"} == $version && !$type_hash{"inherited"})
  {
    print_error("Line $. - Identifier \'$identifier\' already declared as const\n");
    while(defined($token = read_token()) and $token ne ";")
    {
      next;
    }
    return;
  }
  if(defined($type_hash{"typedef_hash"}{$identifier}) &&
     $type_hash{"typedef_hash"}{$identifier}{"version"} == $version && !$type_hash{"inherited"})
  {
    print_error("Line $. - Identifier \'$identifier\' already a typedef\n");
    while(defined($token = read_token()) and $token ne ";")
    {
      next;
    }
    return;
  }
  if(defined($forbidden_keywords{$identifier}))
  {
    print_error("Line $. - Identifier \'$identifier\' not valid\n");
    while(defined($token = read_token()) and $token ne ";")
    {
      next;
    }
    return;
  }
  if($identifier =~ m/^[0-9]/)
  {
    print_error("Line $. - Identifier \'$identifier\' not valid\n");
    while(defined($token = read_token()) and $token ne ";")
    {
      next;
    }
    return;
  }
  if(defined($type_hash{"user_types"}{$identifier}) &&
     $type_hash{"user_types"}{$identifier}{"version"} == $version && $type_hash{"inherited"})
  {
    print_warning("Line $. - Redefining Identifier \'$identifier\' \n");
    delete $type_hash{"user_types"}{$identifier};
  }
  return $identifier;
}#  check_identifier

#===========================================================================
#
#FUNCTION CHECK_NUMBER
#
#DESCRIPTION
# This function checks a value to determine if it is a valid
# number (decimal or hex)
#
#DEPENDENCIES
# None.
#
#RETURN VALUE
# None.
#
#SIDE EFFECTS
# May modify ARGV.
#
#===========================================================================
sub check_number
{
   my $number = shift;
   my $token;
   if ($number =~ m/^0x[0-9A-Fa-f]+$|^-?\d+$/)
   {#Value is an integer
      return $TRUE;
   }elsif ($number =~ m/^\d+\.\d+$/)
   {#Value has a decimal
      return $NOT_INTEGER;
   }elsif (defined($type_hash{"const_hash"}{$number}))
   {
      if ($type_hash{"const_hash"}{$number}{"isinteger"})
      {#Value is an integer
         return $TRUE;
      }
      return $NOT_INTEGER;#Value has a decimal
   }

   handle_errors('\n',"Line $. - $number not a valid value\n");

   return $FALSE; #Value is not a valid number
} # check_number

#===========================================================================
#
#FUNCTION CHECK_RESERVED
#
#DESCRIPTION
# This function checks a value to determine if it is one among the
# reserved values, if yes, it increments it and again does the check.
#
#DEPENDENCIES
# None.
#
#RETURN VALUE
# The number in decimal format
#
#SIDE EFFECTS
# None
#
#===========================================================================
sub check_reserved
{
   my $message_id = shift;
   my @reserved_tlvs = shift;
   my $tempId;
   if ($message_id =~ m/^0x[0-9A-Fa-f]+$/)
   {
      $tempId = hex($message_id);
   }
   while( $tempId ~~ @reserved_tlvs )
   {
      $tempId++;
   }
   return $tempId;
} #check_reserved


sub compare_numbers
{
  my $first = shift;
  my $second = shift;
  if (defined($type_hash{"const_hash"}{$first})) {$first = $type_hash{"const_hash"}{$first};}
  if (defined($type_hash{"const_hash"}{$second})) {$second = $type_hash{"const_hash"}{$second};}
  if ($first =~ m/^0x[0-9A-Fa-f]+$/){$first = hex($first);}
  if ($second =~ m/^0x[0-9A-Fa-f]+$/){$second = hex($second);}

  if ($first < $second)
  {
    return -1;
  }elsif ($first > $second)
  {
    return 1;
  }else
  {
    return 0;
  }
}#  compare_numbers

sub is_bitmask
{
  my $number = shift;
  my $low_bits;
  my $high_bits;
  if ($number !~ m/^0x[0-9A-Fa-f]+$/){return $FALSE;}
  #0x00000000 00000000
  #Handle values greater than 32 bits.
  if (length($number) > 10)
  {
    $low_bits = substr($number, -8);
    $low_bits = "0x" . $low_bits;
    $high_bits = substr($number,0,-8);
    $low_bits = hex($low_bits);
    $high_bits = hex($high_bits);
    $number = $low_bits + $high_bits;
    if ($number != $low_bits && $number != $high_bits)
    {
      return $FALSE;
    }
  }else
  {
  $number = hex($number);
  }

  return (($number == 0) || (($number & ($number - 1)) == 0));
}#  is_power_of_two

sub bitmask_range_check {
  my $number = shift;
  my $type = shift;

  if ($type eq "mask")
  {
    if (length($number) > 18) {return $FALSE;}
  }elsif ($type eq "mask32")
  {
    if (length($number) > 10) {return $FALSE;}
  }elsif ($type eq "mask16")
  {
    if (length($number) > 8) {return $FALSE;}
  }else
  {
    if (length($number) > 4) {return $FALSE;}
  }
  return $TRUE;
}#  bitmask_range_check

sub get_enum_values_from_description
{
  my $element = shift;
  my $description = $$element{"valuedescription"};
  my $type = $$element{"type"};
  my $identifier = $$element{"identifier"};
  my $enum_info = $type_hash{"user_types"}{$type};
  my %full_enum_list = ();
  my $enum_list = "";
  foreach (@{$$enum_info{"elementlist"}})
  {
    $full_enum_list{$$_[0]} = $_;
  }
  $description =~ s/\n/@@@@@/g;
  $description =~ s/\s+/ /g;
  if($description =~ s/\s+\@((ENUM)||(MASK))\s*\((.*)\)/%%%%%/)
  {
    my @enum_array = ();
    my @enum_val_array = ();
    my @enum_range_array =();
    my $enum_range_begin;
    my $enum_range_end;
    $enum_list = $4;
    $enum_list =~ s/@@@@@//g;
    $enum_list =~ s/\s+//g;
    if ($enum_list =~ s/(\w+:\w+)//g)
    {
       my $enum_range = $1;
       @enum_range_array = split(/:/,$enum_range);
       if ( $full_enum_list{$enum_range_array[0]}[1] =~ "0[xX]" )
       {
          $enum_range_begin = hex($full_enum_list{$enum_range_array[0]}[1]);
       }
       else
       {
          $enum_range_begin = $full_enum_list{$enum_range_array[0]}[1];
       }
       if ( $full_enum_list{$enum_range_array[1]}[1] =~ "0[xX]" )
       {
           $enum_range_end = hex($full_enum_list{$enum_range_array[1]}[1]);
       }
       else
       {
          $enum_range_end = $full_enum_list{$enum_range_array[1]}[1];
       }
       for (my $index=0; $index< @{$$enum_info{"elementlist"}}; $index++)
       {
          my $val;
          if( $$enum_info{"elementlist"}[$index][1] =~ "0[xX]" )
          {
             $val = hex($$enum_info{"elementlist"}[$index][1]);
          }
          else
          {
             $val = $$enum_info{"elementlist"}[$index][1];
          }
          if ($val >= $enum_range_begin && $val <= $enum_range_end )
          {
             push(@enum_array, $$enum_info{"elementlist"}[$index][0]);
          }
       }
    }
    push(@enum_array, split(/[\;,]/,$enum_list));
    if (@enum_array == 0)
    {
      if (exists($$element{"rangelist"}))
      {
        foreach(@{$$element{"rangelist"}})
        {
          push(@enum_array,$_->{"name"});
        }
      }
    }
    @enum_array = grep { $_ ne ''} @enum_array;
    foreach (@enum_array)
    {
      if (! exists($full_enum_list{$_}))
      {
        print_error("Line $. - Enum Element \'$_\' not in enum $type.  \n" .
                    "          \@ENUM tag for field \'$identifier\' is incorrect.\n");
      }else
      {
        my %enum_hash = ();
        my $enum_id = $_;
        my $enum_value = $full_enum_list{$_}[1];
        my $enum_desc = $full_enum_list{$_}[2];
        chomp($enum_desc);
        $_ = "      - $enum_id ($enum_value) -- $enum_desc";
        $enum_hash{"identifier"} = $enum_id;
        if ($enum_value =~ "0[xX]")
        {
           $enum_value = hex($enum_value);
        }
        $enum_hash{"value"} = $enum_value;
        $enum_hash{"description"} = $enum_desc;
        push(@enum_val_array,\%enum_hash);
      }
    }
    if (@enum_array == 0)
    {
      foreach (@{$$enum_info{"elementlist"}})
      {
        my %enum_hash = ();
        my $enum_id = $$_[0];
        my $enum_value = $$_[1];
        my $enum_desc = $$_[2];
        chomp($enum_desc);
        my $string = "      - $enum_id ($enum_value) -- $enum_desc";
        push(@enum_array,$string);
        $enum_hash{"identifier"} = $enum_id;
        if ($enum_value =~ "0[xX]")
        {
           $enum_value = hex($enum_value);
        }
        $enum_hash{"value"} = $enum_value;
        $enum_hash{"description"} = $enum_desc;
        push(@enum_val_array,\%enum_hash);
      }
    }
    @enum_val_array = sort { ($a->{"value"}) <=> ($b->{"value"}) }@enum_val_array;
    $enum_list = join("\n",@enum_array);
    $$element{"allowedenumvals"}{"description"} = $enum_list;
    $$element{"allowedenumvals"}{"valList"} = \@enum_val_array;
    $description =~ s/@@@@@/\n/g;
    $description =~ s/%%%%%/$enum_list/;
    $$element{"valuedescription"} = $description;
  }
}#  get_enum_values_from_description

sub order_enum_ranges
{
  my $ranges = shift;
  my $min_val = ${@{$ranges}[0]}{"val"};
  my $max_val = ${@{$ranges}[0]}{"val"};
  my %range_hash = ();
  my @range_array = ();
  my $tmp_val;
  $range_hash{"min"} = $min_val;
  $range_hash{"minname"} = ${@{$ranges}[0]}{"name"};
  $range_hash{"max"} = $max_val;
  $range_hash{"maxname"} = ${@{$ranges}[0]}{"name"};
  foreach $tmp_val (@{$ranges})
  {
    if (($$tmp_val{"val"} == $range_hash{"max"} + 1) || ($$tmp_val{"val"} == $range_hash{"max"}))
    {
      $range_hash{"max"} = $$tmp_val{"val"};
      $range_hash{"maxname"} = $$tmp_val{"name"};
    }else
    {
      push(@range_array,dclone(\%range_hash));
      $range_hash{"min"} = $$tmp_val{"val"};
      $range_hash{"minname"} = $$tmp_val{"name"};
      $range_hash{"max"} = $$tmp_val{"val"};
      $range_hash{"maxname"} = $$tmp_val{"name"};
    }
  }
  push(@range_array,dclone(\%range_hash));
  return \@range_array;
}#  order_enum_ranges

sub order_mask_ranges
{
  my $ranges = shift;
  my $tmp_val;
  my $range = 0;
  my $number;
  my $low_bits;
  my $high_bits;

  foreach $number (@{$ranges})
  {
    if (length($number) > 10)
    {
      $low_bits = substr($number, -8);
      $low_bits = "0x" . $low_bits;
      $high_bits = substr($number,0,-8);
      $low_bits = hex($low_bits);
      $high_bits = hex($high_bits);
      $number = $low_bits + $high_bits;
    }else
    {
      $number = hex($number);
    }
    $range = $range | $number;
  }
  return $range;
}

#===========================================================================
#
#FUNCTION HANDLE_COMMENTS
#
#DESCRIPTION
# **This Function is a part of the tokenizing element of this tool**
# This function strips out C style (/**/) comments from the front of
# the current line.  Since comments may span multiple lines, this
# function has state to carry from one line to the next in
# comment_mode.  This function expects to be called after each token
# is removed from the line to catch multiple comments on the same
# line.
# This function is significantly more complex with the addition of the
# Doxygen-style commenting to the ipc IDLs.
#
#DEPENDENCIES
# $COMMENT_MODE is the current state of the state machine.
#
#RETURN VALUE
# The leftovers of the current line.  Undef if the entire current line
# is inside a comment.
#
#SIDE EFFECTS
# The global $COMMENT_MODE may be modified.
#
#===========================================================================
{
   #COMMENT_MODE declared at a scope only accessible to handle_comments function
   my $COMMENT_MODE = "SIMPLE";
sub handle_comments {
  $_ = $_[0];
  my $comment = $_;
  my $keyword;
  my $doc_name;
  #check for the start of document comments
  s/^(\s*?\/\*\*+\<)// and do {
     if ($COMMENT_MODE eq "DOCCOMMENT")  {
        print_error("Line $. - Previous comment not terminated properly\n");
     }
     if ($COMMENT_MODE ne "COMMENT")
     {
        $COMMENT_MODE = "PREVDOCCOMMENT";
     }
  };
  s/^(\s*?\/\/\!\<)// and do {
     if (($COMMENT_MODE eq "PREVDOCCOMMENT") or ($COMMENT_MODE eq "DOCCOMMENT")) {
        print_error("Line $. - Previous comment not terminated properly\n");
     }
      if ($COMMENT_MODE ne "COMMENT")
      {
         $COMMENT_MODE = "PREVDOCSLCOMMENT";
      }
  };
  s/^(\s*?\/\*\*+)// and do {
     if ($COMMENT_MODE eq "PREVDOCCOMMENT") {
        print_error("Line $. - Previous comment not terminated properly\n");
     }
      if ($COMMENT_MODE ne "COMMENT")
      {
         $COMMENT_MODE = "DOCCOMMENT";
      }
  };
  s/^(\s*?\/\/\!)// and do {
     if (($COMMENT_MODE eq "PREVDOCCOMMENT") or ($COMMENT_MODE eq "DOCCOMMENT")) {
        print_error("Line $. - Previous comment not terminated properly\n");
     }
      if ($COMMENT_MODE ne "COMMENT")
      {
         $COMMENT_MODE = "DOCSLCOMMENT";
      }
  };
  # Check for start of comment
  s/^(\s*?\/\*)// and do {
    if (($COMMENT_MODE eq "PREVDOCCOMMENT") or ($COMMENT_MODE eq "DOCCOMMENT")) {
       print_error("Line $. - Previous comment not terminated properly\n");
    }
    $COMMENT_MODE = "COMMENT";
    # We continue on here so that we can check for end of comment etc
  };
  s/^(\s*?\/\/)// and do {
     if (($COMMENT_MODE eq "PREVDOCCOMMENT") or ($COMMENT_MODE eq "DOCCOMMENT")) {
        print_error("Line $. - Previous comment not terminated properly\n");
     }
     if ($COMMENT_MODE ne "COMMENT")
     {
        $COMMENT_MODE = "SLCOMMENT";
     }
  };

  (($COMMENT_MODE eq "DOCCOMMENT" or $COMMENT_MODE eq "DOCSLCOMMENT")
     and ($_ !~ m/(\@latexonly)|(\@endlatexonly)/) and s/(\@\w+)// )and do {
    $keyword = uc($1);
    $keyword =~ s/\@//;

    if (defined($ALLOWED_DOC_MODES{$keyword})) {
      $doc_name = $comment;
      $doc_name =~ s/^.*\@\w+\s+//;
      $DOCUMENTATION_MODE = $keyword;
      $DOCUMENTATION_NAME = $doc_name;
      #The information for this line has been captured, return
      if ($COMMENT_MODE eq "SLCOMMENT") {
        $COMMENT_MODE = "SIMPLE";
      }
      if ($DOCUMENTATION_MODE eq "FILE") {
        $FILE_DOCUMENTATION{"NAME"} = $DOCUMENTATION_NAME unless($INCLUDE_MODE);
      }elsif ($DOCUMENTATION_MODE eq "MSG"){
        $MSG_NAME = $DOCUMENTATION_NAME;
        push(@MSG_ORDER,$DOCUMENTATION_NAME);
      }elsif($DOCUMENTATION_MODE eq "FOOTER" || $DOCUMENTATION_MODE eq "APPENDIX"){
        push(@FOOTER_ORDER,$DOCUMENTATION_NAME);
        $DOCUMENTATION_KEYWORD = "FOOTER";
      }else{
        $DOCUMENTATION_NAME =~ s/\s+$//;
        $PREV_COMMAND_NAME = $COMMAND_NAME;
        $COMMAND_NAME = $DOCUMENTATION_NAME;
        push(@COMMAND_ORDER,$DOCUMENTATION_NAME);
      }
      undef $DOCUMENTATION_KEYWORD unless ($DOCUMENTATION_MODE eq "FOOTER" || $DOCUMENTATION_MODE eq "APPENDIX");
      return undef;
    }
    print STDERR "Keyword \@FILE, \@MSG, or \@COMMAND not set, ERROR\n" unless ($DOCUMENTATION_MODE ne "");
    $DOCUMENTATION_KEYWORD = $keyword;
  };
  if (($COMMENT_MODE eq "DOCCOMMENT" or $COMMENT_MODE eq "DOCSLCOMMENT") and defined($DOCUMENTATION_KEYWORD)) {
    $COMMENT_MODE = handle_doc_comments($COMMENT_MODE,$DOCUMENTATION_KEYWORD,$comment);
    return undef;
  }
  # handle end of comments
  (("DOCCOMMENT" eq $COMMENT_MODE or "PREVDOCCOMMENT" eq $COMMENT_MODE) and s/(\*+\/)// ) and do {
    if ($COMMENT_MODE eq "DOCCOMMENT") {
      $CURRENT_DESCRIPTION .= $_ . "\n";
    }else{
      $PREV_DESCRIPTION .= $_ . "\n";
    }
    $COMMENT_MODE = "SIMPLE";
    return undef;
  };
  ( "DOCSLCOMMENT" eq $COMMENT_MODE or "PREVDOCSLCOMMENT" eq $COMMENT_MODE) and do {
    if ($COMMENT_MODE eq "DOCSLCOMMENT") {
      $CURRENT_DESCRIPTION .= $_ . "\n";
    }else{
      $PREV_DESCRIPTION .= $_ . "\n";
    }
    $COMMENT_MODE = "SIMPLE";
    return undef;
  };
  # handle entire lines inside comments
  ( "DOCCOMMENT" eq $COMMENT_MODE or "PREVDOCCOMMENT" eq $COMMENT_MODE) and do {
    if ($COMMENT_MODE eq "DOCCOMMENT") {
      $CURRENT_DESCRIPTION .= $_ . "\n";
    }else{
      $PREV_DESCRIPTION .= $_ . "\n";
    }
    return undef;
  };
  # handle end of comments
  ( "COMMENT" eq $COMMENT_MODE and s/(.*?\*+\/)// ) and do {
    $COMMENT_MODE = "SIMPLE";
    not /./ and return undef;
  };
  ( "SLCOMMENT" eq $COMMENT_MODE) and do {
    $COMMENT_MODE = "SIMPLE";
    return undef;
  };
  # handle entire lines inside comments
  ( "COMMENT" eq $COMMENT_MODE ) and do {
    return undef;
  };

  return $_;
}#  handle_comments
}

#===========================================================================
#FUNCTION HANDLE_DOC_COMMENTS
#
#DESCRIPTION
# **This Function is a part of the tokenizing element of this tool**
#
#DEPENDENCIES
# $COMMENT_MODE is the current state of the state machine.
#
#RETURN VALUE
# The leftovers of the current line.  Undef if the entire current line
# is inside a comment.
#
#SIDE EFFECTS
# The global $COMMENT_MODE may be modified.
#
#===========================================================================
sub handle_doc_comments
{
  my $COMMENT_MODE = shift;
  my $keyword = shift;
  my $comment = shift;

  if ($comment !~ m/(\@latexonly)|(\@endlatexonly)/)
  {
    $comment =~ s/^.*\@\w+ *//;
  }
  if ($DOCUMENTATION_MODE eq "FILE")
  {
    unless($INCLUDE_MODE)
    {
      if ($keyword eq "REVERSE_SERVICE")
      {
        $REVERSE_SERVICE = 1;
      }else
      {
      $FILE_DOCUMENTATION{$keyword} .= $comment . "\n";
      $FILE_DOCUMENTATION{$keyword} =~ s/\*+\///;
    }
    }
  }elsif($keyword =~ /COMMON\_COMMAND/ and $COMMAND_NAME ne "")
  {
    $comment =~ s/\s+\*+\///;
    if (defined($COMMAND_DOCUMENTATION{$comment}))
    {
      $COMMAND_DOCUMENTATION{$COMMAND_NAME} = dclone($COMMAND_DOCUMENTATION{$comment});
      $COMMON_COMMAND_LINKS{$comment} = $COMMAND_NAME;
    }
  }elsif($keyword =~ /DESCRIPTION|ERROR/ and $COMMAND_NAME ne "")
  {
    $COMMAND_DOCUMENTATION{$COMMAND_NAME}{$keyword} .= $comment . "\n";
    $COMMAND_DOCUMENTATION{$COMMAND_NAME}{$keyword} =~ s/\*+\///;
  }elsif($keyword =~ /CMD\_VERSION|CMD\_DEPRECATED/ and $COMMAND_NAME ne "")
  {
    if ($comment !~ /^\s*\*+\/\s*\n*$/)
    {
      $COMMAND_DOCUMENTATION{$COMMAND_NAME}{$keyword} = $comment . "\n";
      $COMMAND_DOCUMENTATION{$COMMAND_NAME}{$keyword} =~ s/\*+\///;
    }
  }elsif($keyword =~ /CMD\_PROVISIONAL/ and $COMMAND_NAME ne "")
  {
    if ($comment !~ /^\s*\*+\/\s*\n*$/)
    {
      $COMMAND_DOCUMENTATION{$COMMAND_NAME}{$keyword} = $comment . "\n";
      $COMMAND_DOCUMENTATION{$COMMAND_NAME}{$keyword} =~ s/\*+\///;
      print_warning("Line $. - Provisional Command: $COMMAND_NAME - " .
                    $COMMAND_DOCUMENTATION{$COMMAND_NAME}{$keyword});
    }
  }elsif($keyword =~ /($SECURITY_COMMAND_DOC_VALS)/ and $COMMAND_NAME ne "")
  {
    handle_security_comments($keyword,$comment);
  }elsif($keyword eq "ID")
  {
    $comment =~ s/ +//g;
    $comment =~ s/\n//g;
    if (defined($COMMAND_DOCUMENTATION{$comment}))
    {
      $PREV_COMMAND_NAME = $COMMAND_NAME;
      $COMMAND_NAME = $comment;
    }else
    {
      print STDERR "Line $. - WARNING, $comment not a documented command\n";
    }
  }elsif($keyword eq "DOCUMENT_AS_MANDATORY")
  {
    $TLV_DOCUMENTATION{$keyword} = 1;
  }elsif($keyword eq "VERSION" || $keyword eq "TLV_NAME" || $keyword eq "LEN_FIELD"
         || $keyword eq "FIELD_NAME" || $keyword eq "TLVINTRO" || $keyword eq "CARRY_NAME"
         || $keyword eq "VERSION_INTRODUCED" || $keyword eq "PROVISIONAL" || $keyword eq "LEN_DESCRIPTION")
  {
    if (! defined($TLV_DOCUMENTATION{$keyword}) || $keyword =~ /VERSION/)
    {
      $TLV_DOCUMENTATION{$keyword} = $comment;
    }else
    {
      $TLV_DOCUMENTATION{$keyword} .= "\n" . $comment;
    }
  }elsif ($DOCUMENTATION_MODE eq "MSG")
  {
    if($keyword eq "COMMON_MSG")
    {
      my $identifier;
      my $common_found = $FALSE;
      $comment =~ s/\s*\n*$//;
      foreach $identifier (keys %{$type_hash{"user_types"}})
      {
        if ($type_hash{"user_types"}{$identifier}{'ismessage'})
        {
          if ($type_hash{"user_types"}{$identifier}{"msg"} eq $comment)
          {
            $type_hash{"user_types"}{$identifier}{"msg"} = $MSG_NAME;
            undef (%MSG_DOCUMENTATION);
            $common_found = $TRUE;
            last;
          }
        }
      }
      if ($common_found != $TRUE)
      {
         print STDERR "Line $. - WARNING, Common Message $comment not found.\n";
      }
    }else
    {
    $MSG_DOCUMENTATION{$keyword} .= $comment . "\n";
    $MSG_DOCUMENTATION{$keyword} =~ s/\*+\///;
    }
  }elsif ($DOCUMENTATION_MODE eq "FOOTER" || $DOCUMENTATION_MODE eq "APPENDIX")
  {
    $FOOTER_HASH{$FOOTER_ORDER[-1]} .= $comment . "\n";
    $FOOTER_HASH{$FOOTER_ORDER[-1]} =~ s/\*+\///;
  }else
  {
    $COMMAND_DOCUMENTATION{$DOCUMENTATION_NAME}{$keyword} .= $comment . "\n";
    $COMMAND_DOCUMENTATION{$DOCUMENTATION_NAME}{$keyword} =~ s/\*+\///;
  }
  if ($COMMENT_MODE eq "DOCSLCOMMENT")
  {
    $COMMENT_MODE = "SIMPLE";
    undef $DOCUMENTATION_KEYWORD;
  }
  if ($comment =~ m/(.*?\*+\/)/)
  {
    $COMMENT_MODE = "SIMPLE";
    undef $DOCUMENTATION_KEYWORD;
  }
  return $COMMENT_MODE;
}#  handle_doc_comments

sub handle_security_comments
{
  my $keyword = shift;
  my $comment = shift;
  my $usage_vals = "QC Internal|OEM Internal|Production";
  my $security_levels = "Development|Critical|High Risk|Medium Risk|Low Risk";
  my $required_actions = "Remove QC|Remove OEM|Review|SPC|PIN|Verification|Default|Other";
  my $security_sublevels = "SFS|EFS|Write Secret|SPC Items|Address|User Specified|Read Non-Readable|Write Non-Writable|Other";
  if ($keyword eq "USAGE")
  {
    chomp($comment);
    $comment =~ s/^\s+//g;
    $comment =~ s/\s+$//g;
    $comment =~ s/\*\///g;
    return if $comment eq "";
    if ($comment !~ /^($usage_vals)$/i)
    {
      print_error("Line $. - Value \"$comment\" for tag USAGE invalid.\n");
      return;
    }
  }elsif($keyword eq "SECURITY_LEVEL")
  {
    chomp($comment);
    $comment =~ s/^\s+//g;
    $comment =~ s/\s+$//g;
    $comment =~ s/\*\///g;
    return if $comment eq "";
    if ($comment !~ /^($security_levels)$/i)
    {
      print_error("Line $. - Value \"$comment\" for tag SECURITY_LEVEL invalid.\n");
      return;
    }
  }elsif($keyword eq "REQUIRED_ACTION")
  {
    chomp($comment);
    my $errors = $FALSE;
    $comment =~ s/\*\///g;
    $comment =~ s/^\s+//g;
    $comment =~ s/\s+$//g;
    my @comments = split(/\,\s*/,$comment);
    foreach (@comments)
    {
      if ($_ !~ /^($required_actions)$/i)
      {
        print_error("Line $. - Value \"$comment\" for tag REQUIRED_ACTION invalid.\n");
        $errors = $TRUE;
      }
    }
    return if ($errors || $comment eq "");
  }elsif($keyword eq "SECURITY_SUBLEVEL")
  {
    chomp($comment);
    my $errors = $FALSE;
    $comment =~ s/\*\///g;
    $comment =~ s/^\s+//g;
    $comment =~ s/\s+$//g;
    my @comments = split(/\,\s*/,$comment);
    foreach (@comments)
    {
      if ($_ !~ /^($security_sublevels)$/i)
      {
        print_error("Line $. - Value \"$_\" for tag SECURITY_SUBLEVEL invalid.\n");
        $errors = $TRUE;
      }
    }
    return if ($errors || $comment eq "");
  }
  $comment =~ s/\*\///g;
  $COMMAND_DOCUMENTATION{$DOCUMENTATION_NAME}{$keyword} .= $comment . "\n";
}
#===========================================================================
#
#FUNCTION HANDLE_CONST
#
#DESCRIPTION
#  Parses a const and adds a #define to the .h file
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the
#  const and verify its format
#
#RETURN VALUE
#  Void
#
#SIDE EFFECTS
#  .h file updated with new #define
#
#===========================================================================
sub handle_const
{
  my $token;
  my $name;
  my $value;
  my $is_integer;
  my $bwc_error;
  my $version = ($INCLUDE_MODE) ? $INCLUDE_VERSION:$VERSION_NUMBER;
  return unless(defined($token = handle_errors('\w+',"Line $. - Improperly formatted const\n")));
  return unless(defined($name = check_identifier($token,$version)));
  return unless(defined($token = handle_errors('=',"Line $. - Improperly formatted const with identifier: $name\n")));
  return unless(defined($value = read_token()));
  return unless(defined($token = read_token()));

  #Check to see if it is a number w/ a decimal point.
  $type_hash{"const_hash"}{$name}{"suffix"} = "";
  if ($token eq ".")
  {
     $value = $value . $token . read_token();
  }
  elsif ($token =~ /[a-zA-Z]+/)
  {
     $type_hash{"const_hash"}{$name}{"suffix"} = $token;
  }
  $is_integer=check_number($value);
  if ($is_integer == $NOT_INTEGER)
  {
    $type_hash{"const_hash"}{$name}{"isinteger"} = $FALSE;
  }elsif ($is_integer)
  {
    $type_hash{"const_hash"}{$name}{"isinteger"} = $TRUE;
  }else
  {
    return;
  }
  #Check for backwards compatibility
  if (defined(${$golden_xml_hash{$GOLDEN_MODE}}{"consts"}{$name}) && $NO_BWC_CHECKS == $FALSE)
  {
    $bwc_error = bwc_const(${$golden_xml_hash{$GOLDEN_MODE}}{"consts"}{$name}{"value"},$value,$name);
  }
  print_error($bwc_error) if defined($bwc_error);
  $type_hash{"const_hash"}{$name}{"value"} = $value;# unless ($INCLUDE_MODE);

  #Add the version number of the const value, for the case where consts from include files are used.
  if ($INCLUDE_MODE)
  {
    $type_hash{"const_hash"}{$name}{"version"} = $INCLUDE_VERSION;
    $type_hash{"const_hash"}{$name}{"included"} = $TRUE;
  }else
  {
    $type_hash{"const_hash"}{$name}{"version"} = $VERSION_NUMBER;
    $type_hash{"const_hash"}{$name}{"included"} = $FALSE;
  }
  push(@{$type_hash{"const_order"}},$name);
  $type_hash{"const_hash"}{$name}{"description"} = "";
  if ($CURRENT_DESCRIPTION ne "")
  {
    $type_hash{"const_hash"}{$name}{"description"} .= $CURRENT_DESCRIPTION . "\n";
    $CURRENT_DESCRIPTION = "";
  }
  if ($PREV_DESCRIPTION ne "")
  {
    $type_hash{"const_hash"}{$PREV_CONST_NAME}{"description"} .= $PREV_DESCRIPTION . "\n";
    $PREV_DESCRIPTION = "";
  }

  if ($token eq ";")
  {
    $PREV_CONST_NAME = $name;
    $CONST_STATE = $TRUE;
    return;
  }else
  {
    return unless(defined($token = handle_errors(';',"Line $. - Improperly formatted " .
                                                 "const with identifier: $name\n")));
  }
  return;
}#  handle_const

#===========================================================================
#
#FUNCTION HANDLE_DUPLICATE
#
#DESCRIPTION
#  Parses a dup
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the
#  dup and verify its format
#
#RETURN VALUE
#  Void
#
#SIDE EFFECTS
#
#
#===========================================================================
sub handle_duplicate
{
  my %duplicate_hash=();
  my $token;
  my $name;
  my $type = shift;
  my $is_optional = shift;
  my $message_id = shift;
  my $is_lengthless = shift;
  my $offset = shift;
  my $alignment = shift;
  my $orig_offset = $offset;
  unless (defined($message_id))
  {
     $message_id = 0;
  }

  $duplicate_hash{"primitivetype"} = "duplicate";
  $duplicate_hash{"isoptional"} = $is_optional;
  $duplicate_hash{"rangeChecked"} = $FALSE;
  $duplicate_hash{"offset"} = $offset;
  $duplicate_hash{"isduplicate"} = $TRUE;
  $duplicate_hash{"isvararray"} = $FALSE;
  $duplicate_hash{"isarray"} = $FALSE;
  $duplicate_hash{"ismessage"} = $FALSE;
  $duplicate_hash{"isstruct"} = $FALSE;
  $duplicate_hash{"isstring"} = $FALSE;
  $duplicate_hash{"islengthless"} = $FALSE;
  $duplicate_hash{"isenum"} = $FALSE;
  $duplicate_hash{"ismask"} = $FALSE;
  $duplicate_hash{"isvarwiresize"} = $FALSE;
  $duplicate_hash{"set16bitflag"} = $FALSE;
  $duplicate_hash{"set32bitflag"} = $FALSE;
  $duplicate_hash{"len_field_offset"} = 0;
  $duplicate_hash{"command"} = "";
  $duplicate_hash{"msg"} = "";
  $duplicate_hash{"typedescription"} = "";
  $duplicate_hash{"valuedescription"} = "";
  $duplicate_hash{"tlvtype"} = $message_id;
  $duplicate_hash{"type"} = $type;
  $duplicate_hash{"islengthless"} = $is_lengthless;
  $duplicate_hash{"n"} = 1;
  $duplicate_hash{"isincludetype"} = $INCLUDE_MODE;
  $duplicate_hash{"sizeof"} = $type_hash{"idltype_to_ctype"}->{$type};
  $duplicate_hash{"wiresize"} = $type_hash{"idltype_to_wiresize"}->{$type};
  $duplicate_hash{"csize"} = $type_hash{"idltype_to_csize"}->{$type};
  $duplicate_hash{"tlv_version"} = (exists($TLV_DOCUMENTATION{"VERSION"})) ? $TLV_DOCUMENTATION{"VERSION"} : "";
  $duplicate_hash{"tlv_version_introduced"} = (exists($TLV_DOCUMENTATION{"VERSION_INTRODUCED"}))
    ? $TLV_DOCUMENTATION{"VERSION_INTRODUCED"} : "Unknown";
  $duplicate_hash{"tlv_name"} = (exists($TLV_DOCUMENTATION{"TLV_NAME"})) ? $TLV_DOCUMENTATION{"TLV_NAME"} : "";
  $duplicate_hash{"len_field"} = (exists($TLV_DOCUMENTATION{"LEN_FIELD"})) ? $TLV_DOCUMENTATION{"LEN_FIELD"} : "";
  $duplicate_hash{"len_description"} = (exists($TLV_DOCUMENTATION{"LEN_DESCRIPTION"}))
    ? $TLV_DOCUMENTATION{"LEN_DESCRIPTION"} : "";
  $duplicate_hash{"field_name"} = (exists($TLV_DOCUMENTATION{"FIELD_NAME"})) ? $TLV_DOCUMENTATION{"FIELD_NAME"} : "";
  $duplicate_hash{"tlv_intro"} = (exists($TLV_DOCUMENTATION{"TLVINTRO"})) ? $TLV_DOCUMENTATION{"TLVINTRO"} : "";
  $duplicate_hash{"carry_name"} = (exists($TLV_DOCUMENTATION{"CARRY_NAME"})) ? $TLV_DOCUMENTATION{"CARRY_NAME"} : "";
  $duplicate_hash{"provisional"} = (exists($TLV_DOCUMENTATION{"PROVISIONAL"})) ?
    $TLV_DOCUMENTATION{"PROVISIONAL"} : "";
  $duplicate_hash{"document_as_mandatory"} = (exists($TLV_DOCUMENTATION{"DOCUMENT_AS_MANDATORY"})) ? $TRUE : $FALSE;

  undef(%TLV_DOCUMENTATION);

  return unless(defined($token = read_token()));
  unless(check_number($token) == $TRUE)
  {
    print_error("Line $. - Value for TLV Number of $type - must be an integer\n");
  }
  if ($token !~ m/0x/)
  {
    $token = sprintf("0x%02X", $token);
  }
  $duplicate_hash{"isduplicate"} = $token;
  return unless(defined($token = handle_errors('[;=]',"Line $. - improperly formatted $type\n")));
  if ($token eq "=")
  {
    return unless(defined($token = read_token()));
    unless(check_number($token) == $TRUE && hex($token) >= hex($message_id))
    {
      print_error("Line $. - ID Number for message __DUPLICATE__ " .
                  "must be an integer greater than previous element IDs\n");
    }
    $duplicate_hash{"tlvtype"} = $token;
    return unless(defined($token = handle_errors(';',"Line $. - " .
                                                 "improperly formatted $type\n")));
  }
  $duplicate_hash{"identifier"} = "__DUP__" . $duplicate_hash{"isduplicate"};
  return \%duplicate_hash;
}#  handle_duplicate

#===========================================================================
#
#FUNCTION HANDLE_MASK
#
#DESCRIPTION
#  Parses an mask element and generates a hash that is passed to the PRINT_MASK
#  function to produce the correct output for the .h and .c files
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the enum and
#  verify correct format
#
#RETURN VALUE
#  Returns a hash that contains the type (enum) and the identifier
#
#SIDE EFFECTS
#
#
#===========================================================================
sub handle_mask
{
  my %mask_hash = ();
  my %used_values = ();
  my $sub_name;
  my $sub_value;
  my $token;
  my $name;
  my $type = shift;
  my $is_optional = shift;
  my $bwc_error;
  my $version_number;
  my $documentation = "";
  if ($CONST_STATE)
  {
    if ($PREV_DESCRIPTION ne "")
    {
      $type_hash{"const_hash"}{$PREV_CONST_NAME}{"description"} .= $PREV_DESCRIPTION . "\n";
    }
    $CONST_STATE = $FALSE;
  }
  $PREV_DESCRIPTION = "";
  if ($INCLUDE_MODE)
  {
     $version_number = $INCLUDE_VERSION;
  }else
  {
     $version_number = $VERSION_NUMBER;
  }
  $mask_hash{"type"} = $type;
  $mask_hash{"isoptional"} = $is_optional;
  $mask_hash{"ismask"} = $TRUE;
  $mask_hash{"typedescription"} = "";
  if ($CURRENT_DESCRIPTION ne "")
  {
    $mask_hash{"typedescription"} = $CURRENT_DESCRIPTION;
    $CURRENT_DESCRIPTION = "";
  }
  return unless (defined($token = handle_errors('{',"Line $. - Improperly formatted mask encountered\n")));
  #Iterate through all of the defined values in the mask
  while (1)
  {
     return unless (defined($token = handle_errors('\w+',"Line $. - Improperly formatted mask encountered\n")));
     $sub_name = $token;
     if (defined($used_enum_mask_ids{$token}) &&
         $used_enum_mask_ids{$token}{"version"} == $version_number)
     {
        print_error("Line $. - Mask element with identifier: $sub_name - repeated in mask declaration\n");
     }
     $used_enum_mask_ids{$sub_name}{"version"} = $version_number;
     return unless (defined($token = handle_errors('=',"Line $. - Improperly formatted mask encountered\n")));
     return unless(defined($token = read_token()));
     if (bitmask_range_check($token, $type) == $FALSE)
     {
       print_error("Line $. - Value \'$token\' for mask element with identifier: $sub_name - out of range\n");
     }else
     {
       if(is_bitmask($token) == $FALSE)
       {
         print_error("Line $. - Value \'$token\' for mask element with identifier: $sub_name - must be a valid bitmask value in hexadecimal format \n");
       }
     }
     $sub_value = $token;
     if ($PREV_DESCRIPTION ne "") {
       if (defined($mask_hash{"elementlist"}))
       {
         @{@{$mask_hash{"elementlist"}}[-1]}[2] = $PREV_DESCRIPTION;
         $documentation .= $PREV_DESCRIPTION;
       $PREV_DESCRIPTION = "";
     }
     }
     return unless (defined($token = handle_errors('[,\}]',"Line $. - Improperly formatted mask encountered\n")));
     push @{$mask_hash{"elementlist"}},[$sub_name,$sub_value,""];
     if ($token eq "}") {last;}
  }

  return unless (defined($token = handle_errors('\w+',"Line $. - Improperly formatted mask encountered\n")));
  return unless (defined($name = check_identifier($token,$version_number)));
  $mask_hash{"identifier"} = $name;
  return unless (defined($token = handle_errors(';',"Line $. - Improperly formatted mask with identifier: $name encountered\n")));
  if ($PREV_DESCRIPTION ne "")
  {
    @{@{$mask_hash{"elementlist"}}[-1]}[2] = $PREV_DESCRIPTION;
    $documentation .= $PREV_DESCRIPTION;
    $PREV_DESCRIPTION = "";
  }
  if (defined(${$golden_xml_hash{$GOLDEN_MODE}}{"types"}{$name}) && $ERROR_FLAG == $FALSE && $NO_BWC_CHECKS == $FALSE)
  {
     $bwc_error = bwc_mask(${$golden_xml_hash{$GOLDEN_MODE}}{"types"}{$name},\%mask_hash);
  }
  print_error($bwc_error) if defined($bwc_error);

  #$mask_hash{"valuedescription"} = $documentation;
  $mask_hash{"isenum"} = $FALSE;
  $mask_hash{"isstruct"} = $FALSE;
  $mask_hash{"isarray"} = $FALSE;
  $mask_hash{"isstring"} = $FALSE;
  $mask_hash{"n"} = 1;
  $mask_hash{"command"} = "";
  $mask_hash{"tlvtype"} = $FALSE;
  $mask_hash{"isvararray"} = $FALSE;
  $mask_hash{"set16bitflag"} = $FALSE;
  $mask_hash{"set32bitflag"} = $FALSE;
  $mask_hash{"ismessage"} = $FALSE;
  $mask_hash{"sequence"} = 0;
  $mask_hash{"command"} = "";
  $mask_hash{"msg"} = "";
  $mask_hash{"isunsignedenum"} = $FALSE;
  $mask_hash{"isincludetype"} = $INCLUDE_MODE;
  $mask_hash{"version"} = $version_number;
  $mask_hash{"description"}{"TYPE"} = "";
  $mask_hash{"description"}{"SENDER"} = "";
  $mask_hash{"description"}{"TODO"} = "";
  $mask_hash{"description"}{"SCOPE"} = "";
  $mask_hash{"description"}{"MSG_ALIAS"} = "";
  $mask_hash{"sizeof"} = $name . "_v$version_number";
  $mask_hash{"wiresize"} = $type_hash{"idltype_to_wiresize"}->{$type};
  $type_hash{"idltype_to_wiresize"}->{$name} = $type_hash{"idltype_to_wiresize"}->{$type};
  $type_hash{"idltype_to_alignment"}->{$name} = $type_hash{"idltype_to_alignment"}->{$type};
  $type_hash{"idltype_to_csize"}->{$name} = $type_hash{"idltype_to_csize"}->{$type};
  return \%mask_hash;
}#  handle_mask

#===========================================================================
#
#FUNCTION HANDLE_ENUM
#
#DESCRIPTION
#  Parses an enum element and generates a hash that is passed to the PRINT_ENUM
#  function to produce the correct output for the .h and .c files
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the enum and
#  verify correct format
#
#RETURN VALUE
#  Returns a hash that contains the type (enum) and the identifier
#
#SIDE EFFECTS
#
#
#===========================================================================
sub handle_enum
{
  my $type = shift;
  my $is_optional = shift;
  my %enum_hash=();
  my %used_values = ();
  my $sub_name;
  my $sub_value=-1;
  my $prev_value = $MIN_ENUM_SIZE;
  my $token;
  my $name;
  my $bwc_error;
  my $version_number;
  my $unsigned = $FALSE;
  my $display_in_hex = $FALSE;
  if ($type =~ m/uenum/)
  {
    $unsigned = $TRUE;
  }
  if ($CONST_STATE)
  {
    if ($PREV_DESCRIPTION ne "")
    {
      $type_hash{"const_hash"}{$PREV_CONST_NAME}{"description"} .= $PREV_DESCRIPTION . "\n";
    }
    $CONST_STATE = $FALSE;
  }
  $PREV_DESCRIPTION = "";
  if ($INCLUDE_MODE)
  {
     $version_number = $INCLUDE_VERSION;
  }else
  {
     $version_number = $VERSION_NUMBER;
  }
  $enum_hash{"type"} = $type;
  $enum_hash{"isoptional"} = $is_optional;
  $enum_hash{"isenum"} = $TRUE;
  $enum_hash{"isunsignedenum"} = $unsigned;
  return unless (defined($token = handle_errors('{',"Line $. - Improperly formatted enum encountered\n")));
  #Iterate through all of the defined values in the enumeration
  while (1)
  {
     return unless (defined($token = handle_errors('\w+',"Line $. - Improperly formatted enum encountered\n")));
     $sub_name = $token;
     if (defined($used_enum_mask_ids{$token}) &&
         $used_enum_mask_ids{$token}{"version"} == $version_number)
     {
        print_error("Line $. - Enum element with identifier: $sub_name - repeated in enum declaration\n");
     }
     $used_enum_mask_ids{$sub_name}{"version"} = $version_number;
     if ($PREV_DESCRIPTION ne "")
     {
       if (defined($enum_hash{"elementlist"}))
       {
         @{@{$enum_hash{"elementlist"}}[-1]}[2] = $PREV_DESCRIPTION;
         $PREV_DESCRIPTION = "";
       }
     }
     return unless (defined($token = handle_errors('[=,\}]',"Line $. - Improperly formatted enum encountered\n")));
     if ($token eq "=")
     {
        return unless(defined($token = read_token()));
       if ($token =~ m/^\D\w+$/ && $token !~ m/^[-+]/)
       {
         if (defined($used_enum_mask_ids{$token}))
         {
           $sub_value = $used_enum_mask_ids{$token}{"value"};
         }else
         {
           print_error("Line $. - Value \'$token\' for enum element with identifier: " .
                       "$sub_name is not a defined enum element\n");
         }
       }else
       {
        unless(check_number($token) == $TRUE)
        {
           print_error("Line $. - Value \'$token\' for enum element with identifier: " .
                       "$sub_name - must be an integer\n");
        }
         if ($token =~ m/^0x[0-9A-Fa-f]+$/)
     {
           my $length = length($token);
           if ($length-2 > $display_in_hex)
           {
             $display_in_hex = $length - 2;
     }
           if (hex($token) > $MAX_INT_VALUE)
          {
            print_warning("Line $. - Some compilers do not support unsigned int32 values.\n");
          }
         }else
     {
           if ($token < 0)
       {
             if ($display_in_hex)
             {
               print_warning("Line $. - Negative value \'$token\' used in enum with non-negative hex values.\n");
             }
           }
          if ($token > $MAX_INT_VALUE)
          {
            print_warning("Line $. - Some compilers do not support unsigned int32 values.\n");
          }
         }
         $sub_value = $token;
       }
       return unless (defined($token = handle_errors('[,\}]',"Line $. - Improperly formatted enum encountered\n")));
     }else
     {
        $sub_value = increment_enum_value($sub_value,$display_in_hex);
     }
     $prev_value = $sub_value;
     $used_enum_mask_ids{$sub_name}{"value"} = $sub_value;
     push @{$enum_hash{"elementlist"}},[$sub_name,$sub_value,""];
     if ($token eq "}") {last;}
  }
  return unless (defined($token = handle_errors('\w+',"Line $. - Improperly formatted enum encountered\n")));
  return unless (defined($name = check_identifier($token, $version_number)));
  $enum_hash{"identifier"} = $name;
  if ($PREV_DESCRIPTION ne "")
  {
    @{@{$enum_hash{"elementlist"}}[-1]}[2] = $PREV_DESCRIPTION;
    $PREV_DESCRIPTION = "";
  }
  return unless (defined($token = handle_errors(';',"Line $. - Improperly formatted enum with " .
                                                "identifier: $name encountered\n")));

  if (defined(${$golden_xml_hash{$GOLDEN_MODE}}{"types"}{$name}) && $ERROR_FLAG == $FALSE && $NO_BWC_CHECKS == $FALSE)
  {
     $bwc_error = bwc_enum(${$golden_xml_hash{$GOLDEN_MODE}}{"types"}{$name},\%enum_hash);
  }
  print_error($bwc_error) if defined($bwc_error);

  # Initialize the refCnt for the ENUM
  $enum_hash{"refCnt"}=0;
  $enum_hash{"displayinhex"} = $display_in_hex;
  $enum_hash{"ismask"} = $FALSE;
  $enum_hash{"isstruct"} = $FALSE;
  $enum_hash{"isarray"} = $FALSE;
  $enum_hash{"isstring"} = $FALSE;
  $enum_hash{"n"} = 1;
  $enum_hash{"command"} = "";
  $enum_hash{"tlvtype"} = $FALSE;
  $enum_hash{"isvararray"} = $FALSE;
  $enum_hash{"set16bitflag"} = $FALSE;
  $enum_hash{"set32bitflag"} = $FALSE;
  $enum_hash{"ismessage"} = $FALSE;
  $enum_hash{"sequence"} = 0;
  $enum_hash{"command"} = "";
  $enum_hash{"msg"} = "";
  $enum_hash{"isincludetype"} = $INCLUDE_MODE;
  $enum_hash{"version"} = $version_number;
  $enum_hash{"description"}{"TYPE"} = "";
  $enum_hash{"description"}{"SENDER"} = "";
  $enum_hash{"description"}{"TODO"} = "";
  $enum_hash{"description"}{"SCOPE"} = "";
  $enum_hash{"description"}{"MSG_ALIAS"} = "";
  $enum_hash{"sizeof"} = $name . "_v$version_number";
  $enum_hash{"wiresize"} = $type_hash{"idltype_to_wiresize"}->{$type};
  $type_hash{"idltype_to_wiresize"}->{$name} = $type_hash{"idltype_to_wiresize"}->{$type};
  $type_hash{"idltype_to_alignment"}->{$name} = $type_hash{"idltype_to_alignment"}->{$type};
  $type_hash{"idltype_to_csize"}->{$name} = $type_hash{"idltype_to_csize"}->{$type};
  return \%enum_hash;
}#  handle_enum

#===========================================================================
#
#FUNCTION INCREMENT_ENUM_VALUE
#
#DESCRIPTION
#  Increments the value of enum elements, all enum elements not explicitly
#  numbered by the user are given values by the compiler, incrementing the
#  values by 1, the first element is defaulted to 0
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  The value that the next enum element will be if it is not explicitly
#  numbered in the IDL
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub increment_enum_value
{
   my $value = shift;
   my $display_in_hex = shift;
   if ($value =~ m/^0x[0-9A-Fa-f]+$/)
   {
      my $intval = hex($value);
      $intval ++;
      $value = sprintf("0x%0".$display_in_hex."X", $intval);
   }else
   {
      $value++;
      if ($value > $MAX_INT_VALUE)
      {
         print_error("Line $. - Enum values must not be greater than $MAX_INT_VALUE\n");
      }
   }
   return $value;
}#  increment_enum_value

#===========================================================================
#
#FUNCTION HANDLE_ERRORS
#
#DESCRIPTION
#  Checks the next token in the .api file against a supplied test condition and on failure
#  adds the supplied error string to the error_msgs array and then reads through the .api
#  file until it finds the next semi-colon, and on success returns the token.
#
#DEPENDENCIES
#  gets a test_condition and an error_string from the calling function
#  Utilizes function READ_TOKEN to get the token to test against the test condition
#
#RETURN VALUE
#  returns the token from the .api file if the test condition passes, otherwise void
#
#SIDE EFFECTS
#  if the test condition does not pass the error string is added to the error_msgs array,
#  and all of the following tokens in the .api file that precede the next semicolon will
#  be thrown away
#
#===========================================================================
sub handle_errors
{
   my $test_condition = shift;
   my $error_string = shift;
   my $token;
   #compare the token to the test condition, and return it if it passes
   if (defined($token = read_token()) and $token =~ /$test_condition/)
   {
      return $token;
   }
   #If the test has failed, add the error message to the error_msgs array and
   #parse through to the next semicolon
   print_error($error_string);
   if ($token eq ";")
   {
      return;
   }
   while(defined($token = read_token()) and $token ne ";")
   {
      next;
   }
   if ($token eq ";")
   {
      return;
   }else
   {
      die "Too many parsing errors, dying\n";
   }
}# handle_errors

#===========================================================================
#
#FUNCTION HANDLE_INHERIT
#
#DESCRIPTION
#  Parses any inherited JSON files, pulling out the relevant type information so that the current IDL
#  file can be processed correctly
#
#DEPENDENCIES
#  Inherited JSON file must be in at least one of the directories in the @INCLUDE_FILES variable
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  Type hashes and arrays filled in with inherited JSON information
#===========================================================================
sub handle_inherit
{
   my $token;
   my $filename;
   my $results;
   return unless(defined($token = handle_errors('"',"Line $. - improperly formatted inherit declaration\n")));
   return unless(defined($token = handle_errors('\w+',"Line $. - improperly formatted inherit declaration\n")));
   $filename = $token;
   $token = read_token();
   while ($token ne "\"")
   {
      $filename .= $token;
      return unless(defined($token = handle_errors('\.|\w+|\"',"Line $. - improperly formatted inherit declaration\n")));
   }
   return unless(defined($token = handle_errors(';',"Line $. - improperly formatted inherit declaration\n")));
   if ($filename =~ /\.json$/ && $USE_JSON_LIBS)
   {
      # Its a json file, decode the file, assign the info to the type_hash structure and return
      local $/;
      my $json = JSON->new;
      if (!(-r $filename))
      {
         print_error("Line $. File $filename not readable. The generated O/P for this file might not be complete. \n");
         return;
      }
      open( my $fh, '<',$filename);
      my $new_hash = "";
      my $json_text   = <$fh>;
      close($fh);
      $new_hash = $json->utf8->decode($json_text);
      %type_hash = %{ dclone $new_hash};
      %COMMAND_DOCUMENTATION = %{dclone $type_hash{"command_documentation"}};
      %COMMON_COMMAND_LINKS = %{dclone $type_hash{"common_command_links"}};
      @COMMAND_ORDER = @{dclone $type_hash{"command_order"}};
      %FOOTER_HASH = %{dclone $type_hash{"footer"}};
      @FOOTER_ORDER = @{dclone $type_hash{"footer_order"}};
      $type_hash{"inherited"} = $TRUE;
      return;
   }
   else
   {
      if ( $USE_JSON_LIBS == $FALSE)
      {
         print_error("Line $. - Perl JSON library not installed \n");
      }
      else
      {
         print_error("Line $. - Invalid INHERIT syntax. Can inherit only JSON files. EXITING !!! \n");
      }
      return;
   }
   return;
} #handle_inherit

#===========================================================================
#
#FUNCTION HANDLE_INCLUDE
#
#DESCRIPTION
#  Parses any #included IDL files, pulling out the relevant type information so that the current IDL
#  file can be generated correctly
#
#DEPENDENCIES
#  #included file must be in at least one of the directories in the @INCLUDE_FILES variable
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  Type hashes and arrays filled in with included IDL type information
#===========================================================================
sub handle_include
{
   my $token;
   my $filename;
   my $idlname;
   my $results;
   my $array_loc;
   my $INC_STRUCT_SEQ_NUM = 0;       #Keep track of sequence numbers for included structures, used
                                     # for backwards compatibility and array indexes
   my $INC_MSG_SEQ_NUM = 0;          #Keep track of sequence numbers for included messages, used for
                                     # backwards compatibility and array indexes
   if ($INCLUDE_LEVEL > 1)
   {
      handle_errors('\n',"Line $. - Cannot include files more than 2 levels deep.\n");
      return;
   }
   return unless(defined($token = handle_errors('"',"Line $. - improperly formatted include declaration\n")));
   return unless(defined($token = handle_errors('\w+',"Line $. - improperly formatted include declaration\n")));
   $filename = $token;
   $token = read_token();
   while ($token ne "\"")
   {
      $filename .= $token;
      return unless(defined($token = handle_errors('\.|\w+|\"',"Line $. - improperly formatted include declaration\n")));
   }
   return unless(defined($token = handle_errors(';',"Line $. - improperly formatted include declaration\n")));
   if ($filename =~ /\w+\_v(\d\d)/)
   {
      $INCLUDE_VERSION = $1;
   }else
   {
      #TODO:dont die
      die "Included IDL filename ($filename) must end with _v##.idl where ## is the major version of the IDL.";
   }
   $idlname = basename($filename,".idl");
   foreach (@{$type_hash{"include_files"}})
   {
     if ($filename eq $_)
     {
       return;
     }
   }
   if ($filename =~ /\w+\_v(\d\d)/)
   {
       push(@INCLUDE_VERSION_QUEUE,$INCLUDE_VERSION);
      $INCLUDE_VERSION = $1;
   }else
   {
      #TODO:dont die
      die "Included IDL filename ($filename) must end with _v##.idl where ## is the major version of the IDL.";
   }
   push(@{$type_hash{"include_files"}},$filename);
   $INC_MSG_SEQ_NUM = 0;
   $INC_STRUCT_SEQ_NUM = 0;
   $INCLUDE_LEVEL ++;
   $INCLUDE_MODE = $TRUE;
   $GOLDEN_MODE = "include";
   #Get the index into the type table
   $array_loc = @{$type_hash{"include_files"}};

   #Find the included idl file in @INCLUDE_FILES directories
   $INCLUDEFILENAME = find_file($filename);
   $IDL_FILENAMES[$INCLUDE_LEVEL] = find_file($filename);
   die "Unable to locate include file $filename" unless defined($IDL_FILENAMES[$INCLUDE_LEVEL]);
   read_golden_xml();
   #open(INCLUDEFILE,$INCLUDEFILENAME) or die("Unable to open include file $INCLUDEFILENAME");
   open($IDL_FILES[$INCLUDE_LEVEL],$IDL_FILENAMES[$INCLUDE_LEVEL])
     or die("Unable to open include file $INCLUDEFILENAME");
   #Loop over the entire included file, parsing out all definitions and storing them
   while (defined ($token = read_token()))
   {
      if (defined $type_keywords{$token})
      {
         $results = $type_keywords{$token}($token,0,0,$FALSE,0,0);
         if (defined($results))
         {
            push(@{$type_hash{"include_types_order"}},$results->{"identifier"});
            $type_hash{"user_types"}{$results->{"identifier"}} = $results;
            $type_hash{"include_types"}{$idlname}{$results->{"identifier"}} = $results;
            $type_hash{"include_types"}{$idlname}{$results->{"identifier"}}{"arrayLoc"} = $array_loc;
            $type_keywords{$results->{"identifier"}} = \&handle_primitives;
            $type_hash{"idltype_to_ctype"}->{$results->{"identifier"}} = $results->{"sizeof"};
            $type_hash{"idltype_to_type_array"}->{$results->{"identifier"}} =
               $type_hash{"idltype_to_type_array"}->{$results->{"type"}};
            if ($results->{"type"} eq "struct")
            {
               $type_hash{"include_types"}{$idlname}{$results->{"identifier"}}{"sequence"} = $INC_STRUCT_SEQ_NUM;
               $INC_STRUCT_SEQ_NUM++;
            }elsif ($results->{"type"} eq "message")
            {
               $type_hash{"include_types"}{$idlname}{$results->{"identifier"}}{"sequence"} = $INC_MSG_SEQ_NUM;
               $INC_MSG_SEQ_NUM++;
            }
         }
      } else
      {
         print STDERR "Line $. - unrecognized token $token encountered\n"
      }
   }
   $type_hash{"include_types"}{$idlname}{"version"} = $INCLUDE_VERSION;
   @{$type_hash{"range_types"}} = ();
   close($IDL_FILES[$INCLUDE_LEVEL]);
   $GOLDEN_MODE = "golden";
   $INCLUDE_LEVEL --;
   $INCLUDE_MODE = ($INCLUDE_LEVEL > 0) ? $TRUE:$FALSE;
   $INCLUDE_VERSION = pop(@INCLUDE_VERSION_QUEUE);
   return;
}#  handle_include

#===========================================================================
#
#FUNCTION HANDLE_RESERVED_IDS
#
#DESCRIPTION
#  Parses the "reserved_xxx" tag and populates the values in a list until
#  it encounters ";". Invoked while handling "reserved_tlvs" and "reserved_msgs"
#  keyword
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the list and
#  verify correct format
#
#RETURN VALUE
#  Returns a list of the reserved IDs which should not be used (in decimal format)
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub handle_reserved_ids
{
  my ($reserved_ids_list) = @_;
  my $token;
  my $next_token;
  my @temp_array;
  while (defined($token = read_token()) and $token ne ";")
  {
     if ($token =~ m/^0x[0-9A-Fa-f]+$|^\d+$/)
     {
        if ($token =~ m/^0x[0-9A-Fa-f]+$/)
        {
           $token = hex($token);
        }
        if ( defined($next_token = read_token()) and $next_token eq ":" )
        {
           if ( defined($next_token = read_token()) and $next_token ne ";")
           {
                if ($next_token =~ m/^0x[0-9A-Fa-f]+$|^\d+$/)
                {
                   if ($next_token =~ m/^0x[0-9A-Fa-f]+$/)
                   {
                      $next_token = hex($next_token);
                   }
                }
                @temp_array = ($token..$next_token);
                push(@$reserved_ids_list,@temp_array);
                next;
           }
           else
           {
              print_error("Line $. - Invalid syntax \n");
              last;
           }

        }
        elsif ( $next_token eq ";" )
        {
           push(@$reserved_ids_list, $token);
           last;
        }
        push(@$reserved_ids_list, $token);
     }
  }
} # handle_reserved_ids

#===========================================================================
#
#FUNCTION HANDLE_MESSAGE
#
#DESCRIPTION
#  Parses a struct element and generates a hash that is passed to the PRINT_STRUCT
#  function to produce the correct output for the .h and .c files
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the struct and
#  verify correct format
#
#RETURN VALUE
#  Returns a hash that contains the name of the struct as well as an array of
#  hashes that contain information about the types defined within the struct
#
#SIDE EFFECTS
#
#
#===========================================================================
sub handle_message
{
  my %message_hash = ();
  my $sub_stack;
  my $token;
  my $name;
  my $wiresize = 0;
  my $is_var_wire_size = $FALSE;
  my $is_optional = $FALSE;
  my $is_lengthless = $FALSE;
  my $message_id = "0x01";
  my $last_index = -1;
  my $elm_offset = 0;
  my $alignment = 0;
  my %identifier_list = ();
  my $version_number;
  my $bwc_error;
  my @reserved_tlvs = ();
  my $extended = $FALSE;
  my $refcnt = 0;
  if ($CONST_STATE)
  {
    if ($PREV_DESCRIPTION ne "")
    {
      $type_hash{"const_hash"}{$PREV_CONST_NAME}{"description"} .= $PREV_DESCRIPTION . "\n";
    }
    $CONST_STATE = $FALSE;
  }
  $PREV_DESCRIPTION = "";
  if ($INCLUDE_MODE)
  {
     $version_number = $INCLUDE_VERSION;
  }else
  {
     $version_number = $VERSION_NUMBER;
  }
  $message_hash{"isoptional"} = $FALSE;
  $message_hash{"isenum"} = $FALSE;
  $message_hash{"type"} = "message";
  #Verify the first token after the struct keyword is the opening bracket
  $CURRENT_DESCRIPTION = "";
  return unless(defined($token = handle_errors('{',"Line $. - improperly formatted message declaration\n")));
  #Iterate through all the elements declared within the struct

  while (defined ($token = read_token()) and "}" ne $token )
  {
     #check for message inheritance
     if ($token eq "extends")
     {
        %message_hash = handle_extends();
        # since it is an extended message, populate the identifier list so as to eliminate duplicate identifiers
        for (@{$message_hash{"elementlist"}})
        {
           if ($_->{"isvarwiresize"})
           {
              $identifier_list{$_->{"identifier"} . "_len"} = 1;
           }
           elsif ($_->{"isoptional"})
           {
              $identifier_list{$_->{"identifier"} . "_valid"} = 1;
           }
           $identifier_list{$_->{"identifier"}} = 1;
        }
        $message_id = $message_hash{"lastTLVid"};
        $extended = $TRUE;
        $wiresize += $message_hash{"wiresize"};
        # to determine the offset and alignment
        $elm_offset = $message_hash{"lastOffset"};
        $alignment = $message_hash{"lastAlignment"};
        next;
     }

     # check for reserved IDs
     if ($token eq "reserved_tlvs")
     {
        handle_reserved_ids(\@reserved_tlvs);
        next;
     }
     # perform checks to see if the message has been extended and if the first attribute is optional.
     if ( $extended && $token eq "mandatory" )
     {
        print_error("Line $. 'Mandatory' keyword in an inherited message is not allowed !!\n");
     }
     #Perform checks for mandatory and optional keywords. Verify no mandatory elements declared after optionals
     if (($token eq "mandatory") && $is_optional)
     {
        handle_errors('\n',"Line $. - mandatory message parameter(s) located after optional message paramater(s)\n");
        next;
     }elsif (($token eq "optional") && not $is_optional)
     {
        $is_optional = $TRUE;
        my $tempId = hex($message_id);
        if ($tempId < 0x10 )
        {
           $message_id = "0x10";
        }
     }elsif ($token eq "optional")
     {
        $is_optional = $TRUE;
     }elsif ($token eq "mandatory")
     {
        $is_optional = $FALSE;
     }
     else
     {
        handle_errors('\n',"Line $. - message parameter requires optional or mandatory keyword\n");
        next;
     }

     next unless(defined($token = handle_errors('\w+',"Line $. - improperly formatted message declaration\n")));
     if ($token eq "lengthless")
     {
        $is_lengthless = $TRUE;
        next unless(defined($token = handle_errors('\w+',"Line $. - improperly formatted message declaration\n")));
     }
     #If a type keyword is encountered, handle that type
     if (defined $type_keywords{$token} || ($token ~~ @{$type_hash{"user_types_order"}} ))
     {
        if (defined $type_keywords{$token})
        {
           $sub_stack = $type_keywords{$token}($token,$is_optional,$message_id,$is_lengthless,$elm_offset,$alignment,\@reserved_tlvs);
        }
        elsif ($token ~~ @{$type_hash{"user_types_order"}})
        {
           $sub_stack = handle_primitives($token,$is_optional,$message_id,$is_lengthless,$elm_offset,$alignment,\@reserved_tlvs);
        }
        else
        {
           print_error("Line $. -Unknown identifier $token");
           handle_errors(';',"Line $. - improperly formatted message declaration\n");
        }
        if(defined($sub_stack))
        {
           if ($sub_stack->{"isvarwiresize"})
           {
              $is_var_wire_size = $TRUE;
              #check to see if the _len field of the variable sized element was
              #already defined, if so, error
              if (defined($identifier_list{$sub_stack->{"identifier"} . "_len"}))
              {
                 #Better Error message -AJL
                 print_error("Line $. - Multiple definition of identifier: " .
                             $sub_stack->{"identifier"} . "_len\n" .
                             "          _len fields for variable length elements automatically" .
                             " added by qmi_idl_compiler.\n");
                 if($extended)
                 {
                    print_error("Identifier may be defined in the base message.\n");
                 }
              }else
              {
                 $identifier_list{$sub_stack->{"identifier"} . "_len"} = 1;
              }
           }
           #check to see if the _valie field of the optional element was
           #already defined, if so, error
           if ($sub_stack->{"isoptional"})
           {
              if (defined($identifier_list{$sub_stack->{"identifier"} . "_valid"}))
              {
                 print_error("Line $. - Multiple definition of identifier: " .
                             $sub_stack->{"identifier"} . "_valid\n");
                 if($extended)
                 {
                    print_error("Identifier may be defined in the base message.\n");
                 }
              }else
              {
                 $identifier_list{$sub_stack->{"identifier"} . "_valid"} = 1;
              }
           }
           #Check to see if the identifier is used multiple times within the same message
           if (defined($identifier_list{$sub_stack->{"identifier"}}))
           {
              print_error("Line $. - Multiple definition of identifier: " . $sub_stack->{"identifier"} . "\n");
              if($extended)
              {
                 print_error("Identifier may be defined in the base message.\n");
              }
           }else
           {
              $identifier_list{$sub_stack->{"identifier"}} = 1;
           }

           #Increment the wire size of the message based on the element wire size
           $wiresize += $sub_stack->{"wiresize"};
           $elm_offset += $sub_stack->{"csize"};
           $alignment = $type_hash{"idltype_to_alignment"}->{$sub_stack->{"type"}} unless
             ($alignment > $type_hash{"idltype_to_alignment"}->{$sub_stack->{"type"}});

           #If the element is a variable array add more bytes for the additional length field
           if ($sub_stack->{"isvararray"})
           {
              my $len;
              if (defined($type_hash{"const_hash"}{$sub_stack->{"n"}}))
              {
                 $len = $type_hash{"const_hash"}{$sub_stack->{"n"}}->{"value"}
              }else
              {
                 $len = $sub_stack->{"n"}
              }
              #Add bytes for the additional _len field
              if($sub_stack->{"set32bitflag"})
              {
                 $wiresize += 4;
              }elsif ($len > $SET_16_BIT_VALUE || $sub_stack->{"set16bitflag"})
              {
                 $wiresize += 2;
              }else
              {
                 $wiresize += 1;
              }
           }
           #If the TLV is a string, set the lengthless flag to true
           if ($sub_stack->{"isstring"})
           {
              $sub_stack->{"islengthless"} = $TRUE;
              $sub_stack->{"len_field"} = "";
           }
           #Add 3 bytes for the TL portion of the TLV
           $wiresize += 3;
           #message documentation logic
           if ($last_index != -1)
           {
             my $tmp_last_index = $last_index;
             if (${message_hash{"elementlist"}}[$last_index]{"tlvtype"} eq "0x01" && ${message_hash{"elementlist"}}[0]{"type"} eq "qmi_response_type")
             {
               $last_index = 0;
             }
             ${message_hash{"elementlist"}}[$last_index]{"valuedescription"} = $PREV_DESCRIPTION;
             ${message_hash{"elementlist"}}[$last_index]{"allowedenumvals"}{"description"} = "";
             if (${message_hash{"elementlist"}}[$last_index]{"primitivetype"} =~ m/(enum)|(mask)/)
             {
               get_enum_values_from_description(${message_hash{"elementlist"}}[$last_index]);
             }
             if (defined($type_hash{"user_types"}{${message_hash{"elementlist"}}[$last_index]{"type"}}))
             {
               if ($type_hash{"user_types"}{${message_hash{"elementlist"}}[$last_index]{"type"}}{"ismask"} ||
                 $type_hash{"user_types"}{${message_hash{"elementlist"}}[$last_index]{"type"}}{"isenum"})
               {
                 if (defined($type_hash{"user_types"}{${message_hash{"elementlist"}}
                 [$last_index]{"type"}}->{'valuedescription'}))
                 {
                   #${message_hash{"elementList"}}[$last_index]{"valuedescription"} .=
                   #  $type_hash{"user_types"}{${message_hash{"elementList"}}
                   #  [$last_index]{"type"}}->{'valueDescription'};
                 }
               }
             }
             $last_index = $tmp_last_index;
             $PREV_DESCRIPTION = "";
           }

           if ($CURRENT_DESCRIPTION ne "")
           {
              $sub_stack->{"typedescription"} = $CURRENT_DESCRIPTION . "\n";
              $CURRENT_DESCRIPTION = "";
           }
           if ($sub_stack->{"type"} eq "qmi_response_type")
           {
             unshift (@{$message_hash{"elementlist"}},$sub_stack);
           }else
           {
             push (@{$message_hash{"elementlist"}},$sub_stack);
           }
           $message_id = $sub_stack->{"tlvtype"};
           my $tempId = hex($message_id);
           $tempId++;
           $message_id = sprintf("0x%02X", $tempId);
           $message_hash{"lastTLVid"} = $message_id;
           $message_hash{"lastOffset"} = $elm_offset;
           $message_hash{"lastAlignment"} = $alignment;
           my @array = @{$message_hash{"elementlist"}};
           $last_index = $#array;
        }
     }else
     {
        #Type not recognized, Error message
        handle_errors('\n',"Line $. - $token not a recognized type\n");
     }
  }
  return unless(defined($token = handle_errors('\w+',"Line $. - improperly formatted message declaration\n")));
  if (defined($type_hash{"user_types"}{$token}) &&
      ($type_hash{"user_types"}{$token}{"version"}  == $version_number) &&
      $type_hash{"inherited"})
  {
      $refcnt = $type_hash{"user_types"}{$token}{"refCnt"};
      $COMMAND_NAME = $type_hash{"user_types"}{$token}{"command"};
  }

  return unless(defined($name = check_identifier($token, $version_number)));
  return unless(defined($token = handle_errors(';',"Line $. - improperly formatted message with identifier: $name\n")));

  if (defined($message_hash{"elementlist"}))
  {
     if (($elm_offset % $alignment) != 0)
     {
        $elm_offset = calc_offset($elm_offset,$alignment);
     }
  }
  if ($version_number < 0)
  {
     print_error("Line $. - Version number not defined before message $name\n");
  }
  #if ($PREV_DESCRIPTION ne "")
  #{
  #   ${message_hash{"elementList"}}[$last_index]{"valuedescription"} = $PREV_DESCRIPTION unless ($last_index == -1);
  #}
  if ($last_index != -1)
  {
    my $tmp_last_index = $last_index;
    if (${message_hash{"elementlist"}}[$last_index]{"tlvtype"} eq "0x01" && ${message_hash{"elementlist"}}[0]{"type"} eq "qmi_response_type")
    {
      $last_index = 0;
    }
    ${message_hash{"elementlist"}}[$last_index]{"valuedescription"} = $PREV_DESCRIPTION;
    ${message_hash{"elementlist"}}[$last_index]{"allowedenumvals"}{"description"} = "";
    if (${message_hash{"elementlist"}}[$last_index]{"primitivetype"} =~ m/(enum)|(mask)/)
    {
      get_enum_values_from_description(${message_hash{"elementlist"}}[$last_index]);
    }
    if (defined($type_hash{"user_types"}{${message_hash{"elementlist"}}[$last_index]{"type"}}))
    {
      if ($type_hash{"user_types"}{${message_hash{"elementlist"}}[$last_index]{"type"}}{"ismask"} ||
        $type_hash{"user_types"}{${message_hash{"elementlist"}}[$last_index]{"type"}}{"isenum"})
  {
        if (defined($type_hash{"user_types"}{${message_hash{"elementlist"}}
        [$last_index]{"type"}}->{'valuedescription'}))
        {
          ${message_hash{"elementlist"}}[$last_index]{"valuedescription"} .=
            $type_hash{"user_types"}{${message_hash{"elementlist"}}
            [$last_index]{"type"}}->{'valuedescription'};
        }
      }
    }
    $last_index = $tmp_last_index;
  }
  $PREV_DESCRIPTION = "";
  $CURRENT_DESCRIPTION = "";
  #Fill in Documentation information
  $message_hash{"description"}{"TYPE"} = "";
  $message_hash{"description"}{"SENDER"} = "";
  $message_hash{"description"}{"TODO"} = "";
  $message_hash{"description"}{"SCOPE"} = "";
  $message_hash{"description"}{"MSG_ALIAS"} = "";

  # Initialize the reference counter for the type
  $message_hash{"refCnt"}=$refcnt;

  if (defined($MSG_DOCUMENTATION{"TYPE"}))
  {
     $message_hash{"description"}{"TYPE"} = format_doc_output($MSG_DOCUMENTATION{"TYPE"});
  }
  if (defined($MSG_DOCUMENTATION{"SENDER"}))
  {
     $message_hash{"description"}{"SENDER"} = format_doc_output($MSG_DOCUMENTATION{"SENDER"});
  }
  if (defined($MSG_DOCUMENTATION{"TODO"}))
  {
     $message_hash{"description"}{"TODO"} = format_doc_output($MSG_DOCUMENTATION{"TODO"});
  }
  if (defined($MSG_DOCUMENTATION{"SCOPE"}))
  {
     $message_hash{"description"}{"SCOPE"} = format_doc_output($MSG_DOCUMENTATION{"SCOPE"});
  }
  if (defined($MSG_DOCUMENTATION{"MSG_ALIAS"}))
  {
     $message_hash{"msgalias"} = format_doc_output($MSG_DOCUMENTATION{"MSG_ALIAS"});
  }
  $type_hash{"idltype_to_wiresize"}->{$name} = $wiresize;
  $type_hash{"idltype_to_csize"}->{$name} = $elm_offset;
  $type_hash{"idltype_to_alignment"}->{$name} = $alignment;
  if ($wiresize ne "var" and $wiresize > $MAX_TYPE_SIZE)
  {
     print STDERR "Message $name\'s wire size might be >= $MAX_TYPE_SIZE bytes\n";
     print STDERR "Max wire size for $name is $wiresize\n";
     $wiresize = $MAX_TYPE_SIZE-1;
  }
  #Update Range Checking Name Information
  foreach (@{$message_hash{"elementlist"}})
  {
    if($_->{"rangeChecked"})
    {
      @{$type_hash{"range_types"}}[$_->{"rangerorder"}]->{"rangeCheckName"} = $name . "_" . $_->{"identifier"};
    }
  }
  #Fill in the hash
  $message_hash{"csize"} = $elm_offset;
  $message_hash{"identifier"} = $name;
  $message_hash{"isvarwiresize"} = $is_var_wire_size;
  $message_hash{"wiresize"} = $wiresize;
  $message_hash{"command"} = $COMMAND_NAME;
  $message_hash{"msg"} = $MSG_NAME;
  $message_hash{"isstruct"} = $FALSE;
  $message_hash{"isstring"} = $FALSE;
  $message_hash{"isenum"} = $FALSE;
  $message_hash{"ismask"} = $FALSE;
  $message_hash{"isarray"} = $FALSE;
  $message_hash{"n"} = 1;
  $message_hash{"tlvtype"} = $FALSE;
  $message_hash{"version"} = $version_number;
  $message_hash{"isvararray"} = $FALSE;
  $message_hash{"islengthless"} = $FALSE;
  $message_hash{"set16bitflag"} = $FALSE;
  $message_hash{"set32bitflag"} = $FALSE;
  $message_hash{"ismessage"} = $TRUE;
  $message_hash{"isincludetype"} = $INCLUDE_MODE;
  $message_hash{"sizeof"} = "struct " . $name;
  undef %MSG_DOCUMENTATION;
  if (defined(${$golden_xml_hash{$GOLDEN_MODE}}{"types"}{$name}) && $ERROR_FLAG == $FALSE && $NO_BWC_CHECKS == $FALSE)
  {
     $bwc_error = bwc_type_msg_elms(${$golden_xml_hash{$GOLDEN_MODE}}{"types"}{$name},\%message_hash,$name);
     bwc_deprecated_type(${$golden_xml_hash{$GOLDEN_MODE}}{"types"}{$name},\%message_hash,$name);
  }
  print_error($bwc_error) if defined($bwc_error);
  return \%message_hash;
}#  handle_message

#===========================================================================
#
#FUNCTION handle_primitives
#
#DESCRIPTION
#  Parses an int, unsigned int, double, or float element and generates a hash
#  that is passed to the PRINT_STRING function to produce the correct output
#  for the .h and .c files
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the type and
#  verify correct format
#
#RETURN VALUE
#  Returns a hash that contains the type, the identifier, and the size
#
#SIDE EFFECTS
#
#
#===========================================================================
sub handle_primitives
{
  my %primitive_hash=();
  my $token;
  my $name;
  my $type = shift;
  my $is_optional = shift;
  my $message_id = shift;
  my $is_lengthless = shift;
  my $offset = shift;
  my $alignment = shift;
  my @reserved_tlvs = shift;
  my $orig_offset = $offset;
  my $version_number = ($INCLUDE_MODE) ? $INCLUDE_VERSION:$VERSION_NUMBER;
  my $explicit_assignment = $FALSE;
  unless (defined($message_id))
  {
     $message_id = 0;
  }
  $alignment = $type_hash{"idltype_to_alignment"}->{$type} unless
    ($alignment > $type_hash{"idltype_to_alignment"}->{$type});
  if ($is_optional)
  {
     #increment offset for boolean is_valid field
     $offset++;
  }

  #Fill in the hash (Some values are defaults)
  $primitive_hash{"primitivetype"} = $type;
  if (defined($type_hash{"user_types"}{$type}->{"type"}))
  {
    $primitive_hash{"primitivetype"} = $type_hash{"user_types"}{$type}->{"type"};
  }
  if (defined($type_hash{"user_types"}{$type}->{"isunsignedenum"}))
  {
    $primitive_hash{"isunsignedenum"} = $type_hash{"user_types"}{$type}->{"isunsignedenum"};
  }else
  {
    $primitive_hash{"isunsignedenum"} = $FALSE
  }
  $primitive_hash{"isoptional"} = $is_optional;
  $primitive_hash{"rangeChecked"} = $FALSE;
  $primitive_hash{"offset"} = $offset;
  $primitive_hash{"isduplicate"} = $FALSE;
  $primitive_hash{"isvararray"} = $FALSE;
  $primitive_hash{"isarray"} = $FALSE;
  $primitive_hash{"ismessage"} = $FALSE;
  $primitive_hash{"isstruct"} = $FALSE;
  $primitive_hash{"isstring"} = $FALSE;
  $primitive_hash{"islengthless"} = $FALSE;
  $primitive_hash{"isenum"} = $FALSE;
  $primitive_hash{"ismask"} = $FALSE;
  $primitive_hash{"isvarwiresize"} = $FALSE;
  $primitive_hash{"set16bitflag"} = $FALSE;
  $primitive_hash{"set32bitflag"} = $FALSE;
  $primitive_hash{"len_field_offset"} = 0;
  $primitive_hash{"command"} = "";
  $primitive_hash{"msg"} = "";
  $primitive_hash{"typedescription"} = "";
  $primitive_hash{"valuedescription"} = "";
  $primitive_hash{"tlvtype"} = $message_id;
  $primitive_hash{"type"} = $type;
  $primitive_hash{"islengthless"} = $is_lengthless;
  $primitive_hash{"n"} = 1;
  $primitive_hash{"isincludetype"} = $INCLUDE_MODE;
  $primitive_hash{"sizeof"} = $type_hash{"idltype_to_ctype"}->{$type};
  $primitive_hash{"wiresize"} = $type_hash{"idltype_to_wiresize"}->{$type};
  $primitive_hash{"csize"} = $type_hash{"idltype_to_csize"}->{$type};
  $primitive_hash{"tlv_version"} = (exists($TLV_DOCUMENTATION{"VERSION"})) ? $TLV_DOCUMENTATION{"VERSION"} : "Unknown";
  $primitive_hash{"tlv_version_introduced"} = (exists($TLV_DOCUMENTATION{"VERSION_INTRODUCED"}))
    ? $TLV_DOCUMENTATION{"VERSION_INTRODUCED"} : "Unknown";
  $primitive_hash{"tlv_name"} = (exists($TLV_DOCUMENTATION{"TLV_NAME"})) ? $TLV_DOCUMENTATION{"TLV_NAME"} : "";
  $primitive_hash{"len_field"} = (exists($TLV_DOCUMENTATION{"LEN_FIELD"})) ? $TLV_DOCUMENTATION{"LEN_FIELD"} : "";
  $primitive_hash{"len_description"} = (exists($TLV_DOCUMENTATION{"LEN_DESCRIPTION"}))
    ? $TLV_DOCUMENTATION{"LEN_DESCRIPTION"} : "";
  $primitive_hash{"field_name"} = (exists($TLV_DOCUMENTATION{"FIELD_NAME"})) ? $TLV_DOCUMENTATION{"FIELD_NAME"} : "";
  $primitive_hash{"tlv_intro"} = (exists($TLV_DOCUMENTATION{"TLVINTRO"})) ? $TLV_DOCUMENTATION{"TLVINTRO"} : "";
  $primitive_hash{"carry_name"} = (exists($TLV_DOCUMENTATION{"CARRY_NAME"})) ? $TLV_DOCUMENTATION{"CARRY_NAME"} : "";
  $primitive_hash{"provisional"} = (exists($TLV_DOCUMENTATION{"PROVISIONAL"})) ?
    $TLV_DOCUMENTATION{"PROVISIONAL"} : "";
  $primitive_hash{"document_as_mandatory"} = (exists($TLV_DOCUMENTATION{"DOCUMENT_AS_MANDATORY"})) ? $TRUE : $FALSE;

  undef(%TLV_DOCUMENTATION);
  #Handle the special case of the qmi_response_type message
  if ($message_id and $type eq "qmi_response_type")
  {
     $primitive_hash{"tlvtype"} = "0x02";
  }

  #Parse the identifier for the type
  return unless(defined($token = handle_errors('\w+',"Line $. - improperly formatted identifier for $type\n")));
  return unless(defined($name = check_identifier($token,$version_number)));
  $primitive_hash{"identifier"} = $name;
  return unless(defined($token = handle_errors('[;\[\<=\{]',"Line $. - " .
                                               "improperly formatted $type with identifier: $name\n")));
  # increment the refCnt
  if ( defined ($type_hash{"user_types"}{$type}) && ( $type_hash{"user_types"}{$type}{"isenum"} || $type_hash{"user_types"}{$type}{"isstruct"} ||
     $type_hash{"user_types"}{$type}{"ismessage"} ) )
  {
     $type_hash{"user_types"}{$type}{"refCnt"}++;
  }
  if ($primitive_hash{"provisional"} ne "")
  {
    print_warning("Line $. - Provisional Field: $name - " . $primitive_hash{"provisional"} . "\n");
  }
  if ($token eq ";")
  {
     if ($type eq "string" || $type eq "string16")
     {
        print_error("Line $. - String types require a maximum length definition\n");
     }
     if (($offset % $alignment) + $type_hash{"idltype_to_alignment"}->{$type} > $alignment)
     {
        $offset = calc_offset($offset,$alignment);
        $primitive_hash{"offset"} = $offset;
     }
     $primitive_hash{"csize"} = $primitive_hash{"csize"} + ($offset - $orig_offset);
     if ( hex($primitive_hash{"tlvtype"}) ~~ @reserved_tlvs )
     {
        # Cannot use the reserved TLV IDs, increment the number
        $primitive_hash{"tlvtype"} = sprintf("0x%02X", check_reserved($message_id,\@reserved_tlvs));
     }
     return \%primitive_hash;
  }
  #If the angle brackets are used it is a variable array
  if ($token eq "<")
  {
     $primitive_hash{"isvararray"} = $TRUE;
     $primitive_hash{"isvarwiresize"} = $TRUE;
     $primitive_hash{"len_field"} = "$name\_len" if ($primitive_hash{"len_field"} eq "");
     return unless(defined($token = read_token()));
     unless(check_number($token) == $TRUE)
     {
        print_error("Line $. - Value for size of array with identifier: $name\ - must be an integer\n");
     }
     $primitive_hash{"n"}=$token;

     if(get_num_value($token) > ($MAX_TYPE_SIZE-1))
     {
       print_error("Line $. - Value for size of array with identifier: $name\ - cannot exceed 64k\n");
     }elsif (get_num_value($token) > $SET_16_BIT_VALUE)#Set the 16bitflag if the len field will be 2 bytes
     {
       $primitive_hash{"set16bitflag"} = $TRUE;
     }
     return unless(defined($token = handle_errors('[\>\:\-]',"Line $. - " .
                                                  "improperly formatted $type with identifier: $name\n")));
     if ($type eq "string" || $type eq "string16")
     {
        $primitive_hash{"isstring"} = $TRUE;
        $primitive_hash{"isvararray"} = $FALSE;
        $primitive_hash{"isvarwiresize"} = $TRUE;
     }else
     {
        #Increment offset for length field
        $offset++;
     }
     $primitive_hash{"sizeof"} = $type_hash{"idltype_to_ctype"}->{$type} . " * " . $primitive_hash{"n"};
     if ($token eq ":")
     {
        return unless(defined($token = read_token()));
        if($token == 2)
        {
           $primitive_hash{"set16bitflag"} = $TRUE;
           return unless(defined($token = handle_errors('[\>\-]',"Line $. - " .
                                                        "improperly formatted $type with identifier: $name\n")));
        }elsif($token == 4)
        {
           $primitive_hash{"set32bitflag"} = $TRUE;
           return unless(defined($token = handle_errors('[\>\-]',"Line $. - " .
                                                        "improperly formatted $type with identifier: $name\n")));
        }elsif($token == 0){
          $primitive_hash{"islengthless"} = $TRUE;
          return unless(defined($token = handle_errors('[\>\-]',"Line $. - " .
                                                        "improperly formatted $type with identifier: $name\n")));
        }else
        {
           print_error("Line $. - Value for length field with identifier: $name\ - must be 0, 2, or 4\n");
        }
     }
     if ($token =~ m/-/)
     {
       $token =~ s/-//;
       unless(check_number($token) == $TRUE)
       {
         print_error("Line $. - Value for size of array with identifier: $name\ - must be an integer\n");
       }
       $primitive_hash{"len_field_offset"} = $token;
       return unless(defined($token = handle_errors('\>',"Line $. - " .
                                                    "improperly formatted $type with identifier: $name\n")));
     }
  }elsif ($token eq "[")
  { #Square brackets mean static sized array
     $primitive_hash{"isarray"} = $TRUE;
     return unless(defined($token = read_token()));
     unless(check_number($token) == $TRUE)
     {
        print_error("Line $. - Value for size of array with identifier: $name\ - must be an integer\n");
     }
     $primitive_hash{"n"}=$token;

     if(get_num_value($token) > ($MAX_TYPE_SIZE-1))
     {
       print_error("Line $. - Value for size of array with identifier: $name\ - cannot exceed 64k\n");
     }elsif (get_num_value($token) > $SET_16_BIT_VALUE)#Set the 16bitflag if the len field will be 2 bytes
     {
       $primitive_hash{"set16bitflag"} = $TRUE;
     }
     return unless(defined($token = handle_errors('\]',"Line $. - " .
                                                  "improperly formatted $type with identifier: $name\n")));
     if ($type eq "string" || $type eq "string16")
     {
        print_error("Line $. - String types require a maximum length definition");
     }
     $primitive_hash{"sizeof"} = $type_hash{"idltype_to_ctype"}->{$type} . " * " . $primitive_hash{"n"};
  }elsif ($token eq "{")
  {
    parse_range_checking(\%primitive_hash,$type,$name);

  }else
  { #Equal sign encountered, verify it is a message and assign message ID
     if ($message_id)
     {
             return unless(defined($token = read_token()));
             unless(check_number($token) == $TRUE && hex($token) >= hex($message_id))
             {
                print_error("Line $. - ID Number for message element " .
                            "$name must be an integer greater than previous element IDs\n");
             }
             $primitive_hash{"tlvtype"} = $token;
             $explicit_assignment = $TRUE;
     }else
     {
        print_error("Line $. - ID Number may only be assigned to message elements\n");
     }
  }
  $primitive_hash{"wiresize"} = $primitive_hash{"wiresize"} * get_num_value($primitive_hash{"n"});
  $primitive_hash{"csize"} = $primitive_hash{"csize"} * get_num_value($primitive_hash{"n"});
  $primitive_hash{"csize"} ++ if $primitive_hash{"isstring"};
  $primitive_hash{"csize"} ++ if $type eq "string16";
  #Check to see if it is a message element that has the ID Number defined in the IDL
  return unless(defined($token = handle_errors('[;=]',"Line $. - improperly formatted $type with identifier: $name\n")));
  if ($token eq "=" && $message_id)
  {
     return unless(defined($token = read_token()));
     unless(check_number($token) == $TRUE && hex($token) >= hex($message_id))
     {
        print_error("Line $. - ID Number for message element " .
                    "$name must be an integer greater than previous element IDs\n");
     }
     $primitive_hash{"tlvtype"} = $token;
     $explicit_assignment = $TRUE;
     return unless(defined($token = handle_errors(';',"Line $. - " .
                                                  "improperly formatted $type with identifier: $name\n")));
  }elsif ($token eq "=")
  {
     print_error("Line $. - ID Number may only be assigned to message elements\n");
  }
  if (($offset % $alignment) + $type_hash{"idltype_to_alignment"}->{$type} > $alignment)
  {
     $offset = calc_offset($offset,$alignment);
     $primitive_hash{"offset"} = $offset;
  }
  $primitive_hash{"csize"} = $primitive_hash{"csize"} + ($offset - $orig_offset);
  if ( (hex($primitive_hash{"tlvtype"}) ~~ @reserved_tlvs) && !$explicit_assignment )
  {
     # Cannot use the reserved TLV IDs, increment the number
     $primitive_hash{"tlvtype"} = sprintf("0x%02X",check_reserved($message_id,\@reserved_tlvs));
  }
  elsif ( (hex($primitive_hash{"tlvtype"}) ~~ @reserved_tlvs) && $explicit_assignment )
  {
     # Print warning, using the reserved ID
     print_warning("Line $. - Using the reserved TLV ID $primitive_hash{\"tlvtype\"} for \"$name\" \n");
  }
  return \%primitive_hash;
}#  handle_primitives

sub parse_range_checking
{
  my $primitive_hash = shift;
  my $type = shift;
  my $name = shift;
  my %range_hash = ();
  my @range_array = ();
  my %range_info = ();
  my $token;
  $$primitive_hash{"rangeChecked"} = $TRUE;

  #Range definition, parse and validate range values.
  return unless(defined($token = read_token()));
  while ($token ne "}")
  {
    $range_hash{$token} = $TRUE;
    push(@range_array,$token);
    if (!$type_hash{"user_types"}{$type}{"ismask"} && !$type_hash{"user_types"}{$type}{"isenum"})
    {
      return unless(defined($token = handle_errors('[\:\.]',"Line $. - " .
                                                   "improperly formatted range for identifier: $name $token\n")));
      return unless(defined($token = read_token()));
      $range_hash{$token} = $TRUE;
      push(@range_array,$token);
    }
    return unless(defined($token = handle_errors('[\,\}]',"Line $. - " .
                                                 "improperly formatted range for identifier: $name $token\n")));
    if ($token eq ",")
    {
      return unless(defined($token = read_token()));
    }
  }
  if (scalar(@range_array) == 0)
  {
    foreach(@{$type_hash{"user_types"}{$type}{'elementlist'}})
    {
      $range_hash{@{$_}[0]} = $TRUE;
      push(@range_array,@{$_}[0]);
    }
  }
  if(!defined($type_hash{"user_types"}{$type}{"ismask"}) || $type_hash{"user_types"}{$type}{"ismask"} == $FALSE)
  {
    return unless(defined($token = read_token()));
    if ($token eq "IGNORE_TLV")
    {
      $range_info{"rangecheckresponse"} = "QMI_IDL_RANGE_RESPONSE_IGNORE";
      $$primitive_hash{"rangecheckresponse"} = "QMI_IDL_RANGE_RESPONSE_IGNORE";
    }elsif($token eq "RETURN_ERR")
    {
      my $tmp_key;
      my $tmp_val;
      my $val_found = $FALSE;
      return unless(defined($token = read_token()));
      $$primitive_hash{"rangecheckresponse"} = "QMI_IDL_RANGE_RESPONSE_ERROR";
      $$primitive_hash{"rangecheckerrorname"} = $token;
      $range_info{"rangecheckresponse"} = "QMI_IDL_RANGE_RESPONSE_ERROR";
      $range_info{"rangecheckerrorname"} = $token;
      while(($tmp_key,$tmp_val) = each(%{$type_hash{"user_types"}}))
      {
        if (%{$tmp_val})
        {
          if($$tmp_val{"isenum"} == $TRUE)
          {
            foreach(@{$$tmp_val{"elementlist"}})
            {
              #if (@{$_}[0] eq $$primitive_hash{"rangecheckerrorname"})
              if (@{$_}[0] eq $range_info{"rangecheckerrorname"} && $val_found == $FALSE)
              {
                $$primitive_hash{"rangecheckerrorvalue"} = @{$_}[1];
                $range_info{"rangecheckerrorvalue"} = @{$_}[1];
                $val_found = $TRUE;
              }
            }
          }
        }
      }
      if ($val_found == $FALSE)
      {
        print_error("Line $. - Value: " . $$primitive_hash{"rangecheckerrorname"} . " not a defined enum " .
          "element\n");
      }
    }else
    {
      $$primitive_hash{"rangecheckresponse"} = "QMI_IDL_RANGE_RESPONSE_DEFAULT";
      $$primitive_hash{"rangecheckerrorname"} = $token;
      $range_info{"rangecheckresponse"} = "QMI_IDL_RANGE_RESPONSE_DEFAULT";
      $range_info{"rangecheckerrorname"} = $token;
      if (defined($type_hash{"user_types"}{$type}{'elementlist'}))
      {
        foreach(@{$type_hash{"user_types"}{$type}{'elementlist'}})
        {
          if ($range_info{"rangecheckerrorname"} eq @{$_}[0])
          {
            $$primitive_hash{"rangecheckerrorvalue"} = @{$_}[1];
            $range_info{"rangecheckerrorvalue"} = @{$_}[1];
          }
        }
      }else
      {
        if (defined($type_hash{"const_hash"}{$range_info{"rangecheckerrorname"}}))
        {
          $$primitive_hash{"rangecheckerrorvalue"} =
            $type_hash{"const_hash"}{$range_info{"rangecheckerrorname"}}{"value"};
          $range_info{"rangecheckerrorvalue"} =
            $type_hash{"const_hash"}{$range_info{"rangecheckerrorname"}}{"value"};
        }else
        {
          $$primitive_hash{"rangecheckerrorvalue"} = $range_info{"rangecheckerrorname"};
          $range_info{"rangecheckerrorvalue"} = $range_info{"rangecheckerrorname"};
        }
      }
    }
  }
  $range_info{"primitivetype"} = $type;
  if($type_hash{"user_types"}{$type}{"isenum"})
  {
    my $range;
    my $value_found;
    my @range_values = ();
    #Validate all elements in the range are in the enum
    $$primitive_hash{"rangechecktype"} = "QMI_IDL_RANGE_ENUM";
    $range_info{"rangechecktype"} = "QMI_IDL_RANGE_ENUM";
    foreach $range (@range_array)
    {
      $value_found = $FALSE;
      foreach(@{$type_hash{"user_types"}{$type}{'elementlist'}})
      {
        if ($range eq @{$_}[0])
        {
          my $tmp_value = @{$_}[1];
          my %tmp_val_hash = ();
          $value_found = $TRUE;
          if ($tmp_value =~ m/^0x/)
          {
            $tmp_value = hex($tmp_value);
          }
          $tmp_val_hash{"val"} = $tmp_value;
          $tmp_val_hash{"name"} = $range;
          push(@range_values,\%tmp_val_hash);
          last;
        }
      }
      if ($value_found == $FALSE)
      {
        print_error("Line $. - Value $range speficied in range not valid for identifier: $name\n");
      }
    }
    $$primitive_hash{"rangevalues"} = order_enum_ranges(\@range_values);
    $$primitive_hash{"rangelist"} = dclone(\@range_values);
    $range_info{"rangevalues"} = order_enum_ranges(\@range_values);
    push(@{$type_hash{"range_types"}},\%range_info);
    $$primitive_hash{"rangerorder"} = scalar(@{$type_hash{"range_types"}}) - 1;
  }elsif($type_hash{"user_types"}{$type}{"ismask"})
  {
    my $range;
    my $value_found;
    my @range_values = ();
    $$primitive_hash{"rangechecktype"} = "QMI_IDL_RANGE_MASK";
    $$primitive_hash{"rangecheckresponse"} = "QMI_IDL_RANGE_RESPONSE_MASK";
    $range_info{"rangechecktype"} = "QMI_IDL_RANGE_MASK";
    $range_info{"rangecheckresponse"} = "QMI_IDL_RANGE_RESPONSE_MASK";
    foreach $range (@range_array)
    {
      $value_found = $FALSE;
      foreach(@{$type_hash{"user_types"}{$type}{'elementlist'}})
      {
        if ($range eq @{$_}[0])
        {
          $value_found = $TRUE;
          push(@range_values,@{$_}[1]);
          last;
        }
      }
      if ($value_found == $FALSE)
      {
        print_error("Line $. - Value $range speficied in range not valid for identifier: $name\n");
      }
    }
    $range_info{"rangevalues"} = order_mask_ranges(\@range_values);
    push(@{$type_hash{"range_types"}},\%range_info);
    $$primitive_hash{"rangerorder"} = scalar(@{$type_hash{"range_types"}}) - 1;
    $$primitive_hash{"rangevalues"} = order_mask_ranges(\@range_values);
    $$primitive_hash{"rangelist"} = dclone(\@range_values);
  }else
  {
    my $range_values = dclone(\@range_array);
    foreach(@{$range_values})
    {
      if (defined($type_hash{"const_hash"}{$_}))
      {
        $_ = $type_hash{"const_hash"}{$_}{"value"};
      }
    }
    if ($type =~ m/^u/)
    {
      $range_info{"rangechecktype"} = "QMI_IDL_RANGE_UINT";
      $$primitive_hash{"rangechecktype"} = "QMI_IDL_RANGE_UINT";
    }elsif ($type eq "float")
    {
      $range_info{"rangechecktype"} = "QMI_IDL_RANGE_DOUBLE";
      $$primitive_hash{"rangechecktype"} = "QMI_IDL_RANGE_DOUBLE";
    }elsif ($type eq "double")
    {
      $range_info{"rangechecktype"} = "QMI_IDL_RANGE_FLOAT";
      $$primitive_hash{"rangechecktype"} = "QMI_IDL_RANGE_FLOAT";
    }else
    {
      $range_info{"rangechecktype"} = "QMI_IDL_RANGE_INT";
      $$primitive_hash{"rangechecktype"} = "QMI_IDL_RANGE_INT";
    }
    $range_info{"rangevalues"} = $range_values;
    $$primitive_hash{"rangevalues"} = $range_values;
    $$primitive_hash{"rangelist"} = $range_values;
    $range_info{"rangeSize"} = $type_hash{"idltype_to_type_array"}{$type};
    push(@{$type_hash{"range_types"}},\%range_info);
    $$primitive_hash{"rangerorder"} = scalar(@{$type_hash{"range_types"}}) - 1;
  }
}#  parse_range_checking

#===========================================================================
#
#FUNCTION HANDLE_SERVICE_TYPE
#
#DESCRIPTION
#  Parses the service_type keyword from an IDL
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the service_type and
#  verify correct format
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#
#
#===========================================================================
sub handle_service_type
{
   my $token;
   if ( not defined($token = read_token()) )
   {
      print_error("Line $. undefined token \n");
      return;
   }

   if ( not exists($service_types{$token}) )
   {
      print_error("Line $. : \"$token\" is not a valid service type\n");
   }
   else
   {
      $type_hash{"service_type"} = $token;
   }
   handle_errors(";","Line $. - Improperly formatted service type declaration\n");
   return;
}
#===========================================================================
#
#FUNCTION HANDLE_SERVICE
#
#DESCRIPTION
#  Parses a struct element and generates a hash that is passed to the PRINT_STRUCT
#  function to produce the correct output for the .h and .c files
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the struct and
#  verify correct format
#
#RETURN VALUE
#  Returns a hash that contains the name of the struct as well as an array of
#  hashes that contain information about the types defined within the struct
#
#SIDE EFFECTS
#
#
#===========================================================================
sub handle_service
{
  my $token;
  my $name = "";
  my $bwc_error;
  $type_hash{"common_file"} =0;
  if ($CONST_STATE)
  {
    if ($PREV_DESCRIPTION ne "")
    {
      $type_hash{"const_hash"}{$PREV_CONST_NAME}{"description"} .= $PREV_DESCRIPTION . "\n";
      $PREV_DESCRIPTION = "";
    }
    $CONST_STATE = $FALSE;
  }
  $PREV_DESCRIPTION = "";
  if ($INCLUDE_MODE)
  {
     my $filename = $type_hash{"include_files"}[$#{$type_hash{"include_files"}}];
     print_error("Line $. - Service definitions not allowed in included files: in file $filename\n");
  }

  #Do not return from this function if the service is improperly formatted before handling the service
  #message definitions.  This prevents a list of compiler errors for a single formatting problem
  if(defined($token = handle_errors('\w+',"Line $. - Improperly formatted service declaration\n")))
  {
     if(defined($name = check_identifier($token, $VERSION_NUMBER)))
     {
        if ( $type_hash{"inherited"} && ($type_hash{"service_hash"}{"identifier"} ne $name) )
        {
           print_warning("Line $. Redefining the Service name. \n");
        }
        $type_hash{"service_hash"}{"identifier"} = $name;
        handle_errors("{","Line $. - Improperly formatted service declaration\n");
     }
  }
  return unless(defined($type_hash{"service_hash"}{"elementlist"} = handle_service_messages()));
  return unless(defined($token = handle_errors("=","Line $. - Improperly formatted service declaration\n")));
  return unless(defined($token = read_token()));
  unless(check_number($token) == $TRUE)
  {
     print_error("Line $. - Value \'$token\' for service - must be an integer\n");
  }
  if (($token !~ m/^\D/) && ($token !~ m/0x/))
  {
    $token = sprintf("0x%02X", $token);
  }
  if ( $type_hash{"inherited"} && ($type_hash{"service_hash"}{"servicenumber"} ne $token) )
  {
     print_warning("Line $. Redefining the Service number \n");
  }
  $type_hash{"service_hash"}{"servicenumber"} = $token;
  $type_hash{"service_hash"}{"version"} = $VERSION_NUMBER;
  if (-1 != $MINOR_VERSION)
  {
     $type_hash{"service_hash"}{"minor_version"} = $MINOR_VERSION;
  }
  #$type_hash{"service_hash"}{"minor_version"} = $MINOR_VERSION;
  $type_hash{"service_hash"}{"max_msg_id"} = @{$type_hash{"service_hash"}{"elementlist"}}[-1]->{"messageid"};
  return unless(defined($token = handle_errors(";","Line $. - Improperly formatted service declaration\n")));
  if (keys %{$golden_xml_hash{$GOLDEN_MODE}{"types"}} && $ERROR_FLAG == $FALSE && $NO_BWC_CHECKS == $FALSE)
  {
     $bwc_error = bwc_service(${$golden_xml_hash{$GOLDEN_MODE}}{"service"},$type_hash{"service_hash"});
  }
  print_error($bwc_error) if defined($bwc_error);
  return;
}#  handle_service

#===========================================================================
#
#FUNCTION HANDLE_SERVICE_MESSAGES
#
#DESCRIPTION
#  Parses the types defined within the api definition, generating a
#  type hash returned to HANDLE_SERVICE
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the
#  type and verify its format
#
#RETURN VALUE
#  Returns a hash reference that contains the relevant information for the type
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub handle_service_messages
{
   my $token = "";
   my $type;
   my $name;
   my $message_id = $type_hash{"lastMsgId"};
   my $prev_message_id = 0;
   my %message_hash = ();
   my @message_ids = ();
   my @return_array = ();
   my %msg_type_values = (
                          0 => "COMMAND",
                          1 => "RESPONSE",
                          2 => "INDICATION",);
   my $current_msg_type = 0;
   my $max_message_id = 0;
   my %used_msg_identifiers = ();
   my $identifier_base_name = "";
   my $identifier_suffix = "";
   my $prev_identifier = "";
   my @reserved_msgs = ();
   my $explicitly_set = $FALSE;
   my ($oem_lower_msgid, $oem_upper_msgid) = (0x5556, 0xAAAA);
   my $CCB_MODE = $type_hash{"ccb_mode"};

   while ($token ne "}")
   {
      if (defined($token = handle_errors('}|\w+',"Line $. - Improperly formatted service message declaration\n")))
      {
	if ( $token eq "reserved_msgs" )
        {
           handle_reserved_ids(\@reserved_msgs);
           next;
        }
        if ($prev_identifier ne "")
        {
          $PREV_DESCRIPTION =~ s/\n+$//;
          $message_hash{$prev_identifier}{"description"} = $PREV_DESCRIPTION;
          $PREV_DESCRIPTION = "";
        }
         last if ($token eq "}");
         unless (defined($type_hash{"user_types"}{$token}) && $type_hash{"user_types"}{$token}{"ismessage"})
         {
            handle_errors('\n',"Line $. - $token not a recognized message type\n");
         }
         $type = $token;
         $type_hash{"max_msg_size"} = $type_hash{"user_types"}{$type}{"wiresize"} if ($type_hash{"user_types"}{$type}{"wiresize"} > $type_hash{"max_msg_size"});
         if (defined($token = handle_errors('\w+',"Line $. - Improperly formatted service message declaration\n")))
         {
            $name = $token;
            if(($type_hash{"user_types"}{$type}{"msg"} !~ m/$name/) && ($MSG_CHECK_ERRORS == $TRUE))
            {
              print_warning("Line $. - Mismatched message name: $name with \@MSG tag: " .
                          $type_hash{"user_types"}{$type}{"msg"} . "\n");
            }
            if (exists($used_msg_identifiers{$name}))
            {
              print_error("Line $. - Identifier \'$name\' already used.\n");
            }else
            {
              $used_msg_identifiers{$name} = $TRUE;
              $identifier_suffix = $name;
              $identifier_suffix =~ s/.*\_(\w+)/$1/;
              if ($identifier_base_name eq "")
              {
                $identifier_base_name = $name;
                $identifier_base_name =~ s/(.*)\_\w+$/$1/;
              }else
              {
                my $base_name = $name;
                $base_name =~ s/(.*)\_\w+$/$1/;
                if ($base_name ne $identifier_base_name)
                {
                  #print_error("Line $. - Identifier $base_name does not match current base name set for Request message.\n");
                }
              }
            }
            $type_hash{"user_types"}{$type}{"refCnt"}++;
            $message_hash{$token}{"identifier"} = $name;
            $prev_identifier = $name;
            $message_hash{$token}{"type"} = $type;
	    if ($COMMAND_DOCUMENTATION{$COMMAND_NAME} ne "")
            {
               if($type_hash{"user_types"}{$type}{"msg"} =~ /label/)
               {
                  push(@{$COMMAND_DOCUMENTATION{$COMMAND_NAME}{"msgs"}}, $type_hash{"user_types"}{$type}{"msg"});
               }
               else
               {
                  push(@{$COMMAND_DOCUMENTATION{$COMMAND_NAME}{"msgs"}},$name);
               }
	    }
            push(@message_ids,$token);
            if (defined($token = handle_errors('[,;=]',"Line $. - Improperly formatted " .
                                               "service message declaration with identifier: $name\n")))
            {
               if ($token ne "," and $current_msg_type == 0)
               {
                  $message_hash{$name}{"messagetype"} = "INDICATION";
               }else
               {
                  if ($current_msg_type > 2)
                  {
                    print_error("Line $. - Improperly formatted service message declaration. Possible " .
                                "missing semi colon.\n");
                  }
                  $message_hash{$name}{"messagetype"} = $msg_type_values{$current_msg_type};
                  $current_msg_type++;
               }
               if ($message_hash{$name}{"messagetype"} eq "COMMAND")
               {
                 if ($identifier_suffix ne "REQ")
                 {
                   #print_error("Line $. - Request Message Identifier must end with _REQ.\n");
                 }
               }elsif($message_hash{$name}{"messagetype"} eq "RESPONSE")
               {
                 if ($identifier_suffix ne "RESP")
                 {
                   #print_error("Line $. - Response Message Identifier must end with _RESP.\n");
                 }
               }else
               {
                         if ($identifier_suffix ne "IND")
                 {
                   #print_error("Line $. - Indication Message Identifier must end with _IND.\n");
                 }
               }
               if ($token eq "=")
               {
                  if (defined($token = read_token()))
                  {
                     unless(check_number($token) == $TRUE)
                     {
                        print_error("Line $. - Value \'$token\' - must be an integer\n");
                     }
                     $message_id = $token;
                     if ( hex($message_id) ~~ @reserved_msgs )
                     {
                        $explicitly_set = $TRUE;
                     }
                     if ( (hex($message_id) >= $oem_lower_msgid) && (hex($message_id) <= $oem_upper_msgid) && $CCB_MODE )
                     {
                        print_warning("Line $. - Message IDs in the range 0x". sprintf("%X",$oem_lower_msgid) .
                        " - 0x". sprintf("%X",$oem_upper_msgid) ." is reserved for OEMs.\n");
                     }

                     $token = handle_errors(';',"Line $. - Improperly formatted service " .
                                            "message declaration with identifier: $name\n");
                  }
               }
               if ($token eq ";")
               {
                  $current_msg_type = 0;
                  $message_id = hex($message_id);
                  if ($message_id <= $prev_message_id && $message_id != 0)
                  {
                     print_error("Line $. - Message IDs must be in incrementing numerical order.\n");
                  }
                  $prev_message_id = $message_id;
                  $message_id = sprintf("0x%04X", $message_id);
                  if ( (hex($message_id) >= $oem_lower_msgid) && (hex($message_id) <= $oem_upper_msgid) && $CCB_MODE )
                  {
                     print_warning("Line $. - Message IDs in the range 0x". sprintf("%X",$oem_lower_msgid) .
                     " - 0x". sprintf("%X",$oem_upper_msgid) ." is reserved for OEMs.\n");
                  }
                  if ( ( hex($message_id) ~~ @reserved_msgs ) && $explicitly_set )
                  {
                     print_warning("Line $. - Using the reserved Message ID $message_id for $name\n");
                     $explicitly_set = $FALSE;
                  }
                  elsif( hex($message_id) ~~ @reserved_msgs )
                  {
                     $message_id = sprintf("0x%04X",check_reserved($message_id,\@reserved_msgs));
                  }
                  foreach (@message_ids)
                  {
                     $message_hash{$_}{"messageid"} = $message_id;
                     push(@return_array,$message_hash{$_});
                  }
                  $COMMAND_DOCUMENTATION{$COMMAND_NAME}{"commandid"} = $message_id;
                  unless(defined($COMMAND_DOCUMENTATION{$PREV_COMMAND_NAME}{"commandid"}))
                  {
                     $COMMAND_DOCUMENTATION{$PREV_COMMAND_NAME}{"commandid"} = $message_id;
                  }
                  $PREV_COMMAND_NAME = $COMMAND_NAME;
                  $COMMAND_NAME = "";
                  @message_ids = ();
                  $identifier_base_name = "";
                  my $tempId = hex($message_id);
                  $tempId++;
                  $message_id = sprintf("0x%04X", $tempId);
                  $type_hash{"lastMsgId"} = $message_id;
               }
            }
         }
      }
   }
   if ($type_hash{"inherited"})
   {
      @return_array = ( @{$type_hash{"service_hash"}{"elementlist"}}, @return_array);
   }
   return \@return_array;
}#  handle_service_messages

#===========================================================================
#
#FUNCTION HANDLE_STRUCT
#
#DESCRIPTION
#  Parses a struct element and generates a hash that is passed to the PRINT_STRUCT
#  function to produce the correct output for the .h and .c files
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the struct and
#  verify correct format
#
#RETURN VALUE
#  Returns a hash that contains the name of the struct as well as an array of
#  hashes that contain information about the types defined within the struct
#
#SIDE EFFECTS
#
#
#===========================================================================
sub handle_struct
{
  my %struct_hash = ();
  my $sub_stack;
  my $token;
  my $last_index=-1;
  my $name;
  my $wiresize = 0;
  my $type = shift;
  my $is_optional = shift;
  my $elm_offset = 0;
  my $alignment = 0;
  my $is_var_wire_size = $FALSE;
  my %identifier_list = ();
  my $version_number;
  my $bwc_error;
  if ($CONST_STATE)
  {
    if ($PREV_DESCRIPTION ne "")
    {
      $type_hash{"const_hash"}{$PREV_CONST_NAME}{"description"} .= $PREV_DESCRIPTION . "\n";
    }
    $CONST_STATE = $FALSE;
  }
  $PREV_DESCRIPTION = "";
  if ($INCLUDE_MODE) {
     $version_number = $INCLUDE_VERSION;
  }else{
     $version_number = $VERSION_NUMBER;
  }
  if ($CURRENT_DESCRIPTION ne "")
  {
    $struct_hash{"typedescription"} = $CURRENT_DESCRIPTION;
  }
  $struct_hash{"isoptional"} = $is_optional;
  $struct_hash{"type"} = "struct";
  $CURRENT_DESCRIPTION = "";
  #Verify the first token after the struct keyword is the opening bracket
  return unless(defined($token = handle_errors('{',"Line $. - improperly formatted struct declaration\n")));
  #Iterate through all the elements declared within the struct
  while (defined ($token = read_token()) and "}" ne $token ){
    #If a type keyword is encountered, handle that type
    if (defined $type_keywords{$token}){
      $sub_stack = $type_keywords{$token}($token,0,0,$FALSE,$elm_offset,$alignment);
      if(defined($sub_stack))
      {
         if ($sub_stack->{"isvarwiresize"})
         {
            $is_var_wire_size = $TRUE;
            #check to see if the _len field of the variable sized element was
            #already defined, if so, error
            if (defined($identifier_list{$sub_stack->{"identifier"} . "_len"}))
            {
               print_error("Line $. - Multiple definition of identifier: " . $sub_stack->{"identifier"} . "_len\n");
            }else
            {
               $identifier_list{$sub_stack->{"identifier"} . "_len"} = 1;
            }
         }
         if (defined($identifier_list{$sub_stack->{"identifier"}}))
         {
            print_error("Line $. - Multiple definition of identifier: " . $sub_stack->{"identifier"} . "\n");
         }else
         {
            $identifier_list{$sub_stack->{"identifier"}} = 1;
         }
         $wiresize += $sub_stack->{"wiresize"};
         #$wiresize += 1 if $sub_stack->{"isvarwiresize"};
         if ($sub_stack->{"isvararray"} || $sub_stack->{"isstring"})
         {
              my $len;
              if (defined($type_hash{"const_hash"}{$sub_stack->{"n"}}))
              {
                 $len = $type_hash{"const_hash"}{$sub_stack->{"n"}}->{"value"};
              }else
              {
                 $len = $sub_stack->{"n"}
              }
              if($sub_stack->{"set32bitflag"})
              {
                 $wiresize += 4;
              }elsif ($len > $SET_16_BIT_VALUE || $sub_stack->{"set16bitflag"})
              {
                 $wiresize += 2;
              }else
              {
                 $wiresize += 1;
              }
              if ($sub_stack->{"isvararray"} && !$sub_stack->{"isstring"})
              {
                #update alignment and offset by 4 for the _len field
                $alignment = 4 unless ($alignment > 4);
                $elm_offset += 4;
              }
           }
         $alignment = $type_hash{"idltype_to_alignment"}->{$sub_stack->{"type"}}
         unless ($alignment > $type_hash{"idltype_to_alignment"}->{$sub_stack->{"type"}});
         $elm_offset += $sub_stack->{"csize"};
         if ($PREV_DESCRIPTION ne "")
         {
           unless ($last_index == -1)
           {
             ${struct_hash{"elementlist"}}[$last_index]{"valuedescription"} = $PREV_DESCRIPTION;
             ${struct_hash{"elementlist"}}[$last_index]{"allowedenumvals"}{"description"} = "";
             if (${struct_hash{"elementlist"}}[$last_index]{"primitivetype"} =~ m/(enum)|(mask)/)
             {
               get_enum_values_from_description(${struct_hash{"elementlist"}}[$last_index]);
             }
           }

           $PREV_DESCRIPTION = "";
         }
         if ($CURRENT_DESCRIPTION ne "")
         {
           $sub_stack->{"typedescription"} = $CURRENT_DESCRIPTION . "\n";
           $CURRENT_DESCRIPTION = "";
         }
         if ($sub_stack->{"len_field_offset"})
         {
           my %tmp_stack = %{$sub_stack};
           my $offset = -1 * $sub_stack->{"len_field_offset"};
           $tmp_stack{"len_field_offset"} = -1;
           splice(@{$struct_hash{"elementlist"}},$offset,0,\%tmp_stack);
         }
         push (@{$struct_hash{"elementlist"}},$sub_stack);
         my @array = @{$struct_hash{"elementlist"}};
         $last_index = $#array;
      }
    }else
    {
       #Type not recognized, Error message
       handle_errors('\n',"Line $. - $token not a recognized type\n");
    }
  }
  #Calcluate the new offset for byte alignment
  $elm_offset = calc_offset($elm_offset,$alignment);

  return unless(defined($token = handle_errors('\w+',"Line $. - improperly formatted struct declaration\n")));
  return unless(defined($name = check_identifier($token,$version_number)));
  return unless(defined($token = handle_errors(';',"Line $. - improperly formatted " .
                                               "struct with identifier: $name\n")));
  if ($version_number < 0)
  {
     print_error("Line $. - Version number not defined before struct $name\n");
  }
  if ($PREV_DESCRIPTION ne "")
  {
    #${struct_hash{"elementlist"}}[$last_index]{"valuedescription"} = $PREV_DESCRIPTION unless ($last_index == -1);
    unless ($last_index == -1)
    {
      ${struct_hash{"elementlist"}}[$last_index]{"valuedescription"} = $PREV_DESCRIPTION;
      ${struct_hash{"elementlist"}}[$last_index]{"allowedenumvals"}{"description"} = "";
      if (${struct_hash{"elementlist"}}[$last_index]{"primitivetype"} =~ m/(enum)|(mask)/)
      {
        get_enum_values_from_description(${struct_hash{"elementlist"}}[$last_index]);
      }
    }
  }
  #Update Range Checking Name Information
  foreach (@{$struct_hash{"elementlist"}})
  {
    if($_->{"rangeChecked"})
    {
      @{$type_hash{"range_types"}}[$_->{"rangerorder"}]->{"rangeCheckName"} = $name . "_" . $_->{"identifier"};
    }
  }
  $CURRENT_DESCRIPTION = "";
  $PREV_DESCRIPTION = "";
  $type_hash{"idltype_to_wiresize"}->{$name} = $wiresize;
  $type_hash{"idltype_to_csize"}->{$name} = $elm_offset;
  $type_hash{"idltype_to_alignment"}->{$name} = $alignment;
  # Initialize the refCnt for the structure
  $struct_hash{"refCnt"}=0;
  #Fill in the hash information
  $struct_hash{"identifier"} = $name;
  $struct_hash{"isvarwiresize"} = $is_var_wire_size;
  $struct_hash{"wiresize"} = $wiresize;
  $struct_hash{"csize"} = $elm_offset;
  $struct_hash{"isstruct"} = $TRUE;
  $struct_hash{"isarray"} = $FALSE;
  $struct_hash{"n"} = 1;
  $struct_hash{"tlvtype"} = $FALSE;
  $struct_hash{"command"} = "";
  $struct_hash{"msg"} = "";
  $struct_hash{"isvararray"} = $FALSE;
  $struct_hash{"set16bitflag"} = $FALSE;
  $struct_hash{"set32bitflag"} = $FALSE;
  $struct_hash{"islengthless"} = $FALSE;
  $struct_hash{"ismessage"} = $FALSE;
  $struct_hash{"isenum"} = $FALSE;
  $struct_hash{"ismask"} = $FALSE;
  $struct_hash{"isstring"} = $FALSE;
  $struct_hash{"version"} = $version_number;
  $struct_hash{"description"}{"TYPE"} = "";
  $struct_hash{"description"}{"SENDER"} = "";
  $struct_hash{"description"}{"TODO"} = "";
  $struct_hash{"description"}{"SCOPE"} = "";
  $struct_hash{"description"}{"MSG_ALIAS"} = "";
  $struct_hash{"sizeof"} = $name . "_v$version_number";
  $struct_hash{"isincludetype"} = $INCLUDE_MODE;

  if (defined(${$golden_xml_hash{$GOLDEN_MODE}}{"types"}{$name}) && $ERROR_FLAG == $FALSE && $NO_BWC_CHECKS == $FALSE)
  {
     $bwc_error = bwc_type_msg_elms(${$golden_xml_hash{$GOLDEN_MODE}}{"types"}{$name},\%struct_hash,$name);
     bwc_deprecated_type(${$golden_xml_hash{$GOLDEN_MODE}}{"types"}{$name},\%struct_hash,$name);
  }
  print_error($bwc_error) if defined($bwc_error);
  return \%struct_hash;
}#  handle_struct

#===========================================================================
#
#FUNCTION HANDLE_TYPEDEF
#
#DESCRIPTION
#  Parses the typedef keyword from an IDL
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the version
#  verify correct format
#
#RETURN VALUE
#
#
#SIDE EFFECTS
#  Sets up a typedef to be used through the rest of the file
#
#===========================================================================
sub handle_typedef
{
   my $token;
   my $golden_xml;
   my $name;
   my $type;
   my $version_number;
   my $bwc_error;

   if ($INCLUDE_MODE)
   {
      $version_number = $INCLUDE_VERSION;
   }else
   {
      $version_number = $VERSION_NUMBER;
   }
   return unless(defined($token = handle_errors('\w+',"Line $. - improperly formatted typedef\n")));
   #Verify that the type is a recognized primitive type
   $type = $token;
   unless(defined($valid_typedefs{$type}))
   {
      print_error("line $. - $type not a valid primitive type for typedef\n");
   }
   return unless(defined($token = handle_errors('\w+',"Line $. - improperly formatted identifier for typedef\n")));
   #Verify that the new typename is not already used
   return unless(defined($name = check_identifier($token,$version_number)));
   return unless(defined($token = handle_errors(";","Line $. - Improperly formatted typedef\n")));
   #Check for backwards compatibility
   if (defined(${$golden_xml_hash{$GOLDEN_MODE}}{"typedefs"}{$name}) && $NO_BWC_CHECKS == $FALSE)
   {
      $bwc_error = bwc_typedef(${$golden_xml_hash{$GOLDEN_MODE}}{"typedefs"}{$name}{"type"},$type,$name);
   }
   print_error($bwc_error) if defined($bwc_error);
   unless($INCLUDE_MODE)
   {
      $type_hash{"typedef_hash"}{$name}{"type"} = $type;
      $type_hash{"typedef_hash"}{$name}{"version"} = $version_number;
      $type_hash{"typedef_hash"}{$name}{"identifier"} = $name;
      push(@{$type_hash{"typedef_order"}},$name);
   }
   $type_keywords{$name} = \&handle_primitives;
   $type_hash{"idltype_to_ctype"}->{$name} = $name . "_v" . $version_number;
   $type_hash{"idltype_to_type_array"}->{$name} = $type_hash{"idltype_to_type_array"}->{$type};
   $type_hash{"idltype_to_alignment"}->{$name} = $type_hash{"idltype_to_alignment"}->{$type};
   $type_hash{"idltype_to_csize"}->{$name} = $type_hash{"idltype_to_csize"}->{$type};
   $type_hash{"idltype_to_wiresize"}->{$name} = $type_hash{"idltype_to_wiresize"}->{$type};
   $valid_typedefs{$name} = 1;
   return;
}#  handle_typedef


#===========================================================================
#
#FUNCTION HANDLE_VERSION
#
#DESCRIPTION
#  Parses the version keyword from an IDL
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the version
#  verify correct format
#
#RETURN VALUE
#
#
#SIDE EFFECTS
#  Sets the VERSION_NUNBER or INCLUDE_VERSION variables that are used to populate types
#
#===========================================================================
sub handle_version
{
   my $token;
   my $golden_xml;
   my $version_number;
   my $bwc_error;
   my $type = shift;
   return unless(defined($token = read_token()));
   unless(check_number($token) == $TRUE)
   {
      print_error("Line $. - Value \'$token\' for version - must be an integer\n");
   }
   if ($INCLUDE_MODE)
   {
      if ($type eq "revision")
      {
         $INCLUDE_MINOR_VERSION = sprintf("%02d",$token);
      }else
      {
         $version_number = $token;
         $version_number = sprintf("%02d",$version_number);
         if ($version_number != $INCLUDE_VERSION)
         {
           print_error("Line $. - Version number does not match included idl file name version\n");
         }
      }
   }else
   {
      if ($type eq "revision")
      {
         $MINOR_VERSION = sprintf("%02d",$token);
         if (defined($golden_xml_hash{$GOLDEN_MODE}{"version"}{"minor"}))
         {
               if($MINOR_VERSION <= ($golden_xml_hash{$GOLDEN_MODE}{"version"}{"minor"}))
               {
                  if ($NO_MINOR_UPDATE)
                  {
                     print STDERR "WARNING: Revision has not been incremented in IDL File.\n";
                  }else
                  {
                     print_error("Line $. - Revision has not been incremented in IDL File.\n");
                  }
                  #Update Spin Number
                  $type_hash{"service_hash"}{"spin_number"} =
                    defined($golden_xml_hash{$GOLDEN_MODE}{"version"}{"spin"}) ?
                      $golden_xml_hash{$GOLDEN_MODE}{"version"}{"spin"}+ 1 : 1;
               }else
               {
                 #Reset Spin Number
                 $type_hash{"service_hash"}{"spin_number"} = 0;
               }
         }else
         {
           #Spin #1
           $type_hash{"service_hash"}{"spin_number"} = 0;
         }
      }else
      {
         $version_number = $token;
         $version_number = sprintf("%02d",$version_number);
         if ($version_number != $VERSION_NUMBER)
         {
            print_error("Line $. - Version number does not match included idl file name version\n");
         }
      }
   }
   if ($NO_BWC_CHECKS)
   {
     undef($golden_xml_hash{$GOLDEN_MODE});
   }
   return unless(defined($token = handle_errors(";","Line $. - Improperly formatted version\n")));
   return;
}#  handle_version

#===========================================================================
#
#FUNCTION READ_GOLDEN_XML
#
#DESCRIPTION
#  Parses the golden XML file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#
#
#SIDE EFFECTS
#
#
#===========================================================================
sub read_golden_xml
{
   my $golden_xml;

   $golden_xml = basename($IDL_FILENAMES[$INCLUDE_LEVEL],".idl");
   if ($CUSTOMER_ENV)
   {
      $golden_xml .= ".bwc";
   }else
   {
      $golden_xml .= ".xml";
   }

   $golden_xml = find_file($golden_xml);
   $golden_xml = "" unless defined($golden_xml);

   if (-e $golden_xml && $USE_XML_LIBS)
   {
      $golden_xml_hash{$GOLDEN_MODE} = parse_golden_xml($golden_xml);
   }else
   {
      undef($golden_xml_hash{$GOLDEN_MODE});
   }
   return;
}#  read_golden_xml

#===========================================================================
#
#FUNCTION PARSE_IDL_FILE
#
#DESCRIPTION
#  Runs the primary loop that parses the input IDL Files
#
#DEPENDENCIES
#  Utilizes function READ_TOKEN to get each token needed to parse the version
#  verify correct format
#
#RETURN VALUE
#
#
#SIDE EFFECTS
#
#
#===========================================================================
sub parse_idl_file
{
   my $filename = shift;
   my $include_path = shift;
   my $return_hash = shift;
   my $minor_update = shift;
   my $no_bwc_check = shift;
   my $msg_check_errors = shift;
   my $use_xml_libs = shift;
   my $customer_env = shift;
   my $ccb_mode = shift;
   my $use_json_libs = shift;
   $GOLDEN_MODE = "golden";
   #Set the global values to their defaults
   reset_global_values();
   $type_hash{"ccb_mode"} = $ccb_mode;
   $NO_BWC_CHECKS = $no_bwc_check;
   $MSG_CHECK_ERRORS = $msg_check_errors;
   $USE_XML_LIBS = $use_xml_libs;
   $USE_JSON_LIBS = $use_json_libs;
   $NO_MINOR_UPDATE = $minor_update;
   set_include_path($include_path);
   $IDLFILENAME = find_file($filename);
   $CUSTOMER_ENV = $customer_env;
   $IDL_FILENAMES[$INCLUDE_LEVEL] = find_file($filename);
   if ($USE_XML_LIBS == $FALSE)
   {
     $NO_BWC_CHECKS = $TRUE;
   }
   die "Unable to locate supplied idl file $filename \n" unless defined $IDL_FILENAMES[$INCLUDE_LEVEL];
   if ($IDL_FILENAMES[$INCLUDE_LEVEL] =~ /\w+\_v(\d\d)/)
   {
      $VERSION_NUMBER = $1;
   }else
   {
      #Dont die, error and return
      die "IDL filename ($IDL_FILENAMES[$INCLUDE_LEVEL]) must" .
        " end with _v##.idl where ## is the major version of the IDL.";
   }
   #dont die, return error
   #open(IDLFILE,$IDLFILENAME) or die "Unable to open idl file $IDLFILENAME";
   #$IDL_FILES[$INCLUDE_LEVEL] = IDLFILE;
   open($IDL_FILES[$INCLUDE_LEVEL],$IDL_FILENAMES[$INCLUDE_LEVEL])
     or die "Unable to open idl file $IDL_FILENAMES[$INCLUDE_LEVEL]";
   read_golden_xml();
   my $token = "";
   my $results;
   my $bwc_message;
   #Iterate through the entire input file
   while (defined ($token = read_token()))
   {
      if (defined $type_keywords{$token})
      {
         $results = $type_keywords{$token}($token,0,0,$FALSE,0,0);
         #If parsing the type was successful add the info to the type hash
         if (defined($results))
         {
            if (!($results->{"identifier"} ~~ @{$type_hash{"user_types_order"}}))
            {
               push(@{$type_hash{"user_types_order"}},$results->{"identifier"});
            }
            $type_hash{"user_types"}{$results->{"identifier"}} = $results;
            my $temp_seq = 0;
            #Branch smaller, to switch on STRUCT vs MSG, but rest of the code is identical.  Fix
            if ($results->{"type"} eq "struct")
            {
               if (keys %{$golden_xml_hash{$GOLDEN_MODE}{"types"}})
               {
                  $temp_seq = bwc_type_msg(\$golden_xml_hash{$GOLDEN_MODE},
                                           \$type_hash{"user_types"}{$results->{"identifier"}});
                  $type_hash{"struct_seq_num"} = $temp_seq if $temp_seq > $type_hash{"struct_seq_num"};
               }else
               {
                $type_hash{"user_types"}{$results->{"identifier"}}{"sequence"} = $type_hash{"struct_seq_num"};
                $type_hash{"struct_seq_num"}++;
               }
            }elsif ($results->{"type"} eq "message")
            {
               if (keys %{$golden_xml_hash{$GOLDEN_MODE}{"types"}})
               {
                  $temp_seq = bwc_type_msg(\$golden_xml_hash{$GOLDEN_MODE},
                                           \$type_hash{"user_types"}{$results->{"identifier"}});
                  $type_hash{"msg_seq_num"} = $temp_seq if $temp_seq > $type_hash{"msg_seq_num"};
               }else
               {
                $type_hash{"user_types"}{$results->{"identifier"}}{"sequence"} = $type_hash{"msg_seq_num"};
                $type_hash{"msg_seq_num"}++;
            }
            }
            #Add this type info to the map hash and type_keywords
            $type_keywords{$results->{"identifier"}} = \&handle_primitives;
            #how to eliminate these?  Magik
            $type_hash{"idltype_to_ctype"}->{$results->{"identifier"}} = $results->{"sizeof"};
            $type_hash{"idltype_to_type_array"}->{$results->{"identifier"}} =
               $type_hash{"idltype_to_type_array"}->{$results->{"type"}};
         }
      } else
      {
         print_error("Line $. - unrecognized token $token encountered\n");
      }
   }

   if (defined($golden_xml_hash{$GOLDEN_MODE}) && $ERROR_FLAG == $FALSE && $NO_BWC_CHECKS == $FALSE)
   {
      $bwc_message = bwc_check_for_removed_values($golden_xml_hash{$GOLDEN_MODE},\%type_hash);
   }
   print_error($bwc_message) if defined($bwc_message);
   close($IDL_FILES[$INCLUDE_LEVEL]);
   #If there were no errors fill out the rest of the type hash and assign it to the return hash
   if ($ERROR_FLAG == $FALSE)
   {
     unless (defined($type_hash{"service_hash"}{"identifier"}))
     {
        my $tmp_id = basename($filename,".idl");
        $tmp_id =~ m/(.*)_v(\d\d)/;
        $type_hash{"service_hash"}{"identifier"} = $1;
        $type_hash{"service_hash"}{"version"} = $2;
        if (-1 != $MINOR_VERSION)
        {
           $type_hash{"service_hash"}{"minor_version"} = $MINOR_VERSION;
        }
     }
     $FILE_DOCUMENTATION{"REVERSE_SERVICE"} = $REVERSE_SERVICE;
     $type_hash{"file_documentation"} = dclone(\%FILE_DOCUMENTATION);
     $type_hash{"command_documentation"} = dclone(\%COMMAND_DOCUMENTATION);
     $type_hash{"common_command_links"} = dclone(\%COMMON_COMMAND_LINKS);
     $type_hash{"command_order"} = dclone(\@COMMAND_ORDER);
     $type_hash{"footer"} = dclone(\%FOOTER_HASH);
     $type_hash{"footer_order"} = dclone(\@FOOTER_ORDER);

     %$return_hash =  %type_hash;
   }
   # Need to handle the case where the type_hash was populated out of the inherited JSON file
   else
   {
     undef %$return_hash;
   }
   return;

}#  parse_idl_file

#===========================================================================
#
#FUNCTION READ_TOKEN
#
#DESCRIPTION
#  **This Function is a part of the tokenizing element of this tool**
#  Read a token from a line cache.  Read a new line into the line
#  cache if the cache is empty.  Tokens are a group of (alpha numeric
#  punctuation) characters that are grouped/separated by white space.
#  C style (/**/ or //) comments will be stripped out via the handle_comments()
#  function called from this function.
#
#DEPENDENCIES
#  Input taken from <>.
#
#RETURN VALUE
#  A single token.
#
#SIDE EFFECTS
#  The line_string cache will be updated and the input will be
#  advanced.  Comments will be silently removed.
#  This function may recursively call itself.
#
#===========================================================================
{
   #LINE_STRING declared at a scope only accessible to read_token function
   my $LINE_STRING = "";
sub read_token
  {
    my $input = $IDL_FILES[$INCLUDE_LEVEL];
    # Remove leading whitespace from the currently cached line.
    defined $LINE_STRING and $LINE_STRING =~ /^\s*$/ and undef $LINE_STRING;

    # If cached line empty, try to read a new line.
    while ( not defined $LINE_STRING )
    {
      while ( <$input> )
      {
      chomp;
      s/\r//g; # isn't chomp supposed to deal?

      $_ = handle_comments($_);

      # Fix the case where we used up all the current line.
      next if not defined $_;
      # Set up the line_string for below.
      $LINE_STRING = $_;
      last;
    } # while input

      return undef if not defined $_;
    } # While not defined line_string
    $LINE_STRING = handle_comments( $LINE_STRING );

    # Handle empty line_string...
    return read_token( )
      if not defined $LINE_STRING or not $LINE_STRING =~ /\p{IsGraph}/;

    $LINE_STRING =~ s/([^[:ascii:]]*)//;
    $LINE_STRING =~ s/^\s*(0[xX][a-fA-F\d]+|([-+]?\d+(\.\d+)?)|\w+|\p{IsGraph}(\b|\Z)?)//;
    my $ret = $1;
    $ret =~ s/\s//g;
    return $ret;
  }#  read_token
}

#===========================================================================
#
#FUNCTION PRINT_ERROR
#
#DESCRIPTION
#  Prints out an error message to STDOUT and sets the ERROR_FLAG
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  ERROR_FLAG set to true
#
#===========================================================================
sub print_error
{
   my $error_string = shift;
   my $compiler_version = $type_hash{"service_hash"}{"tool_major_version"} . "." . $type_hash{"service_hash"}{"tool_minor_version"} . "." . $type_hash{"service_hash"}{"tool_spin_version"};
   print STDERR "**************************************\n" .
      "Errors encountered during processing of IDL FILE: $IDLFILENAME\n" .
      "Compiler Version: $compiler_version\n" .
      "**************************************\n\n" unless $ERROR_FLAG;
   print STDERR $error_string;
   $ERROR_FLAG = $TRUE;
}#  print_error

sub print_warning
{
    my $warning_string = shift;
    print STDERR "WARNING: " . $warning_string;
}

{
  #Include path array, declared at a scope only accessible to find_file and
  #set_include_path functions
  my @INCLUDE_PATH = (".");         #Array to hold passed in include path information
#===========================================================================
#
#FUNCTION FIND_FILE
#
#DESCRIPTION
#  Checks the @INCLUDE_PATH variable and the supplied filename to determine if the file exists
#  in the path
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  Returns undef if the file is not found, returns the full path if it is found
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub find_file
{
  my $pattern = shift;
  if (-e $pattern)
  {
    #return $pattern;
  }
  foreach (@INCLUDE_PATH)
  {
    if (-e "$_\/$pattern")
    {
      return "$_\/$pattern";
    }elsif (-e "$_\\$pattern")
    {
      return "$_\\$pattern";
    }
  }
  return;
}#  find_file

sub set_include_path
{
  my $path_array = shift;
  push(@INCLUDE_PATH,@$path_array);
}#  set_include_path
}

#===========================================================================
#
#FUNCTION FORMAT_DOC_OUTPUT
#
#DESCRIPTION
#  Formats documentation strings to eliminate extra whitespace and newline characters.
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  Returns the formatted string
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub format_doc_output
{
   my $in_string = shift;
   $in_string =~ s/\n/ /g;
   $in_string =~ s/  +/ /g;
   $in_string =~ s/^ *//g;
   return $in_string;
}#  format_doc_output

#===========================================================================
#
#FUNCTION HANDLE_EXTENDS
#
#DESCRIPTION
#  Populates the hash with the Base message details.
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  Returns the hash of the Base message
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub handle_extends
{
   my $temp_hash ;
   my $token;
   while (defined($token = read_token()) and $token ne ";")
   {
      if(exists($type_hash{"user_types"}{$token}))
      {
         $temp_hash = dclone($type_hash{"user_types"}{$token});
      }
      else
      {
         print_error("Line $. - $token is not defined.\n");
         handle_errors(';',"Line $. - improperly formatted message declaration\n");
         return ;
      }

   } # end of while
   return %$temp_hash;
} #handle_extends
#===========================================================================
#
#FUNCTION HANDLE_REMOVE_MESSASGES
#
#DESCRIPTION
#  Remove the messages to be deleted from the type_hash.
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub handle_remove_msgs
{
   my $token;
   my $msg;
   my $type;
   my @msg_names;
   my @tmp;
   if (!$type_hash{"inherited"})
   {
      print_error("Line $. - 'remove_msgs' section can be defined only for the inherited files.\n");
      return;
   }
   return unless(defined($token = handle_errors('{',"Line $. - improperly formatted delete messages declaration.\n")));
   while ( defined ($token = read_token()) and "}" ne $token )
   {
      if ( $token eq ";" )
      {
         next;
      }
      push(@tmp,$token);
   }
   remove_messages(\@tmp, \@COMMAND_ORDER, \%COMMAND_DOCUMENTATION);
   handle_errors(';',"Line $. - Improperly formatted 'remove_msgs' section. Missing ';' \n");
   return;
}
1;
