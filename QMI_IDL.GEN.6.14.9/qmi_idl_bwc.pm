#!/usr/local/bin/perl
# ========================================================================
#                Q M I _ I D L _ B W C . P M
#
# DESCRIPTION
#  Performs backwards compatibility checks for the qmi_idl_compiler tool
#
# REFERENCE
# 
# Copyright (c) 2011 by QUALCOMM Incorporated. All Rights Reserved.
# ========================================================================
# 
# $Header: //source/qcom/qct/core/mproc/tools_crm/idl_compiler/main/latest/customer/qmi_idl_bwc.pm#2 $
#
# ========================================================================
package qmi_idl_bwc;

use strict;
use warnings;

require Exporter;
use Data::Dumper;
use File::Basename;
use IO::File;
eval 'use XML::Simple';

our @ISA = qw(Exporter);

#Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration       use IDLCompiler::IDLOutput ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(bwc_const
                                   bwc_typedef
                                   bwc_enum
                                   bwc_mask
                                   bwc_type_msg
                                   bwc_type_msg_elms
                                   bwc_deprecated_type
                                   bwc_service
                                   bwc_check_for_removed_values) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

my $FALSE = 0;
my $TRUE = 1;

my %allowed_type_changes = (
                            "int8" => { "mask8"=>$TRUE,"enum8"=>$TRUE },
                            "uint8" => { "mask8"=>$TRUE,"enum8"=>$TRUE },
                            "int16" => { "mask16"=>$TRUE,"enum16"=>$TRUE },
                            "uint16" => { "mask16"=>$TRUE,"enum16"=>$TRUE },
                            "int32" => { "mask32"=>$TRUE,"enum"=>$TRUE },
                            "uint32" => { "mask32"=>$TRUE },
                            );

#===========================================================================
#
#FUNCTION BWC_CONST
#
#DESCRIPTION
#  Performs backwards compatibility checks on const values
#  Const values cannot be changed
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  Returns an error string if the check fails.
#
#SIDE EFFECTS
#  
#
#===========================================================================
sub bwc_const {
   my $golden_xdr_value = shift;
   my $idl_value = shift;
   my $const_name = shift;
   if($golden_xdr_value =~ m/^\D/) {
      return "Line $. - Value of constant $const_name has changed from " . 
         "$golden_xdr_value to $idl_value: This is not backwards compatible.\n"
         unless ($golden_xdr_value eq $idl_value);
   }else{
      if($golden_xdr_value =~ m/0x/) 
      {
         $golden_xdr_value = hex($golden_xdr_value);
         $idl_value = hex($idl_value);
      }
      return "Line $. - Value of constant $const_name has changed from " . 
         "$golden_xdr_value to $idl_value: This is not backwards compatible.\n"
         unless ($golden_xdr_value == $idl_value);
   }
   return;
}#  bwc_const

#===========================================================================
#
#FUNCTION BWC_ENUM
#
#DESCRIPTION
#  Performs backwards compatibility checks on enum values.
#  Values must be added to an enum in a way that does not change
#  the values of existing enum elements.
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  Returns an error string if the check fails.
#
#SIDE EFFECTS
#  
#
#===========================================================================
sub bwc_enum {
   my $golden_xml = shift;
   my $enum_hash = shift;
   my $ENUM_HASH_NAME_POS=0;
   my $ENUM_HASH_VAL_POS=1;
   my $golden_enum_len = 1;
   my $enum_len = 1;
   my $enum_elm_match = $FALSE;
   if(ref(${$golden_xml}{"elementList"}{"enum"}) eq "ARRAY") {
      $golden_enum_len = @{${$golden_xml}{"elementList"}{"enum"}};
   }
   if(ref($$enum_hash{"elementList"}) eq "ARRAY") {
      $enum_len = @{$$enum_hash{"elementList"}};
   }
   #Iterate through all enum elements, compare old golden xml to new hash values
   if($golden_enum_len > 1) {
      for(my $i=0;$i<$golden_enum_len;$i++){
         #Now iterate through the IDL enum hash to find the matching enum element
         $enum_elm_match = $FALSE;
         for(my $j = $i;$j<$enum_len;$j++) {
            if(@{@{$$enum_hash{"elementList"}}[$j]}[$ENUM_HASH_NAME_POS] eq 
              ${$golden_xml}{"elementList"}{"enum"}[$i]{"identifier"})
            {
              my $temp_val = @{@{$$enum_hash{"elementList"}}[$j]}[$ENUM_HASH_VAL_POS];
              my $temp_gold_val = ${$golden_xml}{"elementList"}{"enum"}[$i]{"value"};
              if ($temp_val =~ m/^0x/)
              {
                $temp_val = hex($temp_val);
              }
              if ($temp_gold_val =~ m/^0x/)
              {
                $temp_gold_val = hex($temp_gold_val);
              }
              if($temp_val == $temp_gold_val) 
              {
                $enum_elm_match = $TRUE;
              }
              last;
            }
         }
         if($enum_elm_match == $FALSE) {
            return "Line $. - enum " . 
              ${$golden_xml}{"identifier"} . " not backwards compatible starting at element: " . 
               ${$golden_xml}{"elementList"}{"enum"}[$i]{"identifier"} . ".\n";
         }
      }
   }else{
      if ($$enum_hash{"elementList"}[0][$ENUM_HASH_NAME_POS] ne 
        ${$golden_xml}{"elementList"}{"enum"}{"identifier"} or
         $$enum_hash{"elementList"}[0][$ENUM_HASH_VAL_POS] ne 
           ${$golden_xml}{"elementList"}{"enum"}{"value"})
      {
         return "Line $. - enum " . ${$golden_xml}{"identifier"} . 
           " not backwards compatible starting at element: " . 
         ${$golden_xml}{"elementList"}{"enum"}{"identifier"} . ".\n";
      }
   }
   return;
}#  bwc_enum

#===========================================================================
#
#FUNCTION BWC_MASK
#
#DESCRIPTION
#  Performs backwards compatibility checks on mask values.
#  Values must be added to a mask in a way that does not change
#  the values of existing mask elements.
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  Returns an error string if the check fails.
#
#SIDE EFFECTS
#  
#
#===========================================================================
sub bwc_mask {
   my $golden_xml = shift;
   my $mask_hash = shift;
   my $MASK_HASH_NAME_POS=0;
   my $MASK_HASH_VAL_POS=1;
   my $golden_mask_len = 1;
   my $mask_len = 1;
   my $mask_elm_match = $FALSE;
   if(ref(${$golden_xml}{"elementList"}{"mask"}) eq "ARRAY") {
      $golden_mask_len = @{${$golden_xml}{"elementList"}{"mask"}};
   }
   if(ref($$mask_hash{"elementList"}) eq "ARRAY") {
      $mask_len = @{$$mask_hash{"elementList"}};
   }
   #Iterate through all mask elements, compare old golden xml to new hash values
   if($golden_mask_len > 1) {
      for(my $i=0;$i<$golden_mask_len;$i++){
         #Now iterate through the IDL mask hash to find the matching mask element
         $mask_elm_match = $FALSE;
         for(my $j = $i;$j<$mask_len;$j++) {
            if(@{@{$$mask_hash{"elementList"}}[$j]}[$MASK_HASH_NAME_POS] eq 
              ${$golden_xml}{"elementList"}{"mask"}[$i]{"identifier"})
            {
               if(@{@{$$mask_hash{"elementList"}}[$j]}[$MASK_HASH_VAL_POS] eq 
                 ${$golden_xml}{"elementList"}{"mask"}[$i]{"value"}) 
               {
                  $mask_elm_match = $TRUE;
               }
               last;
            }
         }
         if($mask_elm_match == $FALSE) {
            return "Line $. - mask " . 
              ${$golden_xml}{"identifier"} . " not backwards compatible starting at element: " . 
               ${$golden_xml}{"elementList"}{"mask"}[$i]{"identifier"} . ".\n";
         }
      }
   }else{
      if ($$mask_hash{"elementList"}[0][$MASK_HASH_NAME_POS] ne 
        ${$golden_xml}{"elementList"}{"mask"}{"identifier"} or
         $$mask_hash{"elementList"}[0][$MASK_HASH_VAL_POS] ne 
           ${$golden_xml}{"elementList"}{"mask"}{"value"})
      {
         return "Line $. - mask " . ${$golden_xml}{"identifier"} . 
           " not backwards compatible starting at element: " . 
         ${$golden_xml}{"elementList"}{"mask"}{"identifier"} . ".\n";
      }
   }
   return;
}#  bwc_mask

#===========================================================================
#
#FUNCTION BWC_TYPEDEF
#
#DESCRIPTION
#  Performs backwards compatibility checks on typedef values.
#  The values of typedefs cannot change
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  Returns an error string if the check fails.
#
#SIDE EFFECTS
#  
#
#===========================================================================
sub bwc_typedef {
   my $golden_xdr_value = shift;
   my $idl_value = shift;
   my $typedef_name = shift;

   return "Line $. - Value of typedef $typedef_name has changed from " . 
      "$golden_xdr_value to $idl_value: This is not backwards compatible.\n" 
      unless ($golden_xdr_value eq $idl_value);
   return;
}#  bwc_typedef

#===========================================================================
#
#FUNCTION BWC_TYPE_MSG
#
#DESCRIPTION
#  Makes sure the sequence numbers of types and messages is consistent between
#  the IDL and the golden XML file
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  Returns the next sequence number
#
#SIDE EFFECTS
#  
#
#===========================================================================
sub bwc_type_msg {
   my $golden_xml = shift;
   my $type_hash = shift;
   my $sequence_num = shift;
   #Sets the sequence numbers of struct and message elements based on the golden xml file
   if(defined($$golden_xml->{"types"}{$$type_hash->{"identifier"}})) 
   {
      $$type_hash->{"sequence"} = $$golden_xml->{"types"}{$$type_hash->{"identifier"}}{"sequence"};
   }else
   {
      if($$type_hash->{"isMessage"}) 
      {
         $$type_hash->{"sequence"} = $$golden_xml->{"sequence"}{"msgs"};
         $$golden_xml->{"sequence"}{"msgs"}++;
      }else
      {
         $$type_hash->{"sequence"} = $$golden_xml->{"sequence"}{"types"};
         $$golden_xml->{"sequence"}{"types"}++;
      }
   }

   return $$type_hash->{"sequence"} + 1;
}#  bwc_type_msg

#===========================================================================
#
#FUNCTION BWC_TYPE_MSG_ELMS
#
#DESCRIPTION
#  Performs backwards compatibility checks on message elements
#  Verifies that no elements have been removed from messages or structs,
#  and calls type_comparison to verify the elements have not been modified
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  Returns an error string if the check fails.
#
#SIDE EFFECTS
#  
#
#===========================================================================
sub bwc_type_msg_elms {
   my $golden_xml = shift;
   my $type_hash = shift;
   my $type_name = shift;
   my $error_string = "";
   my $is_message = 0;
   my $type_elm_len;
   my $i;
   my $j;
   my $golden_duplicate;
   $is_message = 1 if ($$type_hash{"isMessage"});
   if(defined(${$golden_xml}{"elementList"}{"type"})) 
   {
      if (ref(${$golden_xml}{"elementList"}{"type"}) eq "ARRAY")
      {
         #If there is more than 1 element in the struct(most common case)
         $type_elm_len = @{${$golden_xml}{"elementList"}{"type"}};
         for($i=0;$i<$type_elm_len;$i++)
         {
            my %golden_hash = %{${$golden_xml}{"elementList"}{"type"}[$i]};
            if($golden_hash{"primitiveType"} eq "duplicate")
            {
               last;
            }
            my $type_hash_len = @{$$type_hash{"elementList"}};
            for($j=$i;$j<=$type_hash_len;$j++)
            {
               if($j == $type_hash_len)
               {
                  $error_string .= "Line $. - Element " . $golden_hash{"identifier"} . 
                     " in $type_name has been removed.  This is not backwards compatible.\n";
                  last;
               }           
               if(defined(@{$$type_hash{"elementList"}}[$j])) 
               {
                  my %type_elm = %{@{$$type_hash{"elementList"}}[$j]};
                  my $duplicate = hex($type_elm{"isDuplicate"});
                  my $type_tlv = hex($type_elm{"TLVType"});
                  my $golden_tlv = hex($golden_hash{"TLVType"});
                  if($type_tlv < $golden_tlv)
                  {
                     next;
                  }
                  if($duplicate != 0)
                  {
                     next;
                  }
                  $error_string .= type_comparison(\%golden_hash,\%type_elm,$type_name,$is_message);
                  last;
               }
            }
         }
      }else
      {
         #Special handling of structs with one element
         my %golden_hash = %{${$golden_xml}{"elementList"}{"type"}};
         if(defined(@{$$type_hash{"elementList"}}[0])) 
         {
            my %type_elm = %{@{$$type_hash{"elementList"}}[0]};
            $error_string .= type_comparison(\%golden_hash,\%type_elm,$type_name,$is_message);
         }else
         {
            $error_string .= "Line $. - Element " . $golden_hash{"identifier"} . 
               " in $type_name has been removed.  This is not backwards compatible.\n";
         }
      }
   }else
   {
      return;
   }
   if($error_string eq "") 
   {
      return;
   }else
   {
      return $error_string;
   }
}#  bwc_type_elms

sub valid_type_change 
{
   my $golden_hash = shift;
   my $type_elm = shift;

   if (defined($allowed_type_changes{$golden_hash->{"primitiveType"}}->{$type_elm->{"primitiveType"}}))
   {
      return $TRUE;
   }
   return $FALSE;
}

sub bwc_deprecated_type
{
  my $golden_xml = shift;
  my $type_hash = shift;
  my $type_name = shift;
  my $i;
  my $j;
  my $new_tlv = $TRUE;
  if (defined($$type_hash{"elementList"}))
  {
    my $type_hash_len = @{$$type_hash{"elementList"}};
    for($i=0;$i<=$type_hash_len;$i++)
    {
      if(defined(@{$$type_hash{"elementList"}}[$i])) 
      {
        $new_tlv = $TRUE;
        my %type_elm = %{@{$$type_hash{"elementList"}}[$i]};
        
        if ($type_elm{"primitiveType"} eq "string" || $type_elm{"primitiveType"} eq "char")
        {          
          if(defined(${$golden_xml}{"elementList"}{"type"})) 
          {
            if (ref(${$golden_xml}{"elementList"}{"type"}) eq "ARRAY")
            {
              if ($type_elm{"identifier"} eq "testttt")
              {
                print STDERR Dumper(\%type_elm);
              }
              my $type_elm_len = @{${$golden_xml}{"elementList"}{"type"}};
              for($j=0;$j<$type_elm_len;$j++)
              {
                my %golden_hash = %{${$golden_xml}{"elementList"}{"type"}[$j]};
                my $type_tlv = hex($type_elm{"TLVType"});
                my $golden_tlv = hex($golden_hash{"TLVType"});
                if ($type_tlv == $golden_tlv)
                {
                  $new_tlv = $FALSE;
                  last;
                }
              }
              if($new_tlv == $TRUE)
              {
                print STDERR "Line $. - WARNING: Use of type " . $type_elm{"primitiveType"} . 
                  " is deprecated.  Use type string16 instead.\n";
              }
            }else
            {
              #Special handling of structs with one element
              my %golden_hash = %{${$golden_xml}{"elementList"}{"type"}};
              if(defined(@{$$type_hash{"elementList"}}[0])) 
              {
                my %type_elm = %{@{$$type_hash{"elementList"}}[0]};
                my %golden_hash = %{${$golden_xml}{"elementList"}{"type"}};
                my $type_tlv = hex($type_elm{"TLVType"});
                my $golden_tlv = hex($golden_hash{"TLVType"});
                if ($type_tlv != $golden_tlv)
                {
                  print STDERR "Line $. - WARNING: Use of type " . $type_elm{"primitiveType"} . 
                  " is deprecated.  Use type string16 instead.\n";
                }
              }
            }
          }
        }
      }
    }
  }
}
#===========================================================================
#
#FUNCTION TYPE_COMPARISON
#
#DESCRIPTION
#  Performs backwards compatibility checks on types.
#  Identifier cannot change
#  Type cannot change
#  Cannot change between array or variable array types
#  Array size cannot change
#  Message elements cannot change between optional and mandatory
#  T of the TLV cannot change
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  Returns an error string if the check fails.
#
#SIDE EFFECTS
#  
#
#===========================================================================
sub type_comparison 
{
   my $golden_hash = shift;
   my $type_elm = shift;
   my $type_name = shift;
   my $is_message = shift;
   my $return_string = "";
   if($$golden_hash{"identifier"} ne $$type_elm{"identifier"}) 
   {
      #The order of elements in the struct has changed
      $return_string .= "Line $. - Element " . $$golden_hash{"identifier"} . 
         " of $type_name not found or is in a different order.  This is not backwards compatible.\n";
   }
   if($$golden_hash{"type"} ne $$type_elm{"type"}) 
   {
      if(valid_type_change($golden_hash,$type_elm) == $FALSE) 
      {
         #The type of an element in the struct has changed
         $return_string .= "Line $. - Element " . $$golden_hash{"identifier"} . 
            " of $type_name has changed type\n\tfrom " . $$golden_hash{"type"} .  
            " to " . $$type_elm{"type"} . ".  This is not backwards compatible.\n";
      }
   }
   if($$golden_hash{"isArray"} != $$type_elm{"isArray"}) 
   {
      #The type is no longer an array
      $return_string .= "Line $. - Element " . $$golden_hash{"identifier"} . 
         " of $type_name has changed array type.  This is not backwards compatible.\n";
   }
   if($$golden_hash{"isVarArray"} != $$type_elm{"isVarArray"}) 
   {
      #The type is no longer a variable array
      $return_string .= "Line $. - Element " . $$golden_hash{"identifier"} . 
         " of $type_name has changed array type.  This is not backwards compatible.\n";
   }
   if($$golden_hash{"n"} ne $$type_elm{"n"}) 
   {
      #The number of elements of an array or variable array has changed
      $return_string .= "Line $. - Array element " . $$golden_hash{"identifier"} . 
         " of $type_name has different number of elements,\n\tfrom "
         . $$golden_hash{"n"} . " to " . $$type_elm{"n"} . ".  This is not backwards compatible.\n";
   }
   if($is_message) {
      if($$golden_hash{"isOptional"} != $$type_elm{"isOptional"}) 
      {
         #The type has changed between optional and mandatory
         $return_string .= "Line $. - Element " . $$golden_hash{"identifier"} . 
            " of $type_name has changed between Optional and Mandatory.  This is not backwards compatible.\n";
      }
      if($$golden_hash{"TLVType"} ne $$type_elm{"TLVType"}) 
      {
         #The T value has changed
         $return_string .= "Line $. - Element " . $$golden_hash{"identifier"} . " of $type_name has changed T value,\n\tfrom "
            . $$golden_hash{"TLVType"} . " to " . $$type_elm{"TLVType"} . ".  This is not backwards compatible.\n";
      }
   }
   return $return_string;
}#  type_comparison

#===========================================================================
#
#FUNCTION BWC_CHECK_FOR_REMOVED_VALUES
#
#DESCRIPTION
#  Performs backwards compatibility checks to see if something has been removed 
#  from the IDL
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  Returns an error string if the check fails.
#
#SIDE EFFECTS
#  
#
#===========================================================================
sub bwc_check_for_removed_values {
   my $golden_xml = shift;
   my $type_hash = shift;
   my $error_string = "";
   
   #Verify that no constants have been removed
   for my $key (keys %{$$golden_xml{"consts"}}){
      unless(defined($$type_hash{"const_hash"}{$key})){
         $error_string .= "Const value $key removed from IDL.  This is not backwards compatible.\n";
      }
   }

   #Verify that no typedefs have been removed
   for my $key (keys %{$$golden_xml{"typedefs"}}){
      unless(defined($$type_hash{"typedef_hash"}{$key})){
         $error_string .= "typedef value $key removed from IDL.  This is not backwards compatible.\n";
      }
   }

   #Verify that no type definitions have been removed
   for my $key (keys %{$$golden_xml{"types"}}){
      unless(defined($$type_hash{"user_types"}{$key})){
         $error_string .= "Type $key removed from IDL.  This is not backwards compatible.\n";
      }
   }

   if($error_string eq "") {
      return;
   }else{
      return $error_string;
   }
}#  bwc_check_for_removed_values

#===========================================================================
#
#FUNCTION BWC_SERVICE
#
#DESCRIPTION
#  Performs backwards compatibility checks on the values in a service
#  Verifies that service identifier and number have not changed, and that
#  all messages defined in the service have the same types and message IDs
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  Returns an error string if the check fails.
#
#SIDE EFFECTS
#  
#
#===========================================================================
sub bwc_service {
   my $golden_xml = shift;
   my $type_hash = shift;
   my $error_string = "";
   my $golden_msg_list_len;
   my $msg_list_len;

   #Verify identifier remains the same
   if($$golden_xml{"identifier"} ne $$type_hash{"identifier"}) {
      $error_string .= "Service Identifier has changed from " . $$golden_xml{"identifier"} . " to " 
         . $$type_hash{"identifier"} . ". This is not backwards compatible.\n";
   }
   #service number cannot change
   if($$golden_xml{"serviceNumber"} !~ m/^0x/)
   {
      $$golden_xml{"serviceNumber"} = sprintf("0x%02X", $$golden_xml{"serviceNumber"});
   }
   if($$golden_xml{"serviceNumber"} ne $$type_hash{"serviceNumber"}) {
      $error_string .= "Service Number has changed from " . $$golden_xml{"serviceNumber"} . " to " 
         . $$type_hash{"serviceNumber"} . ". This is not backwards compatible.\n";
   }
   $golden_msg_list_len = @{${$golden_xml}{"messageList"}{"message"}};
   $msg_list_len = @{$$type_hash{"elementList"}};
   #Iterate through all messages to verify that their type and message ID has not changed
   for(my $i=0;$i<$golden_msg_list_len;$i++){
      my %golden_hash = %{${$golden_xml}{"messageList"}{"message"}[$i]};
      for(my $j = $i; $j < $msg_list_len; $j++) {
         my %type_elm = %{@{$$type_hash{"elementList"}}[$j]};
         if($golden_hash{"identifier"} ne $type_elm{"identifier"}) {
            next;
         }
         if($golden_hash{"type"} ne $type_elm{"type"}) {
            $error_string .= "Service Message " . $golden_hash{"identifier"} . " type has changed from " . $golden_hash{"type"}
            . " to " . $type_elm{"type"} . ". This is not backwards compatible\n";
         }
         if($golden_hash{"messageId"} ne $type_elm{"messageId"}) {
            $error_string .= "Service Message " . $golden_hash{"identifier"} . " message ID has changed from " . $golden_hash{"messageId"}
            . " to " . $type_elm{"messageId"} . ". This is not backwards compatible\n";
         }
         last;
      }
   }

   if($error_string eq "") {
      return;
   }else{
      return $error_string;
   }
}#  bwc_service

1;
