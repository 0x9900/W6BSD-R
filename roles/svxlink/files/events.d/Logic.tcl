###############################################################################
#
# Generic Logic event handlers
#
###############################################################################

#
# This is the namespace in which all functions and variables below will exist.
#
namespace eval Logic {


#
# A variable used to store a timestamp for the last identification.
#
variable prev_ident 0;

#
# A constant that indicates the minimum time in seconds to wait between two
# identifications. Manual and long identifications is not affected.
#
variable min_time_between_ident 120;

#
# Short and long identification intervals. They are setup from config
# variables below.
#
variable ident_interval 0;


variable need_ident 0;

#
# A list of functions that should be called once every whole minute
#
variable timer_tick_subscribers [list];

#
# Contains the ID of the last receiver that indicated squelch activity
#
variable sql_rx_id 0;

#
# used by checkPeriodicIdentify to determine if there is a transmission going on.
#
variable transmit_on 0;
variable receiver_on 0;

#
# Executed when the SvxLink software is started
#
proc startup {} {
  variable prev_ident;
  variable need_ident;
  #playMsg "EchoLink" "online";
  send_ident
  # we just identified ourselves, we don't need to re-identify for a while.
  set now [clock seconds];
  set prev_ident $now;
  set need_ident 0;
}


#
# Executed when a specified module could not be found
#   module_id - The numeric ID of the module
#
proc no_such_module {module_id} {
  playMsg "Core" "no_such_module";
  playNumber $module_id;
}


#
# Executed when a manual identification is initiated with the * DTMF
# code
#
proc manual_identification {} {
  return 0;
}


#
# Executed when a short identification should be sent
#
proc send_ident {} {
  global mycall;
  variable CFG_TYPE;

  # spellWord $mycall;
  CW::play " ";
  CW::play $mycall;

  # if {$CFG_TYPE == "Repeater"} {
  #  playMsg "Core" "repeater";
  # }
  playSilence 500;
}

#
# Executed when the squelch just have closed and the RGR_SOUND_DELAY
# timer has expired.
#
proc send_rgr_sound {} {
  variable sql_rx_id;

  playTone 440 500 100;
  playSilence 200;

  for {set i 0} {$i < $sql_rx_id} {incr i 1} {
    playTone 880 500 50;
    playSilence 50;
  }
  playSilence 100;
}


#
# Executed when an empty macro command (i.e. D#) has been entered.
#
proc macro_empty {} {
  playMsg "Core" "operation_failed";
}


#
# Executed when an entered macro command could not be found
#
proc macro_not_found {} {
  playMsg "Core" "operation_failed";
}


#
# Executed when a macro syntax error occurs (configuration error).
#
proc macro_syntax_error {} {
  playMsg "Core" "operation_failed";
}


#
# Executed when the specified module in a macro command is not found
# (configuration error).
#
proc macro_module_not_found {} {
  playMsg "Core" "operation_failed";
}


#
# Executed when the activation of the module specified in the macro
# command failed.
#
proc macro_module_activation_failed {} {
  playMsg "Core" "operation_failed";
}


#
# Executed when a macro command is executed that requires a module to
# be activated but another module is already active.
#
proc macro_another_active_module {} {
  global active_module;

  playMsg "Core" "operation_failed";
  playMsg "Core" "active_module";
  playMsg $active_module "name";
}


#
# Executed when an unknown DTMF command is entered
#   cmd - The command string
#
proc unknown_command {cmd} {
  spellWord $cmd;
  playMsg "Core" "unknown_command";
}


#
# Executed when an entered DTMF command failed
#   cmd - The command string
#
proc command_failed {cmd} {
  spellWord $cmd;
  playMsg "Core" "operation_failed";
}


#
# Executed when a link to another logic core is activated.
#   name  - The name of the link
#
proc activating_link {name} {
  if {[string length $name] > 0} {
    playMsg "Core" "activating_link_to";
    spellWord $name;
  }
}


#
# Executed when a link to another logic core is deactivated.
#   name  - The name of the link
#
proc deactivating_link {name} {
  if {[string length $name] > 0} {
    playMsg "Core" "deactivating_link_to";
    spellWord $name;
  }
}


#
# Executed when trying to deactivate a link to another logic core but the
# link is not currently active.
#   name  - The name of the link
#
proc link_not_active {name} {
  if {[string length $name] > 0} {
    playMsg "Core" "link_not_active_to";
    spellWord $name;
  }
}


#
# Executed when trying to activate a link to another logic core but the
# link is already active.
#   name  - The name of the link
#
proc link_already_active {name} {
  if {[string length $name] > 0} {
    playMsg "Core" "link_already_active_to";
    spellWord $name;
  }
}


#
# Executed each time the transmitter is turned on or off
#   is_on - Set to 1 if the transmitter is on or 0 if it's off
#
proc transmit {is_on} {
  #puts "Turning the transmitter $is_on";
  variable prev_ident;
  variable need_ident;
  variable transmit_on;
  if {$is_on && ([clock seconds] - $prev_ident > 5)} {
    set need_ident 1;
  }
  set transmit_on $is_on;
  dbg "Transit is $transmit_on";
}


#
# Executed each time the squelch is opened or closed
#   rx_id   - The ID of the RX that the squelch opened/closed on
#   is_open - Set to 1 if the squelch is open or 0 if it's closed
#
proc squelch_open {rx_id is_open} {
  variable sql_rx_id;
  variable receiver_on;
  #puts "The squelch is $is_open on RX $rx_id";
  set sql_rx_id $rx_id;
  set receiver_on $is_open;
  dbg "Receive is $receiver_on";
}


#
# Executed when a DTMF digit has been received
#   digit     - The detected DTMF digit
#   duration  - The duration, in milliseconds, of the digit
#
# Return 1 to hide the digit from further processing in SvxLink or
# return 0 to make SvxLink continue processing as normal.
#
proc dtmf_digit_received {digit duration} {
  return 0;
}


#
# Executed when a DTMF command has been received
#   cmd - The command
#
proc dtmf_cmd_received {cmd} {
  return 0
}


#
# Executed once every whole minute. Don't put any code here directly
# Create a new function and add it to the timer tick subscriber list
# by using the function addTimerTickSubscriber.
#
proc every_minute {} {
  variable timer_tick_subscribers;
  #puts [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"];
  foreach subscriber $timer_tick_subscribers {
    $subscriber;
  }
}


#
# Use this function to add a function to the list of functions that
# should be executed once every whole minute. This is not an event
# function but rather a management function.
#
proc addTimerTickSubscriber {func} {
  variable timer_tick_subscribers;
  lappend timer_tick_subscribers $func;
}


#
# Should be executed once every whole minute to check if it is time to
# identify.
#
proc checkPeriodicIdentify {} {
  variable prev_ident;
  variable ident_interval;
  variable need_ident;
  variable transmit_on;
  variable receiver_on;
  global logic_name;

  dbg "need_ident $need_ident";
  if {$need_ident == 0} {
    return;
  }

  dbg "transmit_on $transmit_on";
  dbg "receiver_on $receiver_on";
  if {$transmit_on || $receiver_on} {
    return;
  }

  set now [clock seconds];

  dbg "prev_ident $prev_ident + ident_interval $ident_interval < now $now";
  if {$prev_ident + $ident_interval <= $now} {
    puts "$logic_name: Sending identification...";
    send_ident
    set prev_ident $now;
    set need_ident 0;
  }
}


#
# Executed when the QSO recorder is being activated
#
proc activating_qso_recorder {} {
  playMsg "Core" "activating";
  playMsg "Core" "qso_recorder";
}


#
# Executed when the QSO recorder is being deactivated
#
proc deactivating_qso_recorder {} {
  playMsg "Core" "deactivating";
  playMsg "Core" "qso_recorder";
}


#
# Executed when trying to deactivate the QSO recorder even though it's
# not active
#
proc qso_recorder_not_active {} {
  playMsg "Core" "qso_recorder";
  playMsg "Core" "not_active";
}


#
# Executed when trying to activate the QSO recorder even though it's
# already active
#
proc qso_recorder_already_active {} {
  playMsg "Core" "qso_recorder";
  playMsg "Core" "already_active";
}


#
# Executed when the timeout kicks in to activate the QSO recorder
#
proc qso_recorder_timeout_activate {} {
  playMsg "Core" "timeout"
  playMsg "Core" "activating";
  playMsg "Core" "qso_recorder";
}


#
# Executed when the timeout kicks in to deactivate the QSO recorder
#
proc qso_recorder_timeout_deactivate {} {
  playMsg "Core" "timeout"
  playMsg "Core" "deactivating";
  playMsg "Core" "qso_recorder";
}


#
# Executed when the user is requesting a language change
#
proc set_language {lang_code} {
  global logic_name;
  puts "$logic_name: Setting language $lang_code (NOT IMPLEMENTED)";

}


#
# Executed when the user requests a list of available languages
#
proc list_languages {} {
  global logic_name;
  puts "$logic_name: Available languages: (NOT IMPLEMENTED)";

}


#
# Executed when the node is being brought online or offline
#
proc logic_online {online} {
  global mycall
  variable CFG_TYPE

  if {$online} {
    playMsg "Core" "online";
    spellWord $mycall;
    if {$CFG_TYPE == "Repeater"} {
      playMsg "Core" "repeater";
    }
  }
}


##############################################################################
#
# Main program
#
##############################################################################

#
# By default the ident interval is 10 minutes or 600 seconds.
#
if {[info exists CFG_SHORT_IDENT_INTERVAL] && $CFG_SHORT_IDENT_INTERVAL > 0} {
  set ident_interval [expr {$CFG_SHORT_IDENT_INTERVAL * 60}];
} else {
  set ident_interval 600;
}

# Output debug only when the user set the environment variable
# DEBUG=1
if {([info exists env(DEBUG)] && $env(DEBUG)) ||
    ([info exists CFG_DEBUG] && $CFG_DEBUG != 0)} {
  proc dbg {msg} {
    puts ">>> $msg";
  }
} else {
  proc dbg {msg} {}
}


# end of namespace
}

#
# This file has not been truncated
#
