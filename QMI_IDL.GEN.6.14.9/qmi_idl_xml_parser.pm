#!/usr/local/bin/perl
# ========================================================================
#                Q M I _ I D L _ X M L _ P A R S E R . P M
#
# DESCRIPTION
#  Parses the XML files that are used as inputs to the qmi_idl_compiler
#  program and returns the parsed values as hashes
#
# REFERENCE
# 
# Copyright (c) 2011 by QUALCOMM Incorporated. All Rights Reserved.
# ========================================================================
# 
# $Header: //source/qcom/qct/core/mproc/tools_crm/idl_compiler/main/latest/customer/qmi_idl_xml_parser.pm#1 $
#
# ========================================================================
package qmi_idl_xml_parser;

use strict;
use warnings;

require Exporter;
#use XML::Writer;
use Data::Dumper;
use File::Basename;
use IO::File;
eval {require XML::Simple;};

our @ISA = qw(Exporter);

#Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration       use IDLCompiler::IDLOutput ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(parse_golden_xml
                                   parse_config_xml) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

my $TRUE = 1;
my $FALSE = 0;
#The following values index into the golden XML hash
my $XMLFILEDOC = 0;                           
my $XMLCOMDOC = 1;                           
my $XMLINCFILES = 2;                           
my $XMLCONSTS = 3;
my $XMLTYPEDEFS = 4;
my $XMLSEQUENCES = 5;                           
my $XMLTYPES = 6;                           
my $XMLSERVICE = 7;                           
my $XMLFOOTER = 8;
my $XMLVERSIONS = 9;

#===========================================================================
#
#FUNCTION PARSE_GOLDEN_XML
#
#DESCRIPTION
#  
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  Returns a hash populated with fields from the golden XML
#
#SIDE EFFECTS
#  
#
#===========================================================================
sub parse_golden_xml 
{
   my $filename = shift;
   my %type_hash = ();
   my $parser = new XML::Simple;
   #Call the function to parse the XML file
   my $doc = $parser->XMLin($filename);
   #Store the parsed information into a hash
   #Start with consts
   if(defined($doc->{'section'}[$XMLCONSTS]{'const'})) 
   {
      if(ref($doc->{'section'}[$XMLCONSTS]{'const'}) eq "ARRAY") 
      {
         foreach(@{$doc->{'section'}[$XMLCONSTS]{'const'}}) 
         {
            $type_hash{"consts"}{$_->{"identifier"}} = $_;
         }
      }else
      {
         $type_hash{"consts"}{$doc->{'section'}[$XMLCONSTS]{'const'}->{"identifier"}} = $doc->{'section'}[$XMLCONSTS]{'const'};
      }
   }
   #Then typedefs
   if(defined($doc->{'section'}[$XMLTYPEDEFS]{'typedef'})) 
   {
      if(ref($doc->{'section'}[$XMLTYPEDEFS]{'typedef'}) eq "ARRAY") 
      {
         foreach(@{$doc->{'section'}[$XMLTYPEDEFS]{'typedef'}}) 
         {
            $type_hash{"typedefs"}{$_->{"identifier"}} = $_;
         }
      }else
      {
         $type_hash{"typedefs"}{$doc->{'section'}[$XMLTYPEDEFS]{'typedef'}->{"identifier"}} = $doc->{'section'}[$XMLTYPEDEFS]{'typedef'};
      }
   }
   #Then Types
   if(defined($doc->{'section'}[$XMLTYPES]{'type'})) 
   {
      if(ref($doc->{'section'}[$XMLTYPES]{'type'}) eq "ARRAY") 
      {
         @{$type_hash{"user_types_order"}} = ();
         my $j =0;
         foreach(@{$doc->{'section'}[$XMLTYPES]{'type'}}) 
         {
            $type_hash{"user_types_order"}[$j++] = $_->{'identifier'};     
            $type_hash{"types"}{$_->{"identifier"}} = $_;
         }
      }else
      {
         $type_hash{"types"}{$doc->{'section'}[$XMLTYPES]{'type'}->{"identifier"}} = $doc->{'section'}[$XMLTYPES]{'type'};
      }
   }

   $type_hash{"service"} = $doc->{'section'}[$XMLSERVICE];
   $type_hash{"sequence"}{"types"} = $doc->{"section"}[$XMLSEQUENCES]{"types"};
   $type_hash{"sequence"}{"msgs"} = $doc->{"section"}[$XMLSEQUENCES]{"msgs"};
   $type_hash{"version"}{"major"} = $doc->{"section"}[$XMLVERSIONS]{"majorNumber"};
   $type_hash{"version"}{"minor"} = $doc->{"section"}[$XMLVERSIONS]{"minorNumber"};
   $type_hash{"version"}{"tool_major"} = $doc->{"section"}[$XMLVERSIONS]{"toolMajorNumber"};
   $type_hash{"version"}{"tool_minor"} = $doc->{"section"}[$XMLVERSIONS]{"toolMinorNumber"};
   $type_hash{"version"}{"spin"} = $doc->{"section"}[$XMLVERSIONS]{"spinNumber"};
   
   #Adding to the hash what files are included in the idl
   if(defined($doc->{'section'}[$XMLINCFILES]{'file'})) 
   {
      $type_hash{"include_files"} = $doc->{'section'}[$XMLINCFILES]{'file'};      
   }
   

   #Adding all the documentation information to the hash 
   #First General
   if(defined($doc->{'section'}[$XMLFILEDOC]{'BRIEF'})) 
   {
      $type_hash{"file_documentation"}->{"BRIEF"} = $doc->{"section"}->[$XMLFILEDOC]->{"BRIEF"};      
   }   
   if(defined($doc->{'section'}[$XMLFILEDOC]{'DESCRIPTION'})) 
   {
      $type_hash{"file_documentation"}->{"DESCRIPTION"} = $doc->{"section"}->[$XMLFILEDOC]->{"DESCRIPTION"};      
   }   
   if(defined($doc->{'section'}[$XMLFILEDOC]{'NAME'})) 
   {
      $type_hash{"file_documentation"}->{"NAME"} = $doc->{"section"}->[$XMLFILEDOC]->{"NAME"};      
   }

   #Then Command Documentation
   if(defined($doc->{'section'}[$XMLCOMDOC]{'command'})) 
   {
      @{$type_hash{"command_order"}} = ();
      if(ref($doc->{'section'}[$XMLCOMDOC]{'command'}) eq "ARRAY") 
      {         
         my $j =0;
         foreach(@{$doc->{'section'}[$XMLCOMDOC]{'command'}}) 
         {                        
            $type_hash{"command_order"}[$j++] = $_->{'identifier'};             
            $type_hash{"command_documentation"}{$_->{"identifier"}}{"BRIEF"} = $_->{'brief'};
            $type_hash{"command_documentation"}{$_->{"identifier"}}{"CMD_VERSION"} = $_->{'Cmd_Version'};
            $type_hash{"command_documentation"}{$_->{"identifier"}}{"DESCRIPTION"} = $_->{'description'};
            $type_hash{"command_documentation"}{$_->{"identifier"}}{"ERROR"} = $_->{'errors'};
            $type_hash{"command_documentation"}{$_->{"identifier"}}{"commandid"} = $_->{'commandID'};
         }         
      }else
      {
         $type_hash{"command_order"}[0] = $doc->{'section'}[$XMLCOMDOC]{'command'}->{'identifier'};         
         $type_hash{"command_documentation"}{$doc->{'section'}[$XMLCOMDOC]{'command'}->{"identifier"}} = $doc->{'section'}[$XMLCOMDOC]{'command'};         
      }      
   }
   
   #Then Footer   
   if(defined($doc->{'section'}[$XMLFOOTER]{'appendix'}))    
   {   
      @{$type_hash{"footer_order"}} = ();
      my $i =0;            
      if(ref($doc->{'section'}[$XMLFOOTER]{'appendix'}) eq "ARRAY") 
      {         
         foreach(@{$doc->{'section'}[$XMLFOOTER]{'appendix'}}) 
         {
            $type_hash{"footer_order"}[$i++] = $_->{'title'};
            if(ref($_->{'body'}) eq "HASH")
            {
              if(!%{$_->{'body'}})
              {
                 #empty
                 $type_hash{"footer"}{$_->{'title'}} = "";
                 next;
              }
            }            
            $type_hash{"footer"}{$_->{'title'}} = $_->{'body'};
         }
      }
      else
      {
         my $title = $doc->{'section'}[$XMLFOOTER]->{'appendix'}->{'title'};
         $type_hash{"footer_order"}[0] = $title;
         if(ref($doc->{'section'}[$XMLFOOTER]{'appendix'}{'body'}) eq "HASH")
         {            
            if(!%{$doc->{'section'}[$XMLFOOTER]{'appendix'}{'body'}})
            {               
               #empty
               $doc->{"section"}[$XMLFOOTER]{"appendix"}{"body"} = "";                           
            }            
         }         
         $type_hash{"footer"}{$title} = $doc->{'section'}[$XMLFOOTER]{'appendix'}{'body'};                                     
      }           
   }

   return \%type_hash;
}#  parse_golden_xml

#===========================================================================
#
#FUNCTION PARSE_CONFIG_XML
#
#DESCRIPTION
#  Reads the config XML and formats it into a hash
#
#DEPENDENCIES
#  
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  config_hash populated with fields from the config XML
#
#===========================================================================
sub parse_config_xml 
{
   my $config_file = shift;
   my $config_hash = shift;
   my $parser = new XML::Simple;
   my $env;

   #Call the function to parse the XML file
   my $doc = $parser->XMLin($config_file);
   $$config_hash{"copyright"} = $doc->{"copyright"};
   $$config_hash{"p4info"} = $doc->{"p4info"};
   if(defined($doc->{"legacyServices"}))
   {
      if(ref($doc->{"legacyServices"}{"service"}) eq "ARRAY") 
      {
         foreach(@{$doc->{"legacyServices"}{"service"}})
         {
            $$config_hash{"legacy_services"}{$_} = $TRUE;
         }
      }else
      {
         $$config_hash{"legacy_services"}{$doc->{"legacyServices"}{"service"}} = $TRUE;
      }
   }
   if(defined($doc->{"environment"})) 
   {
      if(ref($doc->{"environment"}) eq "ARRAY") 
      {
         foreach(@{$doc->{"environment"}})
         {
            $env = $_->{"env"};
            $$config_hash{"environments"}{$env} = $_;
            if(ref($$config_hash{"environments"}{$env}{"service"}) eq "ARRAY") 
            {
               foreach(@{$$config_hash{"environments"}{$env}{"service"}})
               {
                  my $id = $_->{"identifier"};
                  $$config_hash{"environments"}{$env}{"services"}{$id} = $_;
               }
            }else
            {
               my $id = $$config_hash{"environments"}{$env}{"service"}{"identifier"};
               $$config_hash{"environments"}{$env}{"services"}{$id} = $$config_hash{"environments"}{$env}{"service"};
            }
            undef $$config_hash{"environments"}{$env}{"service"};
         }
      }else
      {
         $env = $doc->{"environment"}{"env"};
         $$config_hash{"environments"}{$env} = $doc->{"environment"};
         if(ref($$config_hash{"environments"}{$env}{"service"}) eq "ARRAY") 
         {
            foreach(@{$$config_hash{"environments"}{$env}{"service"}})
            {
               my $id = $_->{"identifier"};
               $$config_hash{"environments"}{$env}{"services"}{$id} = $_;
            }
         }else
         {
            my $id = $$config_hash{"environments"}{$env}{"service"}{"identifier"};
            $$config_hash{"environments"}{$env}{"services"}{$id} = $$config_hash{"environments"}{$env}{"service"};
         }
         undef $$config_hash{"environments"}{$env}{"service"};
      }
   }
   return;
}#  parse_config_xml

1;

