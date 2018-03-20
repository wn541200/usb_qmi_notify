#!/usr/local/bin/perl
# ========================================================================
#                Q M I _ I D L _ C _ O U T P U T . P M
#
# DESCRIPTION
#  Writes out the C language bindings for the qmi_idl_compiler
#
# REFERENCE
#
# Copyright (c) 2011 by QUALCOMM Incorporated. All Rights Reserved.
# ========================================================================
#
# $Header: //source/qcom/qct/core/mproc/tools_crm/idl_compiler/main/latest/common/qmi_idl_c_output.pm#33 $
#
# ========================================================================
package qmi_idl_c_output;

use strict;
use warnings;

require Exporter;
use Data::Dumper;
use File::Basename;
use IO::File;
use List::MoreUtils qw(any);
use Storable qw(dclone);

our @ISA = qw(Exporter);

#Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration       use IDLCompiler::IDLOutput ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(output_init
                                   populate_h_file
                                   populate_c_file
                                   remove_messages
                                   $IDL_COMPILER_MAJ_VERS
                                   $IDL_COMPILER_MIN_VERS
                                   $IDL_COMPILER_SPIN_VERS
                                   %type_hash
                                   %idltype_to_ctype_map
                                   %idltype_to_wiresize_map
                                   %idltype_to_csize_map
                                   %idltype_to_type_array_map
                                   %idltype_to_alignment_map) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

#The version of the tool, minor version gets updated
#if changes are backwards compatible, major version
#gets updated for non-backwards compatible changes
our $IDL_COMPILER_MAJ_VERS = sprintf("0x%02X",6);
our $IDL_COMPILER_MIN_VERS = sprintf("0x%02X",14);
our $IDL_COMPILER_SPIN_VERS = sprintf("0x%02X",9);

#A mapping of the IDL types to the respective C types
#This hash is not accessed directly, but through the
#map_hash hash
our %idltype_to_ctype_map = (
  "int8" => "int8_t",
  "int16" => "int16_t",
  "int32" => "int32_t",
  "int64" => "int64_t",
  "uint8" => "uint8_t",
  "uint16" => "uint16_t",
  "uint32" => "uint32_t",
  "uint64" => "uint64_t",
  "opaque" => "uint8_t",
  "float" => "float",
  "double" => "double",
  "enum8" => "",
  "enum16" => "",
  "enum" => "",
  "uenum8" => "",
  "uenum16" => "",
  "mask" => "uint64_t",
  "mask32" => "uint32_t",
  "mask16" => "uint16_t",
  "mask8" => "uint8_t",
  "string" => "char",
  "char" => "char",
  "string16" => "uint16_t",
  "struct" => "",
  "boolean" => "uint8_t",
  "__DUPLICATE__" => "",
);

#A mapping of the IDL types to the respective wire sizes
#This hash is not accessed directly, but through the map_hash hash
our %idltype_to_wiresize_map = (
  "int8" => "1",
  "int16" => "2",
  "int32" => "4",
  "int64" => "8",
  "uint8" => "1",
  "uint16" => "2",
  "uint32" => "4",
  "uint64" => "8",
  "opaque" => "1",
  "boolean" => "1",
  "enum8" => "1",
  "enum16" => "2",
  "enum" => "4",
  "uenum8" => "1",
  "uenum16" => "2",
  "mask" => "8",
  "mask32" => "4",
  "mask16" => "2",
  "mask8" => "1",
  "string" => "1",
  "char" => "1",
  "string16" => "2",
  "float" => "4",
  "double" => "8",
  "__DUPLICATE__" => 0,
);

#A mapping of the IDL types to the respective C sizes
#This hash is not accessed directly, but through the map_hash hash
our %idltype_to_csize_map = (
  "int8" => "1",
  "int16" => "2",
  "int32" => "4",
  "int64" => "8",
  "uint8" => "1",
  "uint16" => "2",
  "uint32" => "4",
  "uint64" => "8",
  "opaque" => "1",
  "boolean" => "1",
  "enum8" => "4",
  "enum16" => "4",
  "enum" => "4",
  "uenum8" => "4",
  "uenum16" => "4",
  "mask" => "8",
  "mask32" => "4",
  "mask16" => "2",
  "mask8" => "1",
  "string" => "1",
  "char" => "1",
  "string16" => "2",
  "float" => "4",
  "double" => "8",
  "__DUPLICATE__" => 0,
);

#A mapping of the IDL types to the respective compiler alignments
#This hash is not accessed directly, but through the map_hash hash
our %idltype_to_alignment_map = (
  "int8" => "1",
  "int16" => "2",
  "int32" => "4",
  "int64" => "8",
  "uint8" => "1",
  "uint16" => "2",
  "uint32" => "4",
  "uint64" => "8",
  "float" => "4",
  "double" => "8",
  "opaque" => "1",
  "boolean" => "1",
  "enum8" => "4",
  "enum16" => "4",
  "enum" => "4",
  "uenum8" => "4",
  "uenum16" => "4",
  "mask" => "8",
  "mask32" => "4",
  "mask16" => "2",
  "mask8" => "1",
  "string" => "1",
  "char" => "1",
  "string16" => "2",
  "__DUPLICATE__" => 0,
);

#A mapping of the IDL types to the respective type_array header values
#This hash is not accessed directly, but through the map_hash hash
our %idltype_to_type_array_map = (
  "int8" => "QMI_IDL_GENERIC_1_BYTE",
  "int16" => "QMI_IDL_GENERIC_2_BYTE",
  "int32" => "QMI_IDL_GENERIC_4_BYTE",
  "int64" => "QMI_IDL_GENERIC_8_BYTE",
  "uint8" => "QMI_IDL_GENERIC_1_BYTE",
  "uint16" => "QMI_IDL_GENERIC_2_BYTE",
  "uint32" => "QMI_IDL_GENERIC_4_BYTE",
  "uint64" => "QMI_IDL_GENERIC_8_BYTE",
  "opaque" => "QMI_IDL_GENERIC_1_BYTE",
  "boolean" => "QMI_IDL_GENERIC_1_BYTE",
  "float" => "QMI_IDL_GENERIC_4_BYTE",
  "double" => "QMI_IDL_GENERIC_8_BYTE",
  "string" => "QMI_IDL_STRING",
  "char" => "QMI_IDL_GENERIC_1_BYTE",
  "string16" => "QMI_IDL_GENERIC_2_BYTE",
  "enum8" => "QMI_IDL_1_BYTE_ENUM",
  "enum16" => "QMI_IDL_2_BYTE_ENUM",
  "uenum8" => "QMI_IDL_1_BYTE_ENUM",
  "uenum16" => "QMI_IDL_2_BYTE_ENUM",
  "enum" => "QMI_IDL_GENERIC_4_BYTE",
  "mask" => "QMI_IDL_GENERIC_8_BYTE",
  "mask32" => "QMI_IDL_GENERIC_4_BYTE",
  "mask16" => "QMI_IDL_GENERIC_2_BYTE",
  "mask8" => "QMI_IDL_GENERIC_1_BYTE",
);

#The mapping hash used by ipcapicompiler and IDLOutput.pm
#to map idl types to different values
#This hash also gets updated with new values of user-defined types
our %type_hash = (
  "idltype_to_ctype" => \%idltype_to_ctype_map,
  "idltype_to_wiresize" => \%idltype_to_wiresize_map,
  "idltype_to_csize" => \%idltype_to_csize_map,
  "idltype_to_type_array" => \%idltype_to_type_array_map,
  "idltype_to_alignment" => \%idltype_to_alignment_map,
);

#==============================================#
#==================Constants===================#
#==============================================#
my $FALSE = 0;
my $TRUE = 1;
my $SZ_IS_16 = 200;
my $SZ_IS_32=64000;
my $CCB_MODE = $FALSE;
my $MAX_ENUM_SIZE = 2147483647;
my $MIN_ENUM_SIZE = -2147483647;
my $INVALID_MSG_ID = "0xFFFFF";
#The following string is used at the beginning of header files
my $HEADER_EXPLANATION =<<"EOF";
  This header file defines the types and structures that were defined in
  <SERVICENAME>. It contains the constant values defined, enums, structures,
  messages, and service message IDs (in that order) Structures that were
  defined in the IDL as messages contain mandatory elements, optional
  elements, a combination of mandatory and optional elements (mandatory
  always come before optionals in the structure), or nothing (null message)

  An optional element in a message is preceded by a uint8_t value that must be
  set to true if the element is going to be included. When decoding a received
  message, the uint8_t values will be set to true or false by the decode
  routine, and should be checked before accessing the values that they
  correspond to.

  Variable sized arrays are defined as static sized arrays with an unsigned
  integer (32 bit) preceding it that must be set to the number of elements
  in the array that are valid. For Example:

  uint32_t test_opaque_len;
  uint8_t test_opaque[16];

  If only 4 elements are added to test_opaque[] then test_opaque_len must be
  set to 4 before sending the message.  When decoding, the _len value is set
  by the decode routine and should be checked so that the correct number of
  elements in the array will be accessed.
EOF

my $CONST_HASH;
my $doc;

#===========================================================================
#
#FUNCTION GET_NUM_VAULE
#
#DESCRIPTION
#  Used to get numerical values in situations where a types length or size
#  could be a number or a previously defined constant
#  This is used primarily in calculating wire and c sizes
#
#DEPENDENCIES
#  CONSTS hash must be populated with all constants defined in the IDL
#
#RETURN VALUE
#  The numerical value of a field
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub get_num_value
{
   my $value = shift;
   if (defined($$CONST_HASH{$value}))
   {
      if($$CONST_HASH{$value}{"value"} =~ m/^0x/)
      {
       return hex($$CONST_HASH{$value}{"value"});
     }else
     {
       return $$CONST_HASH{$value}{"value"};
     }
   }
   return $value;
}#  get_num_value

#===========================================================================
#
#FUNCTION GET_TYPE_INDEX
#
#DESCRIPTION
#  Searches type hashes to determine the location of an element in the type tables
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  Array of 2 elements, first element is the type table index
#   second element is the type table object index
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub get_type_index
{
   my $type_name = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $struct_name = shift;
   my %include_hash = %{$inc_hash} if defined($inc_hash);
   my $key;
   my $value;

   #Search included types
   while (($key, $value) = each(%include_hash) )
   {
      if (defined($$inc_hash{$key}{$type_name}))
      {
         return($$inc_hash{$key}{$type_name}{"sequence"},$$inc_hash{$key}{$type_name}{"arrayLoc"});
      }
   }
   #Wasn't in the included types, in the type_hash
   return($$type_hash{$type_name}{"sequence"},0);
}#  get_type_index

#===========================================================================
#
#FUNCTION GET_TYPE_WIRE_SIZE
#
#DESCRIPTION
#  Searches type hashes to determine the location of an element in the type tables
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  Array of 2 elements, first element is the type table index
#   second element is the type table object index
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub get_type_wire_size
{
   my $type_name = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $struct_name = shift;
   my %include_hash = %{$inc_hash} if defined($inc_hash);
   my $key;
   my $value;

   #Search included types
   while (($key, $value) = each(%include_hash) )
   {
      if (defined($$inc_hash{$key}{$type_name}))
      {
         return($$inc_hash{$key}{$type_name}{"wiresize"});
      }
   }
   #Wasn't in the included types, in the type_hash
   return($$type_hash{$type_name}{"wiresize"});
}#  get_type_wire_size

#===========================================================================
#
#FUNCTION GET_TYPE_BY_TLV
#
#DESCRIPTION
#  Searches type hash by TLV # to find the correct type
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  Hash for the type
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub get_type_by_tlv
{
   my $type_hash = shift;
   my $type_name = shift;
   my $tlv_num = shift;
   my $key;
   my $value;
   my $return_value = "";

   #Search included types
   while (($key, $value) = each(%$type_hash) )
   {
      if ($value->{"ismessage"} && $value->{"identifier"} eq $type_name)
      {
         if (defined($value->{"elementlist"}))
         {
            foreach (@{$value->{"elementlist"}})
            {
               if ($_->{"tlvtype"} eq $tlv_num)
               {
                  $return_value =  $_;
               }
            }
         }
      }
   }
   return $return_value
   #Wasn't in the included types, in the type_hash

}#  get_type_by_tlv
#===========================================================================
#
#FUNCTION REMOVE_MESSAGES
#
#DESCRIPTION
#  This function is invoked from 2 code paths, one when the 'remove_msgs'
#  section is to be parsed from the inherited file and the other when parsing
#  the messages to be removed passed as an argument to the input script. This
#  function removes the messages from the generated .c, .tex and .html files
#  but retains them in the .h file with a comment specifying that the particular
#  message is no longer used. This is done so that if the message related code
#  are removed during the linking phase then the compilation of the service and
#  client code using these removed messages till should go through.
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  Populates the conditional message removal definitions in the header file.
#
#===========================================================================
sub remove_messages
{
   my $remove_msgs = shift;
   my $command_order = shift;
   my $command_documentation = shift;
   my $token;
   my $VERSION = $type_hash{"service_hash"}{"version"};
   my $FOUND = $FALSE;
   my $msg;
   my $type;
   my $OUT = "";
   my @msg_names;
   my $index;
   foreach $token (@{$remove_msgs})
   {
      if ( $token ~~ @{$command_order} )
      {
         $OUT .= "#define REMOVE_".$token."_V".$VERSION. " \n";
         @msg_names = @{$$command_documentation{$token}{"msgs"}};
         foreach $msg (@msg_names)
         {
            $FOUND = $FALSE;
            # FROM "msgs" figure out the type
            foreach (@{$type_hash{"service_hash"}{"elementlist"}})
            {
               $type = "";
               if (defined ($_->{'identifier'}))
               {
                  if ($_->{'identifier'} eq $msg)
                  {
                     $type = $_->{'type'};
                     $FOUND = $TRUE;
                     last;
                  }
               }
            }
            if ($FOUND)
            {
               $index = 0;
               # remove from command_documentation array (HTML and tex)
               $index++ until $$command_documentation{$token}{"msgs"}[$index] eq $msg;
               splice(@{$$command_documentation{$token}{"msgs"}},$index,1);

               # remove from type_hash{"service_hash"}{"elementlist"} ---> .c file
               foreach (@{$type_hash{"service_hash"}{"elementlist"}})
               {
                  if($msg eq $_->{'identifier'})
                  {
                     $_->{"removed"} = $TRUE;
                     last;
                  }
               }
               if (defined($type_hash{"user_types"}{$type}))
               {
                  $type_hash{"user_types"}{$type}{"refCnt"}--;
                  foreach (@{$type_hash{"user_types"}{$type}{"elementlist"}})
                  {
                     if (defined($type_hash{"user_types"}{$_->{"type"}}))
                     {
                        $type_hash{"user_types"}{$_->{"type"}}{"refCnt"}--;
                        if ( ref($type_hash{"user_types"}{$_->{"type"}}{"elementlist"}) eq "ARRAY" )
                        {
                           foreach my $elm_list_type (@{$type_hash{"user_types"}{$_->{"type"}}{"elementlist"}})
                           {
                              # we want only HASH references not ARRAY
                              if (!(ref($elm_list_type) eq "ARRAY") && exists($type_hash{"user_types"}{$elm_list_type->{"type"}}))
                              {
                                 $type_hash{"user_types"}{$elm_list_type->{"type"}}{"refCnt"}--;
                              }
                           }
                        }
                     }
                  }
               } # end of if defined($type_hash{"user_types"}{$type})
            } # end of if ($FOUND)
         } # end of foreach (@msg_names)

         # if you were sucessful in removing the messages associated with the command, remove the command too..
         if ($FOUND)
         {
            $index = 0;
            $index++ until $$command_order[$index] eq $token;
            splice(@{$command_order},$index,1);
            $$command_documentation{$token}{"removed"} = 1;
         }
      }
   }
   $type_hash{"removed_msgs"} .= $OUT;
}
#===========================================================================
#
#FUNCTION PREPARE_REMOVE_MESSAGES
#
#DESCRIPTION
#  Populates the $OUT buffer with "#define REMOVE_MESSAGE_NAME" fields to
#  remove a certain set of messages from being compiled. By default
#  all messages defined in the IDL file will be inserted in the commented
#  mode for conditional compilation with the exception of those defined with
#  '--remove-msgs' option.
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
sub prepare_remove_msgs
{
   my $filename = $type_hash{"remove_msgs_file"};
   my $version = $type_hash{"service_hash"}{"version"};
   my @remove_msgs = ();
   my %params = ();
   my $token;
   my $msg;
   my $type;
   my @msg_names;
   my $index;
   my $FOUND = $FALSE;
   my $OUT ="";
   if ( $filename ne "" )
   {
      @remove_msgs = do {
         open my $fh, "<", $filename
         or die "could not open $filename: $!";
         <$fh>;
      };
   }
   chomp (@remove_msgs);
   %params = map { $_ => 1 } @{$type_hash{"command_order"}};
   if (@remove_msgs)
   {
      foreach (@remove_msgs)
      {
         if ( exists $params{$_} )
         {
            delete $params{$_};
         }
         elsif ( $_ ne "" )
         {
            print STDERR "WARNING: $_ is not present in the messages defined for this IDL file \n";
         }
      }
   }
   if ( keys %params )
   {
      foreach (sort keys%params)
      {
         if (defined($type_hash{"command_documentation"}{$_}{"commandid"}))
         {
            $OUT .= "//#define REMOVE_". $_ . "_V". $version ." \n";
         }
      }
   }
   $OUT .= "\n";
   if(@remove_msgs)
   {
      remove_messages(\@remove_msgs, \@{$type_hash{"command_order"}}, \%{$type_hash{"command_documentation"}});
   }
   return $OUT;
}

#===========================================================================
#
#FUNCTION H_REMOVE_MESSAGES
#
#DESCRIPTION
#  Populates the header file with the REMOVE_MESSAGE #defines
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
sub h_remove_messages
{
   my $HOUT= shift;
   my $OUT= shift;
   $$HOUT .= "/* Conditional compilation tags for message removal */ \n";
   $$HOUT .= $type_hash{"removed_msgs"} . $OUT;
}

#===========================================================================
#                  VESRION 1 OUTPUT ROUTINES
#===========================================================================


#===========================================================================
#
#FUNCTION H_INIT
#
#DESCRIPTION
#  Populates the header information for the output .h and .c files
#
#DEPENDENCIES
#  Takes in references to the $DOTHFILE and $DOTCFILE variables from
#  ipcapicompiler.pl
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  $DOTHFILE and $DOTCFILE variables updated with header information in
#  ipcapicompiler.pl
#
#===========================================================================
sub h_init_v01
{
   my $HOUT = shift;
   my $service_name = shift;
   my $outfile_name = shift;
   my $service_version = shift;
   my $minor_version = shift;
   my $max_msg_size = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $max_msg_id = shift;
   my $out_version = shift;
   my $spin = shift;
   my $ifdefname = uc($service_name) . "_SERVICE_$service_version\_H";
   my $headername = uc($outfile_name);
   my $version_name = uc($service_name) . "_V$service_version";
   my $timestamp = gmtime();
   my $header_explanation = $HEADER_EXPLANATION;
   my $dec_version = hex($IDL_COMPILER_MAJ_VERS) . "." . hex($IDL_COMPILER_MIN_VERS) . "." . hex($IDL_COMPILER_SPIN_VERS);
   my $out_version_string = "";

   if ($out_version != 0 && $out_version != hex($IDL_COMPILER_MAJ_VERS))
   {
      $out_version_string = "\n   It requires encode/decode library version $out_version or later";
   }
   if ($max_msg_id eq $INVALID_MSG_ID)
   {
      $max_msg_id = "";
   }else
   {
      $max_msg_id = "/** Maximum Defined Message ID */\n\#define $version_name\_MAX_MESSAGE_ID $max_msg_id";
   }
   $service_version = sprintf("0x%02X",$service_version);
   $minor_version = sprintf("0x%02X",$minor_version);
   $timestamp =~ s/\s+\d\d\:\d\d\:\d\d\s+/ /;
   $headername =~ s/(.)/$1 /g;
   $header_explanation =~ s/<SERVICENAME>/$service_name/g;
   $$HOUT .= <<"EOF";
#ifndef $ifdefname
#define $ifdefname
/**
  \@file $outfile_name\.h

  \@brief This is the public header file which defines the $service_name service Data structures.

$header_explanation
*/
/*====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*
  $copyright

  $p4info
 *====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*/
/*====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*
 *THIS IS AN AUTO GENERATED FILE. DO NOT ALTER IN ANY WAY
 *====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*/

/* This file was generated with Tool version $dec_version $out_version_string
   It was generated on: $timestamp (Spin $spin)
   From IDL File: $outfile_name\.idl */

/** \@defgroup $service_name\_qmi_consts Constant values defined in the IDL */
/** \@defgroup $service_name\_qmi_msg_ids Constant values for QMI message IDs */
/** \@defgroup $service_name\_qmi_enums Enumerated types used in QMI messages */
/** \@defgroup $service_name\_qmi_messages Structures sent as QMI messages */
/** \@defgroup $service_name\_qmi_aggregates Aggregate types used in QMI messages */
/** \@defgroup $service_name\_qmi_accessor Accessor for QMI service object */
/** \@defgroup $service_name\_qmi_version Constant values for versioning information */

#include <stdint.h>
#include "qmi_idl_lib.h"
<INCLUDEFILES>

#ifdef __cplusplus
extern "C" {
#endif

/** \@addtogroup $service_name\_qmi_version
    \@{
  */
/** Major Version Number of the IDL used to generate this file */
#define $version_name\_IDL_MAJOR_VERS $service_version
/** Revision Number of the IDL used to generate this file */
#define $version_name\_IDL_MINOR_VERS $minor_version
/** Major Version Number of the qmi_idl_compiler used to generate this file */
#define $version_name\_IDL_TOOL_VERS $IDL_COMPILER_MAJ_VERS
$max_msg_id
/**
    \@}
  */

EOF

}

sub sh_init_v06
{
   my $HOUT = shift;
   my $service_name = shift;
   my $outfile_name = shift;
   my $service_version = shift;
   my $minor_version = shift;
   my $max_msg_size = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $max_msg_id = shift;
   my $out_version = shift;
   my $spin = shift;
   $service_name =~ s/(\_v\d\d)/_types$1/;
   $outfile_name =~ s/(\_v\d\d)/_types$1/;
   my $ifdefname = uc($service_name) . "_SERVICE_TYPES_$service_version\_H";
   my $headername = uc($outfile_name);
   my $version_name = uc($service_name) . "_V$service_version";
   my $timestamp = gmtime();
   my $header_explanation = $HEADER_EXPLANATION;
   my $dec_version = hex($IDL_COMPILER_MAJ_VERS) . "." . hex($IDL_COMPILER_MIN_VERS) . "." . hex($IDL_COMPILER_SPIN_VERS);
   my $out_version_string = "";

   if ($out_version != 0 && $out_version != hex($IDL_COMPILER_MAJ_VERS))
   {
      $out_version_string = "\n   It requires encode/decode library version $out_version or later";
   }
   if ($max_msg_id eq $INVALID_MSG_ID)
   {
      $max_msg_id = "";
   }else
   {
      $max_msg_id = "/** Maximum Defined Message ID */\n\#define $version_name\_MAX_MESSAGE_ID $max_msg_id";
   }

   $service_version = sprintf("0x%02X",$service_version);
   $minor_version = sprintf("0x%02X",$minor_version);
   $timestamp =~ s/\s+\d\d\:\d\d\:\d\d\s+/ /;
   $headername =~ s/(.)/$1 /g;
   $header_explanation =~ s/<SERVICENAME>/$service_name/g;
   $$HOUT .= <<"EOF";
#ifndef $ifdefname
#define $ifdefname
/**
  \@file $outfile_name\.h

  \@brief This is the public header file which defines the $service_name service Data structures.

$header_explanation
*/
/*====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*
 *THIS IS AN AUTO GENERATED FILE. DO NOT ALTER IN ANY WAY
 *====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*/

/* This file was generated with Tool version $dec_version $out_version_string
   It was generated on: $timestamp (Spin $spin) */

/** \@defgroup $service_name\_qmi_consts Constant values defined in the IDL */
/** \@defgroup $service_name\_qmi_msg_ids Constant values for QMI message IDs */
/** \@defgroup $service_name\_qmi_enums Enumerated types used in QMI messages */
/** \@defgroup $service_name\_qmi_messages Structures sent as QMI messages */
/** \@defgroup $service_name\_qmi_aggregates Aggregate types used in QMI messages */
/** \@defgroup $service_name\_qmi_accessor Accessor for QMI service object */
/** \@defgroup $service_name\_qmi_version Constant values for versioning information */

#include <stdint.h>
<INCLUDEFILES>

#ifdef __cplusplus
extern "C" {
#endif

/** \@addtogroup $service_name\_qmi_version
    \@{
  */
$max_msg_id
/**
    \@}
  */

EOF
}

#===========================================================================
#
#FUNCTION C_INIT
#
#DESCRIPTION
#  Populates the header information for the output .h and .c files
#
#DEPENDENCIES
#
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  $DOTHFILE and $DOTCFILE variables updated with header information in
#  ipcapicompiler.pl
#
#===========================================================================
sub c_init_v01
{
   my $COUT = shift;
   my $service_name = shift;
   my $outfile_name = shift;
   my $service_version = shift;
   my $max_msg_size = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $out_version = shift;
   my $spin = shift;
   my $ifdefname = uc($service_name) . "_SERVICE_H";
   my $headername = uc($outfile_name);
   my $version_name = uc($service_name) . "_V$service_version";
   my $timestamp = gmtime();
   my $dec_version = hex($IDL_COMPILER_MAJ_VERS) . "." . hex($IDL_COMPILER_MIN_VERS). "." . hex($IDL_COMPILER_SPIN_VERS);
   my $out_version_string = "";

   if ($out_version != 0 && $out_version != hex($IDL_COMPILER_MAJ_VERS))
   {
      $out_version_string = "\n   It requires encode/decode library version $out_version or later";
   }
   $timestamp =~ s/\s+\d\d\:\d\d\:\d\d\s+/ /;
   $headername =~ s/(.)/$1 /g;
   $$COUT .= <<"EOF";
/*====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*

                        $headername . C

GENERAL DESCRIPTION
  This is the file which defines the $service_name service Data structures.

  $copyright

  $p4info
 *====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*/
/*====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*
 *THIS IS AN AUTO GENERATED FILE. DO NOT ALTER IN ANY WAY
 *====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*/

/* This file was generated with Tool version $dec_version $out_version_string
   It was generated on: $timestamp (Spin $spin)
   From IDL File: $outfile_name\.idl */

#include "stdint.h"
#include "qmi_idl_lib_internal.h"
#include "$outfile_name\.h"
<INCLUDEFILES>

EOF
}



#===========================================================================
#
#FUNCTION ADD_INCLUDES
#
#DESCRIPTION
#  Adds the #include information to the file variables
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  file variables filled w/ any include file information
#
#===========================================================================
sub add_includes_v01
{
   my $OUT = shift;
   my $include_files = shift;
   #my $include_types = shift;
   my $include_name;
   my $version_number;
   my $include_string;
   if (ref($include_files) eq "ARRAY")
   {
      foreach (@$include_files)
      {
         chomp();
         $include_name = basename($_,".idl");
         chomp($include_name);
         $include_name .= ".h";
         #$$HOUT .= "#include \"$include_name\"\n";
         $include_string = "#include \"$include_name\"\n";
         $$OUT =~ s/(<INCLUDEFILES>)/$include_string$1/;
      }
   }
   $$OUT =~ s/(<INCLUDEFILES>)//;
   return;
}#  h_add_includes_v01

#===========================================================================
#
#FUNCTION H_ADD_CONSTS
#
#DESCRIPTION
#  Adds #define into .h file variable for constant definitions
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .h file variable filled w/ any constant information
#
#===========================================================================
sub h_add_consts_v01
{
   my $HOUT = shift;
   my $const_hash = shift;
   my $const_order = shift;
   my $version = shift;
   my $service_name = shift;
   my $const_value;
   my $value_version;
   if (ref($const_order) eq "ARRAY") {
      $$HOUT .=<<"EOF";

/** \@addtogroup $service_name\_qmi_consts
    \@{
  */
EOF
      foreach (@$const_order)
      {
         #if (defined($$const_hash{$_}{"value"})) {
         if ($$const_hash{$_}{"included"} == $FALSE)
         {
            if ($$const_hash{$_}{"description"} ne "")
            {
               $$const_hash{$_}{"description"} =~ s/\n*$//;
               $$HOUT .= "\n/** " . $$const_hash{$_}{"description"} . " */\n";
            }
            $const_value = $$const_hash{$_}{"value"};
            if (exists($$const_hash{$const_value}))
            {
               $value_version = $$const_hash{$const_value}{"version"};
               $$HOUT .= "#define " . $_ . "_V$version " . $const_value . "_V$value_version\n";
            }elsif (exists($$const_hash{$_}{"suffix"}))
            {
               $$HOUT .= "#define " . $_ . "_V$version " . $const_value . $$const_hash{$_}{"suffix"} . "\n";
            }
            else
            {
               $$HOUT .= "#define " . $_ . "_V$version " . $const_value . "\n";
            }
         }
      }
      $$HOUT .= "/**\n    \@}\n  */\n\n";
   }
   return;
}#  h_add_consts_v01

#===========================================================================
#
#FUNCTION H_ADD_MASK
#
#DESCRIPTION
#  Adds mask definitions to the .h file variable
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .h file variable filled w/ any mask information
#
#===========================================================================
sub h_add_mask_v01
{
   my $HOUT = shift;
   my $mask_hash = shift;
   my $service_name = shift;
   my $elm_comment = "";
   my $version = $$mask_hash->{"version"};
   my $mask_type = $$mask_hash->{"identifier"} . "_v" . $version;
   my $ull = "";

   if ($$mask_hash->{"type"} eq "mask")
   {
      $ull = "ull";
   }

   if ($$mask_hash->{"typedescription"} ne "")
   {
      chomp($$mask_hash->{"typedescription"});
      $$HOUT .= "/** $$mask_hash->{'typedescription'} */\n";
   }
   $$HOUT .= "typedef " . $type_hash{"idltype_to_ctype"}->{$$mask_hash->{"type"}} .
      " " . $mask_type . ";\n";

   foreach(@{$$mask_hash->{"elementlist"}})
   {
      chomp(@{$_}[2]);
      $elm_comment = "/**< " . @{$_}[2] . " */" unless (@{$_}[2] eq "");
      $$HOUT .= "\#define " . @{$_}[0] . "_V$version " . "(($mask_type)" . @{$_}[1] . "$ull) $elm_comment\n";
      $elm_comment = "";
   }

   return;
}

#===========================================================================
#
#FUNCTION H_ADD_ENUM
#
#DESCRIPTION
#  Adds enum definitions to the .h file variable
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .h file variable filled w/ any enum information
#
#===========================================================================
sub h_add_enum_v01
{
   my $HOUT = shift;
   my $enum_hash = shift;
   my $service_name = shift;
   my $elm_comment = "";
   my $version = $$enum_hash->{"version"};
   my $display_in_hex = $$enum_hash->{"displayinhex"};
   $$HOUT .= "/** \@addtogroup $service_name\_qmi_enums\n    \@{\n  */\n";
   $$HOUT .= "typedef enum {\n  ";
   $$HOUT .= uc($$enum_hash->{"identifier"}) . "_MIN_ENUM_VAL_V$version = $MIN_ENUM_SIZE, /**< To force a 32 bit signed enum.  Do not change or use*/\n";

   #Iterate through all elements of the enum and add them to the HOUT variable
   foreach(@{$$enum_hash->{"elementlist"}})
   {
      my $enum_value = @{$_}[1];
      #if ($display_in_hex != $FALSE && $enum_value !~ m/^0x[0-9A-Fa-f]+$/)
      #{
      #   $enum_value = sprintf("0x%0".$display_in_hex."X", $enum_value);
      #}
      chomp(@{$_}[2]);
      $elm_comment = "/**< " . @{$_}[2] . " */" unless (@{$_}[2] eq "");
      $$HOUT .= "  " . @{$_}[0] . "_V$version = " . $enum_value . ", $elm_comment\n";
      $elm_comment = "";
   }
   $$HOUT .= "  " . uc($$enum_hash->{"identifier"}) . "_MAX_ENUM_VAL_V$version = $MAX_ENUM_SIZE /**< To force a 32 bit signed enum.  Do not change or use*/\n";
   $$HOUT .= "}" . $$enum_hash->{"identifier"} . "_v" . $version . ";\n";
   $$HOUT .= "/**\n    \@}\n  */\n\n";
   return;
}#  h_add_enum_v01

#===========================================================================
#
#FUNCTION H_ADD_STRUCT
#
#DESCRIPTION
#  Adds struct (and message) definitions to the .h file variable
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .h file variable filled w/ struct and message information
#
#===========================================================================
sub h_add_struct_v01
{
   my $HOUT = shift;
   my $struct_hash = shift;
   my $command_info = shift;
   my $service_name = shift;
   my $struct_comment = "";
   my $struct_end_comment = "";
   my $dox_comment = "";
   my $struct_type = "";
   my $struct_desc = "";
   if ($$struct_hash->{"ismessage"})
   {
      if (defined($$command_info{$$struct_hash->{"command"}}{"BRIEF"}))
      {
         $struct_desc = $$command_info{$$struct_hash->{"command"}}{"BRIEF"};
         $struct_desc =~ s/\n*$//g;
      }
      if (defined($$struct_hash->{"description"}{"TYPE"}))
      {
         $struct_type = $$struct_hash->{"description"}{"TYPE"};
         $struct_type =~ s/\s//g;
      }
      $struct_comment = "/** " . $struct_type .
         " Message; " . $struct_desc . " */\n";
      $struct_end_comment = "  /* Message */\n";
      $dox_comment = "/** \@addtogroup $service_name\_qmi_messages\n    \@{\n  */\n";
   }else
   {
      $struct_end_comment = "  /* Type */\n";
      $dox_comment = "/** \@addtogroup $service_name\_qmi_aggregates\n    \@{\n  */\n";
   }
   if (defined($$struct_hash->{"elementlist"}) && scalar(@{$$struct_hash->{"elementlist"}}) > 0)
   {
      $$HOUT .= $dox_comment;
      $$HOUT .= "$struct_comment";
      $$HOUT .= "typedef struct {\n";
      $$HOUT .= h_add_struct_elms_v01($struct_hash,1);
      #$$HOUT =~ s/\n\n$/\n/;
      $$HOUT .= "}" . $$struct_hash->{"identifier"} . "_v" . $$struct_hash->{"version"} . "\;";
      $$HOUT .= $struct_end_comment;
      $$HOUT .= "/**\n    \@}\n  */\n\n";
   }else
   {
      $$HOUT .=<<EOF;
/*
 * $$struct_hash->{"identifier"} is empty
 * typedef struct {
 * }$$struct_hash->{"identifier"}\_v$$struct_hash->{"version"}\;
 */

EOF
   }
   return;
}#  h_add_struct_v01

#===========================================================================
#
#FUNCTION H_ADD_STRUCT_ELMS
#
#DESCRIPTION
#  Iterates through the elementlist of the struct/message hash and populates that information
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  A string containing the output for a struct/message elementlist
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub h_add_struct_elms_v01
{
   my $return_string = "";
   my $elm_list = "";
   my $type_hash = shift;
   my $indent_depth = shift;
   my $array_len = "";
   my $indent_string = "  " x $indent_depth;
   foreach(@{$$type_hash->{"elementlist"}})
   {
      if ($_->{"isduplicate"} || $_->{"len_field_offset"} == -1)
      {
         next;
      }
      $return_string .= "\n";
      if ($$type_hash->{"ismessage"})
      {
         if ($_->{"isoptional"})
         {
            $return_string .= "$indent_string/* Optional */\n";
         }else
         {
            $return_string .= "$indent_string/* Mandatory */\n";
         }
      }
      if ($_->{"typedescription"} ne "")
      {
         chomp($_->{"typedescription"});
         chomp($_->{"typedescription"});
         $return_string .= "$indent_string/* $_->{'typedescription'} */\n";
      }
      if ($_->{"provisional"} ne "")
      {
        chomp($_->{"provisional"});
        $return_string .= "$indent_string/* This field is provisional and is subject to change or removal. */\n";
      }
      if ($_->{"isoptional"})
      {#Optional elements require an additional boolean that defines if the element was passed
         $return_string .= $indent_string . "uint8_t " . $_->{"identifier"} .
            "_valid;  /**< Must be set to true if $_->{'identifier'} is being passed */\n";
      }
      if (defined($_->{"elementlist"})  && scalar(@{$_->{"elementlist"}}) > 0)
      {
         $elm_list = h_add_struct_elms_v01($_,$indent_depth+1);
      }
      if ($_->{"n"} !~ /^\d/)
      {
         #Length value is a string value, must be a const, append the version number
         $array_len = $_->{"n"} . "_V" . $$CONST_HASH{$_->{"n"}}{"version"};
      }else
      {
         $array_len = $_->{"n"};
      }
      if ($_->{"isarray"})
      {
         $return_string .= $indent_string . $type_hash{"idltype_to_ctype"}->{$_->{"type"}} . " " . $_->{"identifier"} .
            "[" . $array_len . "];";
      }elsif($_->{"isvararray"})
      {
         #Variable sized arrays require an additional length element
         $return_string .= $indent_string . "uint32_t " . $_->{"identifier"} .
            "_len;  /**< Must be set to # of elements in $_->{'identifier'} */\n";
         $return_string .= $indent_string . $type_hash{"idltype_to_ctype"}->{$_->{"type"}} . " " . $_->{"identifier"} .
            "[" . $array_len . "];";
      }elsif($_->{"isstring"})
      {
         #Strings do not require an additional length element, they are null terminated, so the array length is
         #increased by 1
         #my $size = "$array_len + 1";
         $return_string .= $indent_string . $type_hash{"idltype_to_ctype"}->{$_->{"type"}} . " " .
            $_->{"identifier"} . "[$array_len + 1];";
      }elsif($_->{"isstruct"})
      {
         $return_string .= $indent_string . "typedef struct {\n" . $elm_list . "}" . $_->{"identifier"} . "_v" .
            $_->{"version"} . ";";
      }else
      {
         $return_string .= $indent_string . $type_hash{"idltype_to_ctype"}->{$_->{"type"}} .
            " " . $_->{"identifier"} . ";";
      }
      if ($_->{"valuedescription"} ne "")
      {
         chomp($_->{"valuedescription"});
         chomp($_->{"valuedescription"});
         $return_string .= "\n  /**<  $_->{'valuedescription'}*/\n";
      }else
      {
         $return_string .= "\n";
      }
   }
   return $return_string;
}#  h_add_struct_elms_v01

#===========================================================================
#
#FUNCTION H_ADD_EXTERNS
#
#DESCRIPTION
#  Adds an extern definition to the .h file of the qmi_idl_type_table_object defined
#  in the .c file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .h file variable updated with extern definition
#
#===========================================================================
sub h_add_externs_v01
{
  my $HOUT = shift;
  my $identifier = shift;
  my $version = shift;

  $$HOUT .= "/*Extern Definition of Type Table Object*/\n";
  $$HOUT .= "/*THIS IS AN INTERNAL OBJECT AND SHOULD ONLY*/\n";
  $$HOUT .= "/*BE ACCESSED BY AUTOGENERATED FILES*/\n";
  $$HOUT .= "extern const qmi_idl_type_table_object $identifier\_qmi_idl_type_table_object_v$version\;\n\n";
}#  h_add_externs_v01

#===========================================================================
#
#FUNCTION H_ADD_SERVICE
#
#DESCRIPTION
#  Adds #define values to the .h file that define the message IDs associated with
#  each set of requests, responses, and indications
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .h file variable updated with service message information
#
#===========================================================================
sub h_add_service_v01
{
   my $HOUT = shift;
   my $service_hash = shift;
   my $service_identifier = $$service_hash{"identifier"};
   my $version = $$service_hash{"version"};
   my $uc_id = uc($service_identifier);
   $$HOUT .= "/*Service Message Definition*/\n";
   $$HOUT .= "/** \@addtogroup $service_identifier\_qmi_msg_ids\n    \@{\n  */\n";
   foreach(@{$$service_hash{"elementlist"}})
   {
      if ($_->{"description"} ne "")
      {
         $$HOUT .= "#define " . $_->{"identifier"} . "_V" . $$service_hash{"version"} . " " . $_->{"messageid"} .
            " /**< " . $_->{"description"} . " */\n";
      }else
      {
         $$HOUT .= "#define " . $_->{"identifier"} . "_V" . $$service_hash{"version"} . " " . $_->{"messageid"} . "\n";
      }
   }
   $$HOUT .= "/**\n    \@}\n  */\n\n";

   $$HOUT .=<<"EOF";
/* Service Object Accessor */
/** \@addtogroup wms_qmi_accessor
    \@{
  */
/** This function is used internally by the autogenerated code.  Clients should use the
   macro $service_identifier\_get_service_object_v$version\( ) that takes in no arguments. */
qmi_idl_service_object_type $service_identifier\_get_service_object_internal_v$version
 ( int32_t idl_maj_version, int32_t idl_min_version, int32_t library_version );

/** This macro should be used to get the service object */
#define $service_identifier\_get_service_object_v$version\( ) \\
          $service_identifier\_get_service_object_internal_v$version\( \\
            $uc_id\_V$version\_IDL_MAJOR_VERS, $uc_id\_V$version\_IDL_MINOR_VERS, \\
            $uc_id\_V$version\_IDL_TOOL_VERS )
/**
    \@}
  */

EOF
}#  h_add_service_v01

#===========================================================================
#
#FUNCTION H_ADD_SERVICE
#
#DESCRIPTION
#  Adds #define values to the .h file that define the message IDs associated with
#  each set of requests, responses, and indications
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .h file variable updated with service message information
#
#===========================================================================
sub h_add_split_service_v06
{
   my $HOUT = shift;
   my $SHOUT = shift;
   my $service_hash = shift;
   my $service_identifier = $$service_hash{"identifier"};
   my $version = $$service_hash{"version"};
   my $uc_id = uc($service_identifier);
   $$SHOUT .= "/*Service Message Definition*/\n";
   $$SHOUT .= "/** \@addtogroup $service_identifier\_qmi_msg_ids\n    \@{\n  */\n";
   foreach(@{$$service_hash{"elementlist"}})
   {
      if ($_->{"description"} ne "")
      {
         $$SHOUT .= "#define " . $_->{"identifier"} . "_V" . $$service_hash{"version"} . " " . $_->{"messageid"} .
            " /**< " . $_->{"description"} . " */\n";
      }else
      {
         $$SHOUT .= "#define " . $_->{"identifier"} . "_V" . $$service_hash{"version"} . " " . $_->{"messageid"} . "\n";
      }
   }
   $$SHOUT .= "/**\n    \@}\n  */\n\n";

   $$HOUT .=<<"EOF";
/* Service Object Accessor */
/** \@addtogroup wms_qmi_accessor
    \@{
  */
/** This function is used internally by the autogenerated code.  Clients should use the
   macro $service_identifier\_get_service_object_v$version\( ) that takes in no arguments. */
qmi_idl_service_object_type $service_identifier\_get_service_object_internal_v$version
 ( int32_t idl_maj_version, int32_t idl_min_version, int32_t library_version );

/** This macro should be used to get the service object */
#define $service_identifier\_get_service_object_v$version\( ) \\
          $service_identifier\_get_service_object_internal_v$version\( \\
            $uc_id\_V$version\_IDL_MAJOR_VERS, $uc_id\_V$version\_IDL_MINOR_VERS, \\
            $uc_id\_V$version\_IDL_TOOL_VERS )
/**
    \@}
  */

EOF
}#  h_add_split_service_v06

sub h_add_typedef_v01
{
   my $HOUT = shift;
   my $typedef_hash = shift;
   my $typedef_order = shift;

   if (ref($typedef_order) eq "ARRAY")
   {
      $$HOUT .=<<"EOF";
   /* Typedefs */

EOF

      foreach (@$typedef_order)
      {
         $$HOUT .= "typedef " . $type_hash{"idltype_to_ctype"}->{$$typedef_hash{$_}->{"type"}} . " " .
            $$typedef_hash{$_}->{"identifier"} . "_v" . $$typedef_hash{$_}->{"version"} . ";\n\n";
      }
   }
}

#===========================================================================
#
#FUNCTION C_TYPE_TABLE
#
#DESCRIPTION
#  Adds the type table to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_type_table_v01
{
   my $IS_COMMON_FILE = $type_hash{"common_file"};
   my $COUT = shift;
   my $type_hash = shift;
   my $struct_order = shift;
   my $service_identifier = shift;
   my $service_version = shift;
   my $version;
   my $num_types = 0;
   my $i = 0;
   my $index = 0;
   my %struct_hash = ();
   $$COUT .=<<"EOF";
/* Type Table */
EOF
   if (ref($struct_order) eq "ARRAY")
   {
      if (@{$struct_order} != 0)
      {#CONDENSE CONDITIONAL
         foreach (@$struct_order)
         {
            if ($$type_hash{$_}{"isstruct"})
            {  if ( ($$type_hash{$_}{"refCnt"} != 0) || ($IS_COMMON_FILE) )
               {
                  $struct_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
                  $num_types ++;
               }
            }
         }
         if ($num_types > 0)
         {
            $$COUT .= "static const qmi_idl_type_table_entry  " . $service_identifier . "_type_table_v" . $service_version . "[] = {\n";
         }else
         {
            $$COUT .= "/* No Types Defined in IDL */\n\n";
            return $num_types;
         }
         foreach my $key (sort { $struct_hash{$a}->{"sequence"} <=> $struct_hash{$b}->{"sequence"} } keys %struct_hash){
            $version = $struct_hash{$key}{"version"};
            #First time through conditional.  Add one.
            if (defined($struct_hash{$key}{"elementlist"}))
            {
               while (($struct_hash{$key}{"sequence"} != $i))
               {
                  $$COUT .= "  {0, 0},\n";
                  if ($CCB_MODE)
                  {
                     print STDERR "Warning: previously existing type definition moved to different IDL file.\n";
                     print STDERR "         rerun without golden XML file to optimize type table output.\n";
                  }
                  $i++;
               }
               $$COUT .= "  {sizeof(" . $struct_hash{$key}{"identifier"} . "_v$version), " . $struct_hash{$key}{"identifier"} . "_data_v$version},\n";
            }else
            {
               $$COUT .= "  {0, 0},\n";
            }
            $i++;
            $$type_hash{$key}{"sequence"} = $index;
            $index++;
         }
         $$COUT =~ s/,\n$/\n/; #Strip off the last trailing comma from the type table
         $$COUT .= "};\n\n";
      }
   }
   return $num_types;
}#  c_type_table_v01


#===========================================================================
#
#FUNCTION C_MESSAGE_TABLE
#
#DESCRIPTION
#  Adds the type table to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_message_table_v01
{
   my $IS_COMMON_FILE = $type_hash{"common_file"};
   my $COUT = shift;
   my $type_hash = shift;
   my $struct_order = shift;
   my $service_identifier = shift;
   my $service_version = shift;
   my $version;
   my $num_msgs = 0;
   my %message_hash = ();
   $$COUT .= "/* Message Table */\n";
   if (ref($struct_order) eq "ARRAY")
   {
      if (@{$struct_order} != 0)
      {#CONDENSE CONDITIONAL
         foreach (@$struct_order)
         {
            if ($$type_hash{$_}{"ismessage"} && ( ($$type_hash{$_}{"refCnt"} !=0 ) || $IS_COMMON_FILE ) )
            {
               $message_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
               $num_msgs++;
            }
         }
         if ($num_msgs > 0)
         {
            $$COUT .= "static const qmi_idl_message_table_entry " . $service_identifier
               . "_message_table_v" . $service_version . "[] = {\n";
         }else
         {
            $$COUT .= "/* No Messages Defined in IDL */\n\n";
         }
         foreach my $key (sort { $message_hash{$a}->{"sequence"} <=> $message_hash{$b}->{"sequence"} } keys %message_hash){
            $version = $message_hash{$key}{"version"};
            #FIRST TIME THROUGH CONDITIONAL
            if (scalar(@{$message_hash{$key}{"elementlist"}}) > 0)
            {
               $$COUT .= "  {sizeof(" . $message_hash{$key}{"identifier"}
               . "_v$version), " . $message_hash{$key}{"identifier"} . "_data_v$version},\n";
            }else
            {
               $$COUT .= "  {0, 0},\n";
            }
         }
         if ($num_msgs > 0)
         {
            $$COUT =~ s/,\n$/\n/; #Strip off the last trailing comma from the message table
            $$COUT .= "};\n\n";
         }
      }
   }
   return $num_msgs;
}#  c_message_table_v01

#===========================================================================
#
#FUNCTION C_TYPE_TABLE_OBJECT
#
#DESCRIPTION
#  Adds the type table object to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_type_table_object_v01
{
   my $COUT = shift;
   #my $service_identifier = shift;
   my $inc_type_order = shift;
   my $service_hash = shift;
   my $num_types = shift;
   my $num_msgs = shift;
   my $service_identifier = $$service_hash{"identifier"};
   my $service_version = $$service_hash{"version"};
   my $static_keyword = "const";

   my $type_size = "0";
   my $msg_size = "0";
   my $type_pointer = "NULL";
   my $msg_pointer = "NULL";
   if ($num_types != 0)
   {
      $type_size = "sizeof($service_identifier\_type_table_v$service_version)/sizeof(qmi_idl_type_table_entry )";
      $type_pointer = "$service_identifier\_type_table_v$service_version";
   }
   if ($num_msgs != 0)
   {
      $msg_size = "sizeof($service_identifier\_message_table_v$service_version)/sizeof(qmi_idl_message_table_entry)";
      $msg_pointer = "$service_identifier\_message_table_v$service_version";
   }

   $static_keyword = "static const" if (defined($$service_hash{"servicenumber"}));
   my $referenced_tables = "{&$service_identifier\_qmi_idl_type_table_object_v$service_version";
   if (ref($inc_type_order) eq "ARRAY")
   {
      foreach(@{$inc_type_order})
      {
         my $idlname = basename($_,".idl");
         my $include_version = "";
         $idlname =~ m/(.*)(_v\d\d)/;
         $idlname = $1;
         $include_version = $2;
         $referenced_tables .= ", &$idlname\_qmi_idl_type_table_object$include_version";
      }
   }
   $referenced_tables .= "};";
   $$COUT .=<<EOF;
/* Predefine the Type Table Object */
$static_keyword qmi_idl_type_table_object $service_identifier\_qmi_idl_type_table_object_v$service_version\;

/*Referenced Tables Array*/
static const qmi_idl_type_table_object *$service_identifier\_qmi_idl_type_table_object_referenced_tables_v$service_version\[] =
$referenced_tables

/*Type Table Object*/
$static_keyword qmi_idl_type_table_object $service_identifier\_qmi_idl_type_table_object_v$service_version = {
  $type_size,
  $msg_size,
  1,
  $type_pointer,
  $msg_pointer,
  $service_identifier\_qmi_idl_type_table_object_referenced_tables_v$service_version
};

EOF
}#  c_type_table_object_v01

#===========================================================================
#
#FUNCTION C_SERVICE_OBJECT
#
#DESCRIPTION
#  Adds the service object to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_service_object_v01
{
   my $COUT = shift;
   my $service_identifier = shift;
   my $service_hash = shift;
   my $max_msg_size = shift;
   my $lib_version = shift;
   my $req_list = 0;
   my $resp_list = 0;
   my $ind_list = 0;
   my $req_ptr = "NULL";
   my $resp_ptr = "NULL";
   my $ind_ptr = "NULL";
   my $service_id = $$service_hash{"servicenumber"};
   my $idl_version = $$service_hash{"version"};
   my $hex_idl_version = sprintf("0x%02X",$$service_hash{"version"});
   $lib_version = sprintf("0x%02X",$lib_version);
   if ($service_id !~ m/^\d+/)
   {
      $service_id .= "_V$idl_version";
   }
   foreach(@{$$service_hash{"elementlist"}})
   {
      if ($_->{"messagetype"} eq "COMMAND")
      {
         $req_list = "sizeof($service_identifier\_service_command_messages_v$idl_version)" .
            "/sizeof(qmi_idl_service_message_table_entry)";
         $req_ptr = "$service_identifier\_service_command_messages_v$idl_version";
      }elsif ($_->{"messagetype"} eq "RESPONSE")
      {
         $resp_list = "sizeof($service_identifier\_service_response_messages_v$idl_version)" .
            "/sizeof(qmi_idl_service_message_table_entry)";
         $resp_ptr = "$service_identifier\_service_response_messages_v$idl_version";
      }else
      {
         $ind_list = "sizeof($service_identifier\_service_indication_messages_v$idl_version)" .
            "/sizeof(qmi_idl_service_message_table_entry)";
         $ind_ptr = "$service_identifier\_service_indication_messages_v$idl_version";
      }
   }

   $$COUT .=<<EOF;
/*Service Object*/
const struct qmi_idl_service_object $service_identifier\_qmi_idl_service_object_v$service_hash->{"version"} = {
  $lib_version,
  $hex_idl_version,
  $service_id,
  $max_msg_size,
  { $req_list,
    $resp_list,
    $ind_list },
  { $req_ptr, $resp_ptr, $ind_ptr},
  &$service_identifier\_qmi_idl_type_table_object_v$idl_version
};

EOF
    #my $version = $service_hash->{"version"};
    my $uc_service = uc($service_identifier);
$$COUT .=<<"EOF";
/* Service Object Accessor */
qmi_idl_service_object_type $service_identifier\_get_service_object_internal_v$idl_version
 ( int32_t idl_maj_version, int32_t idl_min_version, int32_t library_version ){
  if ( $uc_service\_V$idl_version\_IDL_MAJOR_VERS != idl_maj_version || $uc_service\_V$idl_version\_IDL_MINOR_VERS != idl_min_version
       || $uc_service\_V$idl_version\_IDL_TOOL_VERS != library_version)
  {
    return NULL;
  }
  return (qmi_idl_service_object_type)&$service_identifier\_qmi_idl_service_object_v$idl_version;
}

EOF
}#  c_service_object_v01

#===========================================================================
#
#FUNCTION C_ADD_TYPES
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_types_v01
{
   my $COUT = shift;
   my $type_hash = shift;
   my $struct_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my %struct_hash = ();
   my $type_offset = 0;
   my $OFFSET = "QMI_IDL_OFFSET8(";
   $$COUT .= "/*Type Definitions*/\n";
   #Iterate through all of the elements in the type hash, and add all structs (not messages)
   #to the struct_hash
   if (ref($struct_order) eq "ARRAY")
   {
      if (@{$struct_order} != 0)
      {
         foreach (@$struct_order)
         {
            if ($$type_hash{$_}{"isstruct"})
            {
               $struct_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
            }
         }
         #Iterate through all of the structs, sorted by their sequence numbers
         foreach my $key (sort { $struct_hash{$a}->{"sequence"} <=> $struct_hash{$b}->{"sequence"} } keys %struct_hash){
            if (defined($struct_hash{$key}{"elementlist"}))
            {
               $$COUT .= "static const uint8_t " . $struct_hash{$key}{"identifier"} . "_data_v" .
                  $struct_hash{$key}{"version"} . "[] = {\n";
               foreach(@{$struct_hash{$key}{"elementlist"}})
               {
                  c_add_type_elms_v01($COUT,$struct_hash{$key}{"identifier"},
                                      $struct_hash{$key}{"version"},$_,$inc_types,$type_hash);
               }
               $$COUT .= "  QMI_IDL_FLAG_END_VALUE\n};\n\n";
            }else
            {#The struct is empty, do not define an empty struct, add it to the C file commented out
               $$COUT .=<<EOF;
/*
 * $struct_hash{$key}{"identifier"} is empty
 * static const uint8_t $struct_hash{$key}{"identifier"}\_data_v\$struct_hash{$key}{"version"}\[] = {
 * };
 */

EOF
            }
         }
      }
   }
}#  c_add_types_v01

#===========================================================================
#
#FUNCTION C_ADD_TYPE_ELMS
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_type_elms_v01
{
   my $COUT = shift;
   my $struct_name = shift;
   my $version_number = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $offset;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $ar_offset;
   my $sz_offset;
   my $type_table_index=0;
   my $qmi_idl_type_table_object_index=0;
   my $array_size_offset = "";
   my $size_is_16 = "";
   my $array_is_16 = $FALSE;
   my $aggregate_type = "";
   my $array_len = "";
   $$COUT .= "  ";

   #If the offset of this element in the structure is > 200
   if ($elm_hash->{"offset"} > $SZ_IS_16)
   {
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
      $$COUT .= "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }

   if ($elm_hash->{"n"} !~ /^\d/)
   {
      #Length value is a string value, must be a const, append the version number
      $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"};  #$version_number;
   }else
   {
      $array_len = $elm_hash->{"n"};
   }
   #If the element is an array with > 255 elements

   if ($elm_hash->{"set16bitflag"})
   {
      $size_is_16 = "QMI_IDL_FLAGS_SZ_IS_16 | ";
      $array_is_16 = $TRUE;
   }
   $offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   $sz_offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isarray"})
   {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | $size_is_16";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n";        #" $offset - $sz_offset,";
      }
   }elsif ($elm_hash->{"isvararray"})
   {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_is_16";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len .
            ") >> 8),\n  $offset - $sz_offset,\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
      }
   }elsif ($elm_hash->{"isstring"})
   {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_is_16";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}}))
   { #Generic type
      $$COUT .= $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}} . ",\n";
   }else
   { #Aggregate type
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},
                                                                             $inc_hash,$type_hash);
      $$COUT .= " QMI_IDL_AGGREGATE,\n";
      $aggregate_type = " $type_table_index, $qmi_idl_type_table_object_index,";
   }
   if ($elm_hash->{"offset"} > $SZ_IS_16)
   {
      $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else
   {
      $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
}#  c_add_type_elms_v01

#===========================================================================
#
#FUNCTION C_ADD_MESSAGES
#
#DESCRIPTION
#  Adds the message definitions to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message information filled in.
#
#===========================================================================
sub c_add_messages_v01
{
   my $COUT = shift;
   my $type_hash = shift;
   my $type_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my $tmp_out_buf = "";
   my %msg_hash = ();
   my $void_message = $FALSE;
   $$COUT .= "/*Message Definitions*/\n";
   if (ref($type_order) eq "ARRAY")
   {
      if (@{$type_order} != 0)
      {
         #Iterate through all of the elements in the type hash, and add all messages (not structs)
         #to the msg_hash
         foreach (@$type_order)
         {
            if ($$type_hash{$_}{"ismessage"})
            {
               $msg_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
            }
         }
         #Iterate through all of the messages, sorted by sequence number
         foreach my $key (sort { $msg_hash{$a}->{"sequence"} <=> $msg_hash{$b}->{"sequence"} } keys %msg_hash)
         {
            if (defined($msg_hash{$key}{"elementlist"}))
            {
               if (@{$msg_hash{$key}{"elementlist"}} != 0)
               {
                  $tmp_out_buf .= "static const uint8_t " . $msg_hash{$key}{"identifier"} . "_data_v" .
                     $msg_hash{$key}{"version"} . "[] = {\n";
                  foreach(@{$msg_hash{$key}{"elementlist"}})
                  {
                     c_add_msg_elms_v01(\$tmp_out_buf,$msg_hash{$key}{"identifier"},
                                        $msg_hash{$key}{"version"},$_,$inc_types,$type_hash);
                  }
                  $tmp_out_buf =~ s/,\n$//; #Strip off the last trailing comma and newline
                  #Put in the LAST_TLV keyword for the last TLV
                  #If there is more than 1 TLV, a different pattern match is necessary
                  if ($tmp_out_buf =~ /.*(,\n\n\s\s)(.*?\n.*)/)
                  {
                     my $tmp_match;
                     while ($tmp_out_buf =~ /(,\n\n\s\s)(.*\n)/g)
                     {
                        $tmp_match = $2;
                     }
                     $tmp_out_buf =~ s/(?=\Q$tmp_match\E)/QMI_IDL_TLV_FLAGS_LAST_TLV | /;
                  }else
                  {#Only 1 TLV, easy search and replace
                     $tmp_out_buf =~ s/({\n\s\s)(.*\n)(?!.*\n\n)/$1QMI_IDL_TLV_FLAGS_LAST_TLV | $2/;
                  }
               #}
                  $$COUT .= $tmp_out_buf;
                  $$COUT .= "};\n\n";
                  $tmp_out_buf = "";
               }else
               {#The message is empty, do not define an empty struct, add it to the C file commented out
                  $$COUT .=<<EOF;
/*
 * $msg_hash{$key}{"identifier"} is empty
 * static const uint8_t $msg_hash{$key}{"identifier"}\_data_v$msg_hash{$key}{"version"}\[] = {
 * };
 */

EOF
               }
            }else
            {#The message is empty, do not define an empty struct, add it to the C file commented out
               $$COUT .=<<EOF;
/*
 * $msg_hash{$key}{"identifier"} is empty
 * static const uint8_t $msg_hash{$key}{"identifier"}\_data_v$msg_hash{$key}{"version"}\[] = {
 * };
 */

EOF
            }
         }
      }
   }
}#  c_add_messages_v01

#===========================================================================
#
#FUNCTION C_ADD_MSG_ELMS
#
#DESCRIPTION
#  Adds the message elements to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message element information filled in.
#
#===========================================================================
sub c_add_msg_elms_v01
{
   my $COUT = shift;
   my $struct_name = shift;
   my $version = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $qmi_idl_type_table_object_index=0;
   my $type_table_index=0;
   my $array_size_offset = "";
   my $type;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $tlvtype = $elm_hash->{"tlvtype"};
   my $offset16 = "";
   my $ar_offset;
   my $size_is_16 = "";
   my $array_is_16 = $FALSE;
   my $aggregate_type = "";
   my $array_len = "";

   $$COUT .= "  ";
   #If the offset of this element in the structure is > 255
   if ($elm_hash->{"offset"} > $SZ_IS_16)
   {
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
      $offset16 = "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }

   if ($elm_hash->{"n"} !~ /^\d/)
   {
      #Length value is a string value, must be a const, append the version number
      $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"}; #$version;
   }else
   {
      $array_len = $elm_hash->{"n"};
   }
   #If the element is an array with > 255 elements
   #if ((get_num_value($elm_hash->{"n"}) > $SZ_IS_16) or ($elm_hash->{"isstring"} and (get_num_value($elm_hash->{"n"}) + 1 > $SZ_IS_16)) or ($elm_hash->{"set16bitflag"})) {
   if ($elm_hash->{"set16bitflag"})
   {
      $size_is_16 = "QMI_IDL_FLAGS_SZ_IS_16 | ";
      $array_is_16 = $TRUE;
   }
   my $offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   my $sz_offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isoptional"})
   {
      $$COUT .= "QMI_IDL_TLV_FLAGS_OPTIONAL | ";
      $$COUT .= "($offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} .
         ") - $offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_valid)),\n  ";
   }
   if ($elm_hash->{"isarray"})
   {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | $size_is_16";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }elsif ($elm_hash->{"isvararray"})
   {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_is_16";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len .
            ") >> 8),\n  $offset - $sz_offset,\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
      }
   }elsif ($elm_hash->{"isstring"})
   {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_is_16";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }else
   {
      $$COUT .= "$tlvtype,\n";
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}}))
   { #Generic type
      $type = $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}};
      $$COUT .= "  $offset16$type,\n";
   }else
   { #Aggregate type
      $type = "QMI_IDL_AGGREGATE";
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},
                                                                             $inc_hash,$type_hash,$struct_name);
      $$COUT .= "  $offset16$type,\n";
      $aggregate_type = "  $type_table_index, $qmi_idl_type_table_object_index,\n";
   }
   if ($elm_hash->{"offset"} > $SZ_IS_16)
   {
      $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else
   {
      $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
}#  c_add_msg_elms_v01

#===========================================================================
#
#FUNCTION C_SERVICE_MESSAGE_TABLE
#
#DESCRIPTION
#  Adds the service message table to the c file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has service message table element information filled in.
#
#===========================================================================
sub c_service_message_table_v01
{
   my $COUT = shift;
   my $identifier = shift;
   my $service_hash = shift;
   my $type_hash = shift;
   my $inc_type_hash = shift;
   my $qmi_idl_type_table_object_index=0;
   my $type_table_index=0;
   my $wire_size = 0;
   my $command_list="";
   my $response_list="";
   my $indication_list="";

   foreach(@{$$service_hash{"elementlist"}})
   {
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($_->{"type"},$inc_type_hash,$type_hash);
      $wire_size = get_type_wire_size($_->{"type"},$inc_type_hash,$type_hash);
      my $tempString = "  {" . $_->{"identifier"} . "_V" . $$service_hash{"version"} .
         ", QMI_IDL_TYPE16($qmi_idl_type_table_object_index, $type_table_index), $wire_size},\n";
      if ($_->{"messagetype"} eq "COMMAND")
      {
         if (not defined $_->{"removed"})
         {
            $command_list .= $tempString;
         }
      }elsif ($_->{"messagetype"} eq "RESPONSE")
      {
         if (not defined $_->{"removed"})
         {
            $response_list .= $tempString;
         }
      }else
      {
         if (not defined $_->{"removed"})
         {
            $indication_list .= $tempString;
         }
      }
   }
   $command_list =~ s/,\n$/\n/; #Strip off the last trailing comma
   $response_list =~ s/,\n$/\n/; #Strip off the last trailing comma
   $indication_list =~ s/,\n$/\n/; #Strip off the last trailing comma
   chomp($command_list,$response_list,$indication_list);
   $$COUT .= <<"EOF";
/*Arrays of service_message_table_entries for commands, responses and indications*/
EOF
   if ($command_list ne "")
   {
      $$COUT .=<<"EOF";
static const qmi_idl_service_message_table_entry $identifier\_service_command_messages_v$service_hash->{"version"}\[] = {
$command_list
};

EOF
   }
   if ($response_list ne "")
   {
      $$COUT .=<<"EOF";
static const qmi_idl_service_message_table_entry $identifier\_service_response_messages_v$service_hash->{"version"}\[] = {
$response_list
};

EOF
   }
   if ($indication_list ne "")
   {
      $$COUT .=<<"EOF";
static const qmi_idl_service_message_table_entry $identifier\_service_indication_messages_v$service_hash->{"version"}\[] = {
$indication_list
};

EOF
   }
}#  c_service_message_table_v01


#===========================================================================
#                  VESRION 2 OUTPUT ROUTINES
#===========================================================================

#===========================================================================
#
#FUNCTION C_ADD_TYPES
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_types_v02
{
   my $COUT = shift;
   my $type_hash = shift;
   my $struct_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my %struct_hash = ();
   my $type_offset = 0;
   my $OFFSET = "QMI_IDL_OFFSET8(";
   $$COUT .= "/*Type Definitions*/\n";
   #Iterate through all of the elements in the type hash, and add all structs (not messages)
   #to the struct_hash
   if (ref($struct_order) eq "ARRAY")
   {
      if (@{$struct_order} != 0)
      {
         foreach (@$struct_order)
         {
            if ($$type_hash{$_}{"isstruct"})
            {
               $struct_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
            }
         }
         #Iterate through all of the structs, sorted by their sequence numbers
         foreach my $key (sort { $struct_hash{$a}->{"sequence"} <=> $struct_hash{$b}->{"sequence"} } keys %struct_hash){
            if (defined($struct_hash{$key}{"elementlist"}))
            {
               $$COUT .= "static const uint8_t " . $struct_hash{$key}{"identifier"} . "_data_v" .
                  $struct_hash{$key}{"version"} . "[] = {\n";
               foreach(@{$struct_hash{$key}{"elementlist"}})
               {
                  c_add_type_elms_v02($COUT,$struct_hash{$key}{"identifier"},
                                      $struct_hash{$key}{"version"},$_,$inc_types,$type_hash);
               }
               $$COUT .= "  QMI_IDL_FLAG_END_VALUE\n};\n\n";
            }else
            {#The struct is empty, do not define an empty struct, add it to the C file commented out
               $$COUT .=<<EOF;
/*
 * $struct_hash{$key}{"identifier"} is empty
 * static const uint8_t $struct_hash{$key}{"identifier"}\_data_v\$struct_hash{$key}{"version"}\[] = {
 * };
 */

EOF
            }
         }
      }
   }
}#  c_add_types_v02

#===========================================================================
#
#FUNCTION C_ADD_TYPE_ELMS
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_type_elms_v02 {
   my $COUT = shift;
   my $struct_name = shift;
   my $version_number = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $offset;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $ar_offset;
   my $sz_offset;
   my $type_table_index=0;
   my $qmi_idl_type_table_object_index=0;
   my $array_size_offset = "";
   my $size_gt_8 = "";
   my $extended_byte = "";
   my $array_is_16 = $FALSE;
   my $array_is_32 = $FALSE;
   my $aggregate_type = "";
   my $array_len = "";
   $$COUT .= "  ";
   #If the offset of this element in the structure is > 255
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
      $$COUT .= "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }

   if ($elm_hash->{"n"} !~ /^\d/) {
      #Length value is a string value, must be a const, append the version number
      $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"}; #$version_number;
   }else{
      $array_len = $elm_hash->{"n"};
   }
   #If the element is an array with > 255 elements
   if ($elm_hash->{"set16bitflag"}) {
      $size_gt_8 = "QMI_IDL_FLAGS_SZ_IS_16 | ";
      $array_is_16 = $TRUE;
   }
   if ($elm_hash->{"set32bitflag"}) {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte = "  QMI_IDL_FLAGS_SZ_IS_32,\n";
      $array_is_16 = $FALSE;
      $array_is_32 = $TRUE;
   }
   #if ($elm_hash->{"len_field_offset"} != 0)
   #{
   #   $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
   #   if ($elm_hash->{"len_field_offset"} > 0)
   #   {
   #      $extended_byte = "  QMI_IDL_FLAGS_ARRAY_DATA_ONLY,\n";
   #   }else
   #   {
   #      $extended_byte = "  QMI_IDL_FLAGS_ARRAY_LENGTH_ONLY,\n";
   #   }
   #}
   #if ($elm_hash->{"islengthless"} && !$elm_hash->{"isstring"})
   #{
   #   $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
   #   $extended_byte = "  QMI_IDL_FLAGS_ARRAY_IS_LENGTHLESS,\n";
   #}
   $offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   $sz_offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isarray"}) {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8-bit byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";      #" $offset - $sz_offset,";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";        #" $offset - $sz_offset,";
      }
   }elsif ($elm_hash->{"isvararray"}) {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8-bit byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n  $offset - $sz_offset,\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0," .
            "\n  $offset - $sz_offset,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
      }
   }elsif ($elm_hash->{"isstring"}){
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}})) { #Generic type
      $$COUT .= $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}} . ",\n";
   }else{ #Aggregate type
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},$inc_hash,$type_hash);
      $$COUT .= " QMI_IDL_AGGREGATE,\n";
      $aggregate_type = " $type_table_index, $qmi_idl_type_table_object_index,";
   }
   $$COUT .= "$extended_byte";
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else{
      $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
}#  c_add_type_elms_v02

#===========================================================================
#
#FUNCTION C_ADD_MESSAGES
#
#DESCRIPTION
#  Adds the message definitions to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message information filled in.
#
#===========================================================================
sub c_add_messages_v02 {
   my $COUT = shift;
   my $type_hash = shift;
   my $type_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my $tmp_out_buf = "";
   my %msg_hash = ();
   my $void_message = $FALSE;
   $$COUT .= "/*Message Definitions*/\n";
   if (ref($type_order) eq "ARRAY") {
      if (@{$type_order} != 0) {
         #Iterate through all of the elements in the type hash, and add all messages (not structs)
         #to the msg_hash
         foreach (@$type_order) {
            if ($$type_hash{$_}{"ismessage"}) {
               $msg_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
            }
         }
         #Iterate through all of the messages, sorted by sequence number
         foreach my $key (sort { $msg_hash{$a}->{"sequence"} <=> $msg_hash{$b}->{"sequence"} } keys %msg_hash){
            if (defined($msg_hash{$key}{"elementlist"})) {#condense into one conditional
               if (@{$msg_hash{$key}{"elementlist"}} != 0) {
                  $tmp_out_buf .= "static const uint8_t " . $msg_hash{$key}{"identifier"} . "_data_v" .
                     $msg_hash{$key}{"version"} . "[] = {\n";
                  foreach(@{$msg_hash{$key}{"elementlist"}}){
                     c_add_msg_elms_v02(\$tmp_out_buf,$msg_hash{$key}{"identifier"},$msg_hash{$key}{"version"},$_,$inc_types,$type_hash);
                  }
                  $tmp_out_buf =~ s/,\n$//; #Strip off the last trailing comma and newline
                  #Put in the LAST_TLV keyword for the last TLV
                  #If there is more than 1 TLV, a different pattern match is necessary
                  if ($tmp_out_buf =~ /.*(,\n\n\s\s)(.*?\n.*)/) {
                     my $tmp_match;
                     while ($tmp_out_buf =~ /(,\n\n\s\s)(.*\n)/g) {
                        $tmp_match = $2;
                     }
                     #Check to see if there are multiple instances of $tmp_match
                     #(Necessary w/ the addition of the DUPLICATE type
                     my $count = 0;
                     $count++ while($tmp_out_buf =~ /\Q$tmp_match\E/g);
                     if ($count >1)
                     {
                        my @temp_array = split(/\n/,$tmp_out_buf);
                        my $match_count = 0;
                        foreach (@temp_array)
                        {
                           if ($_ =~ /$tmp_match/g)
                           {
                              $match_count++;
                              next if ($match_count != $count);
                              $_ = "  QMI_IDL_TLV_FLAGS_LAST_TLV |" . $_;
                           }
                        }
                        $tmp_out_buf = join("\n",@temp_array);
                        $tmp_out_buf .= "\n";
                     }else
                     {
                        $tmp_out_buf =~ s/(?=\Q$tmp_match\E)/QMI_IDL_TLV_FLAGS_LAST_TLV | /;
                     }
                  }else{#Only 1 TLV, easy search and replace
                     $tmp_out_buf =~ s/({\n\s\s)(.*\n)(?!.*\n\n)/$1QMI_IDL_TLV_FLAGS_LAST_TLV | $2/;
                  }

                  $$COUT .= $tmp_out_buf;
                  $$COUT .= "};\n\n";
                  $tmp_out_buf = "";
               }else{#The message is empty, do not define an empty struct, add it to the C file commented out
                  $$COUT .=<<EOF;
/*
 * $msg_hash{$key}{"identifier"} is empty
 * static const uint8_t $msg_hash{$key}{"identifier"}\_data_v$msg_hash{$key}{"version"}\[] = {
 * };
 */

EOF
               }
            }else{#The message is empty, do not define an empty struct, add it to the C file commented out
               $$COUT .=<<EOF;
/*
 * $msg_hash{$key}{"identifier"} is empty
 * static const uint8_t $msg_hash{$key}{"identifier"}\_data_v$msg_hash{$key}{"version"}\[] = {
 * };
 */

EOF
            }
         }
      }
   }
}#  c_add_messages_v02

#===========================================================================
#
#FUNCTION C_ADD_MSG_ELMS
#
#DESCRIPTION
#  Adds the message elements to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message element information filled in.
#
#===========================================================================
sub c_add_msg_elms_v02 {
   my $COUT = shift;
   my $struct_name = shift;
   my $version = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $qmi_idl_type_table_object_index=0;
   my $type_table_index=0;
   my $array_size_offset = "";
   my $type;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $tlvtype = $elm_hash->{"tlvtype"};
   my $offset16 = "";
   my $ar_offset;
   my $size_gt_8 = "";
   my $array_is_16 = $FALSE;
   my $array_is_32 = $FALSE;
   my $extended_byte = "";
   my $aggregate_type = "";
   my $array_len = "";

   if ($elm_hash->{"isduplicate"})
   {
      my $temp_hash = get_type_by_tlv($type_hash,$struct_name,$elm_hash->{"isduplicate"});
      $temp_hash->{"valuedescription"} = "Duplicate of TLV #: " . $temp_hash->{"tlvtype"} . "\n";
      $temp_hash->{"tlvtype"} = $elm_hash->{"tlvtype"};
      $elm_hash = $temp_hash;
   }
   $$COUT .= "  ";
   #If the offset of this element in the structure is > 255
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
      $offset16 = "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }

   if ($elm_hash->{"n"} !~ /^\d/) {
      #Length value is a string value, must be a const, append the version number
      $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"}; #$version;
   }else{
      $array_len = $elm_hash->{"n"};
   }
   #If the element is an array with > 255 elements
   if ($elm_hash->{"set16bitflag"}) {
      $size_gt_8 = "QMI_IDL_FLAGS_SZ_IS_16 | ";
      $array_is_16 = $TRUE;
   }
   if ($elm_hash->{"set32bitflag"}) {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte = "  QMI_IDL_FLAGS_SZ_IS_32,\n";
      $array_is_16 = $FALSE;
      $array_is_32 = $TRUE;
   }

   #if ($elm_hash->{"islengthless"} && !$elm_hash->{"isstring"})
   #{
   #   $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
   #   $extended_byte = "  QMI_IDL_FLAGS_ARRAY_IS_LENGTHLESS,\n";
   #}
   my $offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   my $sz_offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isoptional"}) {
      $$COUT .= "QMI_IDL_TLV_FLAGS_OPTIONAL | ";
      $$COUT .= "($offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . ") - $offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_valid)),\n  ";
   }
   if ($elm_hash->{"isarray"}) {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }elsif ($elm_hash->{"isvararray"}) {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n  $offset - $sz_offset,\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0," .
            "\n  $offset - $sz_offset,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
      }
   }elsif ($elm_hash->{"isstring"}){
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }else{
      $$COUT .= "$tlvtype,\n";
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}})) { #Generic type
      $type = $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}};
      $$COUT .= "  $offset16$type,\n";
   }else{ #Aggregate type
      $type = "QMI_IDL_AGGREGATE";
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},$inc_hash,$type_hash,$struct_name);
      $$COUT .= "  $offset16$type,\n";
      $aggregate_type = "  $type_table_index, $qmi_idl_type_table_object_index,\n";
   }
   $$COUT .= "$extended_byte";
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else{
      $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
}#  c_add_msg_elms_v02

#===========================================================================
#                  VESRION 3 OUTPUT ROUTINES
#===========================================================================

#===========================================================================
#
#FUNCTION C_ADD_TYPES
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_types_v03
{
   my $COUT = shift;
   my $type_hash = shift;
   my $struct_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my %struct_hash = ();
   my $type_offset = 0;
   my $OFFSET = "QMI_IDL_OFFSET8(";
   $$COUT .= "/*Type Definitions*/\n";
   #Iterate through all of the elements in the type hash, and add all structs (not messages)
   #to the struct_hash
   if (ref($struct_order) eq "ARRAY")
   {
      if (@{$struct_order} != 0)
      {
         foreach (@$struct_order)
         {
            if ($$type_hash{$_}{"isstruct"})
            {
               $struct_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
            }
         }
         #Iterate through all of the structs, sorted by their sequence numbers
         foreach my $key (sort { $struct_hash{$a}->{"sequence"} <=> $struct_hash{$b}->{"sequence"} } keys %struct_hash){
            if (defined($struct_hash{$key}{"elementlist"}))
            {
               $$COUT .= "static const uint8_t " . $struct_hash{$key}{"identifier"} . "_data_v" .
                  $struct_hash{$key}{"version"} . "[] = {\n";
               foreach(@{$struct_hash{$key}{"elementlist"}})
               {
                  c_add_type_elms_v03($COUT,$struct_hash{$key}{"identifier"},
                                      $struct_hash{$key}{"version"},$_,$inc_types,$type_hash);
               }
               $$COUT .= "  QMI_IDL_FLAG_END_VALUE\n};\n\n";
            }else
            {#The struct is empty, do not define an empty struct, add it to the C file commented out
               $$COUT .=<<EOF;
/*
 * $struct_hash{$key}{"identifier"} is empty
 * static const uint8_t $struct_hash{$key}{"identifier"}\_data_v\$struct_hash{$key}{"version"}\[] = {
 * };
 */

EOF
            }
         }
      }
   }
}#  c_add_types_v03

#===========================================================================
#
#FUNCTION C_ADD_TYPE_ELMS
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_type_elms_v03 {
   my $COUT = shift;
   my $struct_name = shift;
   my $version_number = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $offset;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $ar_offset;
   my $sz_offset;
   my $type_table_index=0;
   my $qmi_idl_type_table_object_index=0;
   my $array_size_offset = "";
   my $size_gt_8 = "";
   my $extended_byte = "";
   my $array_is_16 = $FALSE;
   my $array_is_32 = $FALSE;
   my $aggregate_type = "";
   my $array_len = "";
   $$COUT .= "  ";
   #If the offset of this element in the structure is > 255
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
      $$COUT .= "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }

   if ($elm_hash->{"n"} !~ /^\d/) {
      #Length value is a string value, must be a const, append the version number
      $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"}; #$version_number;
   }else{
      $array_len = $elm_hash->{"n"};
   }
   if ($elm_hash->{"len_field_offset"} != 0)
   {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      if ($elm_hash->{"len_field_offset"} > 0)
      {
         $extended_byte = "  QMI_IDL_FLAGS_ARRAY_DATA_ONLY,\n";
      }else
      {
         $extended_byte = "  QMI_IDL_FLAGS_ARRAY_LENGTH_ONLY,\n";
      }
   }
   #If the element is an array with > 255 elements
   if ($elm_hash->{"set16bitflag"}) {
      $size_gt_8 .= "QMI_IDL_FLAGS_SZ_IS_16 | ";
      $array_is_16 = $TRUE;
   }
   if ($elm_hash->{"set32bitflag"}) {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_SZ_IS_32,\n";
      $array_is_16 = $FALSE;
      $array_is_32 = $TRUE;
   }
   #if ($elm_hash->{"islengthless"} && !$elm_hash->{"isstring"})
   #{
   #   $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
   #   $extended_byte = "  QMI_IDL_FLAGS_ARRAY_IS_LENGTHLESS,\n";
   #}
   $offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   $sz_offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isarray"}) {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8-bit byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";      #" $offset - $sz_offset,";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";        #" $offset - $sz_offset,";
      }
   }elsif ($elm_hash->{"isvararray"}) {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8-bit byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n  $offset - $sz_offset,\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0," .
            "\n  $offset - $sz_offset,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
      }
   }elsif ($elm_hash->{"isstring"}){
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}})) { #Generic type
      $$COUT .= $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}} . ",\n";
   }else{ #Aggregate type
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},$inc_hash,$type_hash);
      $$COUT .= " QMI_IDL_AGGREGATE,\n";
      $aggregate_type = " $type_table_index, $qmi_idl_type_table_object_index,";
   }
   $$COUT .= "$extended_byte";
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else{
      $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
}#  c_add_type_elms_v03

#===========================================================================
#
#FUNCTION C_ADD_MESSAGES
#
#DESCRIPTION
#  Adds the message definitions to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message information filled in.
#
#===========================================================================
sub c_add_messages_v03 {
   my $COUT = shift;
   my $type_hash = shift;
   my $type_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my $tmp_out_buf = "";
   my %msg_hash = ();
   my $void_message = $FALSE;
   $$COUT .= "/*Message Definitions*/\n";
   if (ref($type_order) eq "ARRAY") {
      if (@{$type_order} != 0) {
         #Iterate through all of the elements in the type hash, and add all messages (not structs)
         #to the msg_hash
         foreach (@$type_order) {
            if ($$type_hash{$_}{"ismessage"}) {
               $msg_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
            }
         }
         #Iterate through all of the messages, sorted by sequence number
         foreach my $key (sort { $msg_hash{$a}->{"sequence"} <=> $msg_hash{$b}->{"sequence"} } keys %msg_hash){
            if (defined($msg_hash{$key}{"elementlist"})) {#condense into one conditional
               if (@{$msg_hash{$key}{"elementlist"}} != 0) {
                  $tmp_out_buf .= "static const uint8_t " . $msg_hash{$key}{"identifier"} . "_data_v" .
                     $msg_hash{$key}{"version"} . "[] = {\n";
                  foreach(@{$msg_hash{$key}{"elementlist"}}){
                     c_add_msg_elms_v03(\$tmp_out_buf,$msg_hash{$key}{"identifier"},$msg_hash{$key}{"version"},$_,$inc_types,$type_hash);
                  }
                  $tmp_out_buf =~ s/,\n$//; #Strip off the last trailing comma and newline
                  #Put in the LAST_TLV keyword for the last TLV
                  #If there is more than 1 TLV, a different pattern match is necessary
                  if ($tmp_out_buf =~ /.*(,\n\n\s\s)(.*?\n.*)/) {
                     my $tmp_match;
                     while ($tmp_out_buf =~ /(,\n\n\s\s)(.*\n)/g) {
                        $tmp_match = $2;
                     }
                     #Check to see if there are multiple instances of $tmp_match
                     #(Necessary w/ the addition of the DUPLICATE type
                     my $count = 0;
                     $count++ while($tmp_out_buf =~ /\Q$tmp_match\E/g);
                     if ($count >1)
                     {
                        my @temp_array = split(/\n/,$tmp_out_buf);
                        my $match_count = 0;
                        foreach (@temp_array)
                        {
                           if ($_ =~ /$tmp_match/g)
                           {
                              $match_count++;
                              next if ($match_count != $count);
                              $_ = "  QMI_IDL_TLV_FLAGS_LAST_TLV |" . $_;
                           }
                        }
                        $tmp_out_buf = join("\n",@temp_array);
                        $tmp_out_buf .= "\n";
                     }else
                     {
                        $tmp_out_buf =~ s/(?=\Q$tmp_match\E)/QMI_IDL_TLV_FLAGS_LAST_TLV | /;
                     }
                  }else{#Only 1 TLV, easy search and replace
                     $tmp_out_buf =~ s/({\n\s\s)(.*\n)(?!.*\n\n)/$1QMI_IDL_TLV_FLAGS_LAST_TLV | $2/;
                  }

                  $$COUT .= $tmp_out_buf;
                  $$COUT .= "};\n\n";
                  $tmp_out_buf = "";
               }else{#The message is empty, do not define an empty struct, add it to the C file commented out
                  $$COUT .=<<EOF;
/*
 * $msg_hash{$key}{"identifier"} is empty
 * static const uint8_t $msg_hash{$key}{"identifier"}\_data_v$msg_hash{$key}{"version"}\[] = {
 * };
 */

EOF
               }
            }else{#The message is empty, do not define an empty struct, add it to the C file commented out
               $$COUT .=<<EOF;
/*
 * $msg_hash{$key}{"identifier"} is empty
 * static const uint8_t $msg_hash{$key}{"identifier"}\_data_v$msg_hash{$key}{"version"}\[] = {
 * };
 */

EOF
            }
         }
      }
   }
}#  c_add_messages_v03

#===========================================================================
#
#FUNCTION C_ADD_MSG_ELMS
#
#DESCRIPTION
#  Adds the message elements to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message element information filled in.
#
#===========================================================================
sub c_add_msg_elms_v03 {
   my $COUT = shift;
   my $struct_name = shift;
   my $version = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $qmi_idl_type_table_object_index=0;
   my $type_table_index=0;
   my $array_size_offset = "";
   my $type;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $tlvtype = $elm_hash->{"tlvtype"};
   my $offset16 = "";
   my $ar_offset;
   my $size_gt_8 = "";
   my $array_is_16 = $FALSE;
   my $array_is_32 = $FALSE;
   my $extended_byte = "";
   my $aggregate_type = "";
   my $array_len = "";

   if ($elm_hash->{"isduplicate"})
   {
      my $temp_hash = get_type_by_tlv($type_hash,$struct_name,$elm_hash->{"isduplicate"});
      $temp_hash->{"valuedescription"} = "Duplicate of TLV #: " . $temp_hash->{"tlvtype"} . "\n";
      $temp_hash->{"tlvtype"} = $elm_hash->{"tlvtype"};
      $elm_hash = $temp_hash;
   }
   $$COUT .= "  ";
   #If the offset of this element in the structure is > 255
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
      $offset16 = "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }

   if ($elm_hash->{"n"} !~ /^\d/) {
      #Length value is a string value, must be a const, append the version number
      $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"}; #$version;
   }else{
      $array_len = $elm_hash->{"n"};
   }
   #If the element is an array with > 255 elements
   if ($elm_hash->{"set16bitflag"}) {
      $size_gt_8 = "QMI_IDL_FLAGS_SZ_IS_16 | ";
      $array_is_16 = $TRUE;
   }
   if ($elm_hash->{"set32bitflag"}) {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte = "  QMI_IDL_FLAGS_SZ_IS_32,\n";
      $array_is_16 = $FALSE;
      $array_is_32 = $TRUE;
   }

   #if ($elm_hash->{"islengthless"} && !$elm_hash->{"isstring"})
   #{
   #   $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
   #   $extended_byte = "  QMI_IDL_FLAGS_ARRAY_IS_LENGTHLESS,\n";
   #}
   my $offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   my $sz_offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isoptional"}) {
      $$COUT .= "QMI_IDL_TLV_FLAGS_OPTIONAL | ";
      $$COUT .= "($offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . ") - $offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_valid)),\n  ";
   }
   if ($elm_hash->{"isarray"}) {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }elsif ($elm_hash->{"isvararray"}) {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n  $offset - $sz_offset,\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0," .
            "\n  $offset - $sz_offset,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
      }
   }elsif ($elm_hash->{"isstring"}){
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }else{
      $$COUT .= "$tlvtype,\n";
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}})) { #Generic type
      $type = $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}};
      $$COUT .= "  $offset16$type,\n";
   }else{ #Aggregate type
      $type = "QMI_IDL_AGGREGATE";
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},$inc_hash,$type_hash,$struct_name);
      $$COUT .= "  $offset16$type,\n";
      $aggregate_type = "  $type_table_index, $qmi_idl_type_table_object_index,\n";
   }
   $$COUT .= "$extended_byte";
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else{
      $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
}#  c_add_msg_elms_v03

#===========================================================================
#                  VESRION 4 OUTPUT ROUTINES
#===========================================================================

#===========================================================================
#
#FUNCTION C_ADD_TYPES
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_types_v04
{
   my $COUT = shift;
   my $type_hash = shift;
   my $struct_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my %struct_hash = ();
   my $type_offset = 0;
   my $OFFSET = "QMI_IDL_OFFSET8(";
   $$COUT .= "/*Type Definitions*/\n";
   #Iterate through all of the elements in the type hash, and add all structs (not messages)
   #to the struct_hash
   if (ref($struct_order) eq "ARRAY")
   {
      if (@{$struct_order} != 0)
      {
         foreach (@$struct_order)
         {
            if ($$type_hash{$_}{"isstruct"})
            {
               $struct_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
            }
         }
         #Iterate through all of the structs, sorted by their sequence numbers
         foreach my $key (sort { $struct_hash{$a}->{"sequence"} <=> $struct_hash{$b}->{"sequence"} } keys %struct_hash){
            if (defined($struct_hash{$key}{"elementlist"}))
            {
               $$COUT .= "static const uint8_t " . $struct_hash{$key}{"identifier"} . "_data_v" .
                  $struct_hash{$key}{"version"} . "[] = {\n";
               foreach(@{$struct_hash{$key}{"elementlist"}})
               {
                  c_add_type_elms_v04($COUT,$struct_hash{$key}{"identifier"},
                                      $struct_hash{$key}{"version"},$_,$inc_types,$type_hash);
               }
               $$COUT .= "  QMI_IDL_FLAG_END_VALUE\n};\n\n";
            }else
            {#The struct is empty, do not define an empty struct, add it to the C file commented out
               $$COUT .=<<EOF;
/*
 * $struct_hash{$key}{"identifier"} is empty
 * static const uint8_t $struct_hash{$key}{"identifier"}\_data_v\$struct_hash{$key}{"version"}\[] = {
 * };
 */

EOF
            }
         }
      }
   }
}#  c_add_types_v04

#===========================================================================
#
#FUNCTION C_ADD_TYPE_ELMS
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_type_elms_v04 {
   my $COUT = shift;
   my $struct_name = shift;
   my $version_number = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $offset;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $ar_offset;
   my $sz_offset;
   my $type_table_index=0;
   my $qmi_idl_type_table_object_index=0;
   my $array_size_offset = "";
   my $size_gt_8 = "";
   my $extended_byte = "";
   my $array_is_16 = $FALSE;
   my $array_is_32 = $FALSE;
   my $aggregate_type = "";
   my $array_len = "";
   $$COUT .= "  ";
   #If the offset of this element in the structure is > 255
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
      $$COUT .= "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }

   if ($elm_hash->{"n"} !~ /^\d/) {
      #Length value is a string value, must be a const, append the version number
      $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"}; #$version_number;
   }else{
      $array_len = $elm_hash->{"n"};
   }

   if ($elm_hash->{"len_field_offset"} != 0)
   {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      if ($elm_hash->{"len_field_offset"} > 0)
      {
         $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_DATA_ONLY |";
      }else
      {
         $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_LENGTH_ONLY |";
      }
   }
   if ($elm_hash->{"islengthless"} && !$elm_hash->{"isstring"})
   {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_IS_LENGTHLESS |";
   }
   #If the element is an array with > 255 elements
   if ($elm_hash->{"set16bitflag"}) {
      $size_gt_8 .= "QMI_IDL_FLAGS_SZ_IS_16 | ";
      $array_is_16 = $TRUE;
   }
   if ($elm_hash->{"set32bitflag"}) {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_SZ_IS_32 |";
      $array_is_16 = $FALSE;
      $array_is_32 = $TRUE;
   }
   $extended_byte =~ s/\|$/,\n/;
   $offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   $sz_offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isarray"}) {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8-bit byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";      #" $offset - $sz_offset,";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";        #" $offset - $sz_offset,";
      }
   }elsif ($elm_hash->{"isvararray"}) {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8-bit byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n  $offset - $sz_offset,\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0," .
            "\n  $offset - $sz_offset,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
      }
   }elsif ($elm_hash->{"isstring"}){
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}})) { #Generic type
      $$COUT .= $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}} . ",\n";
   }else{ #Aggregate type
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},$inc_hash,$type_hash);
      $$COUT .= " QMI_IDL_AGGREGATE,\n";
      $aggregate_type = " $type_table_index, $qmi_idl_type_table_object_index,";
   }
   $$COUT .= "$extended_byte";
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else{
      $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
}#  c_add_type_elms_v04

#===========================================================================
#
#FUNCTION C_ADD_MESSAGES
#
#DESCRIPTION
#  Adds the message definitions to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message information filled in.
#
#===========================================================================
sub c_add_messages_v04 {
   my $COUT = shift;
   my $type_hash = shift;
   my $type_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my $tmp_out_buf = "";
   my %msg_hash = ();
   my $void_message = $FALSE;
   $$COUT .= "/*Message Definitions*/\n";
   if (ref($type_order) eq "ARRAY") {
      if (@{$type_order} != 0) {
         #Iterate through all of the elements in the type hash, and add all messages (not structs)
         #to the msg_hash
         foreach (@$type_order) {
            if ($$type_hash{$_}{"ismessage"}) {
               $msg_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
            }
         }
         #Iterate through all of the messages, sorted by sequence number
         foreach my $key (sort { $msg_hash{$a}->{"sequence"} <=> $msg_hash{$b}->{"sequence"} } keys %msg_hash){
            if (defined($msg_hash{$key}{"elementlist"})) {#condense into one conditional
               if (@{$msg_hash{$key}{"elementlist"}} != 0) {
                  $tmp_out_buf .= "static const uint8_t " . $msg_hash{$key}{"identifier"} . "_data_v" .
                     $msg_hash{$key}{"version"} . "[] = {\n";
                  foreach(@{$msg_hash{$key}{"elementlist"}}){
                     c_add_msg_elms_v04(\$tmp_out_buf,$msg_hash{$key}{"identifier"},$msg_hash{$key}{"version"},$_,$inc_types,$type_hash);
                  }
                  $tmp_out_buf =~ s/,\n$//; #Strip off the last trailing comma and newline
                  #Put in the LAST_TLV keyword for the last TLV
                  #If there is more than 1 TLV, a different pattern match is necessary
                  if ($tmp_out_buf =~ /.*(,\n\n\s\s)(.*?\n.*)/) {
                     my $tmp_match;
                     while ($tmp_out_buf =~ /(,\n\n\s\s)(.*\n)/g) {
                        $tmp_match = $2;
                     }
                     #Check to see if there are multiple instances of $tmp_match
                     #(Necessary w/ the addition of the DUPLICATE type
                     my $count = 0;
                     $count++ while($tmp_out_buf =~ /\Q$tmp_match\E/g);
                     if ($count >1)
                     {
                        my @temp_array = split(/\n/,$tmp_out_buf);
                        my $match_count = 0;
                        foreach (@temp_array)
                        {
                           if ($_ =~ /$tmp_match/g)
                           {
                              $match_count++;
                              next if ($match_count != $count);
                              $_ = "  QMI_IDL_TLV_FLAGS_LAST_TLV |" . $_;
                           }
                        }
                        $tmp_out_buf = join("\n",@temp_array);
                        $tmp_out_buf .= "\n";
                     }else
                     {
                        $tmp_out_buf =~ s/(?=\Q$tmp_match\E)/QMI_IDL_TLV_FLAGS_LAST_TLV | /;
                     }
                  }else{#Only 1 TLV, easy search and replace
                     $tmp_out_buf =~ s/({\n\s\s)(.*\n)(?!.*\n\n)/$1QMI_IDL_TLV_FLAGS_LAST_TLV | $2/;
                  }

                  $$COUT .= $tmp_out_buf;
                  $$COUT .= "};\n\n";
                  $tmp_out_buf = "";
               }else{#The message is empty, do not define an empty struct, add it to the C file commented out
                  $$COUT .=<<EOF;
/*
 * $msg_hash{$key}{"identifier"} is empty
 * static const uint8_t $msg_hash{$key}{"identifier"}\_data_v$msg_hash{$key}{"version"}\[] = {
 * };
 */

EOF
               }
            }else{#The message is empty, do not define an empty struct, add it to the C file commented out
               $$COUT .=<<EOF;
/*
 * $msg_hash{$key}{"identifier"} is empty
 * static const uint8_t $msg_hash{$key}{"identifier"}\_data_v$msg_hash{$key}{"version"}\[] = {
 * };
 */

EOF
            }
         }
      }
   }
}#  c_add_messages_v04

#===========================================================================
#
#FUNCTION C_ADD_MSG_ELMS
#
#DESCRIPTION
#  Adds the message elements to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message element information filled in.
#
#===========================================================================
sub c_add_msg_elms_v04 {
   my $COUT = shift;
   my $struct_name = shift;
   my $version = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $qmi_idl_type_table_object_index=0;
   my $type_table_index=0;
   my $array_size_offset = "";
   my $type;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $tlvtype = $elm_hash->{"tlvtype"};
   my $offset16 = "";
   my $ar_offset;
   my $size_gt_8 = "";
   my $array_is_16 = $FALSE;
   my $array_is_32 = $FALSE;
   my $extended_byte = "";
   my $aggregate_type = "";
   my $array_len = "";

   if ($elm_hash->{"isduplicate"})
   {
      my $temp_ref = dclone($type_hash);
      $temp_ref = get_type_by_tlv($temp_ref,$struct_name,$elm_hash->{"isduplicate"});
      $temp_ref->{"valuedescription"} = "Duplicate of TLV #: " . $temp_ref->{"tlvtype"} . "\n";
      $temp_ref->{"tlvtype"} = $elm_hash->{"tlvtype"};
      $elm_hash = $temp_ref;
   }
   $$COUT .= "  ";
   #If the offset of this element in the structure is > 255
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
      $offset16 = "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }

   if ($elm_hash->{"n"} !~ /^\d/) {
      #Length value is a string value, must be a const, append the version number
      $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"}; #$version;
   }else{
      $array_len = $elm_hash->{"n"};
   }
   if ($elm_hash->{"islengthless"} && !$elm_hash->{"isstring"})
   {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte = "  QMI_IDL_FLAGS_ARRAY_IS_LENGTHLESS,\n";
   }
   #If the element is an array with > 255 elements
   if ($elm_hash->{"set16bitflag"}) {
      $size_gt_8 .= "QMI_IDL_FLAGS_SZ_IS_16 | ";
      $array_is_16 = $TRUE;
   }
   if ($elm_hash->{"set32bitflag"}) {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte = "  QMI_IDL_FLAGS_SZ_IS_32,\n";
      $array_is_16 = $FALSE;
      $array_is_32 = $TRUE;
   }
   my $offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   my $sz_offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isoptional"}) {
      $$COUT .= "QMI_IDL_TLV_FLAGS_OPTIONAL | ";
      $$COUT .= "($offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . ") - $offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_valid)),\n  ";
   }
   if ($elm_hash->{"isarray"}) {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }elsif ($elm_hash->{"isvararray"}) {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n  $offset - $sz_offset,\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0," .
            "\n  $offset - $sz_offset,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
      }
   }elsif ($elm_hash->{"isstring"}){
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN | $size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }else{
      $$COUT .= "$tlvtype,\n";
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}})) { #Generic type
      $type = $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}};
      $$COUT .= "  $offset16$type,\n";
   }else{ #Aggregate type
      $type = "QMI_IDL_AGGREGATE";
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},$inc_hash,$type_hash,$struct_name);
      $$COUT .= "  $offset16$type,\n";
      $aggregate_type = "  $type_table_index, $qmi_idl_type_table_object_index,\n";
   }
   $$COUT .= "$extended_byte";
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else{
      $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
}#  c_add_msg_elms_v04

#===========================================================================
#                  VESRION 5 OUTPUT ROUTINES
#===========================================================================

#===========================================================================
#
#FUNCTION C_SERVICE_OBJECT
#
#DESCRIPTION
#  Adds the service object to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_service_object_v05
{
   my $COUT = shift;
   my $service_identifier = shift;
   my $service_hash = shift;
   my $max_msg_size = shift;
   my $lib_version = shift;
   my $const_type_hash = shift;
   my $req_list = 0;
   my $resp_list = 0;
   my $ind_list = 0;
   my $req_ptr = "NULL";
   my $resp_ptr = "NULL";
   my $ind_ptr = "NULL";
   my $service_id = $$service_hash{"servicenumber"};
   my $idl_version = $$service_hash{"version"};
   my $hex_idl_version = sprintf("0x%02X",$$service_hash{"version"});
   my $minor_version = sprintf("0x%02X",$$service_hash{"minor_version"});

   $lib_version = sprintf("0x%02X",$lib_version);
   if ($service_id !~ m/^\d+/)
   {
	  if (defined($$const_type_hash{$service_id}))
	  {
		 $service_id .= "_V".$$const_type_hash{$service_id}->{"version"};
	  }
	  else
	  {
		 $service_id .= "_V$idl_version";
	  }
   }
   foreach(@{$$service_hash{"elementlist"}})
   {
      if ( ($_->{"messagetype"} eq "COMMAND") && not defined($_->{"removed"}) )
      {
         $req_list = "sizeof($service_identifier\_service_command_messages_v$idl_version)" .
            "/sizeof(qmi_idl_service_message_table_entry)";
         $req_ptr = "$service_identifier\_service_command_messages_v$idl_version";
      }elsif ( ($_->{"messagetype"} eq "RESPONSE") && not defined($_->{"removed"}) )
      {
         $resp_list = "sizeof($service_identifier\_service_response_messages_v$idl_version)" .
            "/sizeof(qmi_idl_service_message_table_entry)";
         $resp_ptr = "$service_identifier\_service_response_messages_v$idl_version";
      }elsif ( ($_->{"messagetype"} eq "INDICATION") && not defined($_->{"removed"}) )
      {
         $ind_list = "sizeof($service_identifier\_service_indication_messages_v$idl_version)" .
            "/sizeof(qmi_idl_service_message_table_entry)";
         $ind_ptr = "$service_identifier\_service_indication_messages_v$idl_version";
      }
   }

   $$COUT .=<<EOF;
/*Service Object*/
struct qmi_idl_service_object $service_identifier\_qmi_idl_service_object_v$service_hash->{"version"} = {
  $lib_version,
  $hex_idl_version,
  $service_id,
  $max_msg_size,
  { $req_list,
    $resp_list,
    $ind_list },
  { $req_ptr, $resp_ptr, $ind_ptr},
  &$service_identifier\_qmi_idl_type_table_object_v$idl_version,
  $minor_version,
  NULL
};

EOF
    #my $version = $service_hash->{"version"};
    my $uc_service = uc($service_identifier);
$$COUT .=<<"EOF";
/* Service Object Accessor */
qmi_idl_service_object_type $service_identifier\_get_service_object_internal_v$idl_version
 ( int32_t idl_maj_version, int32_t idl_min_version, int32_t library_version ){
  if ( $uc_service\_V$idl_version\_IDL_MAJOR_VERS != idl_maj_version || $uc_service\_V$idl_version\_IDL_MINOR_VERS != idl_min_version
       || $uc_service\_V$idl_version\_IDL_TOOL_VERS != library_version)
  {
    return NULL;
  }
  return (qmi_idl_service_object_type)&$service_identifier\_qmi_idl_service_object_v$idl_version;
}

EOF
}#  c_service_object_v05

#===========================================================================
#
#FUNCTION C_ADD_TYPES
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_types_v05
{
   my $COUT = shift;
   my $type_hash = shift;
   my $struct_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my %struct_hash = ();
   my $type_offset = 0;
   my $OFFSET = "QMI_IDL_OFFSET8(";
   $$COUT .= "/*Type Definitions*/\n";
   #Iterate through all of the elements in the type hash, and add all structs (not messages)
   #to the struct_hash
   if (ref($struct_order) eq "ARRAY")
   {
      if (@{$struct_order} != 0)
      {
         foreach (@$struct_order)
         {
            if ($$type_hash{$_}{"isstruct"})
            {
               $struct_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
            }
         }
         #Iterate through all of the structs, sorted by their sequence numbers
         foreach my $key (sort { $struct_hash{$a}->{"sequence"} <=> $struct_hash{$b}->{"sequence"} } keys %struct_hash){
            if (defined($struct_hash{$key}{"elementlist"}))
            {
               $$COUT .= "static const uint8_t " . $struct_hash{$key}{"identifier"} . "_data_v" .
                  $struct_hash{$key}{"version"} . "[] = {\n";
               foreach(@{$struct_hash{$key}{"elementlist"}})
               {
                  c_add_type_elms_v05($COUT,$struct_hash{$key}{"identifier"},
                                      $struct_hash{$key}{"version"},$_,$inc_types,$type_hash);
               }
               $$COUT .= "  QMI_IDL_FLAG_END_VALUE\n};\n\n";
            }else
            {#The struct is empty, do not define an empty struct, add it to the C file commented out
               $$COUT .=<<EOF;
/*
 * $struct_hash{$key}{"identifier"} is empty
 * static const uint8_t $struct_hash{$key}{"identifier"}\_data_v\$struct_hash{$key}{"version"}\[] = {
 * };
 */

EOF
            }
         }
      }
   }
}#  c_add_types_v05

#===========================================================================
#
#FUNCTION C_ADD_TYPE_ELMS
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_type_elms_v05 {
   my $COUT = shift;
   my $struct_name = shift;
   my $version_number = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $offset;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $ar_offset;
   my $sz_offset;
   my $type_table_index=0;
   my $qmi_idl_type_table_object_index=0;
   my $array_size_offset = "";
   my $size_gt_8 = "";
   my $extended_byte = "";
   my $array_is_16 = $FALSE;
   my $array_is_32 = $FALSE;
   my $aggregate_type = "";
   my $array_len = "";
   $$COUT .= "  ";
   #If the offset of this element in the structure is > 255
   if ($elm_hash->{"offset"} > $SZ_IS_32)
   {
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET32ARRAY(";
      $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_EXTENDED_OFFSET |";
   }elsif ($elm_hash->{"offset"} > $SZ_IS_16){
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
      $$COUT .= "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }

   if ($elm_hash->{"n"} !~ /^\d/) {
      #Length value is a string value, must be a const, append the version number
      $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"}; #$version_number;
   }else{
      $array_len = $elm_hash->{"n"};
   }

   if ($elm_hash->{"len_field_offset"} != 0)
   {
      $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      if ($elm_hash->{"len_field_offset"} > 0)
      {
         $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_DATA_ONLY |";
      }else
      {
         $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_LENGTH_ONLY |";
      }
   }
   if ($elm_hash->{"islengthless"} && !$elm_hash->{"isstring"})
   {
      $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_IS_LENGTHLESS |";
   }
   if ($elm_hash->{"isunsignedenum"})
   {
      $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_ENUM_IS_UNSIGNED |";
   }
   #If the element is an array with > 255 elements
   if ($elm_hash->{"set16bitflag"}) {
      $size_gt_8 .= " QMI_IDL_FLAGS_SZ_IS_16 | ";
      $array_is_16 = $TRUE;
   }
   if ($elm_hash->{"set32bitflag"}) {
      $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_SZ_IS_32 |";
      $array_is_16 = $FALSE;
      $array_is_32 = $TRUE;
   }
   $extended_byte =~ s/\|$/,\n/;
   $offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   $sz_offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isarray"}) {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY |$size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8-bit byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";      #" $offset - $sz_offset,";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";        #" $offset - $sz_offset,";
      }
   }elsif ($elm_hash->{"isvararray"}) {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN |$size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8-bit byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n  $offset - $sz_offset,\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0," .
            "\n  $offset - $sz_offset,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
      }
   }elsif ($elm_hash->{"isstring"}){
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN |$size_gt_8";
      if ($array_is_16) {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32){
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else{
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }else
   {
      $$COUT .= "$size_gt_8";
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}})) { #Generic type
      $$COUT .= $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}} . ",\n";
   }else{ #Aggregate type
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},$inc_hash,$type_hash);
      $$COUT .= " QMI_IDL_AGGREGATE,\n";
      $aggregate_type = " $type_table_index, $qmi_idl_type_table_object_index,";
   }
   $$COUT .= "$extended_byte";
   if ($elm_hash->{"offset"} > $SZ_IS_16){
      $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else{
      $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
}#  c_add_type_elms_v05

#===========================================================================
#
#FUNCTION C_ADD_MESSAGES
#
#DESCRIPTION
#  Adds the message definitions to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message information filled in.
#
#===========================================================================
sub c_add_messages_v05 {
   my $COUT = shift;
   my $type_hash = shift;
   my $type_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my $tmp_out_buf = "";
   my %msg_hash = ();
   my $void_message = $FALSE;
   $$COUT .= "/*Message Definitions*/\n";
   if (ref($type_order) eq "ARRAY") {
      if (@{$type_order} != 0) {
         #Iterate through all of the elements in the type hash, and add all messages (not structs)
         #to the msg_hash
         foreach (@$type_order) {
            if ($$type_hash{$_}{"ismessage"}) {
               $msg_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
            }
         }
         #Iterate through all of the messages, sorted by sequence number
         foreach my $key (sort { $msg_hash{$a}->{"sequence"} <=> $msg_hash{$b}->{"sequence"} } keys %msg_hash){
            if (defined($msg_hash{$key}{"elementlist"})) {#condense into one conditional
               if (@{$msg_hash{$key}{"elementlist"}} != 0) {
                  $tmp_out_buf .= "static const uint8_t " . $msg_hash{$key}{"identifier"} . "_data_v" .
                     $msg_hash{$key}{"version"} . "[] = {\n";
                  foreach(@{$msg_hash{$key}{"elementlist"}}){
                     c_add_msg_elms_v05(\$tmp_out_buf,$msg_hash{$key}{"identifier"},$msg_hash{$key}{"version"},$_,$inc_types,$type_hash);
                  }
                  $tmp_out_buf =~ s/,\n$//; #Strip off the last trailing comma and newline
                  #Put in the LAST_TLV keyword for the last TLV
                  #If there is more than 1 TLV, a different pattern match is necessary
                  if ($tmp_out_buf =~ /.*(,\n\n\s\s)(.*?\n.*)/) {
                     my $tmp_match;
                     while ($tmp_out_buf =~ /(,\n\n\s\s)(.*\n)/g) {
                        $tmp_match = $2;
                     }
                     #Check to see if there are multiple instances of $tmp_match
                     #(Necessary w/ the addition of the DUPLICATE type
                     my $count = 0;
                     $count++ while($tmp_out_buf =~ /\Q$tmp_match\E/g);
                     if ($count >1)
                     {
                        my @temp_array = split(/\n/,$tmp_out_buf);
                        my $match_count = 0;
                        foreach (@temp_array)
                        {
                           if ($_ =~ /$tmp_match/g)
                           {
                              $match_count++;
                              next if ($match_count != $count);
                              $_ = "  QMI_IDL_TLV_FLAGS_LAST_TLV |" . $_;
                           }
                        }
                        $tmp_out_buf = join("\n",@temp_array);
                        $tmp_out_buf .= "\n";
                     }else
                     {
                        $tmp_out_buf =~ s/(?=\Q$tmp_match\E)/QMI_IDL_TLV_FLAGS_LAST_TLV | /;
                     }
                  }else{#Only 1 TLV, easy search and replace
                     $tmp_out_buf =~ s/({\n\s\s)(.*\n)(?!.*\n\n)/$1QMI_IDL_TLV_FLAGS_LAST_TLV | $2/;
                  }

                  $$COUT .= $tmp_out_buf;
                  $$COUT .= "};\n\n";
                  $tmp_out_buf = "";
               }else{#The message is empty, do not define an empty struct, add it to the C file commented out
                  $$COUT .=<<EOF;
/*
 * $msg_hash{$key}{"identifier"} is empty
 * static const uint8_t $msg_hash{$key}{"identifier"}\_data_v$msg_hash{$key}{"version"}\[] = {
 * };
 */

EOF
               }
            }else{#The message is empty, do not define an empty struct, add it to the C file commented out
               $$COUT .=<<EOF;
/*
 * $msg_hash{$key}{"identifier"} is empty
 * static const uint8_t $msg_hash{$key}{"identifier"}\_data_v$msg_hash{$key}{"version"}\[] = {
 * };
 */

EOF
            }
         }
      }
   }
}#  c_add_messages_v05

#===========================================================================
#
#FUNCTION C_ADD_MSG_ELMS
#
#DESCRIPTION
#  Adds the message elements to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message element information filled in.
#
#===========================================================================
sub c_add_msg_elms_v05 {
   my $COUT = shift;
   my $struct_name = shift;
   my $version = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $qmi_idl_type_table_object_index=0;
   my $type_table_index=0;
   my $array_size_offset = "";
   my $type;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $tlvtype = $elm_hash->{"tlvtype"};
   my $offset16 = "";
   my $ar_offset;
   my $size_gt_8 = "";
   my $array_is_16 = $FALSE;
   my $array_is_32 = $FALSE;
   my $extended_byte = "";
   my $aggregate_type = "";
   my $array_len = "";

   if ($elm_hash->{"isduplicate"})
   {
      my $temp_ref = dclone($type_hash);
      $temp_ref = get_type_by_tlv($temp_ref,$struct_name,$elm_hash->{"isduplicate"});
      $temp_ref->{"valuedescription"} = "Duplicate of TLV #: " . $temp_ref->{"tlvtype"} . "\n";
      $temp_ref->{"tlvtype"} = $elm_hash->{"tlvtype"};
      $elm_hash = $temp_ref;
   }
   $$COUT .= "  ";
   #If the offset of this element in the structure is > 255
   if ($elm_hash->{"offset"} > $SZ_IS_32)
   {
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET32ARRAY(";
      $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_EXTENDED_OFFSET |";
   }elsif ($elm_hash->{"offset"} > $SZ_IS_16)
   {
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
      $offset16 = "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }

   if ($elm_hash->{"n"} !~ /^\d/)
   {
      #Length value is a string value, must be a const, append the version number
      $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"}; #$version;
   }else
   {
      $array_len = $elm_hash->{"n"};
   }
   if ($elm_hash->{"islengthless"} && !$elm_hash->{"isstring"})
   {
      $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_IS_LENGTHLESS |";
   }
   if ($elm_hash->{"isunsignedenum"})
   {
      $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_ENUM_IS_UNSIGNED |";
   }
   #If the element is an array with > 255 elements
   if ($elm_hash->{"set16bitflag"})
   {
      $size_gt_8 .= " QMI_IDL_FLAGS_SZ_IS_16 | ";
      $array_is_16 = $TRUE;
   }
   if ($elm_hash->{"set32bitflag"})
   {
      $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_SZ_IS_32 |";
      $array_is_16 = $FALSE;
      $array_is_32 = $TRUE;
   }
   $extended_byte =~ s/\|$/,\n/;
   my $offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   my $sz_offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isoptional"})
   {
      $$COUT .= "QMI_IDL_TLV_FLAGS_OPTIONAL | ";
      $$COUT .= "($offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . ") - $offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_valid)),\n  ";
   }
   if ($elm_hash->{"isarray"})
   {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY |$size_gt_8";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32)
      {
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }elsif ($elm_hash->{"isvararray"})
   {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN |$size_gt_8";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n  $offset - $sz_offset,\n";
      }elsif($array_is_32)
      {
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0," .
            "\n  $offset - $sz_offset,\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
      }
   }elsif ($elm_hash->{"isstring"})
   {
      $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN |$size_gt_8";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32)
      {
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }else
   {
      $$COUT .= "$tlvtype,\n $size_gt_8";
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}}))
   { #Generic type
      $type = $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}};
      $$COUT .= "  $offset16$type,\n";
   }else
   { #Aggregate type
      $type = "QMI_IDL_AGGREGATE";
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},$inc_hash,$type_hash,$struct_name);
      $$COUT .= "  $offset16$type,\n";
      $aggregate_type = "  $type_table_index, $qmi_idl_type_table_object_index,\n";
   }
   $$COUT .= "$extended_byte";
   if ($elm_hash->{"offset"} > $SZ_IS_16)
   {
      $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else
   {
      $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
}#  c_add_msg_elms_v05

#===========================================================================
#
#FUNCTION H_ADD_STRUCT
#
#DESCRIPTION
#  Adds struct (and message) definitions to the .h file variable
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .h file variable filled w/ struct and message information
#
#===========================================================================
sub h_add_struct_v06
{
   my $HOUT = shift;
   my $struct_hash = shift;
   my $command_info = shift;
   my $service_name = shift;
   my $struct_comment = "";
   my $struct_end_comment = "";
   my $dox_comment = "";
   my $struct_type = "";
   my $struct_desc = "";

   if ($$struct_hash->{"ismessage"})
   {
      if (defined($$command_info{$$struct_hash->{"command"}}{"BRIEF"}))
      {
         $struct_desc = $$command_info{$$struct_hash->{"command"}}{"BRIEF"};
         $struct_desc =~ s/\n*$//g;
         if (defined($$command_info{$$struct_hash->{"command"}}{"removed"}))
         {
            $struct_desc .= "\n    This Message is REMOVED using the remove options.\n";
         }
      }
      if (defined($$struct_hash->{"description"}{"TYPE"}))
      {
         $struct_type = $$struct_hash->{"description"}{"TYPE"};
         $struct_type =~ s/\s//g;
      }
      $struct_comment = "/** " . $struct_type .
         " Message; " . $struct_desc . " */\n";
      $struct_end_comment = "  /* Message */\n";
      $dox_comment = "/** \@addtogroup $service_name\_qmi_messages\n    \@{\n  */\n";
   }else
   {
     if (defined($$struct_hash->{"typedescription"}))
     {
       $struct_comment .= "/** " . $$struct_hash->{"typedescription"} . " */\n";
     }
      $struct_end_comment = "  /* Type */\n";
      $dox_comment = "/** \@addtogroup $service_name\_qmi_aggregates\n    \@{\n  */\n";
   }
   $$HOUT .= $dox_comment;
   $$HOUT .= "$struct_comment";
   if (defined($$struct_hash->{"elementlist"}) && scalar(@{$$struct_hash->{"elementlist"}}) > 0)
   {
      $$HOUT .= "typedef struct {\n";
      $$HOUT .= h_add_struct_elms_v01($struct_hash,1);
      #$$HOUT =~ s/\n\n$/\n/;
      $$HOUT .= "}" . $$struct_hash->{"identifier"} . "_v" . $$struct_hash->{"version"} . "\;";
   }else
   {
      $$HOUT .=<<EOF;
typedef struct {
  /* This element is a placeholder to prevent the declaration of
     an empty struct.  DO NOT USE THIS FIELD UNDER ANY CIRCUMSTANCE */
  char __placeholder;
}$$struct_hash->{"identifier"}\_v$$struct_hash->{"version"}\;

EOF
   }
   $$HOUT .= $struct_end_comment;
   $$HOUT .= "/**\n    \@}\n  */\n\n";
   return;
}#  h_add_struct_v06

#===========================================================================
#
#FUNCTION C_RANGE_TABLE
#
#DESCRIPTION
#  Adds the type table to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_range_table_v06
{
   my $COUT = shift;
   my $range_array = shift;
   #my $type_hash = shift;
   #my $struct_order = shift;
   my $service_identifier = shift;
   my $service_version = shift;
   my $version;
   my $num_ranges = 0;
   my $i = 0;
   my %struct_hash = ();
   $$COUT .= "/* Range Table */\n";

   if (ref($range_array) eq "ARRAY")
   {
      if (@{$range_array} != 0)
      {
        $$COUT .= "static const qmi_idl_range_table_entry  " . $service_identifier . "_range_table_v"
          . $service_version . "[] = {\n";
         foreach (@$range_array)
         {
           $$COUT .= "  {&" . $_->{"rangeCheckName"} . "_range_data_v" . $service_version . "},\n";
           $num_ranges++;
         }

         $$COUT =~ s/,\n$/\n/; #Strip off the last trailing comma from the type table
         $$COUT .= "};\n\n";
      }else
      {
        $$COUT .= "/* No Ranges Defined in IDL */\n\n";
      }
   }
   return $num_ranges;
}#  c_range_table_v06

#===========================================================================
#
#FUNCTION C_MESSAGE_TABLE
#
#DESCRIPTION
#  Adds the type table to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_message_table_v06
{
   my $IS_COMMON_FILE = $type_hash{"common_file"};
   my $COUT = shift;
   my $type_hash = shift;
   my $struct_order = shift;
   my $service_identifier = shift;
   my $service_version = shift;
   my $version;
   my $num_msgs = 0;
   my $index = 0;
   my %message_hash = ();
   $$COUT .= "/* Message Table */\n";
   if (ref($struct_order) eq "ARRAY")
   {
      if (@{$struct_order} != 0)
      {#CONDENSE CONDITIONAL
         foreach (@$struct_order)
         {
            if ($$type_hash{$_}{"ismessage"} && ( ($$type_hash{$_}{"refCnt"} != 0) || $IS_COMMON_FILE ) )
            {
               $message_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
               $num_msgs++;
            }
         }
         if ($num_msgs > 0)
         {
            $$COUT .= "static const qmi_idl_message_table_entry " . $service_identifier
               . "_message_table_v" . $service_version . "[] = {\n";
         }else
         {
            $$COUT .= "/* No Messages Defined in IDL */\n\n";
         }
         foreach my $key (sort { $message_hash{$a}->{"sequence"} <=> $message_hash{$b}->{"sequence"} } keys %message_hash){
            $version = $message_hash{$key}{"version"};
            #FIRST TIME THROUGH CONDITIONAL
            if (scalar(@{$message_hash{$key}{"elementlist"}}) > 0)
            {
               $$COUT .= "  {sizeof(" . $message_hash{$key}{"identifier"}
               . "_v$version), " . $message_hash{$key}{"identifier"} . "_data_v$version},\n";
            }else
            {
               $$COUT .= "  {sizeof(" . $message_hash{$key}{"identifier"}
               . "_v$version), 0},\n";
            }
            $$type_hash{$key}{"sequence"} = $index;
            $index++;
         }
         if ($num_msgs > 0)
         {
            $$COUT =~ s/,\n$/\n/; #Strip off the last trailing comma from the message table
            $$COUT .= "};\n\n";
         }
      }
   }
   return $num_msgs;
}#  c_message_table_v06

#===========================================================================
#
#FUNCTION C_TYPE_TABLE_OBJECT
#
#DESCRIPTION
#  Adds the type table object to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_type_table_object_v06
{
   my $COUT = shift;
   #my $service_identifier = shift;
   my $inc_type_order = shift;
   my $service_hash = shift;
   my $num_types = shift;
   my $num_msgs = shift;
   my $num_ranges = shift;
   my $service_identifier = $$service_hash{"identifier"};
   my $service_version = $$service_hash{"version"};
   my $static_keyword = "const";

   my $type_size = "0";
   my $msg_size = "0";
   my $type_pointer = "NULL";
   my $msg_pointer = "NULL";
   my $range_pointer = "NULL";
   if ($num_ranges != 0)
   {
     $range_pointer = "$service_identifier\_range_table_v$service_version";
   }
   if ($num_types != 0)
   {
      $type_size = "sizeof($service_identifier\_type_table_v$service_version)/sizeof(qmi_idl_type_table_entry )";
      $type_pointer = "$service_identifier\_type_table_v$service_version";
   }
   if ($num_msgs != 0)
   {
      $msg_size = "sizeof($service_identifier\_message_table_v$service_version)/sizeof(qmi_idl_message_table_entry)";
      $msg_pointer = "$service_identifier\_message_table_v$service_version";
   }

   $static_keyword = "static const" if (defined($$service_hash{"servicenumber"}));
   my $referenced_tables = "{&$service_identifier\_qmi_idl_type_table_object_v$service_version";
   if (ref($inc_type_order) eq "ARRAY")
   {
      foreach(@{$inc_type_order})
      {
         my $idlname = basename($_,".idl");
         my $include_version = "";
         $idlname =~ m/(.*)(_v\d\d)/;
         $idlname = $1;
         $include_version = $2;
         $referenced_tables .= ", &$idlname\_qmi_idl_type_table_object$include_version";
      }
   }
   $referenced_tables .= "};";
   $$COUT .=<<EOF;
/* Predefine the Type Table Object */
$static_keyword qmi_idl_type_table_object $service_identifier\_qmi_idl_type_table_object_v$service_version\;

/*Referenced Tables Array*/
static const qmi_idl_type_table_object *$service_identifier\_qmi_idl_type_table_object_referenced_tables_v$service_version\[] =
$referenced_tables

/*Type Table Object*/
$static_keyword qmi_idl_type_table_object $service_identifier\_qmi_idl_type_table_object_v$service_version = {
  $type_size,
  $msg_size,
  1,
  $type_pointer,
  $msg_pointer,
  $service_identifier\_qmi_idl_type_table_object_referenced_tables_v$service_version,
  $range_pointer
};

EOF
}#  c_type_table_object_v06
#===========================================================================
#
#FUNCTION C_ADD_TYPES
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_types_v06
{
   my $IS_COMMON_FILE = $type_hash{"common_file"};
   my $COUT = shift;
   my $type_hash = shift;
   my $struct_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my %struct_hash = ();
   my $type_offset = 0;
   my $OFFSET = "QMI_IDL_OFFSET8(";
   $$COUT .= "/*Type Definitions*/\n";
   #Iterate through all of the elements in the type hash, and add all structs (not messages)
   #to the struct_hash
   if (ref($struct_order) eq "ARRAY")
   {
      if (@{$struct_order} != 0)
      {
         foreach (@$struct_order)
         {
            if ( $$type_hash{$_}{"isstruct"} && ( ($$type_hash{$_}{"refCnt"} != 0) || $IS_COMMON_FILE ) )
            {
               $struct_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
            }
         }
         #Iterate through all of the structs, sorted by their sequence numbers
         foreach my $key (sort { $struct_hash{$a}->{"sequence"} <=> $struct_hash{$b}->{"sequence"} } keys %struct_hash){
            if (defined($struct_hash{$key}{"elementlist"}))
            {
               $$COUT .= "static const uint8_t " . $struct_hash{$key}{"identifier"} . "_data_v" .
                  $struct_hash{$key}{"version"} . "[] = {\n";
               foreach(@{$struct_hash{$key}{"elementlist"}})
               {
                  c_add_type_elms_v06($COUT,$struct_hash{$key}{"identifier"},
                                      $struct_hash{$key}{"version"},$_,$inc_types,$type_hash);
               }
               $$COUT .= "  QMI_IDL_FLAG_END_VALUE\n};\n\n";
            }else
            {#The struct is empty, do not define an empty struct, add it to the C file commented out
               $$COUT .=<<EOF;
/*
 * $struct_hash{$key}{"identifier"} is empty
 * static const uint8_t $struct_hash{$key}{"identifier"}\_data_v\$struct_hash{$key}{"version"}\[] = {
 * };
 */

EOF
            }
         }
      }
   }
}#  c_add_types_v06

#===========================================================================
#
#FUNCTION C_ADD_TYPE_ELMS
#
#DESCRIPTION
#  Adds the type definition arrays to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has type data array information filled in.
#
#===========================================================================
sub c_add_type_elms_v06 {
   my $COUT = shift;
   my $struct_name = shift;
   my $version_number = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $offset;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $ar_offset;
   my $sz_offset;
   my $type_table_index=0;
   my $qmi_idl_type_table_object_index=0;
   my $array_size_offset = "";
   my $size_gt_8 = "";
   my $size_gt_16 = "";
   my $extended_byte = "";
   my $third_flag_byte = "";
   my $array_is_16 = $FALSE;
   my $array_is_32 = $FALSE;
   my $aggregate_type = "";
   my $array_len = "";
   $$COUT .= "  ";
   #If the offset of this element in the structure is > 255
   if ($elm_hash->{"offset"} > $SZ_IS_32)
   {
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET32ARRAY(";
      $size_gt_8 = "  QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_EXTENDED_OFFSET |";
   }elsif ($elm_hash->{"offset"} > $SZ_IS_16)
   {
      $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
      $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
      $$COUT .= "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }
   if ($elm_hash->{"rangeChecked"})
   {
     $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
     $extended_byte .= "  QMI_IDL_FLAGS_SECOND_EXTENDED |";
     $third_flag_byte .= "  QMI_IDL_FLAGS_RANGE_CHECKED |";
   }
   if ($elm_hash->{"n"} !~ /^\d/)
   {
      #Length value is a string value, must be a const, append the version number
      $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"}; #$version_number;
   }else
   {
      $array_len = $elm_hash->{"n"};
   }

   if ($elm_hash->{"primitivetype"} eq "string16")
   {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_UTF16_STRING |";
   }
   if ($elm_hash->{"len_field_offset"} != 0)
   {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      if ($elm_hash->{"len_field_offset"} > 0)
      {
         $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_DATA_ONLY |";
      }else
      {
         $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_LENGTH_ONLY |";
      }
   }
   if ($elm_hash->{"islengthless"} && !$elm_hash->{"isstring"})
   {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_IS_LENGTHLESS |";
   }
   if ($elm_hash->{"isunsignedenum"})
   {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_ENUM_IS_UNSIGNED |";
   }
   #If the element is an array with > 255 elements
   if ($elm_hash->{"set16bitflag"})
   {
      $size_gt_8 .= " QMI_IDL_FLAGS_SZ_IS_16 | ";
      $array_is_16 = $TRUE;
   }
   if ($elm_hash->{"set32bitflag"})
   {
      $size_gt_8 = "QMI_IDL_FLAGS_FIRST_EXTENDED | ";
      $extended_byte .= "  QMI_IDL_FLAGS_SZ_IS_32 |";
      $array_is_16 = $FALSE;
      $array_is_32 = $TRUE;
   }
   $extended_byte =~ s/\s*\|$/,\n/;
   $third_flag_byte =~ s/\s*\|$/,\n/;
   $offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   $sz_offset = "$offset_val$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version_number, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isarray"})
   {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY |$size_gt_8";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8-bit byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";      #" $offset - $sz_offset,";
      }elsif($array_is_32)
      {
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n";        #" $offset - $sz_offset,";
      }
   }elsif ($elm_hash->{"isvararray"})
   {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN |$size_gt_8";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8-bit byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n  $offset - $sz_offset,\n";
      }elsif($array_is_32)
      {
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0," .
            "\n  $offset - $sz_offset,\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
      }
   }elsif ($elm_hash->{"isstring"})
   {
      $$COUT .= "QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN |$size_gt_8";
      if ($array_is_16)
      {
         #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
      }elsif($array_is_32)
      {
         $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
      }else
      {
         $array_size_offset = "  " . $array_len . ",\n";
      }
   }else
   {
      $$COUT .= "$size_gt_8";
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}}))
   { #Generic type
      $$COUT .= $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}} . ",\n";
   }else
   { #Aggregate type
      ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},$inc_hash,$type_hash);
      $$COUT .= "QMI_IDL_AGGREGATE,\n";
      $aggregate_type = "  QMI_IDL_TYPE88($qmi_idl_type_table_object_index, $type_table_index),";
   }
   $$COUT .= "$extended_byte$third_flag_byte";
   if ($elm_hash->{"offset"} > $SZ_IS_16)
   {
      $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else
   {
      $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
   if ($elm_hash->{"rangeChecked"})
   {
     $$COUT =~ s/\n\n$/\n/;
     $$COUT .=<<EOF;
  (uint32_t)$elm_hash->{"rangerorder"} & 0xFF,
  ((uint32_t)$elm_hash->{"rangerorder"} >> 8) & 0xFF,
  ((uint32_t)$elm_hash->{"rangerorder"} >> 16) & 0xFF,
  ((uint32_t)$elm_hash->{"rangerorder"} >> 24) & 0xFF,

EOF
   }
}#  c_add_type_elms_v06

#===========================================================================
#
#FUNCTION C_ADD_MESSAGES
#
#DESCRIPTION
#  Adds the message definitions to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message information filled in.
#
#===========================================================================
sub c_add_messages_v06 {
   my $IS_COMMON_FILE = $type_hash{"common_file"};
   my $COUT = shift;
   my $type_hash = shift;
   my $type_order = shift;
   my $inc_types = shift;
   my $inc_order = shift;
   my $tmp_out_buf = "";
   my %msg_hash = ();
   my $void_message = $FALSE;
   $$COUT .= "/*Message Definitions*/\n";
   if (ref($type_order) eq "ARRAY")
   {
     if (@{$type_order} != 0)
     {
       #Iterate through all of the elements in the type hash, and add all messages (not structs)
       #to the msg_hash
       foreach (@$type_order)
       {
         if ($$type_hash{$_}{"ismessage"} && ( ($$type_hash{$_}{"refCnt"} != 0) || $IS_COMMON_FILE ) )
         {
           $msg_hash{$$type_hash{$_}{"identifier"}} = $$type_hash{$_};
         }
       }
       #Iterate through all of the messages, sorted by sequence number
       foreach my $key (sort { $msg_hash{$a}->{"sequence"} <=> $msg_hash{$b}->{"sequence"} } keys %msg_hash)
       {
         if (defined($msg_hash{$key}{"elementlist"})
             && scalar(@{$msg_hash{$key}{"elementlist"}}) > 0)
         {
           $tmp_out_buf .= "static const uint8_t " . $msg_hash{$key}{"identifier"} . "_data_v" .
             $msg_hash{$key}{"version"} . "[] = {\n";
           foreach(@{$msg_hash{$key}{"elementlist"}})
           {
                c_add_msg_elms_v06(\$tmp_out_buf,$msg_hash{$key}{"identifier"},$msg_hash{$key}{"version"},
                $_,$inc_types,$type_hash);
           }
           $tmp_out_buf =~ s/,\n$//; #Strip off the last trailing comma and newline
           #Put in the LAST_TLV keyword for the last TLV
           #If there is more than 1 TLV, a different pattern match is necessary
           if ($tmp_out_buf =~ /.*(,\n\n)(.*?\n.*)/)
           {
             my $tmp_match;
             while ($tmp_out_buf =~ /(,\n\n\s\s)(.*\n)/g)
             {
               $tmp_match = $2;
             }
             #Check to see if there are multiple instances of $tmp_match
             #(Necessary w/ the addition of the DUPLICATE type
             my $count = 0;
             $count++ while($tmp_out_buf =~ /\Q$tmp_match\E/g);
             if ($count >1)
             {
               my @temp_array = split(/\n/,$tmp_out_buf);
               my $match_count = 0;
               foreach (@temp_array)
               {
                 if ($_ =~ /$tmp_match/g)
                 {
                   $match_count++;
                   next if ($match_count != $count);
                   $_ = "  QMI_IDL_TLV_FLAGS_LAST_TLV |" . $_;
                 }
               }
               $tmp_out_buf = join("\n",@temp_array);
               $tmp_out_buf .= "\n";
             }else
             {
               $tmp_out_buf =~ s/(?=\Q$tmp_match\E)/QMI_IDL_TLV_FLAGS_LAST_TLV | /;
             }
           }else{#Only 1 TLV, easy search and replace
             $tmp_out_buf =~ s/({\n\s\s)(.*\n)(?!.*\n\n)/$1QMI_IDL_TLV_FLAGS_LAST_TLV | $2/;
           }

           $$COUT .= $tmp_out_buf;
           $$COUT .= "};\n\n";
           $tmp_out_buf = "";
         }else
         {#The message is empty, do not define an empty struct, add it to the C file commented out
           $$COUT .=<<EOF;
/*
 * $msg_hash{$key}{"identifier"} is empty
 * static const uint8_t $msg_hash{$key}{"identifier"}\_data_v$msg_hash{$key}{"version"}\[] = {
 * };
 */

EOF
         }
       }
     }
   }
}#  c_add_messages_v06

#===========================================================================
#
#FUNCTION C_ADD_MSG_ELMS
#
#DESCRIPTION
#  Adds the message elements to the C file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable has message element information filled in.
#
#===========================================================================
sub c_add_msg_elms_v06 {
   my $COUT = shift;
   my $struct_name = shift;
   my $version = shift;
   my $elm_hash = shift;
   my $inc_hash = shift;
   my $type_hash = shift;
   my $qmi_idl_type_table_object_index=0;
   my $type_table_index=0;
   my $array_size_offset = "";
   my $type;
   my $offset_val = "QMI_IDL_OFFSET8(";
   my $tlvtype = $elm_hash->{"tlvtype"};
   my $offset16 = "";
   my $ar_offset;
   my $size_gt_8 = "";
   my $array_is_16 = $FALSE;
   my $array_is_32 = $FALSE;
   my $extended_byte = "";
   my $third_flag_byte = "";
   my $aggregate_type = "";
   my $array_len = "";

   if ($elm_hash->{"isduplicate"})
   {
     my $temp_ref = dclone($type_hash);
     $temp_ref = get_type_by_tlv($temp_ref,$struct_name,$elm_hash->{"isduplicate"});
     $temp_ref->{"valuedescription"} = "Duplicate of TLV #: " . $temp_ref->{"tlvtype"} . "\n";
     $temp_ref->{"tlvtype"} = $elm_hash->{"tlvtype"};
     $elm_hash = $temp_ref;
   }
   $$COUT .= "  ";
   #If the offset of this element in the structure is > 255
   if ($elm_hash->{"offset"} > $SZ_IS_32)
   {
     $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
     $ar_offset = "QMI_IDL_OFFSET32ARRAY(";
     $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
     $extended_byte .= "  QMI_IDL_FLAGS_EXTENDED_OFFSET |";
   }elsif ($elm_hash->{"offset"} > $SZ_IS_16)
   {
     $offset_val = "QMI_IDL_OFFSET16RELATIVE(";
     $ar_offset = "QMI_IDL_OFFSET16ARRAY(";
     $offset16 = "QMI_IDL_FLAGS_OFFSET_IS_16 | ";
   }
   if ($elm_hash->{"rangeChecked"})
   {
     $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
     $extended_byte .= "  QMI_IDL_FLAGS_SECOND_EXTENDED |";
     $third_flag_byte .= "  QMI_IDL_FLAGS_RANGE_CHECKED |";
   }
   if ($elm_hash->{"n"} !~ /^\d/)
   {
     #Length value is a string value, must be a const, append the version number
     $array_len = $elm_hash->{"n"} . "_V" . $$CONST_HASH{$elm_hash->{"n"}}{"version"}; #$version;
   }else
   {
     $array_len = $elm_hash->{"n"};
   }
   if ($elm_hash->{"primitivetype"} eq "string16")
   {
     $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
     $extended_byte .= "  QMI_IDL_FLAGS_UTF16_STRING |";
   }
   if ($elm_hash->{"islengthless"} && !$elm_hash->{"isstring"})
   {
     $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
     $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_IS_LENGTHLESS |";
   }
   if ($elm_hash->{"isunsignedenum"})
   {
     $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
     $extended_byte .= "  QMI_IDL_FLAGS_ENUM_IS_UNSIGNED |";
   }
   if ($elm_hash->{"islengthless"} && !$elm_hash->{"isstring"})
   {
     $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
     $extended_byte .= "  QMI_IDL_FLAGS_ARRAY_IS_LENGTHLESS |";
   }
   #If the element is an array with > 255 elements
   if ($elm_hash->{"set16bitflag"})
   {
     $size_gt_8 .= " QMI_IDL_FLAGS_SZ_IS_16 | ";
     $array_is_16 = $TRUE;
   }
   if ($elm_hash->{"set32bitflag"})
   {
     $size_gt_8 = " QMI_IDL_FLAGS_FIRST_EXTENDED | ";
     $extended_byte .= "  QMI_IDL_FLAGS_SZ_IS_32 |";
     $array_is_16 = $FALSE;
     $array_is_32 = $TRUE;
   }
   $extended_byte =~ s/\s*\|$/,\n/;
   $third_flag_byte =~ s/\s*\|$/,\n/;
   my $offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   my $sz_offset = "$offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_len)";
   $ar_offset .= "$struct_name\_v$version, " . $elm_hash->{"identifier"} . ")";
   #Arrays, Variable Arrays, and Strings all have different values that need to be added to the structure
   if ($elm_hash->{"isoptional"})
   {
     $$COUT .= "QMI_IDL_TLV_FLAGS_OPTIONAL | ";
     $$COUT .= "($offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} .
       ") - $offset_val$struct_name\_v$version, " . $elm_hash->{"identifier"} . "_valid)),\n  ";
   }
   if ($elm_hash->{"isarray"})
   {
     $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY |$size_gt_8";
     if ($array_is_16)
     {
       #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
       $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
     }elsif($array_is_32)
     {
       $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
     }else
     {
       $array_size_offset = "  " . $array_len . ",\n";
     }
   }elsif ($elm_hash->{"isvararray"})
   {
     $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN |$size_gt_8";
     if ($array_is_16)
     {
       #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
       $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len .
         ") >> 8),\n  $offset - $sz_offset,\n";
     }elsif($array_is_32)
     {
       $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0," .
         "\n  $offset - $sz_offset,\n";
     }else
     {
       $array_size_offset = "  " . $array_len . ",\n  $offset - $sz_offset,\n";
     }
   }elsif ($elm_hash->{"isstring"})
   {
     $$COUT .= "$tlvtype,\n  QMI_IDL_FLAGS_IS_ARRAY | QMI_IDL_FLAGS_IS_VARIABLE_LEN |$size_gt_8";
     if ($array_is_16)
     {
       #The N value of the arrays is stored in 2 8 byte values, low byte followed by high byte
       $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8),\n";
     }elsif($array_is_32)
     {
       $array_size_offset = "  ((" . $array_len . ") & 0xFF), ((" . $array_len . ") >> 8), 0, 0,\n";
     }else
     {
       $array_size_offset = "  " . $array_len . ",\n";
     }
   }else
   {
     $$COUT .= "$tlvtype,\n $size_gt_8";
   }
   if (defined($type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}}))
   { #Generic type
     $type = $type_hash{"idltype_to_type_array"}->{$elm_hash->{"type"}};
     $$COUT .= "  $offset16$type,\n";
   }else
   { #Aggregate type
     $type = "QMI_IDL_AGGREGATE";
     ($type_table_index, $qmi_idl_type_table_object_index) = get_type_index($elm_hash->{"type"},
     $inc_hash,$type_hash,$struct_name);
     $$COUT .= "  $offset16$type,\n";
     $aggregate_type = "  QMI_IDL_TYPE88($qmi_idl_type_table_object_index, $type_table_index),\n";
   }
   $$COUT .= "$extended_byte$third_flag_byte";
   if ($elm_hash->{"offset"} > $SZ_IS_16)
   {
     $$COUT .= "  $ar_offset\,\n$array_size_offset$aggregate_type\n";
   }else
   {
     $$COUT .= "  $offset\,\n$array_size_offset$aggregate_type\n";
   }
   if ($elm_hash->{"rangeChecked"} == $TRUE)
   {
     $$COUT =~ s/\n\n$/\n/;
     $$COUT .= "  (uint32_t)$elm_hash->{'rangerorder'} & 0xFF,\n";
     $$COUT .= "  ((uint32_t)$elm_hash->{'rangerorder'} >> 8) & 0xFF,\n";
     $$COUT .= "  ((uint32_t)$elm_hash->{'rangerorder'} >> 16) & 0xFF,\n";
     $$COUT .= "  ((uint32_t)$elm_hash->{'rangerorder'} >> 24) & 0xFF,\n\n";
   }
}#  c_add_msg_elms_v06

sub c_add_ranges_v06
{
  my $COUT = shift;
  my $range_array = shift;
  my $version = shift;
  my $range_elm;
  if (ref($range_array) eq "ARRAY")
  {
    if (@{$range_array} != 0)
    {
      foreach $range_elm (@{$range_array})
      {
        my $min_vals = "";
        my $max_vals = "";
        my $error_response_code;
        my $type = $range_elm->{"primitivetype"};
        my $primitive_type = ($range_elm->{"rangechecktype"} eq "QMI_IDL_RANGE_ENUM") ?
          "uint32_t" : $type_hash{"idltype_to_ctype"}{$$range_elm{"primitivetype"}};
        if ($$range_elm{"rangecheckresponse"} eq "QMI_IDL_RANGE_RESPONSE_IGNORE")
          {
            $error_response_code = "return QMI_IDL_RANGE_RESPONSE_IGNORE;";
          }elsif($$range_elm{"rangecheckresponse"} eq "QMI_IDL_RANGE_RESPONSE_DEFAULT")
          {
            $error_response_code = "*(" . $primitive_type .  " *)val = " .
              $$range_elm{"rangecheckerrorvalue"} . ";\n  return QMI_IDL_RANGE_RESPONSE_DEFAULT;";
          }elsif($$range_elm{"rangecheckresponse"} eq "QMI_IDL_RANGE_RESPONSE_ERROR")
          {
            $error_response_code = "return " . $$range_elm{"rangecheckerrorvalue"} . ";";
          }
        $$COUT .= "static int8_t " . $range_elm->{"rangeCheckName"} . "_range_data_v" .
          $version . "(void *val)\n{\n";
        if ($range_elm->{"rangechecktype"} eq "QMI_IDL_RANGE_ENUM")
        {
          my @range_array = @{$range_elm->{"rangevalues"}};
          my $num_ranges = @range_array;
          my $end_range = 1;
          foreach(@range_array)
          {
            if ($end_range != $num_ranges)
            {
              $min_vals .= "    " . $$_{"min"} . ",\n";
              $max_vals .= "    " . $$_{"max"} . ",\n";
            }else
            {
              $min_vals .= "    " . $$_{"min"};
              $max_vals .= "    " . $$_{"max"};
            }
            $end_range++;
          }
          $$COUT .= "  uint8_t len = $num_ranges;\n";
          $$COUT .= "  int32_t min_val[] = {\n$min_vals};\n";
          $$COUT .= "  int32_t max_val[] = {\n$min_vals};\n\n";
          $$COUT .=<<EOF;
  int8_t i;

  for (i=0;i<len;i++)
  {
    if ( *(uint32_t *)val >= min_val[i] &&
         *(uint32_t *)val <= max_val[i])
    {
      return QMI_IDL_RANGE_RESPONSE_SUCCESS;
    }
  }
  /* Range check unsuccessful, handle error condition */
  $error_response_code
}

EOF
        }elsif($range_elm->{"rangechecktype"} eq "QMI_IDL_RANGE_MASK")
        {
          $$COUT .= "  *(uint64_t*)val &= " . $range_elm->{"rangevalues"} . ";\n";
          $$COUT .= "  return QMI_IDL_RANGE_RESPONSE_SUCCESS;\n}\n\n";
        }else
        {
          my @range_array = @{$range_elm->{"rangevalues"}};
          my $num_ranges = @range_array;
          my $end_range = 1;
          my %map = ("QMI_IDL_GENERIC_1_BYTE", "0xFF",
            "QMI_IDL_GENERIC_2_BYTE", "0xFFFF",
            "QMI_IDL_GENERIC_4_BYTE", "0xFFFFFFFF",
            "QMI_IDL_GENERIC_8_BYTE", "0xFFFFFFFFFFFFFFFFull");
          my $i;
          #my $primitive_type = $map_hash{"idltype_to_ctype"}{$$range_elm{"primitivetype"}};
          $num_ranges = $num_ranges / 2;
          for ($i=0;$i<$num_ranges;$i++)
          {
            if ($range_array[$i*2] eq "INF")
            {
              $range_array[$i*2] = $map{$$range_elm{"rangeSize"}};
            }
            if ($range_array[$i*2+1] eq "INF")
            {
              $range_array[$i*2+1] = $map{$$range_elm{"rangeSize"}};
            }
            if ($end_range != $num_ranges)
            {
              $min_vals .= "    " . $range_array[$i*2] . ",\n";
              $max_vals .= "    " . $range_array[($i*2)+1] . ",\n";
            }else
            {
              $min_vals .= "    " . $range_array[$i*2];
              $max_vals .= "    " . $range_array[($i*2)+1];
            }
            $end_range++;
          }

          $$COUT .=<<EOF
  uint8_t len = $num_ranges;
  int8_t i;
  $primitive_type min_val[] = {
  $min_vals};
  $primitive_type max_val[] = {
  $max_vals};

  for (i=0;i<len;i++)
  {
    if (min_val[i] == $map{$$range_elm{"rangeSize"}})
    {
      if(*($primitive_type *)val <= max_val[i])
      {
        return QMI_IDL_RANGE_RESPONSE_SUCCESS;
      }
    }else if(max_val[i] == $map{$$range_elm{"rangeSize"}})
    {
      if(*($primitive_type *)val >= min_val[i])
      {
        return QMI_IDL_RANGE_RESPONSE_SUCCESS;
      }
    }else if (*($primitive_type *)val >= min_val[i] &&
             (*($primitive_type *)val <= max_val[i]))
    {
      return QMI_IDL_RANGE_RESPONSE_SUCCESS;
    }
  }
  /* Range check unsuccessful, handle error condition */
  $error_response_code
}

EOF
        }
      }
    }
  }
}#  c_add_ranges_v06

sub populate_split_h_file_v06
{
  my $OUTPUT_VERSION = shift;
  my $HOUT = shift;
  my $SHOUT = shift;
  my $base_name = shift;
  my $type_hash = shift;
  my $copyright = shift;
  my $p4info = shift;

  my $include_files = $$type_hash{"include_files"};
  my $include_types = $$type_hash{"include_types"};
  my $const_hash = $$type_hash{"const_hash"};
  my $const_order = $$type_hash{"const_order"};
  my $user_type_hash = $$type_hash{"user_types"};
  my $user_type_order = $$type_hash{"user_types_order"};
  my $service_hash = $$type_hash{"service_hash"};
  my $typedef_hash = $$type_hash{"typedef_hash"};
  my $typedef_order = $$type_hash{"typedef_order"};
  my $command_info = $$type_hash{"command_documentation"};
  my $VERSION = $$type_hash{"service_hash"}->{"version"};
  my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
  my $MINOR_VERSION = $$type_hash{"service_hash"}->{"minor_version"};
  my $MAX_MSG_SIZE = $$type_hash{"max_msg_size"};
  my $MAX_MSG_ID = defined($$type_hash{"service_hash"}->{"max_msg_id"}) ?
    $$type_hash{"service_hash"}->{"max_msg_id"} : $INVALID_MSG_ID;

  my $dec_out_version = hex($OUTPUT_VERSION);
  my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);
  my $inc_files;
  if (defined($include_files))
  {
    $inc_files = dclone($include_files);
  }
  #Call the appropriate output functions to populate the output file variables
  h_init_v01($HOUT,$$service_hash{"identifier"},$base_name,$VERSION,$MINOR_VERSION,
             $MAX_MSG_SIZE,$copyright,$p4info,$MAX_MSG_ID,$dec_out_version,$spin_number);
  sh_init_v06($SHOUT,$$service_hash{"identifier"},$base_name,$VERSION,$MINOR_VERSION,
             $MAX_MSG_SIZE,$copyright,$p4info,$MAX_MSG_ID,$dec_out_version,$spin_number);
  $base_name .= ".h";
  $base_name =~ s/(\_v\d\d)/_types$1/;
  $$HOUT =~ s/(<INCLUDEFILES>)/$1#include \"$base_name\"\n/;
  add_includes_v01($HOUT,$inc_files,$include_types);
  foreach (@{$inc_files})
  {
    $_ =~ s/(\_v\d\d)/_types$1/;
  }
  add_includes_v01($SHOUT,$inc_files,$include_types);

  h_add_consts_v01($SHOUT,$const_hash,$const_order,$$service_hash{"version"},$$service_hash{"identifier"});
  h_add_typedef_v01($SHOUT,$typedef_hash,$typedef_order);

  if (ref($user_type_order) eq "ARRAY")
  {
    if (@{$user_type_order} != 0)
    {
      foreach (@$user_type_order)
      {
        if ($$user_type_hash{$_}{"isenum"})
        {
          h_add_enum_v01($SHOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
        }elsif ($$user_type_hash{$_}{"ismask"})
        {
          h_add_mask_v01($SHOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
        }elsif ($$user_type_hash{$_}{"isstruct"})
        {
          h_add_struct_v06($SHOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
        }elsif ($$user_type_hash{$_}{"ismessage"})
        {
          h_add_struct_v06($SHOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
        }
      }
    }
  }

  if (defined($$service_hash{"servicenumber"}))
  {
    h_add_split_service_v06($HOUT,$SHOUT,$service_hash);
  }else
  {
    h_add_externs_v01($HOUT,$$service_hash{"identifier"},$$service_hash{"version"});
  }
  $$SHOUT .=<<"EOF";

#ifdef __cplusplus
}
#endif
#endif

EOF
  $$HOUT .=<<"EOF";

#ifdef __cplusplus
}
#endif
#endif

EOF
}

sub populate_h_file_v06
{
   my $OUTPUT_VERSION = shift;
   my $HOUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $REMOVE_MESSAGES_TEXT = prepare_remove_msgs();
   my $include_files = $$type_hash{"include_files"};
   my $include_types = $$type_hash{"include_types"};
   my $const_hash = $$type_hash{"const_hash"};
   my $const_order = $$type_hash{"const_order"};
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $typedef_hash = $$type_hash{"typedef_hash"};
   my $typedef_order = $$type_hash{"typedef_order"};
   my $command_info = $$type_hash{"command_documentation"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $MINOR_VERSION = $$type_hash{"service_hash"}->{"minor_version"};
   my $MAX_MSG_SIZE = $$type_hash{"max_msg_size"};
   my $MAX_MSG_ID = defined($$type_hash{"service_hash"}->{"max_msg_id"}) ?
      $$type_hash{"service_hash"}->{"max_msg_id"} : $INVALID_MSG_ID;

   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);
   #Call the appropriate output functions to populate the output file variables
   h_init_v01($HOUT,$$service_hash{"identifier"},$base_name,$VERSION,$MINOR_VERSION,
          $MAX_MSG_SIZE,$copyright,$p4info,$MAX_MSG_ID,$dec_out_version,$spin_number);
   add_includes_v01($HOUT,$include_files,$include_types);
   h_add_consts_v01($HOUT,$const_hash,$const_order,$$service_hash{"version"},$$service_hash{"identifier"});
   h_add_typedef_v01($HOUT,$typedef_hash,$typedef_order);

   if (ref($user_type_order) eq "ARRAY")
   {
      if (@{$user_type_order} != 0)
      {
         foreach (@$user_type_order)
         {
            if ($$user_type_hash{$_}{"isenum"})
            {
               h_add_enum_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismask"})
            {
               h_add_mask_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"isstruct"})
            {
               h_add_struct_v06($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismessage"})
            {
               h_add_struct_v06($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }
         }
      }
   }

   h_remove_messages($HOUT,$REMOVE_MESSAGES_TEXT);

   if (defined($$service_hash{"servicenumber"}))
   {
     h_add_service_v01($HOUT,$service_hash);
   }else
   {
     h_add_externs_v01($HOUT,$$service_hash{"identifier"},$$service_hash{"version"});
   }

   $$HOUT .=<<"EOF";

#ifdef __cplusplus
}
#endif
#endif

EOF
}

sub populate_h_file_v05
{
   my $OUTPUT_VERSION = shift;
   my $HOUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $include_files = $$type_hash{"include_files"};
   my $include_types = $$type_hash{"include_types"};
   my $const_hash = $$type_hash{"const_hash"};
   my $const_order = $$type_hash{"const_order"};
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $typedef_hash = $$type_hash{"typedef_hash"};
   my $typedef_order = $$type_hash{"typedef_order"};
   my $command_info = $$type_hash{"command_documentation"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $MINOR_VERSION = $$type_hash{"service_hash"}->{"minor_version"};
   my $MAX_MSG_SIZE = $$type_hash{"max_msg_size"};
   my $MAX_MSG_ID = defined($$type_hash{"service_hash"}->{"max_msg_id"}) ?
      $$type_hash{"service_hash"}->{"max_msg_id"} : $INVALID_MSG_ID;

   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);
   #Call the appropriate output functions to populate the output file variables
   h_init_v01($HOUT,$$service_hash{"identifier"},$base_name,$VERSION,$MINOR_VERSION,
          $MAX_MSG_SIZE,$copyright,$p4info,$MAX_MSG_ID,$dec_out_version,$spin_number);
   add_includes_v01($HOUT,$include_files,$include_types);
   h_add_consts_v01($HOUT,$const_hash,$const_order,$$service_hash{"version"},$$service_hash{"identifier"});
   h_add_typedef_v01($HOUT,$typedef_hash,$typedef_order);

   if (ref($user_type_order) eq "ARRAY")
   {
      if (@{$user_type_order} != 0)
      {
         foreach (@$user_type_order)
         {
            if ($$user_type_hash{$_}{"isenum"})
            {
               h_add_enum_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismask"})
            {
               h_add_mask_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"isstruct"})
            {
               h_add_struct_v01($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismessage"})
            {
               h_add_struct_v01($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }
         }
      }
   }
   if (defined($$service_hash{"servicenumber"}))
   {
      h_add_service_v01($HOUT,$service_hash);
   }else
   {
      h_add_externs_v01($HOUT,$$service_hash{"identifier"},$$service_hash{"version"});
   }
   $$HOUT .=<<"EOF";

#ifdef __cplusplus
}
#endif
#endif

EOF
}

sub populate_h_file_v04
{
   my $OUTPUT_VERSION = shift;
   my $HOUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $include_files = $$type_hash{"include_files"};
   my $include_types = $$type_hash{"include_types"};
   my $const_hash = $$type_hash{"const_hash"};
   my $const_order = $$type_hash{"const_order"};
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $typedef_hash = $$type_hash{"typedef_hash"};
   my $typedef_order = $$type_hash{"typedef_order"};
   my $command_info = $$type_hash{"command_documentation"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $MINOR_VERSION = $$type_hash{"service_hash"}->{"minor_version"};
   my $MAX_MSG_SIZE = $$type_hash{"max_msg_size"};
   my $MAX_MSG_ID = defined($$type_hash{"service_hash"}->{"max_msg_id"}) ?
      $$type_hash{"service_hash"}->{"max_msg_id"} : $INVALID_MSG_ID;

   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);
   #Call the appropriate output functions to populate the output file variables
   h_init_v01($HOUT,$$service_hash{"identifier"},$base_name,$VERSION,$MINOR_VERSION,
          $MAX_MSG_SIZE,$copyright,$p4info,$MAX_MSG_ID,$dec_out_version,$spin_number);
   add_includes_v01($HOUT,$include_files,$include_types);
   h_add_consts_v01($HOUT,$const_hash,$const_order,$$service_hash{"version"},$$service_hash{"identifier"});
   h_add_typedef_v01($HOUT,$typedef_hash,$typedef_order);

   if (ref($user_type_order) eq "ARRAY")
   {
      if (@{$user_type_order} != 0)
      {
         foreach (@$user_type_order)
         {
            if ($$user_type_hash{$_}{"isenum"})
            {
               h_add_enum_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismask"})
            {
               h_add_mask_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"isstruct"})
            {
               h_add_struct_v01($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismessage"})
            {
               h_add_struct_v01($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }
         }
      }
   }
   if (defined($$service_hash{"servicenumber"}))
   {
      h_add_service_v01($HOUT,$service_hash);
   }else
   {
      h_add_externs_v01($HOUT,$$service_hash{"identifier"},$$service_hash{"version"});
   }
   $$HOUT .=<<"EOF";

#ifdef __cplusplus
}
#endif
#endif

EOF
}

sub populate_h_file_v03
{
   my $OUTPUT_VERSION = shift;
   my $HOUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $include_files = $$type_hash{"include_files"};
   my $include_types = $$type_hash{"include_types"};
   my $const_hash = $$type_hash{"const_hash"};
   my $const_order = $$type_hash{"const_order"};
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $typedef_hash = $$type_hash{"typedef_hash"};
   my $typedef_order = $$type_hash{"typedef_order"};
   my $command_info = $$type_hash{"command_documentation"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $MINOR_VERSION = $$type_hash{"service_hash"}->{"minor_version"};
   my $MAX_MSG_SIZE = $$type_hash{"max_msg_size"};
   my $MAX_MSG_ID = defined($$type_hash{"service_hash"}->{"max_msg_id"}) ?
      $$type_hash{"service_hash"}->{"max_msg_id"} : $INVALID_MSG_ID;

   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);
   #Call the appropriate output functions to populate the output file variables
   h_init_v01($HOUT,$$service_hash{"identifier"},$base_name,$VERSION,$MINOR_VERSION,
          $MAX_MSG_SIZE,$copyright,$p4info,$MAX_MSG_ID,$dec_out_version,$spin_number);
   add_includes_v01($HOUT,$include_files,$include_types);
   h_add_consts_v01($HOUT,$const_hash,$const_order,$$service_hash{"version"},$$service_hash{"identifier"});
   h_add_typedef_v01($HOUT,$typedef_hash,$typedef_order);

   if (ref($user_type_order) eq "ARRAY")
   {
      if (@{$user_type_order} != 0)
      {
         foreach (@$user_type_order)
         {
            if ($$user_type_hash{$_}{"isenum"})
            {
               h_add_enum_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismask"})
            {
               h_add_mask_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"isstruct"})
            {
               h_add_struct_v01($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismessage"})
            {
               h_add_struct_v01($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }
         }
      }
   }
   if (defined($$service_hash{"servicenumber"}))
   {
      h_add_service_v01($HOUT,$service_hash);
   }else
   {
      h_add_externs_v01($HOUT,$$service_hash{"identifier"},$$service_hash{"version"});
   }
   $$HOUT .=<<"EOF";

#ifdef __cplusplus
}
#endif
#endif

EOF
}

sub populate_h_file_v02
{
   my $OUTPUT_VERSION = shift;
   my $HOUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $include_files = $$type_hash{"include_files"};
   my $include_types = $$type_hash{"include_types"};
   my $const_hash = $$type_hash{"const_hash"};
   my $const_order = $$type_hash{"const_order"};
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $typedef_hash = $$type_hash{"typedef_hash"};
   my $typedef_order = $$type_hash{"typedef_order"};
   my $command_info = $$type_hash{"command_documentation"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $MINOR_VERSION = $$type_hash{"service_hash"}->{"minor_version"};
   my $MAX_MSG_SIZE = $$type_hash{"max_msg_size"};
   my $MAX_MSG_ID = defined($$type_hash{"service_hash"}->{"max_msg_id"}) ?
      $$type_hash{"service_hash"}->{"max_msg_id"} : $INVALID_MSG_ID;

   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);
   #Call the appropriate output functions to populate the output file variables
   h_init_v01($HOUT,$$service_hash{"identifier"},$base_name,$VERSION,$MINOR_VERSION,
          $MAX_MSG_SIZE,$copyright,$p4info,$MAX_MSG_ID,$dec_out_version,$spin_number);
   add_includes_v01($HOUT,$include_files,$include_types);
   h_add_consts_v01($HOUT,$const_hash,$const_order,$$service_hash{"version"},$$service_hash{"identifier"});
   h_add_typedef_v01($HOUT,$typedef_hash,$typedef_order);

   if (ref($user_type_order) eq "ARRAY")
   {
      if (@{$user_type_order} != 0)
      {
         foreach (@$user_type_order)
         {
            if ($$user_type_hash{$_}{"isenum"})
            {
               h_add_enum_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismask"})
            {
               h_add_mask_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"isstruct"})
            {
               h_add_struct_v01($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismessage"})
            {
               h_add_struct_v01($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }
         }
      }
   }
   if (defined($$service_hash{"servicenumber"}))
   {
      h_add_service_v01($HOUT,$service_hash);
   }else
   {
      h_add_externs_v01($HOUT,$$service_hash{"identifier"},$$service_hash{"version"});
   }
   $$HOUT .=<<"EOF";

#ifdef __cplusplus
}
#endif
#endif

EOF
}

sub populate_h_file_v01
{
   my $OUTPUT_VERSION = shift;
   my $HOUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $include_files = $$type_hash{"include_files"};
   my $include_types = $$type_hash{"include_types"};
   my $const_hash = $$type_hash{"const_hash"};
   my $const_order = $$type_hash{"const_order"};
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $typedef_hash = $$type_hash{"typedef_hash"};
   my $typedef_order = $$type_hash{"typedef_order"};
   my $command_info = $$type_hash{"command_documentation"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $MINOR_VERSION = $$type_hash{"service_hash"}->{"minor_version"};
   my $MAX_MSG_SIZE = $$type_hash{"max_msg_size"};
   my $MAX_MSG_ID = defined($$type_hash{"service_hash"}->{"max_msg_id"}) ?
      $$type_hash{"service_hash"}->{"max_msg_id"} : $INVALID_MSG_ID;

   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);
   #Call the appropriate output functions to populate the output file variables
   h_init_v01($HOUT,$$service_hash{"identifier"},$base_name,$VERSION,$MINOR_VERSION,
          $MAX_MSG_SIZE,$copyright,$p4info,$MAX_MSG_ID,$dec_out_version,$spin_number);
   add_includes_v01($HOUT,$include_files,$include_types);
   h_add_consts_v01($HOUT,$const_hash,$const_order,$$service_hash{"version"},$$service_hash{"identifier"});
   h_add_typedef_v01($HOUT,$typedef_hash,$typedef_order);

   if (ref($user_type_order) eq "ARRAY")
   {
      if (@{$user_type_order} != 0)
      {
         foreach (@$user_type_order)
         {
            if ($$user_type_hash{$_}{"isenum"})
            {
               h_add_enum_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismask"})
            {
               h_add_mask_v01($HOUT,\$$user_type_hash{$_},$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"isstruct"})
            {
               h_add_struct_v01($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }elsif ($$user_type_hash{$_}{"ismessage"})
            {
               h_add_struct_v01($HOUT,\$$user_type_hash{$_},$command_info,$$service_hash{"identifier"});
            }
         }
      }
   }
   if (defined($$service_hash{"servicenumber"}))
   {
      h_add_service_v01($HOUT,$service_hash);
   }else
   {
      h_add_externs_v01($HOUT,$$service_hash{"identifier"},$$service_hash{"version"});
   }
   $$HOUT .=<<"EOF";

#ifdef __cplusplus
}
#endif
#endif

EOF
}

#===========================================================================
#
#FUNCTION POPULATE_H_FILE
#
#DESCRIPTION
#  Calls the appropriate output functions to populate the .h file variable
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .h file variable populated with all information contained within data
#  hashes
#
#===========================================================================
sub populate_h_file
{
   my $OUTPUT_VERSION = shift;
   my $HOUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $ccb_mode = shift;
   my $split_h_files = shift;
   my $SHOUT = shift;
   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);
   $CONST_HASH = $$type_hash{"const_hash"};
   $CCB_MODE = $ccb_mode;
   if ($dec_out_version == $FALSE || $dec_out_version == $dec_compiler_version)
   {
     if ($split_h_files)
     {
       populate_split_h_file_v06($OUTPUT_VERSION,$HOUT,$SHOUT,$base_name,$type_hash,$copyright,$p4info);
     }else
     {
       populate_h_file_v06($OUTPUT_VERSION,$HOUT,$base_name,$type_hash,$copyright,$p4info);
     }
   }elsif($dec_out_version == 5)
   {
     populate_h_file_v05($OUTPUT_VERSION,$HOUT,$base_name,$type_hash,$copyright,$p4info);
   }elsif($dec_out_version == 4)
   {
     populate_h_file_v04($OUTPUT_VERSION,$HOUT,$base_name,$type_hash,$copyright,$p4info);
   }elsif($dec_out_version == 3)
   {
     populate_h_file_v03($OUTPUT_VERSION,$HOUT,$base_name,$type_hash,$copyright,$p4info);
   }elsif($dec_out_version == 2)
   {
     populate_h_file_v02($OUTPUT_VERSION,$HOUT,$base_name,$type_hash,$copyright,$p4info);
   }elsif($dec_out_version == 1)
   {
     populate_h_file_v01($OUTPUT_VERSION,$HOUT,$base_name,$type_hash,$copyright,$p4info);
   }else
   {
     print STDERR "Version $OUTPUT_VERSION of Encode/Decode Library Output does not exist.\n";
   }
   return;
}#  populate_h_file

sub populate_c_file_v06
{
   my $OUTPUT_VERSION = shift;
   my $COUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $inc_type_hash = $$type_hash{"include_types"};
   my $inc_type_order = $$type_hash{"include_files"};
   my $const_type_hash = $$type_hash{"const_hash"};
   my $service_identifier = $$service_hash{"identifier"};
   my $service_version = $$service_hash{"version"};
   my $range_types = $$type_hash{"range_types"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $max_msg_size = $$type_hash{"max_msg_size"};
   my $num_types = 0;
   my $num_msgs = 0;
   my $num_ranges = 0;
   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);
   #Call the appropriate output functions to populate the output file variables
   c_init_v01($COUT,$$service_hash{"identifier"},$base_name,$VERSION,$max_msg_size,
     $copyright,$p4info,$dec_out_version,$spin_number);
   add_includes_v01($COUT,$inc_type_order);
   c_add_types_v06($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
   c_add_messages_v06($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
   c_add_ranges_v06($COUT,$range_types,$service_version);
   $num_types = c_type_table_v01($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
   $num_msgs = c_message_table_v06($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
   $num_ranges = c_range_table_v06($COUT,$range_types,$service_identifier,$service_version);
   c_type_table_object_v06($COUT,$inc_type_order,$service_hash,$num_types,$num_msgs,$num_ranges);
   if (defined($$service_hash{"servicenumber"}))
   {
      c_service_message_table_v01($COUT,$service_identifier,$service_hash,$user_type_hash,$inc_type_hash);
      c_service_object_v05($COUT,$service_identifier,$service_hash,$max_msg_size,$dec_out_version, $const_type_hash);
   }
}

sub populate_c_file_v05
{
   my $OUTPUT_VERSION = shift;
   my $COUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $inc_type_hash = $$type_hash{"include_types"};
   my $inc_type_order = $$type_hash{"include_files"};
   my $service_identifier = $$service_hash{"identifier"};
   my $service_version = $$service_hash{"version"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $max_msg_size = $$type_hash{"max_msg_size"};
   my $num_types = 0;
   my $num_msgs = 0;
   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);

   #Call the appropriate output functions to populate the output file variables
   c_init_v01($COUT,$$service_hash{"identifier"},$base_name,$VERSION,$max_msg_size,
     $copyright,$p4info,$dec_out_version,$spin_number);
   add_includes_v01($COUT,$inc_type_order);
   c_add_types_v05($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
   c_add_messages_v05($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
   $num_types = c_type_table_v01($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
   $num_msgs = c_message_table_v01($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
   c_type_table_object_v01($COUT,$inc_type_order,$service_hash,$num_types,$num_msgs);
   if (defined($$service_hash{"servicenumber"}))
   {
      c_service_message_table_v01($COUT,$service_identifier,$service_hash,$user_type_hash,$inc_type_hash);
      c_service_object_v05($COUT,$service_identifier,$service_hash,$max_msg_size,$dec_out_version);
   }
}

sub populate_c_file_v04
{
   my $OUTPUT_VERSION = shift;
   my $COUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $inc_type_hash = $$type_hash{"include_types"};
   my $inc_type_order = $$type_hash{"include_files"};
   my $service_identifier = $$service_hash{"identifier"};
   my $service_version = $$service_hash{"version"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $max_msg_size = $$type_hash{"max_msg_size"};
   my $num_types = 0;
   my $num_msgs = 0;
   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);

   #Call the appropriate output functions to populate the output file variables
      c_init_v01($COUT,$$service_hash{"identifier"},$base_name,$VERSION,$max_msg_size,
        $copyright,$p4info,$dec_out_version,$spin_number);
      add_includes_v01($COUT,$inc_type_order);
      c_add_types_v04($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
      c_add_messages_v04($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
      $num_types = c_type_table_v01($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
      $num_msgs = c_message_table_v01($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
      c_type_table_object_v01($COUT,$inc_type_order,$service_hash,$num_types,$num_msgs);
      if (defined($$service_hash{"servicenumber"}))
      {
         c_service_message_table_v01($COUT,$service_identifier,$service_hash,$user_type_hash,$inc_type_hash);
         c_service_object_v01($COUT,$service_identifier,$service_hash,$max_msg_size,$dec_out_version);
      }
}

sub populate_c_file_v03
{
   my $OUTPUT_VERSION = shift;
   my $COUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $inc_type_hash = $$type_hash{"include_types"};
   my $inc_type_order = $$type_hash{"include_files"};
   my $service_identifier = $$service_hash{"identifier"};
   my $service_version = $$service_hash{"version"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $max_msg_size = $$type_hash{"max_msg_size"};
   my $num_types = 0;
   my $num_msgs = 0;
   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);

   #Call the appropriate output functions to populate the output file variables
      c_init_v01($COUT,$$service_hash{"identifier"},$base_name,$VERSION,$max_msg_size,
        $copyright,$p4info,$dec_out_version,$spin_number);
      add_includes_v01($COUT,$inc_type_order);
      c_add_types_v03($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
      c_add_messages_v03($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
      $num_types = c_type_table_v01($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
      $num_msgs = c_message_table_v01($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
      c_type_table_object_v01($COUT,$inc_type_order,$service_hash,$num_types,$num_msgs);
      if (defined($$service_hash{"servicenumber"}))
      {
         c_service_message_table_v01($COUT,$service_identifier,$service_hash,$user_type_hash,$inc_type_hash);
         c_service_object_v01($COUT,$service_identifier,$service_hash,$max_msg_size,$dec_out_version);
      }
}

sub populate_c_file_v02
{
   my $OUTPUT_VERSION = shift;
   my $COUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $inc_type_hash = $$type_hash{"include_types"};
   my $inc_type_order = $$type_hash{"include_files"};
   my $service_identifier = $$service_hash{"identifier"};
   my $service_version = $$service_hash{"version"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $max_msg_size = $$type_hash{"max_msg_size"};
   my $num_types = 0;
   my $num_msgs = 0;
   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);

   #Call the appropriate output functions to populate the output file variables
      c_init_v01($COUT,$$service_hash{"identifier"},$base_name,$VERSION,$max_msg_size,
        $copyright,$p4info,$dec_out_version,$spin_number);
      add_includes_v01($COUT,$inc_type_order);
      c_add_types_v02($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
      c_add_messages_v02($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
      $num_types = c_type_table_v01($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
      $num_msgs = c_message_table_v01($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
      c_type_table_object_v01($COUT,$inc_type_order,$service_hash,$num_types,$num_msgs);
      if (defined($$service_hash{"servicenumber"}))
      {
         c_service_message_table_v01($COUT,$service_identifier,$service_hash,$user_type_hash,$inc_type_hash);
         c_service_object_v01($COUT,$service_identifier,$service_hash,$max_msg_size,$dec_out_version);
      }
}

sub populate_c_file_v01
{
   my $OUTPUT_VERSION = shift;
   my $COUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $user_type_hash = $$type_hash{"user_types"};
   my $user_type_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $inc_type_hash = $$type_hash{"include_types"};
   my $inc_type_order = $$type_hash{"include_files"};
   my $service_identifier = $$service_hash{"identifier"};
   my $service_version = $$service_hash{"version"};
   my $VERSION = $$type_hash{"service_hash"}->{"version"};
   my $spin_number = $$type_hash{"service_hash"}->{"spin_number"};
   my $max_msg_size = $$type_hash{"max_msg_size"};
   my $num_types = 0;
   my $num_msgs = 0;
   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);

   #Call the appropriate output functions to populate the output file variables
      c_init_v01($COUT,$$service_hash{"identifier"},$base_name,$VERSION,$max_msg_size,
        $copyright,$p4info,$dec_out_version,$spin_number);
      add_includes_v01($COUT,$inc_type_order);
      c_add_types_v01($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
      c_add_messages_v01($COUT,$user_type_hash,$user_type_order,$inc_type_hash,$inc_type_order);
      $num_types = c_type_table_v01($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
      $num_msgs = c_message_table_v01($COUT,$user_type_hash,$user_type_order,$service_identifier,$service_version);
      c_type_table_object_v01($COUT,$inc_type_order,$service_hash,$num_types,$num_msgs);
      if (defined($$service_hash{"servicenumber"}))
      {
         c_service_message_table_v01($COUT,$service_identifier,$service_hash,$user_type_hash,$inc_type_hash);
         c_service_object_v01($COUT,$service_identifier,$service_hash,$max_msg_size,$dec_out_version);
      }
}
#===========================================================================
#
#FUNCTION POPULATE_C_FILE
#
#DESCRIPTION
#  Calls the appropriate output functions to populate the .c file variable
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  .c file variable populated with all information contained within data
#  hashes
#
#===========================================================================
sub populate_c_file
{
   my $OUTPUT_VERSION = shift;
   my $COUT = shift;
   my $base_name = shift;
   my $type_hash = shift;
   my $copyright = shift;
   my $p4info = shift;
   my $ccb_mode = shift;
   my $dec_out_version = hex($OUTPUT_VERSION);
   my $dec_compiler_version = hex($IDL_COMPILER_MAJ_VERS);
   $CCB_MODE = $ccb_mode;

   if ($dec_out_version == $FALSE || $dec_out_version == $dec_compiler_version)
   {
      populate_c_file_v06($IDL_COMPILER_MAJ_VERS,$COUT,$base_name,$type_hash,$copyright,$p4info);
   }elsif($dec_out_version == 5)
   {
      populate_c_file_v05($OUTPUT_VERSION,$COUT,$base_name,$type_hash,$copyright,$p4info);
   }elsif($dec_out_version == 4)
   {
      populate_c_file_v04($OUTPUT_VERSION,$COUT,$base_name,$type_hash,$copyright,$p4info);
   }elsif($dec_out_version == 3)
   {
      populate_c_file_v03($OUTPUT_VERSION,$COUT,$base_name,$type_hash,$copyright,$p4info);
   }elsif($dec_out_version == 2)
   {
      populate_c_file_v02($OUTPUT_VERSION,$COUT,$base_name,$type_hash,$copyright,$p4info);
   }elsif($dec_out_version == 1)
   {
      populate_c_file_v01($OUTPUT_VERSION,$COUT,$base_name,$type_hash,$copyright,$p4info);
   }
}#  populate_c_file

1;
