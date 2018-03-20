#!/usr/local/bin/perl
# ========================================================================
#                Q M I _ I D L _ X M L _ O U T P U T . P M
#
# DESCRIPTION
#  Writes out the golden XML file for the qmi_idl_compiler tool
#
# REFERENCE
# 
# Copyright (c) 2011 by QUALCOMM Incorporated. All Rights Reserved.
# ========================================================================
# 
# $Header: //source/qcom/qct/core/mproc/tools_crm/idl_compiler/main/latest/customer/qmi_idl_xml_output.pm#1 $
#
# ========================================================================
package qmi_idl_xml_output;

use strict;
use warnings;

require Exporter;
eval {require XML::Writer;};
use Data::Dumper;
use File::Basename;
use IO::File;

our @ISA = qw(Exporter);

#Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration       use IDLCompiler::IDLOutput ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(xml_print_doc
                                   ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

#==============================================#
#==================Constants===================#
#==============================================#
my $FALSE = 0;
my $TRUE = 1;


my $doc;
#===========================================================================
#
#FUNCTION FORMAT_XML_OUTPUT
#
#DESCRIPTION
#  Formats an input string to be encased within xml tags
#
#DEPENDENCIES
#  a valid string is passed as an argument
#
#RETURN VALUE
#  returns the reformatted input string
#
#SIDE EFFECTS
#  none
#
#===========================================================================
sub format_xml_output 
{
  my $debug_string = shift;
  if (defined($debug_string)) 
  {
    #Replace special characters with common ones
    $debug_string =~ s/‘/'/g;
    $debug_string =~ s/’/'/g;
    $debug_string =~ s/–/-/g;
    $debug_string =~ s/—/-/g;
    $debug_string =~ s/”/"/g;
    $debug_string =~ s/“/"/g;
    $debug_string =~ s/±/+-/g;
    $debug_string =~ s/®/(R)/g;
    $debug_string =~ s/¡//g;
    $debug_string =~ s/°//g;
  }
  return $debug_string;
}#  format_xml_output

#===========================================================================
#
#FUNCTION XML_PRINT_DOC
#
#DESCRIPTION
#  Calls the various XML output methods to print the XML formatted API
#  information either to the terminal or a specified output file
#
#DEPENDENCIES
#  The hash and array parameters are populated 
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  API information is output in XML format
#
#===========================================================================
sub xml_print_doc {
   my $idl = shift;
   my $out_method = shift;
   my $type_hash = shift;
   my $file_documentation = $$type_hash{"file_documentation"};
   my $command_documentation = $$type_hash{"command_documentation"};
   my $command_order = $$type_hash{"command_order"};
   my $include_files = $$type_hash{"include_files"};
   my $const_hash = $$type_hash{"const_hash"};
   my $const_order = $$type_hash{"const_order"};
   my $typedef_hash = $$type_hash{"typedef_hash"};
   my $typedef_order = $$type_hash{"typedef_order"};
   my $user_types = $$type_hash{"user_types"};
   my $user_types_order = $$type_hash{"user_types_order"};
   my $service_hash = $$type_hash{"service_hash"};
   my $footer_order = $$type_hash{"footer_order"};
   my $footer_hash = $$type_hash{"footer"};
   my $max_type_seq_num = $$type_hash{"struct_seq_num"};
   my $max_msg_seq_num = $$type_hash{"msg_seq_num"};
   my $output;

   if ($out_method eq "") {
     $doc = new XML::Writer(DATA_MODE => 1, UNSAFE=> 1, DATA_INDENT =>2);
   }else{
     $output = new IO::File(">$out_method");
     $doc = new XML::Writer(OUTPUT => $output, DATA_MODE => 1, UNSAFE=> 1, DATA_INDENT =>2);
   }
   $doc->startTag("IDLDescription", idl => $idl);
   xml_file_documentation($file_documentation);
   xml_command_documentation($command_documentation,$command_order);
   xml_print_includes($include_files);
   xml_print_consts($const_hash,$const_order);
   xml_print_typedefs($typedef_hash,$typedef_order);
   xml_print_sequence_nums($max_type_seq_num,$max_msg_seq_num);
   xml_print_types($user_types,$user_types_order);
   xml_print_service($service_hash);
   xml_print_footer($footer_order,$footer_hash);
   xml_print_version($$service_hash{"version"}, $$service_hash{"minor_version"},
                     $$service_hash{"tool_major_version"}, $$service_hash{"tool_minor_version"},
                     $$service_hash{"spin_number"});
   $doc->endTag();
   $doc->end();
   $output->close() if (defined($output));
}#  xml_start_doc

#===========================================================================
#
#FUNCTION XML_FILE_DOCUMENTATION
#
#DESCRIPTION
#  Outputs the file documentation hash in XML format
#
#DEPENDENCIES
#  file documentation hash argument is populated
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  file documentation output in XML format
#
#===========================================================================
sub xml_file_documentation {
  my $file_doc = shift;
  $doc->startTag("section", title => "file documentation");
  while ( my ($key, $value) = each(%$file_doc) ) {
    $doc->dataElement( $key => format_xml_output($value) );
  }
  $doc->endTag();
}#  xml_file_documentation

#===========================================================================
#
#FUNCTION XML_COMMAND_DOCUMENTATION
#
#DESCRIPTION
#  Outputs command documentation hash information in XML format
#
#DEPENDENCIES
#  command documentation hash and order array arguments are populated
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  Command documentation output in XML format
#
#===========================================================================
sub xml_command_documentation 
{
  my $command_doc = shift;
  my $command_order = shift;
  my $xml_sequence_number = 1;
  my @temp_order_array = ();
  $doc->startTag("section", title => "command documentation");
  foreach (@$command_order)
  {
    $doc->startTag( "command", identifier => $_);
    $doc->dataElement( commandID =>
               format_xml_output($$command_doc{$_}{"commandid"}) ) if
             defined( $$command_doc{$_}{"commandid"} );
    $doc->dataElement( brief =>
               format_xml_output($$command_doc{$_}{"BRIEF"}) ) if
             defined( $$command_doc{$_}{"BRIEF"} );
    $doc->dataElement( Cmd_Version =>
               format_xml_output($$command_doc{$_}{"CMD_VERSION"}) ) if
             defined( $$command_doc{$_}{"CMD_VERSION"} );
    $doc->dataElement( cmd_deprecated =>
               format_xml_output($$command_doc{$_}{"CMD_DEPRECATED"}) ) if
             defined( $$command_doc{$_}{"CMD_DEPRECATED"} );
    $doc->dataElement( description =>
               format_xml_output($$command_doc{$_}{"DESCRIPTION"}) ) if
             defined( $$command_doc{$_}{"DESCRIPTION"} );
    $doc->dataElement( errors =>
               format_xml_output($$command_doc{$_}{"ERROR"}) ) if
             defined( $$command_doc{$_}{"ERROR"} );
    $doc->dataElement( version => 
             format_xml_output($$command_doc{$_}{"VERSION"}) ) if 
          defined( $$command_doc{$_}{"VERSION"} );
    $doc->dataElement( provisional => 
             format_xml_output($$command_doc{$_}{"CMD_PROVISIONAL"}) ) if 
          defined( $$command_doc{$_}{"CMD_PROVISIONAL"} );
    $doc->dataElement( sequence => $xml_sequence_number );
    $doc->endTag();
    $xml_sequence_number++;
  }
  $doc->endTag();
}#  xml_command_documentation

#===========================================================================
#
#FUNCTION XML_PRINT_INCLUDES
#
#DESCRIPTION
#  Output the information for the files that were included in the IDL
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  include file information output in XML format
#
#===========================================================================
sub xml_print_includes {
  my $include_files = shift;
  $doc->startTag("section", title => "include files");
  if (ref($include_files) eq "ARRAY") {
     foreach (@$include_files){
       $doc->dataElement( file => format_xml_output($_));
     }
  }
  $doc->endTag();
}#  xml_print_includes

#===========================================================================
#
#FUNCTION XML_PRINT_CONSTS
#
#DESCRIPTION
#  Outputs the information for const values in the IDL
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  const information output in XML format
#
#===========================================================================
sub xml_print_consts {
  my $const_hash = shift;
  my $const_order = shift;
  $doc->startTag("section", title => "consts");
  if (ref($const_order) eq "ARRAY") {
     foreach (@$const_order){
       $doc->startTag( "const", identifier => format_xml_output($_ ));
       $doc->dataElement( value => format_xml_output($$const_hash{$_}{"value"}) );
       $doc->dataElement( isInteger => format_xml_output($$const_hash{$_}{"isInteger"}) );
       $doc->dataElement( isIncluded => format_xml_output($$const_hash{$_}{"included"}) );
       $doc->dataElement( description => format_xml_output($$const_hash{$_}{"description"}) );
       $doc->endTag();
     }
  }
  $doc->endTag();
}#  xml_print_consts

#===========================================================================
#
#FUNCTION XML_PRINT_TYPEDEFS
#
#DESCRIPTION
#  Outputs the information for typedef values in the IDL
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  typedef information output in XML format
#
#===========================================================================

sub xml_print_typedefs {
   my $typedef_hash = shift;
   my $typedef_order = shift;
   $doc->startTag("section", title => "typedefs");
   if (ref($typedef_order) eq "ARRAY") {
     foreach (@$typedef_order){
       $doc->startTag( "typedef", identifier => format_xml_output($_) );
       $doc->dataElement( type => format_xml_output($$typedef_hash{$_}{"type"}) );
       $doc->dataElement( version => format_xml_output($$typedef_hash{$_}{"version"}) );
       $doc->endTag();
     }
  }
  $doc->endTag();
}#  xml_print_typedefs

#===========================================================================
#
#FUNCTION XML_PRINT_SEQUENCE_NUMS
#
#DESCRIPTION
#  Outputs the max sequence numbers for types and messages.
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  sequence number information output in XML format
#
#===========================================================================
sub xml_print_sequence_nums {
   my $type_num = shift;
   my $msg_num  = shift;

   $doc->startTag("section", title => "sequence_nums");
   $doc->dataElement( types => format_xml_output($type_num) );
   $doc->dataElement( msgs => format_xml_output($msg_num) );
   $doc->endTag();
}#  xml_print_sequence_nums

#===========================================================================
#
#FUNCTION XML_PRINT_TYPES
#
#DESCRIPTION
#  Outputs all information for various types into XML.
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  type information output in XML format
#
#===========================================================================
sub xml_print_types {
  my $type_hash = shift;
  my $type_order = shift;
  my $type_name;
  $doc->startTag("section", title => "types");
  if (ref($type_order) eq "ARRAY") {
     foreach (@$type_order) {
       $type_name = $_;
       $doc->startTag( "type", identifier => format_xml_output($type_name) );
       $doc->dataElement( command => format_xml_output($$type_hash{$type_name}{"command"}) );
       $doc->dataElement( msg => format_xml_output($$type_hash{$type_name}{"msg"}) );
       $doc->dataElement( msgAlias => format_xml_output($$type_hash{$type_name}{"msgAlias"}) );
       $doc->dataElement( type => format_xml_output($$type_hash{$type_name}{"type"}) );
       $doc->dataElement( n => format_xml_output($$type_hash{$type_name}{"n"}) );
       $doc->dataElement( sizeof => format_xml_output($$type_hash{$type_name}{"sizeof"}) );
       $doc->dataElement( wireSize => format_xml_output($$type_hash{$type_name}{"wireSize"}) );
       $doc->dataElement( isVarWireSize => format_xml_output($$type_hash{$type_name}{"isVarWireSize"}) );
       $doc->dataElement( isArray => format_xml_output($$type_hash{$type_name}{"isArray"}) );
       $doc->dataElement( isVarArray => format_xml_output($$type_hash{$type_name}{"isVarArray"}) );
       $doc->dataElement( isEnum => format_xml_output($$type_hash{$type_name}{"isEnum"}) );
       $doc->dataElement( isMask => format_xml_output($$type_hash{$type_name}{"isMask"}) );
       $doc->dataElement( isMessage => format_xml_output($$type_hash{$type_name}{"isMessage"}) );
       $doc->dataElement( isOptional => format_xml_output($$type_hash{$type_name}{"isOptional"}) );
       $doc->dataElement( isStruct => format_xml_output($$type_hash{$type_name}{"isStruct"}) );
       $doc->dataElement( isString => format_xml_output($$type_hash{$type_name}{"isString"}) );
       $doc->dataElement( isLengthless =>format_xml_output($$type_hash{$type_name}{"isLengthless"}) );
       $doc->dataElement( set16bitflag =>format_xml_output($$type_hash{$type_name}{"set16bitflag"}) );
       $doc->dataElement( set32bitflag =>format_xml_output($$type_hash{$type_name}{"set32bitflag"}) );
       $doc->dataElement( TLVType => format_xml_output($$type_hash{$type_name}{"TLVType"}) );
       $doc->dataElement( sequence => format_xml_output($$type_hash{$type_name}{"sequence"}) );
       $doc->startTag( "description" );
       if ($$type_hash{$type_name}{"description"}{"TYPE"} ne ""){
         $doc->dataElement( TYPE => 
             format_xml_output($$type_hash{$type_name}{"description"}{"TYPE"}));
       }
       if ($$type_hash{$type_name}{"description"}{"SENDER"} ne ""){
         $doc->dataElement( SENDER => 
             format_xml_output($$type_hash{$type_name}{"description"}{"SENDER"}));
       }
       if ($$type_hash{$type_name}{"description"}{"TODO"} ne ""){
         $doc->dataElement( TODO => 
             format_xml_output($$type_hash{$type_name}{"description"}{"TODO"}));
       }
       if ($$type_hash{$type_name}{"description"}{"SCOPE"} ne ""){
         $doc->dataElement( SCOPE => 
             format_xml_output($$type_hash{$type_name}{"description"}{"SCOPE"}));
       }
       if ($$type_hash{$type_name}{"description"}{"MSG_ALIAS"} ne ""){
         $doc->dataElement( MSG_ALIAS => 
             format_xml_output($$type_hash{$type_name}{"description"}{"MSG_ALIAS"}));
       }
       $doc->endTag();
       $doc->startTag( "elementList" );
       if (defined($$type_hash{$type_name}{"elementList"})){
         if ($$type_hash{$type_name}{"type"} =~ /^u?enum/){
            xml_print_enum_list($$type_hash{$type_name}{"elementList"});
         }elsif($$type_hash{$type_name}{"type"} =~ /^mask/){
           xml_print_mask_list($$type_hash{$type_name}{"elementList"});
         }else{
            xml_print_element_list($$type_hash{$type_name}{"elementList"});
         }
       }       
       $doc->endTag();
       $doc->endTag();
     }
  }
  $doc->endTag();
}#  xml_print_types

#===========================================================================
#
#FUNCTION XML_PRINT_SERVICE
#
#DESCRIPTION
#  Outputs information for the service to XML format.
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  service information output in XML format
#
#===========================================================================
sub xml_print_service 
{
  my $service_hash = shift;
  $doc->startTag("section", title => "service");
  $doc->dataElement( identifier => format_xml_output($$service_hash{"identifier"}) );
  $doc->dataElement( serviceNumber => format_xml_output($$service_hash{"serviceNumber"}) );
  $doc->dataElement( versionNumber => format_xml_output($$service_hash{"version"}) );
  $doc->startTag( "messageList" );
  foreach (@{$$service_hash{"elementList"}})
  {
    $doc->startTag( "message", identifier => format_xml_output($_->{"identifier"}) );
    $doc->dataElement( type => format_xml_output($_->{"type"}) );
    $doc->dataElement( messageId => format_xml_output($_->{"messageId"}) );
    $doc->endTag();
  }
  $doc->endTag();
  $doc->endTag();
  $doc->end();
}#  xml_print_service

sub xml_print_footer 
{
  my $footer_order = shift;
  my $footer_hash = shift;
  $doc->startTag("section", title => "footer");
  if (defined($footer_order)) 
  {
    foreach (@{$footer_order}) 
    {
      $doc->startTag("appendix", title => format_xml_output($_));
      $doc->dataElement( body => format_xml_output($footer_hash->{$_}) );
      $doc->endTag();
    }
  }
  $doc->endTag();
}#  xml_print_footer

#===========================================================================
#
#FUNCTION XML_PRINT_ELEMENT_LIST
#
#DESCRIPTION
#  Prints a types element list to XML
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  element list output in XML format
#
#===========================================================================
sub xml_print_element_list 
{
  my $msg_list = shift;
  foreach (@$msg_list) 
  {
    $doc->startTag( "type", identifier => format_xml_output($_->{"identifier"}) );
    $doc->dataElement( command => 
               format_xml_output($_->{"command"}) );
    $doc->dataElement( carry_name => 
               format_xml_output($_->{"carry_name"}) );
    $doc->dataElement( document_as_mandatory => 
               format_xml_output($_->{"document_as_mandatory"}) );    
    $doc->dataElement( msg => 
               format_xml_output($_->{"msg"}) );
    $doc->dataElement( type => 
               format_xml_output($_->{"type"}) );
    $doc->dataElement( primitiveType => 
               format_xml_output($_->{"primitiveType"}) );
    $doc->dataElement( n => 
               format_xml_output($_->{"n"}) );
    $doc->dataElement( cSize => 
               format_xml_output($_->{"cSize"}) );
    $doc->dataElement( sizeof => 
               format_xml_output($_->{"sizeof"}) );
    $doc->dataElement( wireSize => 
               format_xml_output($_->{"wireSize"}) );
    $doc->dataElement( isVarWireSize => 
               format_xml_output($_->{"isVarWireSize"}) );
    $doc->dataElement( isArray => 
                       format_xml_output($_->{"isArray"}) );
    $doc->dataElement( isVarArray => 
                       format_xml_output($_->{"isVarArray"}) );
    $doc->dataElement( set16bitflag =>
                       format_xml_output($_->{"set16bitflag"}) );
    $doc->dataElement( set32bitflag =>
                       format_xml_output($_->{"set32bitflag"}) );
    $doc->dataElement( lenFieldOffset =>
                       format_xml_output($_->{"len_field_offset"}) );
    $doc->dataElement( isEnum => 
               format_xml_output($_->{"isEnum"}) );
    $doc->dataElement( isMask => 
               format_xml_output($_->{"isMask"}) );
    $doc->dataElement( isMessage => 
               format_xml_output($_->{"isMessage"}) );
    $doc->dataElement( isOptional => 
               format_xml_output($_->{"isOptional"}) );
    $doc->dataElement( isStruct => 
               format_xml_output($_->{"isStruct"}) );
    $doc->dataElement( isString => 
               format_xml_output($_->{"isString"}) );
    $doc->dataElement( isLengthless =>
                       format_xml_output($_->{"isLengthless"}) );
    $doc->dataElement( TLVType => 
               format_xml_output($_->{"TLVType"}) );
    $doc->dataElement( typeDescription => 
               format_xml_output($_->{"typeDescription"}) );
    $doc->dataElement( valueDescription => 
               format_xml_output($_->{"valueDescription"}) );
    $doc->dataElement( provisional => 
               format_xml_output($_->{"provisional"}) );
    $doc->startTag("allowedEnumVals");
    if (defined($_->{"allowedEnumVals"})) 
    {
      xml_print_enum_val_list($_->{"allowedEnumVals"});
    }
    $doc->endTag();
    $doc->dataElement( tlv_intro =>
                       format_xml_output($_->{"tlv_intro"}) );
    $doc->dataElement( tlvVersion =>
                       format_xml_output($_->{"tlv_version"}) );
    $doc->dataElement( tlv_version_introduced =>
                       format_xml_output($_->{"tlv_version_introduced"}) );
    $doc->dataElement( version => 
                       format_xml_output($_->{"version"}) );
    $doc->dataElement( tlvName =>
                       format_xml_output($_->{"tlv_name"}) );
    $doc->dataElement( fieldName =>
                       format_xml_output($_->{"field_name"}) );
    $doc->dataElement( lenField =>
                       format_xml_output($_->{"len_field"}) );
    $doc->dataElement( isDuplicate => 
                       format_xml_output($_->{"isDuplicate"}) );
    $doc->dataElement( isIncludeType =>
                       format_xml_output($_->{"isIncludeType"}) );
    $doc->startTag( "elementList" );
    if (defined($_->{"elementList"})) 
    {
      xml_print_element_list($_->{"elementList"});
    }
    $doc->endTag();
    $doc->startTag("rangeChecking");
    if ($_->{"rangeChecked"} == $TRUE)
    {
      my $range;
      $doc->dataElement( rangeCheckType => format_xml_output($_->{"rangeCheckType"}) );
      $doc->dataElement( rangeCheckResponse => format_xml_output($_->{"rangeCheckResponse"}) );
      #print STDERR Dumper($_);
      if ($_->{"rangeCheckType"} eq "QMI_IDL_RANGE_MASK")
      {
        $doc->dataElement( rangeMaskValue => format_xml_output($_->{"rangeValues"}) );
      }elsif($_->{"rangeCheckType"} eq "QMI_IDL_RANGE_ENUM")
      {
        my @range_array = @{$_->{"rangeValues"}};
        $doc->startTag("rangeEnumValues");
        foreach (@range_array)
        {
          $range = $_;
          $doc->startTag("Value");
          $doc->dataElement( minName => format_xml_output($range->{"minName"}) );
          $doc->dataElement( minVal => format_xml_output($range->{"min"}) );
          $doc->dataElement( maxName => format_xml_output($range->{"maxName"}) );
          $doc->dataElement( maxVal => format_xml_output($range->{"max"}) );
          $doc->endTag();
        }
        $doc->endTag();
      }else
      {
        my @range_array = @{$_->{"rangeValues"}};
        $doc->startTag("rangeEnumValues");
        foreach (@range_array)
        {
          $doc->dataElement( Value => format_xml_output($_) );
        }
        $doc->endTag();
      }
    }
    $doc->endTag();
    $doc->endTag();
  }
}#  xml_print_element_list

#===========================================================================
#
#FUNCTION XML_PRINT_ENUM_LIST
#
#DESCRIPTION
#  Outputs the elements of an enum in XML
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  enum list output in XML format
#
#===========================================================================
sub xml_print_enum_list 
{
  my $elm_list = shift;
  foreach (@$elm_list) 
  {
    $doc->emptyTag( "enum", identifier => @{$_}[0], value => @{$_}[1] );
  }
}#  xml_print_enum_list

sub xml_print_enum_val_list 
{
  my $enum_vals = shift;
  if (defined($$enum_vals{"valList"})) 
  {
    foreach (@{$$enum_vals{"valList"}}) 
    {
      $doc->startTag( "allowedVal", identifier => format_xml_output($_->{"identifier"}) );
      $doc->dataElement( value => format_xml_output($_->{"value"}));
      $doc->dataElement( description => format_xml_output($_->{"description"}));
      $doc->endTag();
    }
  }
}
#===========================================================================
#
#FUNCTION XML_PRINT_MASK_LIST
#
#DESCRIPTION
#  Outputs the elements of a mask in XML
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  mask list output in XML format
#
#===========================================================================
sub xml_print_mask_list 
{
  my $mask_list = shift;
  foreach (@$mask_list) 
  {
    $doc->emptyTag( "mask", identifier => @{$_}[0], value => @{$_}[1] );
  }
}#  xml_print_mask_list

#===========================================================================
#
#FUNCTION XML_PRINT_VERSION
#
#DESCRIPTION
#  Outputs the version information to XML
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  version numbers output in XML format
#
#===========================================================================
sub xml_print_version 
{
   my $maj_num = shift;
   my $min_num = shift;
   my $tool_maj_num = shift;
   my $tool_min_num = shift;
   my $spin_num = shift;

   $doc->startTag("section", title => "idl_version");
   $doc->dataElement( majorNumber => $maj_num );
   $doc->dataElement( minorNumber => $min_num );
   $doc->dataElement( toolMajorNumber => $tool_maj_num );
   $doc->dataElement( toolMinorNumber => $tool_min_num );
   $doc->dataElement( spinNumber => $spin_num );
   $doc->endTag();
   $doc->end();
}#  xml_print_version

1;
