#!/usr/local/bin/perl
# ========================================================================
#                Q M I _ I D L _ T E S T _ X M L _ . P M
#
# DESCRIPTION
#  Writes out the test formatted XML file
#
# REFERENCE
# 
# Copyright (c) 2011 by QUALCOMM Incorporated. All Rights Reserved.
# ========================================================================
# 
# $Header: //source/qcom/qct/core/mproc/tools_crm/idl_compiler/main/latest/customer/qmi_idl_msg_xml.pm#1 $
#
# ========================================================================
package qmi_idl_msg_xml;

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
our %EXPORT_TAGS = ( 'all' => [ qw(print_msg_xml
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
my %used_primitive_struct_types = ();
my %hex_conversion_values = (
   "enum8" => "256",
   "enum16" => "65536",
   "enum" => "4294967296",
);


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


sub print_msg_xml
{
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
   my $year = 1900 + (gmtime)[5];
   my $output;
   %used_primitive_struct_types = ();

   if ($out_method eq "") {
      $doc = new XML::Writer(DATA_MODE => 1, UNSAFE=> 1, DATA_INDENT =>2);
   }else{
      $output = new IO::File(">$out_method");
      $doc = new XML::Writer(OUTPUT => $output, DATA_MODE => 1, UNSAFE=> 1, DATA_INDENT =>2);
   }
   $doc->startTag("idldescription", idl => $idl);
   $doc->comment("Copyright (c) $year by Qualcomm Technologies, Inc. All Rights Reserved.");
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
}


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
  while ( my ($key, $value) = each(%$file_doc) ) 
  {
    $key = lc($key);
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
  $doc->startTag("section", title => "command documentation");
  foreach (@$command_order)
  {
    my $version = $$command_doc{$_}{"VERSION"};
    if (defined( $version ))
    {
      if ($version =~ m/(\d+\.\d+).*/)
      {
        $version = $1;
      }
    }
    $doc->startTag( "command", identifier => $_);
    $doc->dataElement( commandid =>
               format_xml_output($$command_doc{$_}{"commandid"}) ) if
             defined( $$command_doc{$_}{"commandid"} );
    $doc->dataElement( brief =>
               format_xml_output($$command_doc{$_}{"BRIEF"}) ) if
             defined( $$command_doc{$_}{"BRIEF"} );
    $doc->dataElement( description =>
               format_xml_output($$command_doc{$_}{"DESCRIPTION"}) ) if
             defined( $$command_doc{$_}{"DESCRIPTION"} );
    $doc->dataElement( errors =>
               format_xml_output($$command_doc{$_}{"ERROR"}) ) if
             defined( $$command_doc{$_}{"ERROR"} );
    $doc->dataElement( version => 
               format_xml_output($version) ) if 
             defined( $version );
    $doc->dataElement( provisional => 
             format_xml_output($$command_doc{$_}{"CMD_PROVISIONAL"}) ) if 
          defined( $$command_doc{$_}{"CMD_PROVISIONAL"} );
    $doc->dataElement( cmd_deprecated => 
             format_xml_output($$command_doc{$_}{"CMD_DEPRECATED"}) ) if 
          defined( $$command_doc{$_}{"CMD_DEPRECATED"} );
    $doc->dataElement( sequence => $xml_sequence_number );
    if (defined( $$command_doc{$_}{"ERROR"} ))
    {
      xml_parsed_error_list($$command_doc{$_}{"ERROR"});
    }
    $doc->endTag();
    $xml_sequence_number++;
  }
  $doc->endTag();
}#  xml_command_documentation

sub xml_parsed_error_list
{
  my $error_list = shift;
  $doc->startTag("parsederrors");
  $error_list =~ s/^\s*\n*//;
  $error_list =~ s/\n\s*/:::::/g;
  $error_list =~ s/^\s+//;

  while($error_list =~ s/^(\-.*?):::::(\-)/$2/)
  {
    my $desc = $1;
    if ($desc =~ m/\-(\S+)\s+(.*)/)
    {
      my $name = $1;
      my $desc = $2;
      $desc =~ s/\s+$//g;
      $desc =~ s/:::::/\n/g;
      $doc->startTag("error");
      $doc->dataElement( name => $name );
      $doc->dataElement( value => format_xml_output($desc) );
      $doc->endTag();
    }
  }
  if ($error_list =~ m/^(\-.*?):::::/)
  {
    my $desc = $1;
    if ($desc =~ m/\-(\S+)\s+(.*)/)
    {
      my $name = $1;
      my $desc = $2;
      $desc =~ s/\s+$//g;
      $desc =~ s/:::::/\n/g;
      $doc->startTag("error");
      $doc->dataElement( name => $name );
      $doc->dataElement( value => format_xml_output($desc) );
      $doc->endTag();
    }
  }
  $doc->endTag();
}

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
  if (ref($include_files) eq "ARRAY") 
  {
     foreach (@$include_files)
     {
       my $msg_xml_name = $_;
       $msg_xml_name =~ s/\.idl/\.xml/g;
       $msg_xml_name =~ s/(_v\d\d)/_msg_xml$1/;
       $doc->dataElement( file => format_xml_output($msg_xml_name));
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
       $doc->dataElement( isinteger => format_xml_output($$const_hash{$_}{"isInteger"}) );
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

sub xml_print_len_field 
{
  my $name = shift;
  my $wire_size = shift;
  my $type = shift;

  $doc->startTag( "type", identifier => format_xml_output($name) );
  $doc->dataElement( command => "" );
  $doc->dataElement( msg => "" );
  $doc->dataElement( type => format_xml_output($type) );
  $doc->dataElement( primitivetype => format_xml_output($type) );
  $doc->dataElement( n => 1 );
  $doc->dataElement( sizeof => "" );
  $doc->dataElement( wiresize => format_xml_output($wire_size) );
  $doc->dataElement( isvarwiresize => 0 );
  $doc->dataElement( isarray => 0 );
  $doc->dataElement( isvararray => 0 );
  $doc->dataElement( set16bitflag => 0 );
  $doc->dataElement( set32bitflag => 0 );
  $doc->dataElement( isenum => 0 );
  $doc->dataElement( ismask => 0 );
  $doc->dataElement( ismessage => 0 );
  $doc->dataElement( isoptional => 0 );
  $doc->dataElement( isstruct => 0 );
  $doc->dataElement( isstring => 0 );
  $doc->dataElement( islengthless => 0 );
  $doc->dataElement( tlvtype => 0 );
  $doc->dataElement( typedescription => "" );
  $doc->dataElement( valuedescription => "" );
  $doc->dataElement( allowedenumvals => "" );
  $doc->dataElement( tlvversion => "" );
  $doc->dataElement( tlvname => "" );
  $doc->dataElement( fieldname => "" );
  $doc->dataElement( lenfield => "" );
  $doc->dataElement( carryname => "");
  $doc->startTag( "elementlist" );
  $doc->endTag();
  $doc->startTag("rangechecking");
  $doc->endTag();
  $doc->endTag();
}
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
  my $is_top_level = $FALSE;
  my @primitive_list;
  $doc->startTag("section", title => "types");
  if (ref($type_order) eq "ARRAY") {
     foreach (@$type_order) {
       $is_top_level = $FALSE;
       @primitive_list = ();
       if ($$type_hash{$_}{"isMessage"}) 
       {
         $is_top_level = $TRUE;
       }
       if ($$type_hash{$_}{"isMask"}) 
       {
         #$$type_hash{$_}{"isEnum"} = 1;
       }
       $doc->startTag( "type", identifier => format_xml_output($_) );
       $doc->dataElement( command => format_xml_output($$type_hash{$_}{"command"}) );
       $doc->dataElement( msg => format_xml_output($$type_hash{$_}{"msg"}) );
       $doc->dataElement( msgalias => format_xml_output($$type_hash{$_}{"msgAlias"}) );
       $doc->dataElement( type => format_xml_output($$type_hash{$_}{"type"}) );
       $doc->dataElement( n => format_xml_output($$type_hash{$_}{"n"}) );
       $doc->dataElement( sizeof => format_xml_output($$type_hash{$_}{"sizeof"}) );
       $doc->dataElement( wiresize => format_xml_output($$type_hash{$_}{"wireSize"}) );
       $doc->dataElement( isvarwiresize => format_xml_output($$type_hash{$_}{"isVarWireSize"}) );
       $doc->dataElement( isarray => format_xml_output($$type_hash{$_}{"isArray"}) );
       $doc->dataElement( isvararray => format_xml_output($$type_hash{$_}{"isVarArray"}) );
       $doc->dataElement( isenum => format_xml_output($$type_hash{$_}{"isEnum"}) );
       $doc->dataElement( ismask => format_xml_output($$type_hash{$_}{"isMask"}) );
       $doc->dataElement( ismessage => format_xml_output($$type_hash{$_}{"isMessage"}) );
       $doc->dataElement( isoptional => format_xml_output($$type_hash{$_}{"isOptional"}) );
       $doc->dataElement( isstruct => format_xml_output($$type_hash{$_}{"isStruct"}) );
       $doc->dataElement( isstring => format_xml_output($$type_hash{$_}{"isString"}) );
       $doc->dataElement( islengthless =>format_xml_output($$type_hash{$_}{"isLengthless"}) );
       $doc->dataElement( set16bitflag =>format_xml_output($$type_hash{$_}{"set16bitflag"}) );
       $doc->dataElement( set32bitflag =>format_xml_output($$type_hash{$_}{"set32bitflag"}) );
       $doc->dataElement( tlvtype => format_xml_output($$type_hash{$_}{"TLVType"}) );
       $doc->dataElement( sequence => format_xml_output($$type_hash{$_}{"sequence"}) );
       $doc->startTag( "description" );
       if ($$type_hash{$_}{"description"}{"TYPE"} ne ""){
         $doc->dataElement( type => 
             format_xml_output($$type_hash{$_}{"description"}{"TYPE"}));
       }
       if ($$type_hash{$_}{"description"}{"SENDER"} ne ""){
         $doc->dataElement( sender => 
             format_xml_output($$type_hash{$_}{"description"}{"SENDER"}));
       }
       if ($$type_hash{$_}{"description"}{"TODO"} ne ""){
         $doc->dataElement( todo => 
             format_xml_output($$type_hash{$_}{"description"}{"TODO"}));
       }
       if ($$type_hash{$_}{"description"}{"SCOPE"} ne ""){
         $doc->dataElement( scope => 
             format_xml_output($$type_hash{$_}{"description"}{"SCOPE"}));
       }
       if ($$type_hash{$_}{"description"}{"MSG_ALIAS"} ne ""){
         $doc->dataElement( msgalias => 
             format_xml_output($$type_hash{$_}{"description"}{"MSG_ALIAS"}));
       }
       $doc->endTag();
       $doc->startTag( "elementlist" );

       if (defined($$type_hash{$_}{"elementList"})){
         if ($$type_hash{$_}{"type"} =~ /^u?enum/){
            xml_print_enum_list($$type_hash{$_}{"elementList"},$$type_hash{$_}{"type"});
         }elsif($$type_hash{$_}{"type"} =~ /^mask/){
           xml_print_mask_list($$type_hash{$_}{"elementList"});
         }else{
            xml_print_element_list($$type_hash{$_}{"elementList"}, $is_top_level, \@primitive_list,"");
         }
       }
       $doc->endTag();
       $doc->endTag();       
       xml_print_primitive_elements(\@primitive_list);
     }
  }
  $doc->endTag();
}#  xml_print_types

sub xml_print_primitive_elements 
{
  my $primitive_list = shift;
  my $primitive_struct_name;
  foreach (@{$primitive_list}) 
  {
    $primitive_struct_name = "";
    $primitive_struct_name .= $_->{"identifier"} . "_" . $_->{"type"} . "_";
    if ($_->{"isVarArray"}) 
    {
      $primitive_struct_name .= "vararray_" . $_->{"n"} . "_type";
    }elsif($_->{"isArray"})
    {
      $primitive_struct_name .= "array_" . $_->{"n"} . "_type";
    }elsif($_->{"isString"})
    {
      $primitive_struct_name .= "string_" . $_->{"n"} . "_type";
    }else
    {
      $primitive_struct_name .= "type";
    }
    if (defined($used_primitive_struct_types{$primitive_struct_name})) 
    {
      next;
    }
    $used_primitive_struct_types{$primitive_struct_name} = 1;
    $doc->startTag( "type", identifier => $primitive_struct_name );
    $doc->dataElement( command => 
                       format_xml_output($_->{"command"}) );
    $doc->dataElement( msg => 
                       format_xml_output($_->{"msg"}) );
    $doc->dataElement( type => 
                       format_xml_output($_->{"type"}) );
    $doc->dataElement( primitivetype => 
                       "struct" );
    $doc->dataElement( n => 
                       1 );
    $doc->dataElement( sizeof => 
                       format_xml_output($_->{"sizeof"}) );
    $doc->dataElement( wiresize => 
                       format_xml_output($_->{"wireSize"}) );
    $doc->dataElement( isvarwiresize => 
                       format_xml_output($_->{"isVarWireSize"}) );
    $doc->dataElement( isarray => 
                       0 );
    $doc->dataElement( isvararray => 
                       0 );
    $doc->dataElement( set16bitflag =>
                       format_xml_output($_->{"set16bitflag"}) );
    $doc->dataElement( set32bitflag =>
                       format_xml_output($_->{"set32bitflag"}) );
    $doc->dataElement( lenfieldoffset =>
                       format_xml_output($_->{"len_field_offset"}) );
    $doc->dataElement( isenum => 
                       0 );
    $doc->dataElement( ismask => 
                       0 );
    $doc->dataElement( ismessage => 
                       0 );
    $doc->dataElement( isoptional => 
                       0 );
    $doc->dataElement( isstruct => 
                       1 );
    $doc->dataElement( isstring => 
                       0 );
    $doc->dataElement( islengthless =>
                       0 );
    $doc->dataElement( tlvtype => 
                       "" );
    $doc->dataElement( typedescription => 
                       format_xml_output($_->{"typeDescription"}) );
    $doc->dataElement( valuedescription => 
                       format_xml_output($_->{"valueDescription"}) );
    $doc->startTag("allowedenumvals");
    if (defined($_->{"allowedEnumVals"})) 
    {
      xml_print_enum_val_list($_->{"allowedEnumVals"});
    }
    $doc->endTag();
    my $tlvversion = $_->{"tlv_version"};
    if ($tlvversion =~ m/(\d+\.\d+).*/)
    {
      $tlvversion = $1;
    }
    $doc->dataElement( tlvversion =>
                       format_xml_output($tlvversion) );
    $doc->dataElement( tlvname =>
                       "" );
    $doc->dataElement( fieldname =>
                       format_xml_output($_->{"field_name"}) );
    $doc->dataElement( lenfield =>
                       format_xml_output($_->{"len_field"}) );
    $doc->dataElement( carryname => "");
    $doc->startTag( "elementlist" );
    if (($_->{"isVarArray"} || $_->{"isString"}) && !$_->{"isLengthless"} ) 
    {
      my $wire_size = 1;
      my $type = "uint8";
      if ($_->{"set16bitflag"}) 
      {
        $wire_size = 2;
        $type = "uint16";
      }elsif ($_->{"set32bitflag"})
      {
        $wire_size = 4;
        $type = "uint32";
      }
      xml_print_len_field($_->{"len_field"},$wire_size,$type);
    }
    if ($_->{"primitiveType"} =~ m/mask/) 
    {
      #$_->{"primitiveType"} = "enum" . $_->{"primitiveType"};
      #$_->{"isEnum"} = $_->{"isMask"};
    }
    $doc->startTag( "type", identifier => format_xml_output($_->{"identifier"}) );
    $doc->dataElement( command => 
                       format_xml_output($_->{"command"}) );
    $doc->dataElement( msg => 
                       format_xml_output($_->{"msg"}) );
    $doc->dataElement( type => 
                       format_xml_output($_->{"type"}) );
    $doc->dataElement( primitivetype => 
                       format_xml_output($_->{"primitiveType"}) );
    $doc->dataElement( n => 
                       format_xml_output($_->{"n"}) );
    $doc->dataElement( sizeof => 
                       format_xml_output($_->{"sizeof"}) );
    $doc->dataElement( wiresize => 
                       format_xml_output($_->{"wireSize"}) );
    $doc->dataElement( isvarwiresize => 
                       format_xml_output($_->{"isVarWireSize"}) );
    $doc->dataElement( isarray => 
                       format_xml_output($_->{"isArray"}) );
    $doc->dataElement( isvararray => 
                       format_xml_output($_->{"isVarArray"}) );
    $doc->dataElement( set16bitflag =>
                       format_xml_output($_->{"set16bitflag"}) );
    $doc->dataElement( set32bitflag =>
                       format_xml_output($_->{"set32bitflag"}) );
    $doc->dataElement( isenum => 
                       format_xml_output($_->{"isEnum"}) );
    $doc->dataElement( ismask => 
                       format_xml_output($_->{"isMask"}) );
    $doc->dataElement( ismessage => 
                       format_xml_output($_->{"isMessage"}) );
    $doc->dataElement( isoptional => 
                       format_xml_output($_->{"isOptional"}) );
    $doc->dataElement( isstruct => 
                       format_xml_output($_->{"isStruct"}) );
    $doc->dataElement( isstring => 
                       format_xml_output($_->{"isString"}) );
    $doc->dataElement( islengthless =>
                         format_xml_output($_->{"isLengthless"}) );
    $doc->dataElement( tlvtype => 
                       format_xml_output($_->{"TLVType"}) );
    $doc->dataElement( typedescription => 
                       format_xml_output($_->{"typeDescription"}) );
    $doc->dataElement( valuedescription => 
                       format_xml_output($_->{"valueDescription"}) );
    $doc->startTag("allowedenumvals");
    if (defined($_->{"allowedEnumVals"})) 
    {
      xml_print_enum_val_list($_->{"allowedEnumVals"});
    }
    $doc->endTag();
    $tlvversion = $_->{"tlv_version"};
    if ($tlvversion =~ m/(\d+\.\d+).*/)
    {
      $tlvversion = $1;
    }
    $doc->dataElement( tlvversion =>
                       format_xml_output($tlvversion) );
    $doc->dataElement( tlvname =>
                       format_xml_output($_->{"tlv_name"}) );
    $doc->dataElement( fieldname =>
                       format_xml_output($_->{"field_name"}) );
    $doc->dataElement( lenfield =>
                       format_xml_output($_->{"len_field"}) );
    $doc->dataElement( carryname => "");
    $doc->startTag( "elementlist" );
    $doc->endTag();
    $doc->startTag("rangechecking");
    $doc->endTag();
    $doc->endTag();
    $doc->endTag();
    $doc->endTag();
  }
}
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
  $doc->dataElement( servicenumber => format_xml_output($$service_hash{"serviceNumber"}) );
  $doc->dataElement( versionnumber => format_xml_output($$service_hash{"version"}) );
  $doc->startTag( "messagelist" );
  foreach (@{$$service_hash{"elementList"}})
  {
    $doc->startTag( "message", identifier => format_xml_output($_->{"identifier"}) );
    $doc->dataElement( type => format_xml_output($_->{"type"}) );
    $doc->dataElement( messageid => format_xml_output($_->{"messageId"}) );
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
  my $top_level = shift;
  my $primitive_list = shift;
  my $primitive_struct_name = "";
  foreach (@$msg_list) 
  {
    if ((($_->{"primitiveType"} ne "struct") ||
        (($_->{"isVarArray"} || $_->{"isString"}) &&
        !$_->{"isLengthless"}))
        && $top_level)
    {
      $primitive_struct_name = "";
      $primitive_struct_name .= $_->{"identifier"} . "_" . $_->{"type"} . "_";
      if ($_->{"isVarArray"}) 
      {
        $primitive_struct_name .= "vararray_" . $_->{"n"} . "_type";
      }elsif($_->{"isArray"})
      {
        $primitive_struct_name .= "array_" . $_->{"n"} . "_type";
      }elsif($_->{"isString"})
      {
        $primitive_struct_name .= "string_" . $_->{"n"} . "_type";
      }else
      {
        $primitive_struct_name .= "type";
      }
      $doc->startTag( "type", identifier => format_xml_output($_->{"identifier"}) );
      $doc->dataElement( command => 
                         format_xml_output($_->{"command"}) );
      $doc->dataElement( msg => 
                         format_xml_output($_->{"msg"}) );
      $doc->dataElement( type => 
                         $primitive_struct_name );
      $doc->dataElement( primitivetype => 
                         "struct" );
      $doc->dataElement( n => 
                         1 );
      $doc->dataElement( sizeof => 
                         format_xml_output($_->{"sizeof"}) );
      $doc->dataElement( wiresize => 
                         format_xml_output($_->{"wireSize"}) );
      $doc->dataElement( isvarwiresize => 
                         format_xml_output($_->{"isVarWireSize"}) );
      $doc->dataElement( isarray => 
                         format_xml_output($_->{"isArray"}) );
      if ($_->{"primitiveType"} eq "struct") 
      {
        $doc->dataElement( isvararray => 
                           format_xml_output($_->{"isVarArray"}) );
      }else
      {
        $doc->dataElement( isvararray =>
                           0 );
      }
      $doc->dataElement( set16bitflag =>
                         format_xml_output($_->{"set16bitflag"}) );
      $doc->dataElement( set32bitflag =>
                         format_xml_output($_->{"set32bitflag"}) );
      $doc->dataElement( isenum => 
                         0 );
      $doc->dataElement( ismask => 
                         0 );
      $doc->dataElement( ismessage => 
                         format_xml_output($_->{"isMessage"}) );
      $doc->dataElement( isoptional => 
                         format_xml_output($_->{"isOptional"}) );
      $doc->dataElement( isstruct => 
                         1 );
      $doc->dataElement( isstring => 
                         0 );
      $doc->dataElement( islengthless =>
                         0 );
      $doc->dataElement( tlvtype => 
                         format_xml_output($_->{"TLVType"}) );
      $doc->dataElement( typedescription => 
                         format_xml_output($_->{"typeDescription"}) );
      $doc->dataElement( valuedescription => 
                         format_xml_output($_->{"valueDescription"}) );
      $doc->startTag("allowedenumvals");
      if (defined($_->{"allowedEnumVals"})) 
      {
        xml_print_enum_val_list($_->{"allowedEnumVals"});
      }
      $doc->endTag();
      my $tlvversion = $_->{"tlv_version"};
      if ($tlvversion =~ m/(\d+\.\d+).*/)
      {
        $tlvversion = $1;
      }
      $doc->dataElement( tlvversion =>
                         format_xml_output($tlvversion) );
      $doc->dataElement( tlvname =>
                         format_xml_output($_->{"tlv_name"}) );
      $doc->dataElement( fieldname =>
                         format_xml_output($_->{"field_name"}) );
      $doc->dataElement( lenfield =>
                         format_xml_output($_->{"len_field"}) );
      $doc->dataElement( carryname => "");
      $doc->startTag( "elementlist" );
      $doc->endTag();
      $doc->startTag("rangeChecking");
      $doc->endTag();
      $doc->endTag();
      push(@{$primitive_list},$_);
    }else
    {
      if (($_->{"isVarArray"} || $_->{"isString"}) && !$_->{"isLengthless"} ) 
      {
        my $wire_size = 1;
        my $type = "uint8";
        if ($_->{"set16bitflag"}) 
        {
          $wire_size = 2;
          $type = "uint16";
        }elsif ($_->{"set32bitflag"})
        {
          $wire_size = 4;
          $type = "uint32";
        }
        xml_print_len_field($_->{"len_field"},$wire_size,$type);
      }
      if ($_->{"primitiveType"} =~ m/mask/) 
      {
        #$_->{"primitiveType"} = "enum" . $_->{"primitiveType"};
        #$_->{"isEnum"} = $_->{"isMask"};
      }
      $doc->startTag( "type", identifier => format_xml_output($_->{"identifier"}) );
      $doc->dataElement( command => 
                         format_xml_output($_->{"command"}) );
      $doc->dataElement( msg => 
                         format_xml_output($_->{"msg"}) );
      $doc->dataElement( type => 
                         format_xml_output($_->{"type"}) );
      $doc->dataElement( primitivetype => 
                         format_xml_output($_->{"primitiveType"}) );
      $doc->dataElement( n => 
                         format_xml_output($_->{"n"}) );
      $doc->dataElement( sizeof => 
                         format_xml_output($_->{"sizeof"}) );
      $doc->dataElement( wiresize => 
                         format_xml_output($_->{"wireSize"}) );
      $doc->dataElement( isvarwiresize => 
                         format_xml_output($_->{"isVarWireSize"}) );
      $doc->dataElement( isarray => 
                         format_xml_output($_->{"isArray"}) );
      $doc->dataElement( isvararray => 
                         format_xml_output($_->{"isVarArray"}) );
      $doc->dataElement( set16bitflag =>
                         format_xml_output($_->{"set16bitflag"}) );
      $doc->dataElement( set32bitflag =>
                         format_xml_output($_->{"set32bitflag"}) );
      $doc->dataElement( isenum => 
                         format_xml_output($_->{"isEnum"}) );
      $doc->dataElement( ismask => 
                         format_xml_output($_->{"isMask"}) );
      $doc->dataElement( ismessage => 
                         format_xml_output($_->{"isMessage"}) );
      $doc->dataElement( isoptional => 
                         format_xml_output($_->{"isOptional"}) );
      $doc->dataElement( isstruct => 
                         format_xml_output($_->{"isStruct"}) );
      $doc->dataElement( isstring => 
                         format_xml_output($_->{"isString"}) );
      $doc->dataElement( islengthless =>
                         format_xml_output($_->{"isLengthless"}) );
      $doc->dataElement( tlvtype => 
                         format_xml_output($_->{"TLVType"}) );
      $doc->dataElement( typedescription => 
                         format_xml_output($_->{"typeDescription"}) );
      $doc->dataElement( valuedescription => 
                         format_xml_output($_->{"valueDescription"}) );
      $doc->startTag("allowedenumvals");
      if (defined($_->{"allowedEnumVals"})) 
      {
        xml_print_enum_val_list($_->{"allowedEnumVals"});
      }
      $doc->endTag();
      my $tlvversion = $_->{"tlv_version"};
      if ($tlvversion =~ m/(\d+\.\d+).*/)
      {
        $tlvversion = $1;
      }
      $doc->dataElement( tlvversion =>
                         format_xml_output($tlvversion) );
      $doc->dataElement( tlvname =>
                         format_xml_output($_->{"tlv_name"}) );
      $doc->dataElement( fieldname =>
                         format_xml_output($_->{"field_name"}) );
      $doc->dataElement( lenfield =>
                         format_xml_output($_->{"len_field"}) );
      $doc->dataElement( carryname => $_->{'carry_name'});
      $doc->startTag( "elementlist" );

      if (defined($_->{"elementList"})) 
      {
        xml_print_element_list($doc,$_->{"elementList"}, $FALSE);
      }
      $doc->endTag();
      $doc->startTag("rangechecking");
      if ($_->{"rangeChecked"} == $TRUE)
      {
        my $range;
        $doc->dataElement( rangechecktype => format_xml_output($_->{"rangeCheckType"}) );
        $doc->dataElement( rangecheckresponse => format_xml_output($_->{"rangeCheckResponse"}) );
        if ($_->{"rangeCheckType"} eq "QMI_IDL_RANGE_MASK")
        {
          $doc->dataElement( rangemaskvalue => format_xml_output($_->{"rangeValues"}) );
        }elsif($_->{"rangeCheckType"} eq "QMI_IDL_RANGE_ENUM")
        {
          my @range_array = @{$_->{"rangeValues"}};
          $doc->startTag("rangeenumvalues");
          foreach (@range_array)
          {
            $range = $_;
            $doc->startTag("value");
            $doc->dataElement( minname => format_xml_output($range->{"minName"}) );
            $doc->dataElement( minval => format_xml_output($range->{"min"}) );
            $doc->dataElement( maxname => format_xml_output($range->{"maxName"}) );
            $doc->dataElement( maxval => format_xml_output($range->{"max"}) );
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
  my $enum_type = shift;
  foreach (@$elm_list) 
  {
    if (@{$_}[1] !~ m/^0x/) 
    {
      if (@{$_}[1] < 0) 
      {
        @{$_}[1] += $hex_conversion_values{$enum_type};
      }
      @{$_}[1] = sprintf("0x%X", @{$_}[1]);
    }
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
      $doc->startTag( "allowedval", identifier => format_xml_output($_->{"identifier"}) );
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
   $doc->dataElement( majornumber => $maj_num );
   $doc->dataElement( minornumber => $min_num );
   $doc->dataElement( toolmajornumber => $tool_maj_num );
   $doc->dataElement( toolminornumber => $tool_min_num );
   $doc->dataElement( spinnumber => $spin_num );
   $doc->endTag();
   $doc->end();
}#  xml_print_version

1;

