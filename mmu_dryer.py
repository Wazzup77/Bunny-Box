# Filament Dryer Manager for Happy Hare MMU
# Provides non-blocking timed drying cycles for filament
#
# Copyright (C) 2025 53Aries 
#
# This file may be distributed under the terms of the GNU GPLv3 license.

import logging

class FilamentDryer:
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        self.reactor = self.printer.get_reactor()
        self.gcode = self.printer.lookup_object('gcode')
        
        # Get heater name from config (can be any heater: heater_box, heater_mmu, etc.)
        # Defaults to 'heater_box' if not specified
        self.heater_name = config.get('heater', 'heater_box')
        self.heater = None
        
        # Drying state
        self.is_drying = False
        self.target_temp = 0
        self.duration = 0
        self.start_time = 0
        self.end_time = 0
        self.timer_handler = None
        self.original_target = 0
        
        # Load presets from config
        self.presets = {}
        preset_names = config.get('presets', '').split(',')
        for preset_name in preset_names:
            preset_name = preset_name.strip()
            if preset_name:
                temp = config.getfloat('preset_%s_temp' % preset_name, None)
                duration = config.getfloat('preset_%s_duration' % preset_name, None)
                if temp is not None and duration is not None:
                    self.presets[preset_name.lower()] = {
                        'temp': temp,
                        'duration': duration * 3600  # Convert hours to seconds
                    }
        
        # Register commands
        self.gcode.register_command('START_FILAMENT_DRYING',
                                    self.cmd_START_FILAMENT_DRYING,
                                    desc=self.cmd_START_FILAMENT_DRYING_help)
        self.gcode.register_command('STOP_FILAMENT_DRYING',
                                    self.cmd_STOP_FILAMENT_DRYING,
                                    desc=self.cmd_STOP_FILAMENT_DRYING_help)
        self.gcode.register_command('DRYER_STATUS',
                                    self.cmd_DRYER_STATUS,
                                    desc=self.cmd_DRYER_STATUS_help)
        self.gcode.register_command('LIST_DRYER_PRESETS',
                                    self.cmd_LIST_DRYER_PRESETS,
                                    desc=self.cmd_LIST_DRYER_PRESETS_help)
        
        # Note: We don't look up the heater here to avoid load order issues
        # It will be looked up lazily when first needed
    
    def _get_heater(self):
        """Lazy lookup of heater to avoid load order issues"""
        if self.heater is None:
            pheaters = self.printer.lookup_object('heaters')
            try:
                self.heater = pheaters.lookup_heater(self.heater_name)
            except Exception as e:
                raise self.gcode.error(
                    "Filament dryer: Unable to find heater '%s': %s" 
                    % (self.heater_name, str(e)))
        return self.heater
    
    def _stop_timer(self):
        if self.timer_handler is not None:
            self.reactor.unregister_timer(self.timer_handler)
            self.timer_handler = None
    
    def _timer_callback(self, eventtime):
        if not self.is_drying:
            return self.reactor.NEVER
        
        remaining = self.end_time - eventtime
        
        if remaining <= 0:
            # Drying cycle complete
            self.gcode.respond_info("Filament drying cycle complete!")
            self._stop_drying()
            return self.reactor.NEVER
        
        # Send status update every 5 minutes to reset idle timeout and inform user
        if int(eventtime - self.start_time) % 300 == 0:  # Every 5 minutes
            remaining_hours = remaining / 3600.0
            elapsed_hours = (eventtime - self.start_time) / 3600.0
            progress = ((eventtime - self.start_time) / self.duration) * 100.0
            
            heater = self._get_heater()
            current_temp = heater.get_status(eventtime).get('temperature', 0)
            
            msg = ("Drying: %.1f°C | %.1f%% complete | "
                   "%.1fh elapsed | %.1fh remaining" 
                   % (current_temp, progress, elapsed_hours, remaining_hours))
            self.gcode.run_script_from_command("M118 " + msg)
        
        # Continue timer
        return eventtime + 1.0
    
    def _start_drying(self, temp, duration):
        if self.is_drying:
            raise self.gcode.error("Drying cycle already in progress")
        
        # Get heater (lazy lookup)
        heater = self._get_heater()
        
        # Store original target temperature
        self.original_target = heater.get_status(self.reactor.monotonic())['target']
        
        # Set new target temperature
        heater.set_temp(temp)
        
        # Setup timer
        self.target_temp = temp
        self.duration = duration
        self.start_time = self.reactor.monotonic()
        self.end_time = self.start_time + duration
        self.is_drying = True
        
        # Start non-blocking timer
        self.timer_handler = self.reactor.register_timer(
            self._timer_callback, self.reactor.monotonic() + 1.0)
        
        hours = duration / 3600.0
        self.gcode.respond_info(
            "Started filament drying: %.1f°C for %.1f hours" 
            % (temp, hours))
    
    def _stop_drying(self):
        if not self.is_drying:
            return
        
        self._stop_timer()
        
        # Return heater to original target (usually 0)
        heater = self._get_heater()
        heater.set_temp(self.original_target)
        
        self.is_drying = False
        self.target_temp = 0
        self.duration = 0
        self.start_time = 0
        self.end_time = 0
        
        self.gcode.respond_info("Filament drying stopped")
    
    cmd_START_FILAMENT_DRYING_help = "Start a filament drying cycle"
    def cmd_START_FILAMENT_DRYING(self, gcmd):
        # Check if preset is specified
        preset = gcmd.get('PRESET', None)
        
        if preset:
            preset = preset.lower()
            if preset not in self.presets:
                raise gcmd.error(
                    "Unknown preset '%s'. Use LIST_DRYER_PRESETS to see available presets." 
                    % preset)
            temp = self.presets[preset]['temp']
            duration = self.presets[preset]['duration']
        else:
            # Manual mode: get temp and duration from parameters
            temp = gcmd.get_float('TEMP', None)
            duration = gcmd.get_float('DURATION', None)
            
            if temp is None or duration is None:
                raise gcmd.error(
                    "Must specify either PRESET or both TEMP and DURATION parameters")
            
            # Duration is in hours, convert to seconds
            duration = duration * 3600
        
        self._start_drying(temp, duration)
    
    cmd_STOP_FILAMENT_DRYING_help = "Stop the current drying cycle"
    def cmd_STOP_FILAMENT_DRYING(self, gcmd):
        if not self.is_drying:
            gcmd.respond_info("No drying cycle in progress")
            return
        
        self._stop_drying()
    
    cmd_DRYER_STATUS_help = "Get the status of the filament dryer"
    def cmd_DRYER_STATUS(self, gcmd):
        if not self.is_drying:
            gcmd.respond_info("Dryer Status: Idle")
            return
        
        current_time = self.reactor.monotonic()
        elapsed = current_time - self.start_time
        remaining = self.end_time - current_time
        
        elapsed_hours = elapsed / 3600.0
        remaining_hours = remaining / 3600.0
        total_hours = self.duration / 3600.0
        progress = (elapsed / self.duration) * 100.0
        
        heater = self._get_heater()
        heater_status = heater.get_status(current_time)
        current_temp = heater_status.get('temperature', 0)
        
        gcmd.respond_info(
            "Dryer Status: Active\n"
            "Target Temperature: %.1f°C\n"
            "Current Temperature: %.1f°C\n"
            "Total Duration: %.1f hours\n"
            "Elapsed: %.1f hours\n"
            "Remaining: %.1f hours\n"
            "Progress: %.1f%%"
            % (self.target_temp, current_temp, total_hours, 
               elapsed_hours, remaining_hours, progress))
    
    cmd_LIST_DRYER_PRESETS_help = "List available drying presets"
    def cmd_LIST_DRYER_PRESETS(self, gcmd):
        if not self.presets:
            gcmd.respond_info("No presets configured")
            return
        
        response = "Available Drying Presets:\n"
        for name, settings in sorted(self.presets.items()):
            hours = settings['duration'] / 3600.0
            response += "  %s: %.1f°C for %.1f hours\n" % (
                name.upper(), settings['temp'], hours)
        
        gcmd.respond_info(response)
    
    def get_status(self, eventtime):
        """Return dryer status for macro/status queries"""
        status = {
            'is_drying': self.is_drying,
            'target_temp': self.target_temp,
        }
        
        if self.is_drying:
            elapsed = eventtime - self.start_time
            remaining = self.end_time - eventtime
            status.update({
                'duration': self.duration,
                'elapsed': elapsed,
                'remaining': remaining,
                'progress': (elapsed / self.duration) * 100.0 if self.duration > 0 else 0
            })
        
        return status

def load_config(config):
    return FilamentDryer(config)
