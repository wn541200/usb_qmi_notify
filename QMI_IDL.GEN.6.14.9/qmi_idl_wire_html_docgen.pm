#!/usr/local/bin/perl
# ========================================================================
#                Q M I _ I D L _ W I R E _ D O C G E N . P M
#
# DESCRIPTION
#  Writes the wire documentation .html file for the qmi_idl_compiler tool
#
# REFERENCE
# 
# Copyright (c) 2011 by QUALCOMM Incorporated. All Rights Reserved.
# ========================================================================
# 
# $Header: //source/qcom/qct/core/mproc/tools_crm/idl_compiler/main/latest/common/qmi_idl_wire_html_docgen.pm#12 $
#
# ========================================================================
package qmi_idl_wire_html_docgen;

use strict;
##use warnings;

require Exporter;
use Data::Dumper;
#use XML::Simple;
use Getopt::Long;
use Storable qw(dclone);


our @ISA = qw(Exporter);

#Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration       use IDLCompiler::IDLOutput ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(write_wire_html_docgen
                                   ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

my $TRUE = 1;
my $FALSE = 0;

my $HTML_STYLESHEET =<<"EOF";
body                { font-family: Verdana, Arial, Helvetica;}
H1                  { page-break-before: always}
H2                  { page-break-before: always}

table.tlv           { width:100%; border-width: 3; border-style: solid; border-color: \#99ccff; border-collapse: collapse; font-size: 10pt;}

table.tlv tr.head   { background: \#99ccff; }
table.tlv tr.row_0  { border-style: none; background: \#ffffff; }
table.tlv tr.row_1  { border-style: none; background: \#ccffff; }

table.tlv th        { text-align: center; font-weight: bold; border-width: 3; border-style: solid; border-color: \#99ccff; border-collapse: collapse; font-size: 10pt;}
table.tlv td        { text-align: center;                    border-width: 3; border-style: solid; border-color: \#99ccff; border-collapse: collapse; font-size: 10pt;}
table.tlv td.l      { text-align: left;                       border-width: 3; border-style: solid; border-color: \#99ccff; border-collapse: collapse; font-size: 10pt;}

table.sep           { width:100%; border-width: 1; border-style: solid; border-color: #99ccff; border-spacing: 0px 0px;}
EOF

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

sub write_wire_html_docgen 
{
  my $type_hash = shift;
  my $OUTSTRING = shift;
  my $STYLESHEET_OUT = shift;
  $$STYLESHEET_OUT = $HTML_STYLESHEET;
  my %msg_list;
  my $service_name = $$type_hash{"service_hash"}->{"identifier"};
  my $ver_num = $$type_hash{"service_hash"}->{"version"};
  my $section_name = "QMI_";
  $section_name .= uc($service_name);
  #$section_name = format_latex_output($section_name);
  #$$OUTSTRING .= $LATEX_PREAMBLE;
  #$$OUTSTRING .= "\\input{$service_name\_wireformat_too_v$ver_num\.tex}\n";
  #$$OUTSTRING .= "\\chapter{$section_name Messages}\n";
  fill_message_hash(\%msg_list,$type_hash);
  display_header($type_hash,$OUTSTRING);
  populate_message_list(\%msg_list,$type_hash,$OUTSTRING);
  output_messages(\%msg_list,$type_hash,$OUTSTRING);
  output_footer($type_hash,$OUTSTRING);
  #$$OUTSTRING .= "\\end{document}\n";
}#  write_wire_html_docgen

#===========================================================================
#
#FUNCTION FILL_MESSAGE_LIST
#
#DESCRIPTION
#  Creates an array of all messages and their corresponding commands
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  msg_list variable filled with commands and messages
#
#===========================================================================
sub fill_message_hash 
{
   my $msg_list = shift;
   my $type_hash = shift;
   my $types = $$type_hash{"user_types"};
   my $type_order = $$type_hash{"user_types_order"};
   my $common_command_links = $$type_hash{"common_command_links"};
   my $commands = $$type_hash{"command_documentation"};
   my $identifier;
   foreach $identifier (sort {$types->{$a}{'sequence'} <=> $types->{$b}{'sequence'} }  keys %{$types})
   {
     if ($types->{$identifier}{'ismessage'}) 
     {
       if (exists($$common_command_links{$types->{$identifier}{'command'}}))
       {
         $types->{$identifier}{'command'} = $$common_command_links{$types->{$identifier}{'command'}};
       }
       $types->{$identifier}{"commandid"} = hex($$commands{$types->{$identifier}{'command'}}{'commandid'});
     }
   }
   foreach $identifier ( keys % {$commands})
   {
      next unless defined($identifier);
      next unless ($identifier ne "");
      next unless defined($$commands{$identifier}{'commandid'});
      next unless exists($$commands{$identifier}{'msgs'});
      @{$$msg_list{$identifier}} = @{$$commands{$identifier}{'msgs'}};
   }
}#  fill_message_list

#==========================================================================
#
#FUNCTION DISPLAY_HEADER
#
#DESCRIPTION
#  Writes out the header information to the .html file
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  None
#
#SIDE EFFECTS
#  Writes out the header to the html file
#
#===========================================================================
sub display_header 
{
   my $type_hash = shift;
   my $OUTSTRING = shift;
   my $title = $$type_hash{"file_documentation"}{'BRIEF'};
   my $brief = format_html_description($$type_hash{"file_documentation"}{'BRIEF'}) . "\n";
   my $desc = format_html_description($$type_hash{"file_documentation"}{'DESCRIPTION'})."\n";
   my $service_num = $$type_hash{"service_hash"}{"servicenumber"};
   my $service_vers_major_num = $$type_hash{"service_hash"}{"version"};
   my $service_vers_minor_num = $$type_hash{"service_hash"}{"minor_version"};
   
   $title =~ s/\n+$//;
   $$OUTSTRING .=<<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<head>
<title>$title</title>
<link rel="stylesheet" type="text/css" href="qmi_idl_wiredoc.css" />
</head>

<body>
<h1>$brief</h1>
$desc
<h1>Service Type</h1>
<ul>
<li>QMI service type <b>$service_num</b>
<li>Version <b>$service_vers_major_num</b>
<li>Revision <b>$service_vers_minor_num</b>
</ul>
EOF
}#  display_header

#===========================================================================
#
#FUNCTION POPULATE_MESSAGE_LIST
#
#DESCRIPTION
#  Creates the message list table at the start of the section
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
sub populate_message_list 
{
   my $msg_list = shift;
   my $type_hash = shift;
   my $OUTSTRING = shift;
   my $commands = $$type_hash{"command_documentation"};
   my $command_order = $$type_hash{"command_order"};
   my $service_name = $$type_hash{"service_hash"}->{"identifier"};
   my $section_name = "QMI_";
   $section_name .= uc($service_name);
   $section_name .= " Messages";
   $$OUTSTRING .=<<EOF;
<h1><a name='Messages'>Messages</a></h1>
<table class = 'tlv'><tr class='head'><th>Command</th><th>ID</th><th>Messages</th><th>Description</th></tr>
EOF
  foreach(@$command_order)
  {
      next unless defined($commands->{$_}{'commandid'});
      # Format description
      my $tmp = $commands->{$_}{'BRIEF'};
      #my $command_name = format_latex_output($_);
      $tmp =~ s/\n+/ /g;
      $tmp =~ s/\s+/ /g;
      #$tmp = format_latex_output($tmp);
      # Format Message list
      my $messages;
      foreach my $msg (@{$$msg_list{$_}}) 
      {
         $msg =~ s/^(\w+)\s.*/$1/;
         $messages .= "<a href=\"#".$msg."\">$msg</a></br>";
      }
      $$OUTSTRING .= "<tr><td class='l'><a href='#".$_.
         "'>$_</a></td><td>$commands->{$_}{'commandid'}</td><td class='l'>$messages</td><td class='l'>$tmp</td></tr>\n";
   }
  $$OUTSTRING .=<<EOF;
</table>
<br><br>
EOF
}#  populate_message_list

sub output_messages 
{
   my $msg_list = shift;
   my $type_hash = shift;
   my $OUTSTRING = shift;
   my $commands = $$type_hash{"command_documentation"};
   my $common_command_links = $$type_hash{"common_command_links"};
   my $command_order = $$type_hash{"command_order"};
   my $user_types = $$type_hash{"user_types"};
   my $service_hash = $$type_hash{"service_hash"};
   my $service_name = uc($$type_hash{"service_hash"}->{"identifier"});
   my $identifier;
   my $prev_command = "";
   my $prev_command_id = -1;
   my $skip_command = $TRUE;
   my $prev_type = "";
   foreach(@$command_order)
   {
      next unless defined($commands->{$_}{'commandid'});
      my $brief_desc = format_html_description($$commands{ $_}{'BRIEF'});
      if ($$commands{$_}{'CMD_PROVISIONAL'} ne "")
      {
         $brief_desc = "<b>This message is provisional and is subject to change or removal.</b><br><br>"
         . $brief_desc;
      }
      my $command_name = $_;
      #convert the command ID to an integer and then back into a 4 digit hex value.  Perl outputs all 0s if you try to convert a
      #hex value into a hex value.
      my $command_id = hex($$commands{$_}{'commandid'});
      $command_id = sprintf("0x%04X", $command_id);
      $$OUTSTRING .=<<EOF;
<h2><a name='$command_name'></a><a href='#Messages'>$command_name</a></h2>
$brief_desc
<h4>Message ID</h4>
$command_id
EOF
 
      if (defined($$commands{$_}{'CMD_VERSION'}))
      {
         my $version_introduced = $$commands{$_}{'CMD_VERSION'};
         $version_introduced =~ m/(\d+)\.(\d+)/;
         $$OUTSTRING .=<<EOF;
<h4>Version introduced</h4>
Major - $1\, Minor - $2
EOF
      }
      if (defined($$commands{$_}{'CMD_DEPRECATED'}))
      {
         my $version_deprecated = $$commands{$_}{'CMD_DEPRECATED'};
         $version_deprecated =~ m/(\d+)\.(\d+)/;
         $$OUTSTRING .=<<EOF;
<h4>Version deprecated</h4>
Major - $1\, Minor - $2
EOF
      }
      my $message_type = "";
      foreach my $msg (@{$$msg_list{$_}})
      {
         my $message_name = $msg;
         $skip_command = $TRUE;
         foreach (@{$$service_hash{"elementlist"}})
         {
            if (defined ($_->{'identifier'}))
            {
               if ($_->{'identifier'} eq $msg)
               {
                  $identifier = $_->{'type'};
                  $skip_command = $FALSE;
                  last;
               }
            }
         }
         if ($skip_command)
         {
            next;
         }
         my $sender = "";
         my $scope = "";
         if ($user_types->{$identifier}{'Type'} ne "")
         {
            $message_type = "<h4>Message Type</h4>$user_types->{$identifier}{'Type'}";
         }else
         {
            $message_type =  "<h4>Message Type</h4>$user_types->{$identifier}{'description'}{'TYPE'}";
         }
         if ($user_types->{$identifier}{'Sender'} ne "")
         {
            $sender = "<h4>Sender</h4>$user_types->{$identifier}{'Sender'}\n";
         }else
         {
            $sender = "<h4>Sender</h4>$user_types->{$identifier}{'description'}{'SENDER'}";
         }
         if ($user_types->{$identifier}{'SCOPE'} ne "")
         {
            $scope = "<h4>Indication scope</h4>$user_types->{$identifier}{'SCOPE'}";
         }elsif ($user_types->{$identifier}{'description'}{'SCOPE'} ne "")
         {
            $scope = "<h4>Indication scope</h4>$user_types->{$identifier}{'description'}{'SCOPE'}";
         }
         $$OUTSTRING .=<<EOF;
<h3><a name="$message_name"></a><a href='#Messages'>$message_name</a></h3>
$message_type
$sender
$scope
EOF
         add_tlv_table($msg_list,$type_hash,$identifier,$OUTSTRING);
         
      }
      # message_type will contain old value, but what is needed for us is to know whether it is IND type or not, 
      # hence it does not matter if it is REQ/RESP.( OK with overwriting of either of these 2 values )
      print_command_footer(\%{$$commands{$command_name}}, $OUTSTRING, $message_type, $command_name);
   }
}#  output_messages

sub print_command_footer 
{
   my $command = shift;
   my $OUTSTRING = shift;
   my $msg_type = shift;
   my $command_name = shift;
   my $error_table = "";
   $error_table = $command->{"ERROR"};
   my $description = format_html_description($command->{"DESCRIPTION"});
   $error_table =~ s/\n+/ /g;
   $error_table =~ s/\s+/ /g;
   $error_table =~ s/\s$//;
   $error_table =~ s/\-+/<li>/g;
   if ($error_table ne "") 
   {
      $$OUTSTRING .=<<EOF;
<h4>Error codes</h4>
<ul>$error_table</ul>
EOF
   }
   if (defined($description)) 
   {
      if ($msg_type =~ m/Indication/) 
      {
         $$OUTSTRING .= "<h4>Description of $command_name</h4>\n";
      }else
      {
         $$OUTSTRING .= "<h4>Description of $command_name REQ/RESP</h4>\n"
      }
      $$OUTSTRING .= "$description\n"
   }
   #Seperator
   $$OUTSTRING .=<<EOF;
<br><br>
<table class='sep'><tr><td></td></tr></table>
EOF
}#  print_command_footer

sub add_tlv_table 
{
   my $msg_list = shift;
   my $type_hash = shift;
   my $identifier = shift;
   my $OUTSTRING = shift;
   my $user_types = $$type_hash{"user_types"};
   my $mand_table = "";
   my $mand_vers = "";
   my $opt_table = "";
   my $opt_vers = "";
   my $ref_table;
   my $vers_table;
   my $wire_size;
   if (defined $user_types->{$identifier}{'elementlist'}) 
   {
      if (ref($user_types->{$identifier}{'elementlist'}) eq "ARRAY")
      {
         foreach (@{$user_types->{$identifier}{'elementlist'}}) 
         {
            my $carry_name = "";
            my $description = format_html_description($_->{"typedescription"});
            if ($_->{"provisional"} ne "")
            {
              $description = "<b>This field is provisional and is subject to change or removal.</b><br><br>" 
                . $description;
            }
            if ($_->{"isoptional"} && $_->{"document_as_mandatory"} == $FALSE) 
            {
               $ref_table = \$opt_table;
               $vers_table = \$opt_vers;
            }else
            {
               $ref_table = \$mand_table;
               $vers_table = \$mand_vers;
            }
            $$ref_table .= "<tr class='row_0'><td class='l'>Type</td><td>$_->{'tlvtype'}" . 
               "</td><td class='l'></td><td>1</td><td class='l'>$description</td></tr>\n";
            #$$vers_table .= "$description & $_->{'tlv_version'} \\\\\n\\hline\n" if ($_->{'tlv_version'} ne "");
            if(is_var_size_tlv($user_types,$_))
            {
               $wire_size = "Var";
            }else
            {
               $wire_size = $_->{'wiresize'};
            }
            $$ref_table .= "<tr class='row_0'><td class='l'>Length</td><td>$wire_size" . 
               "</td><td class='l'></td><td>2</td><td class='l'></td></tr>\n";
            if ($_->{"carry_name"} ne "")
            {
               $carry_name = $_->{"carry_name"} . "_";
            }
            add_tlv_value($type_hash,$_,$TRUE,$ref_table,$carry_name,$identifier);
            #$$ref_table .= "\\hline\n";
         }
      }
   }
   $$OUTSTRING .= "<h4>Mandatory TLVs</h4>\n";
#   if ($mand_vers ne "") {
#      $$OUTSTRING .=<<EOF;
#\\begin{center}
#\\begin{longtable}[l]{|l|c|}
#\\hline
#\\textbf{Name} & \\textbf{Version last modified} \\\\
#\\hline
#$mand_vers;
#\\end{longtable}
#\\end{center}
#EOF
#   }
   if ($mand_table ne "") 
   {
      $$OUTSTRING .=<<EOF;
<table class = 'tlv'><tr class='head'><th>Field</th><th>Field Value</th><th>Parameter</th><th>Size (bytes)</th><th>Description</th></tr>
$mand_table
</table>
EOF
   }else
   {
      $$OUTSTRING .= "None\n";
   }
   $$OUTSTRING .= "<h4>Optional TLVs</h4>\n";
#   if ($opt_vers ne "") {
#      $$OUTSTRING .=<<EOF;
#\\begin{center}
#\\begin{longtable}[l]{|l|c|}
#\\hline
#\\textbf{Name} & \\textbf{Version last modified} \\\\
#\\hline
#$opt_vers;
#\\end{longtable}
#\\end{center}
#EOF
#   }
   if ($opt_table ne "") 
   {
      $$OUTSTRING .=<<EOF;
<table class = 'tlv'><tr class='head'><th>Field</th><th>Field Value</th><th>Parameter</th><th>Size (bytes)</th><th>Description</th></tr>
$opt_table
</table>
EOF
   }else
   {
      $$OUTSTRING .= "None\n";
   }
}#  add_tlv_table

sub is_var_size_tlv 
{
   my $user_types = shift;
   my $tlv_hash = shift;
   if ($tlv_hash->{'isvarwiresize'}) 
   {
      return $TRUE;
   }
   #Search through the user_types hash to see if any of the fields of the TLV are variable
   #sized
   if (defined $user_types->{$tlv_hash->{'type'}}) 
   {
      if ($user_types->{$tlv_hash->{'type'}}->{'isvarwiresize'} && 
         !$user_types->{$tlv_hash->{'type'}}->{'islengthless'}) 
      {
         return $TRUE;
      }
      if (defined ($user_types->{$tlv_hash->{'type'}}->{'elementlist'})) 
      {
         if (ref($user_types->{$tlv_hash->{'type'}}->{'elementlist'}) eq "ARRAY")
         {
            unless ($user_types->{$tlv_hash->{'type'}}->{'isenum'} || 
               $user_types->{$tlv_hash->{'type'}}->{'ismask'}) 
            {
               foreach (@{$user_types->{$tlv_hash->{'type'}}->{'elementlist'}}) 
               {
                  if (is_var_size_tlv($user_types,$_)) 
                  {
                     return $TRUE;
                  }
               }
            }
         }
      }
   }
   return $FALSE;
}

sub get_var_size_elm_list 
{
   my $user_types = shift;
   my $tlv_hash = shift;
   my $OUTSTRING = shift;

   #Search through the user_types hash to see if any of the fields of the TLV are variable
   #sized
   if (defined ($user_types->{$tlv_hash->{'type'}}->{'elementlist'})) 
   {
      if (ref($user_types->{$tlv_hash->{'type'}}->{'elementlist'}) eq "ARRAY")
      {
         unless ($user_types->{$tlv_hash->{'type'}}->{'isenum'} || $user_types->{$tlv_hash->{'type'}}->{'ismask'}) 
         {
            foreach (@{$user_types->{$tlv_hash->{'type'}}->{'elementlist'}}) 
            {
               if (defined ($user_types->{$_->{'type'}}->{'elementlist'})) 
               {
                  get_var_size_elm_list($user_types,$_,$OUTSTRING);
               }else
               {
                  if ($_->{'isvarwiresize'}) 
                  {
                     $$OUTSTRING .= "- $_->{'identifier'}" . "_len\n";
                  }
                  $$OUTSTRING .= "- $_->{'identifier'}\n";
               }
            }
         }else
         {
            $$OUTSTRING .= "- $tlv_hash->{'identifier'}\n";
         }
      }
   }else
   {
      $$OUTSTRING .= "- $tlv_hash->{'identifier'}\n";
   }
}

sub add_tlv_value 
{
   my $type_hash = shift;
   my $tlv_hash = shift;
   my $first_level = shift;
   my $tlv_table = shift;
   my $carry_name = shift;
   my $top_struct_name = shift;
   my $user_types = $$type_hash{"user_types"};
   my $const_hash = $$type_hash{"const_hash"};
   my $table_start;
   my $value_len;
   my $value_desc;
   my $value_name;
   if ($first_level) 
   {
      $table_start = "<tr class='row_0'><td class='l'>Value</td><td>&rarr;</td><td class='l'>";
   }
   else
   {
      $table_start = "<tr class='row_0'><td class='l'></td><td></td><td class='l'>";
   }
   #unless ($first_level) {
   #   $$tlv_table .= "\\cline{3-5}\n";
   #}
   
   #Check if is variable sized
   if ($tlv_hash->{'isvarwiresize'} && !$tlv_hash->{'islengthless'}) 
   {
      my $var_len_name = $tlv_hash->{'identifier'} . "_len";
      my $var_len_desc = "Number of sets of the following elements:\n";
      get_var_size_elm_list($user_types,$tlv_hash,\$var_len_desc);
      $var_len_desc = format_html_description($var_len_desc);
      my $var_len_len;
      if (defined $const_hash->{$tlv_hash->{'n'}}) 
      {
         $var_len_len = $const_hash->{$tlv_hash->{'n'}}->{'value'};
      }
      else
      {
         $var_len_len = $tlv_hash->{'n'};
      }
      my $i = (($var_len_len > 255) || ($tlv_hash->{'set16bitflag'})) ? 2:1;
      $i = 4 if $tlv_hash->{'set32bitflag'};
      $var_len_len = $i;
      $$tlv_table .= "$table_start$var_len_name\</td><td>$var_len_len\</td><td class='l'>$var_len_desc\</td></tr>\n";
      $table_start = "<tr class='row_0'><td class='l'></td><td></td><td class='l'>";
   }
   #It is an aggregate type
      if (defined ($user_types->{$tlv_hash->{'type'}}->{'elementlist'}) && 
          ! $user_types->{$tlv_hash->{'type'}}->{'isenum'} && 
          ! $user_types->{$tlv_hash->{'type'}}->{'ismask'}) 
      {
         if (ref($user_types->{$tlv_hash->{'type'}}->{'elementlist'}) eq "ARRAY")
         {
            my $first_iteration = ($tlv_hash->{'isvarwiresize'}) ? $FALSE:$TRUE;
            foreach (@{$user_types->{$tlv_hash->{'type'}}->{'elementlist'}}) 
            {
               my $prev_carry_name = $carry_name;
               if ($_->{"carry_name"} ne "")
               {
                  $carry_name = $_->{"carry_name"} . "_";
               }
               add_tlv_value($type_hash,$_,$first_iteration,$tlv_table,$carry_name);
               $carry_name = $prev_carry_name;
               $first_iteration = $FALSE;
            }
         }
   #   }
      }
      else
      {
         if ($tlv_hash->{'isduplicate'})
         {
            my $temp_ref = dclone($user_types);
            my $temp_ref = get_type_by_tlv($temp_ref,$top_struct_name,$tlv_hash->{'isduplicate'});
            $tlv_hash->{'identifier'} = $temp_ref->{'identifier'};
         }
         $value_name = $carry_name . $tlv_hash->{'identifier'}; 
         $value_desc = format_html_description($tlv_hash->{'valuedescription'} . "\n");
         if (is_var_size_tlv($user_types,$tlv_hash)) 
         {
            $value_len = "Var";
         }
         else
         {     
            $value_len = $tlv_hash->{'wiresize'};
         }
         $$tlv_table .= "$table_start$value_name\</td><td>$value_len\</td><td class='l'>$value_desc\</td></tr>\n";
      }
}#  add_tlv_value

sub output_footer 
{
   my $type_hash = shift;
   my $OUTSTRING = shift;
   my $footer_hash = $$type_hash{"footer"};
   my $footer_order = $$type_hash{"footer_order"};
   if (defined($footer_order)) 
   {
      if(@{$footer_order})
      {
         $$OUTSTRING .= "\\appendix\n\\chapter{Additional Information}\n";
         foreach(@{$footer_order})
         {
            my $appendix_name = format_latex_output($_);
            my $appendix_text = format_latex_desc($footer_hash->{$_});
            $$OUTSTRING .= "\\section{$appendix_name}\n";
            $$OUTSTRING .= "$appendix_text\n";
         }
      }
   }
}#  output_footer

#===========================================================================
#
#FUNCTION FORMAT_LATEX_OUTPUT
#
#DESCRIPTION
#  Formats all underscores (_) in the input string into the latex formatted
#   output (\_)
#
#DEPENDENCIES
#  None
#
#RETURN VALUE
#  latex formatted output string
#
#SIDE EFFECTS
#  None
#
#===========================================================================
sub format_html_description
{
   my $description = shift;
   my $no_format_line = "";
   $description =~ s/  +/ /g;
   $description =~ s/^ *//g;
   $description =~ s/\n+$//g;
   $description =~ s/\n/\:\:\:/g;
   my $tempstring = $description;
   while ($description =~ m/\@latexonly/)
   {
      if ($tempstring =~ m/\@latexonly(.*)?\@endlatexonly/)
      {
         $no_format_line = $1;
         $description =~ s/\@latexonly(.*)?\@endlatexonly/$no_format_line/;
         $tempstring =~ s/\@latexonly(.*)?\@endlatexonly/$1/;
      }else
      {
         last;
      }
   }
   $description =~ s/\:\:\:/\n/g;

   my @tmp = split(/\n/, $description);
   my $in_list    = $FALSE;
   my $first_line = $TRUE;
   my $text = "";
   my $bullet_level;
   foreach (@tmp) {
      # Process bulleted list
      if (/^\s*(-+)\s*(.*)/) 
      {
         if( $in_list == $FALSE) 
         {
            $in_list = $TRUE;
            $text .= sprintf ("<ul>");
            $bullet_level = length($1);
         }
         #Deal with multiple bullet levels
         if (length($1) > $bullet_level) 
         {
            $text .= sprintf ("<ul>");
            $bullet_level ++;
         }elsif (length($1) < $bullet_level)
         {
            $text .= sprintf ("</ul>");
            $bullet_level--;
         }
         $text .= sprintf("<li>$2");
      # No longer in list
      } else
      {
         if ($in_list) 
         {
            $in_list = $FALSE;
            my $list_level = "</ul>" x $bullet_level;
            $text .= sprintf ("$list_level");
         }else
         {
            if ($first_line == $FALSE) 
            {
               $text .= sprintf ("<br>");
            }
         }
         $text .= $_;
       }
      $first_line = $FALSE;
   }

   # Terminate list if list item is the last line of text
   if ($in_list) 
   {
      $text .= sprintf ("</ul>");
   }
   #Remove breaks after bullet lists, and breaks at the beginning of newlines
   $text =~ s/<\/ul><br>/<\/ul>/g;
   $text =~ s/^<br>//g;
   #Handle italic, bold and bold/italic formatting
   $text =~ s/\'\'\'\'\'(.*)\'\'\'\'\'/<b><i>$1<\/i><\/b>/g;
   $text =~ s/\'\'\'(.*)\'\'\'/<b>$1<\/b>/g;
   $text =~ s/\'\'(.*)\'\'/<i>$1<\/i>/g;
   return $text;
}

sub format_latex_output 
{
   my $instring = shift;
   $instring =~ s/\_/\\\_\\\-/g;
   #Escape the LaTeX special characters
   $instring =~ s/([\#\$\%\&\~\_\^\'\"])/\\$1/g;
   return $instring;
}#  format_latex_output

sub format_latex_desc 
{
   my $instring = shift;
   $instring = format_latex_output($instring);
   $instring =~ s/\n/\\newline\n/g;
   $instring =~ s/(\\newline\s*)+$//;
   return $instring;
}

sub format_latex_table_desc 
{
   my $instring = shift;
   $instring = format_latex_output($instring);
   $instring =~ s/(\n\s*)+$//;
   $instring =~ s/\n/\}\\\\\n & & & & \{/g;
   $instring =~ s/\s+/ /g;
   return $instring;
}
1;
