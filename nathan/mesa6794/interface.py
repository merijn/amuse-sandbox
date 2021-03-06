import os
import numpy
from operator import itemgetter

from amuse.community import *
from amuse.community.interface.se import StellarEvolution, StellarEvolutionInterface, \
    InternalStellarStructure, InternalStellarStructureInterface

from amuse.units.quantities import VectorQuantity
from amuse.support.interface import InCodeComponentImplementation
from amuse.support.options import option

class MESAInterface(CodeInterface, LiteratureReferencesMixIn, StellarEvolutionInterface, 
        InternalStellarStructureInterface, CodeWithDataDirectories): 
    """
    The software project MESA (Modules for Experiments in Stellar Astrophysics, 
    http://mesa.sourceforge.net/), aims to provide state-of-the-art, robust, 
    and efficient open source modules, usable singly or in combination for a 
    wide range of applications in stellar astrophysics. The AMUSE interface to 
    MESA can create and evolve stars using the MESA/STAR module. If you order a 
    metallicity you haven't used before, starting models will be computed 
    automatically and saved in the `mesa/src/data/star_data/starting_models` 
    directory (please be patient...). All metallicities are supported, even the 
    interesting case of Z=0. The supported stellar mass range is from 
    about 0.1 to 100 Msun.
    
    References:
        .. [#] Paxton, Bildsten, Dotter, Herwig, Lesaffre & Timmes 2010, ApJS submitted, arXiv:1009.1622
        .. [#] http://mesa.sourceforge.net/
    """
    def __init__(self, **options):
        CodeInterface.__init__(self, name_of_the_worker="mesa_worker", **options)
        LiteratureReferencesMixIn.__init__(self)
        CodeWithDataDirectories.__init__(self)
    
    set_radius_at_zone = None
    set_density_at_zone = None
    set_temperature_at_zone = None

    @property
    def default_path_to_inlist(self):
#~        return os.path.join(self.get_data_directory(), 'inlist_amuse')
        return os.path.join(self.amuse_root_directory, 'sandbox', 'nathan', 'mesa6794', 'inlist_amuse')

    def get_code_src_directory(self):
        """
        Returns the root name of the application's source code directory.
        """
#~        return os.path.join(self.amuse_root_directory, 'src', 'amuse', 'community', self.module_name, 'src')
        return os.path.join(self.amuse_root_directory, 'sandbox', 'nathan', 'mesa6794', 'src')
    
    @option(type="string", sections=('data'))
    def default_path_to_MESA(self):
        return self.get_code_src_directory()
    
    @legacy_function
    def set_MESA_paths():
        function = LegacyFunctionSpecification()  
        function.addParameter('inlist_path', dtype='string', direction=function.IN,
            description = "Path to the inlist file.")
        function.addParameter('MESA_path', dtype='string', direction=function.IN,
            description = "Path to the mesa directory.")
        function.addParameter('local_data_path', dtype='string', direction=function.IN,
            description = "Path to the data directory.")
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_zamsfile():
        function = LegacyFunctionSpecification()  
        function.addParameter('zamsfile', dtype='string', direction=function.IN,
            description = "Path to the zero-age main sequence stellar models.")
        function.result_type = 'int32'
        return function
    @legacy_function
    def get_zamsfile():
        function = LegacyFunctionSpecification()  
        function.addParameter('zamsfile', dtype='string', direction=function.OUT,
            description = "Path to the zero-age main sequence stellar models.")
        function.result_type = 'int32'
        return function
    
    
    @legacy_function
    def new_zams_star():
        """
        Define a new star in the code: a zero-age main sequence star with the given mass.
        """
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.OUT)
        function.addParameter('mass', dtype='float64', unit=units.MSun, direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def new_prems_star():
        """
        Define a new star in the code: a pre-main-sequence star with the given mass.
        """
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.OUT)
        function.addParameter('mass', dtype='float64', unit=units.MSun, direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def new_star_from_file():
        """
        Define a new star in the code: read the model from file.
        """
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.OUT)
        function.addParameter('filename', dtype='string', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    def new_particle_method(self, mass=0|units.MSun, pms=False, filename=None):
        if not filename is None:
            return self.new_star_from_file(filename)
        if pms:
            return self.new_prems_star(mass)
        else:
            return self.new_zams_star(mass)
    new_particle = None
    
    @legacy_function
    def write_star_to_file():
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN)
        function.addParameter('filename', dtype='string', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_maximum_number_of_stars():
        """
        Retrieve the maximum number of stars that can be
        handled by this instance.
        """
        function = LegacyFunctionSpecification()  
        function.addParameter('maximum_number_of_stars', dtype='int32', direction=function.OUT,
            description = "The current value of the maximum number of stars")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            Current value of was retrieved
        """
        return function
    
    @legacy_function
    def set_time_step():
        function = LegacyFunctionSpecification() 
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
            , description="The index of the star to get the value of")
        function.addParameter('time_step', dtype='float64', direction=function.IN
            , description="The next timestep for the star.")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            The value has been set.
        -1 - ERROR
            A star with the given index was not found.
        """
        return function
    
    
    @legacy_function   
    def get_core_mass():
        """
        Retrieve the current core mass of the star, where hydrogen abundance is <= h1_boundary_limit
        """
        function = LegacyFunctionSpecification() 
        function.can_handle_array = True 
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
            , description="The index of the star to get the value of")
        function.addParameter('core_mass', dtype='float64', direction=function.OUT
            , description="The current core mass of the star, where hydrogen abundance is <= h1_boundary_limit")
        function.result_type = 'int32'
        return function
    
    @legacy_function   
    def get_mass_loss_rate():
        """
        Retrieve the current mass loss rate of the star. (positive for winds, negative for accretion)
        """
        function = LegacyFunctionSpecification() 
        function.can_handle_array = True 
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
            , description="The index of the star to get the value of")
        function.addParameter('mass_loss_rate', dtype='float64', direction=function.OUT
            , description="The current mass loss rate of the star. (positive for winds, negative for accretion)")
        function.result_type = 'int32'
        return function
    
    @legacy_function   
    def get_manual_mass_transfer_rate():
        """
        Retrieve the current user-specified mass transfer rate of the star. (negative for winds, positive for accretion)
        """
        function = LegacyFunctionSpecification() 
        function.can_handle_array = True 
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
            , description="The index of the star to get the value of")
        function.addParameter('mass_change', dtype='float64', direction=function.OUT
            , description="The current user-specified mass transfer rate of the star. (negative for winds, positive for accretion)")
        function.result_type = 'int32'
        return function
    
    @legacy_function   
    def set_manual_mass_transfer_rate():
        """
        Set a new user-specified mass transfer rate of the star. (negative for winds, positive for accretion)
        """
        function = LegacyFunctionSpecification() 
        function.can_handle_array = True 
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
            , description="The index of the star to get the value of")
        function.addParameter('mass_change', dtype='float64', direction=function.IN
            , description="The new user-specified mass transfer rate of the star. (negative for winds, positive for accretion)")
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_accrete_same_as_surface():
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN)
        function.addParameter('accrete_same_as_surface_flag', dtype='int32', direction=function.OUT)
        function.result_type = 'int32'
        return function
    @legacy_function
    def set_accrete_same_as_surface():
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN)
        function.addParameter('accrete_same_as_surface_flag', dtype='int32', direction=function.IN)
        function.result_type = 'int32'
        return function
    @legacy_function
    def get_accrete_composition_non_metals():
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN)
        function.addParameter('h1', dtype='float64', direction=function.OUT)
        function.addParameter('h2', dtype='float64', direction=function.OUT)
        function.addParameter('he3', dtype='float64', direction=function.OUT)
        function.addParameter('he4', dtype='float64', direction=function.OUT)
        function.result_type = 'int32'
        return function
    @legacy_function
    def set_accrete_composition_non_metals():
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN)
        function.addParameter('h1', dtype='float64', direction=function.IN)
        function.addParameter('h2', dtype='float64', direction=function.IN)
        function.addParameter('he3', dtype='float64', direction=function.IN)
        function.addParameter('he4', dtype='float64', direction=function.IN)
        function.result_type = 'int32'
        return function
    @legacy_function
    def get_accrete_composition_metals_identifier():
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN)
        function.addParameter('accrete_composition_metals_identifier', dtype='int32', direction=function.OUT)
        function.result_type = 'int32'
        return function
    @legacy_function
    def set_accrete_composition_metals_identifier():
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN)
        function.addParameter('accrete_composition_metals_identifier', dtype='int32', direction=function.IN)
        function.result_type = 'int32'
        return function
    @legacy_function
    def get_accrete_composition_metals():
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN)
        function.addParameter('li', dtype='float64', direction=function.OUT)
        function.addParameter('be', dtype='float64', direction=function.OUT)
        function.addParameter('b', dtype='float64', direction=function.OUT)
        function.addParameter('c', dtype='float64', direction=function.OUT)
        function.addParameter('n', dtype='float64', direction=function.OUT)
        function.addParameter('o', dtype='float64', direction=function.OUT)
        function.addParameter('f', dtype='float64', direction=function.OUT)
        function.addParameter('ne', dtype='float64', direction=function.OUT)
        function.addParameter('na', dtype='float64', direction=function.OUT)
        function.addParameter('mg', dtype='float64', direction=function.OUT)
        function.addParameter('al', dtype='float64', direction=function.OUT)
        function.addParameter('si', dtype='float64', direction=function.OUT)
        function.addParameter('p', dtype='float64', direction=function.OUT)
        function.addParameter('s', dtype='float64', direction=function.OUT)
        function.addParameter('cl', dtype='float64', direction=function.OUT)
        function.addParameter('ar', dtype='float64', direction=function.OUT)
        function.addParameter('k', dtype='float64', direction=function.OUT)
        function.addParameter('ca', dtype='float64', direction=function.OUT)
        function.addParameter('sc', dtype='float64', direction=function.OUT)
        function.addParameter('ti', dtype='float64', direction=function.OUT)
        function.addParameter('v', dtype='float64', direction=function.OUT)
        function.addParameter('cr', dtype='float64', direction=function.OUT)
        function.addParameter('mn', dtype='float64', direction=function.OUT)
        function.addParameter('fe', dtype='float64', direction=function.OUT)
        function.addParameter('co', dtype='float64', direction=function.OUT)
        function.addParameter('ni', dtype='float64', direction=function.OUT)
        function.addParameter('cu', dtype='float64', direction=function.OUT)
        function.addParameter('zn', dtype='float64', direction=function.OUT)
        function.result_type = 'int32'
        return function
    @legacy_function
    def set_accrete_composition_metals():
        function = LegacyFunctionSpecification()
        function.can_handle_array = True
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN)
        function.addParameter('li', dtype='float64', direction=function.IN)
        function.addParameter('be', dtype='float64', direction=function.IN)
        function.addParameter('b', dtype='float64', direction=function.IN)
        function.addParameter('c', dtype='float64', direction=function.IN)
        function.addParameter('n', dtype='float64', direction=function.IN)
        function.addParameter('o', dtype='float64', direction=function.IN)
        function.addParameter('f', dtype='float64', direction=function.IN)
        function.addParameter('ne', dtype='float64', direction=function.IN)
        function.addParameter('na', dtype='float64', direction=function.IN)
        function.addParameter('mg', dtype='float64', direction=function.IN)
        function.addParameter('al', dtype='float64', direction=function.IN)
        function.addParameter('si', dtype='float64', direction=function.IN)
        function.addParameter('p', dtype='float64', direction=function.IN)
        function.addParameter('s', dtype='float64', direction=function.IN)
        function.addParameter('cl', dtype='float64', direction=function.IN)
        function.addParameter('ar', dtype='float64', direction=function.IN)
        function.addParameter('k', dtype='float64', direction=function.IN)
        function.addParameter('ca', dtype='float64', direction=function.IN)
        function.addParameter('sc', dtype='float64', direction=function.IN)
        function.addParameter('ti', dtype='float64', direction=function.IN)
        function.addParameter('v', dtype='float64', direction=function.IN)
        function.addParameter('cr', dtype='float64', direction=function.IN)
        function.addParameter('mn', dtype='float64', direction=function.IN)
        function.addParameter('fe', dtype='float64', direction=function.IN)
        function.addParameter('co', dtype='float64', direction=function.IN)
        function.addParameter('ni', dtype='float64', direction=function.IN)
        function.addParameter('cu', dtype='float64', direction=function.IN)
        function.addParameter('zn', dtype='float64', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_number_of_backups_in_a_row():
        """
        Retrieve the number_of_backups_in_a_row of the star.
        """
        function = LegacyFunctionSpecification() 
        function.can_handle_array = True 
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
            , description="The index of the star to get the value of number_of_backups_in_a_row")
        function.addParameter('n_backup', dtype='int32', direction=function.OUT
            , description="The current number_of_backups_in_a_row of the star.")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            The number_of_backups_in_a_row was retrieved.
        -1 - ERROR
            A star with the given index was not found.
        """
        return function
    
#~    @legacy_function
#~    def reset_number_of_backups_in_a_row():
#~        """
#~        Reset number_of_backups_in_a_row of the star.
#~        """
#~        function = LegacyFunctionSpecification() 
#~        function.can_handle_array = True 
#~        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
#~            , description="The index of the star to reset the value of number_of_backups_in_a_row")
#~        function.result_type = 'int32'
#~        function.result_doc = """
#~        0 - OK
#~            The number_of_backups_in_a_row was reset.
#~        -1 - ERROR
#~            A star with the given index was not found.
#~        """
#~        return function
    
    @legacy_function
    def get_mass_fraction_at_zone():
        function = LegacyFunctionSpecification() 
        function.can_handle_array = True 
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
            , description="The index of the star to get the value of")
        function.addParameter('zone', dtype='int32', direction=function.IN
            , description="The zone/mesh-cell of the star to get the value of")
        function.addParameter('dq_i', dtype='float64', direction=function.OUT
            , description="The mass fraction at the specified zone/mesh-cell of the star.")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            The value was retrieved.
        -1 - ERROR
            A star with the given index was not found.
        -2 - ERROR
            A zone with the given index was not found.
        """
        return function
    
#~    @legacy_function
#~    def set_mass_fraction_at_zone():
#~        """
#~        Set the mass fraction at the specified zone/mesh-cell of the star.
#~        """
#~        function = LegacyFunctionSpecification() 
#~        function.can_handle_array = True 
#~        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
#~            , description="The index of the star to set the value of")
#~        function.addParameter('zone', dtype='int32', direction=function.IN
#~            , description="The zone/mesh-cell of the star to set the value of")
#~        function.addParameter('dq_i', dtype='float64', direction=function.IN
#~            , description="The mass fraction at the specified zone/mesh-cell of the star.")
#~        function.result_type = 'int32'
#~        function.result_doc = """
#~        0 - OK
#~            The value was set.
#~        -1 - ERROR
#~            A star with the given index was not found.
#~        -2 - ERROR
#~            A zone with the given index was not found.
#~        """
#~        return function
#~    
    @legacy_function
    def get_luminosity_at_zone():
        """
        Retrieve the luminosity at the specified zone/mesh-cell of the star.
        """
        function = LegacyFunctionSpecification() 
        function.can_handle_array = True 
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
            , description="The index of the star to get the value of")
        function.addParameter('zone', dtype='int32', direction=function.IN
            , description="The zone/mesh-cell of the star to get the value of")
        function.addParameter('lum_i', dtype='float64', direction=function.OUT
            , description="The luminosity at the specified zone/mesh-cell of the star.")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            The value was retrieved.
        -1 - ERROR
            A star with the given index was not found.
        -2 - ERROR
            A zone with the given index was not found.
        """
        return function
    
#~    @legacy_function
#~    def set_luminosity_at_zone():
#~        """
#~        Set the luminosity at the specified zone/mesh-cell of the star.
#~        """
#~        function = LegacyFunctionSpecification() 
#~        function.can_handle_array = True 
#~        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
#~            , description="The index of the star to set the value of")
#~        function.addParameter('zone', dtype='int32', direction=function.IN
#~            , description="The zone/mesh-cell of the star to set the value of")
#~        function.addParameter('lum_i', dtype='float64', direction=function.IN
#~            , description="The luminosity at the specified zone/mesh-cell of the star.")
#~        function.result_type = 'int32'
#~        function.result_doc = """
#~        0 - OK
#~            The value was set.
#~        -1 - ERROR
#~            A star with the given index was not found.
#~        -2 - ERROR
#~            A zone with the given index was not found.
#~        """
#~        return function
#~    
#~    @legacy_function
#~    def get_entropy_at_zone():
#~        """
#~        Retrieve the entropy at the specified zone/mesh-cell of the star.
#~        """
#~        function = LegacyFunctionSpecification() 
#~        function.can_handle_array = True 
#~        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
#~            , description="The index of the star to get the value of")
#~        function.addParameter('zone', dtype='int32', direction=function.IN
#~            , description="The zone/mesh-cell of the star to get the value of")
#~        function.addParameter('S_i', dtype='float64', direction=function.OUT
#~            , description="The specific entropy at the specified zone/mesh-cell of the star.")
#~        function.result_type = 'int32'
#~        function.result_doc = """
#~        0 - OK
#~            The value was retrieved.
#~        -1 - ERROR
#~            A star with the given index was not found.
#~        -2 - ERROR
#~            A zone with the given index was not found.
#~        """
#~        return function    

    @legacy_function
    def get_thermal_energy_at_zone():
        """
        Retrieve the entropy at the specified zone/mesh-cell of the star.
        """
        function = LegacyFunctionSpecification() 
        function.can_handle_array = True 
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
            , description="The index of the star to get the value of")
        function.addParameter('zone', dtype='int32', direction=function.IN
            , description="The zone/mesh-cell of the star to get the value of")
        function.addParameter('E_i', dtype='float64', direction=function.OUT
            , description="The specific thermal energy at the specified zone/mesh-cell of the star.")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            The value was retrieved.
        -1 - ERROR
            A star with the given index was not found.
        -2 - ERROR
            A zone with the given index was not found.
        """
        return function    
    
    @legacy_function
    def get_brunt_vaisala_frequency_squared_at_zone():
        """
        Retrieve the Brunt-Vaisala frequency squared at the specified zone/mesh-cell of the star.
        """
        function = LegacyFunctionSpecification() 
        function.can_handle_array = True 
        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN, unit=INDEX)
        function.addParameter('zone', dtype='int32', direction=function.IN, unit=NO_UNIT)
        function.addParameter('brunt_N2', dtype='float64', direction=function.OUT, unit=units.s**-2)
        function.result_type = 'int32'
        return function
    
#~    @legacy_function
#~    def erase_memory():
#~        """
#~        Erase memory of the star, i.e. copy the current structure over the memory of 
#~        the structure of the previous steps. Useful after setting the stucture of 
#~        the star, to prevent backup steps to undo changes
#~        """
#~        function = LegacyFunctionSpecification() 
#~        function.can_handle_array = True
#~        function.addParameter('index_of_the_star', dtype='int32', direction=function.IN
#~            , description="The index of the star to get the value of")
#~        function.result_type = 'int32'
#~        return function
#~    
#~    @legacy_function
#~    def get_max_age_stop_condition():
#~        """
#~        Retrieve the current maximum age stop condition of this instance (in years).
#~        Evolution will stop once the star has reached this maximum age.
#~        """
#~        function = LegacyFunctionSpecification()  
#~        function.addParameter('max_age_stop_condition', dtype='float64', direction=function.OUT
#~            , description="The current maximum age stop condition of this instance (in years).")
#~        function.result_type = 'int32'
#~        function.result_doc = """
#~        0 - OK
#~            Current value was retrieved
#~        -1 - ERROR
#~            The code could not retrieve the value.
#~        """
#~        return function
#~    
#~    @legacy_function
#~    def set_max_age_stop_condition():
#~        """
#~        Set the new maximum age stop condition of this instance (in years).
#~        Evolution will stop once the star has reached this maximum age.
#~        """
#~        function = LegacyFunctionSpecification()  
#~        function.addParameter('max_age_stop_condition', dtype='float64', direction=function.IN
#~            , description="The new maximum age stop condition of this instance (in years).")
#~        function.result_type = 'int32'
#~        function.result_doc = """
#~        0 - OK
#~            The value has been set.
#~        -1 - ERROR
#~            The code could not set the value.
#~        """
#~        return function
#~        
    @legacy_function
    def get_min_timestep_stop_condition():
        """
        Retrieve the current minimum timestep stop condition of this instance (in years).
        Evolution will stop if the timestep required by the solver in order to converge
        has decreased below this minimum timestep.
        """
        function = LegacyFunctionSpecification()  
        function.addParameter('min_timestep_stop_condition', dtype='float64', direction=function.OUT
            , description="The current minimum timestep stop condition of this instance (in years).")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            Current value was retrieved
        -1 - ERROR
            The code could not retrieve the value.
        """
        return function
    
    @legacy_function
    def set_min_timestep_stop_condition():
        """
        Set the new minimum timestep stop condition of this instance (in years).
        Evolution will stop if the timestep required by the solver in order to converge
        has decreased below this minimum timestep.
        """
        function = LegacyFunctionSpecification()  
        function.addParameter('min_timestep_stop_condition', dtype='float64', direction=function.IN
            , description="The new minimum timestep stop condition of this instance (in years).")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            The value has been set.
        -1 - ERROR
            The code could not set the value.
        """
        return function
        
#~    @legacy_function
#~    def get_max_iter_stop_condition():
#~        """
#~        Retrieve the current maximum number of iterations of this instance. (Negative means no maximum)
#~        Evolution will stop after this number of iterations.
#~        """
#~        function = LegacyFunctionSpecification()  
#~        function.addParameter('max_iter_stop_condition', dtype='int32', direction=function.OUT
#~            , description="The current maximum number of iterations of this instance.")
#~        function.result_type = 'int32'
#~        function.result_doc = """
#~        0 - OK
#~            Current value was retrieved
#~        -1 - ERROR
#~            The code could not retrieve the value.
#~        """
#~        return function
#~    
#~    @legacy_function
#~    def set_max_iter_stop_condition():
#~        """
#~        Set the new maximum number of iterations of this instance. (Negative means no maximum)
#~        Evolution will stop after this number of iterations.
#~        """
#~        function = LegacyFunctionSpecification()  
#~        function.addParameter('max_iter_stop_condition', dtype='int32', direction=function.IN
#~            , description="The new maximum number of iterations of this instance.")
#~        function.result_type = 'int32'
#~        function.result_doc = """
#~        0 - OK
#~            The value has been set.
#~        -1 - ERROR
#~            The code could not set the value.
#~        """
#~        return function
    
    @legacy_function
    def get_convective_overshoot_parameter():
        function = LegacyFunctionSpecification()  
        function.addParameter('convective_overshoot_parameter', dtype='float64', direction=function.OUT,
            description="The current value of the convective overshoot parameter.")
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_convective_overshoot_parameter():
        function = LegacyFunctionSpecification()  
        function.addParameter('convective_overshoot_parameter', dtype='float64', direction=function.IN,
            description="The new value of the convective overshoot parameter.")
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_mixing_length_ratio():
        """
        Retrieve the current value of the mixing length ratio.
        """
        function = LegacyFunctionSpecification()  
        function.addParameter('mixing_length_ratio', dtype='float64', direction=function.OUT
            , description="The current value of the mixing length ratio.")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            Current value was retrieved
        -1 - ERROR
            The code could not retrieve the value.
        """
        return function
    
    @legacy_function
    def set_mixing_length_ratio():
        """
        Set the value of the mixing length ratio.
        """
        function = LegacyFunctionSpecification()  
        function.addParameter('mixing_length_ratio', dtype='float64', direction=function.IN
            , description="The new value of the mixing length ratio.")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            The value has been set.
        -1 - ERROR
            The code could not set the value.
        """
        return function
        
    @legacy_function
    def get_semi_convection_efficiency():
        """
        Retrieve the current value of the efficiency of semi-convection,
        after Heger, Langer, & Woosley 2000 (ApJ), which goes back to 
        Langer, Sugimoto & Fricke 1983 (A&A).
        """
        function = LegacyFunctionSpecification()  
        function.addParameter('semi_convection_efficiency', dtype='float64', direction=function.OUT
            , description="The current value of the efficiency of semi-convection.")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            Current value was retrieved
        -1 - ERROR
            The code could not retrieve the value.
        """
        return function
    
    @legacy_function
    def set_semi_convection_efficiency():
        """
        Set the value of the efficiency of semi-convection,
        after Heger, Langer, & Woosley 2000 (ApJ), which goes back to 
        Langer, Sugimoto & Fricke 1983 (A&A).
        """
        function = LegacyFunctionSpecification()  
        function.addParameter('semi_convection_efficiency', dtype='float64', direction=function.IN
            , description="The new value of the efficiency of semi-convection.")
        function.result_type = 'int32'
        function.result_doc = """
        0 - OK
            The value has been set.
        -1 - ERROR
            The code could not set the value.
        """
        return function
    
    @legacy_function
    def get_RGB_wind_scheme():
        function = LegacyFunctionSpecification()  
        function.addParameter('RGB_wind_scheme', dtype='string', direction=function.OUT)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_RGB_wind_scheme():
        function = LegacyFunctionSpecification()  
        function.addParameter('RGB_wind_scheme', dtype='string', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_AGB_wind_scheme():
        function = LegacyFunctionSpecification()  
        function.addParameter('AGB_wind_scheme', dtype='string', direction=function.OUT
            , description="The current wind (mass loss) scheme for AGB stars of this instance.")
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_AGB_wind_scheme():
        function = LegacyFunctionSpecification()  
        function.addParameter('AGB_wind_scheme', dtype='string', direction=function.IN
            , description="The new wind (mass loss) scheme for AGB stars of this instance.")
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_reimers_wind_efficiency():
        function = LegacyFunctionSpecification()  
        function.addParameter('reimers_wind_efficiency', dtype='float64', direction=function.OUT)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_reimers_wind_efficiency():
        function = LegacyFunctionSpecification()  
        function.addParameter('reimers_wind_efficiency', dtype='float64', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_blocker_wind_efficiency():
        function = LegacyFunctionSpecification()  
        function.addParameter('blocker_wind_efficiency', dtype='float64', direction=function.OUT)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_blocker_wind_efficiency():
        function = LegacyFunctionSpecification()  
        function.addParameter('blocker_wind_efficiency', dtype='float64', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_de_jager_wind_efficiency():
        function = LegacyFunctionSpecification()  
        function.addParameter('de_jager_wind_efficiency', dtype='float64', direction=function.OUT)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_de_jager_wind_efficiency():
        function = LegacyFunctionSpecification()  
        function.addParameter('de_jager_wind_efficiency', dtype='float64', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_dutch_wind_efficiency():
        function = LegacyFunctionSpecification()  
        function.addParameter('dutch_wind_efficiency', dtype='float64', direction=function.OUT)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_dutch_wind_efficiency():
        function = LegacyFunctionSpecification()  
        function.addParameter('dutch_wind_efficiency', dtype='float64', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_van_Loon_wind_eta():
        function = LegacyFunctionSpecification()  
        function.addParameter('van_Loon_wind_eta', dtype='float64', direction=function.OUT)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_van_Loon_wind_eta():
        function = LegacyFunctionSpecification()  
        function.addParameter('van_Loon_wind_eta', dtype='float64', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_Kudritzki_wind_eta():
        function = LegacyFunctionSpecification()  
        function.addParameter('Kudritzki_wind_eta', dtype='float64', direction=function.OUT)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_Kudritzki_wind_eta():
        function = LegacyFunctionSpecification()  
        function.addParameter('Kudritzki_wind_eta', dtype='float64', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_Nieuwenhuijzen_wind_eta():
        function = LegacyFunctionSpecification()  
        function.addParameter('Nieuwenhuijzen_wind_eta', dtype='float64', direction=function.OUT)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_Nieuwenhuijzen_wind_eta():
        function = LegacyFunctionSpecification()  
        function.addParameter('Nieuwenhuijzen_wind_eta', dtype='float64', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_Vink_wind_eta():
        function = LegacyFunctionSpecification()  
        function.addParameter('Vink_wind_eta', dtype='float64', direction=function.OUT)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_Vink_wind_eta():
        function = LegacyFunctionSpecification()  
        function.addParameter('Vink_wind_eta', dtype='float64', direction=function.IN)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def get_stabilize_new_stellar_model_flag():
        function = LegacyFunctionSpecification()  
        function.addParameter('stabilize_new_stellar_model_flag', dtype='int32', direction=function.OUT)
        function.result_type = 'int32'
        return function
    
    @legacy_function
    def set_stabilize_new_stellar_model_flag():
        function = LegacyFunctionSpecification()  
        function.addParameter('stabilize_new_stellar_model_flag', dtype='int32', direction=function.IN)
        function.result_type = 'int32'
        return function
    
#~    @legacy_function   
#~    def new_stellar_model():
#~        """
#~        Define a new star model in the code. The star needs to be finalized 
#~        before it can evolve, see 'finalize_stellar_model'.
#~        """
#~        function = LegacyFunctionSpecification()  
#~        function.must_handle_array = True
#~        for par in ['d_mass', 'radius', 'rho', 'temperature', 'luminosity', 
#~                'X_H', 'X_He', 'X_C', 'X_N', 'X_O', 'X_Ne', 'X_Mg', 'X_Si', 'X_Fe']:
#~            function.addParameter(par, dtype='float64', direction=function.IN)
#~        function.addParameter('n', 'int32', function.LENGTH)
#~        function.result_type = 'int32'
#~        return function
#~    
#~    @legacy_function   
#~    def finalize_stellar_model():
#~        """
#~        Finalize the new star model defined by 'new_stellar_model'.
#~        """
#~        function = LegacyFunctionSpecification()  
#~        function.addParameter('index_of_the_star', dtype='int32', 
#~            direction=function.OUT, description = "The new index for the star. "
#~            "This index can be used to refer to this star in other functions")
#~        function.addParameter('age_tag', dtype='float64', direction=function.IN, 
#~            description = "The initial age of the star")
#~        function.result_type = 'int32'
#~        return function

class MESA(StellarEvolution, InternalStellarStructure):
    
    def __init__(self, **options):
        InCodeComponentImplementation.__init__(self, MESAInterface(**options), **options)
        
        output_dir = self.get_output_directory()
        if not self.channel_type == 'distributed':
            self.ensure_data_directory_exists(os.path.join(output_dir, 'star_data', 'starting_models'))
        
        self.set_MESA_paths(
            self.default_path_to_inlist, 
            self.default_path_to_MESA, 
            output_dir
        )
        self.model_time = 0.0 | units.yr
        
    
    def define_parameters(self, object):
        
        object.add_method_parameter(
            "get_metallicity",
            "set_metallicity",
            "metallicity", 
            "Initial metallicity (Z) of all pre-main-sequence stars (for ZAMS stars, change the 'zamsfile' parameter)", 
            default_value = 0.02
        )
        object.add_method_parameter(
            "get_zamsfile",
            "set_zamsfile",
            "zamsfile", 
            "Path to the zero-age main sequence stellar models.", 
            default_value = "zams_z2m2_y28.data"
        )
        
        object.add_method_parameter(
            "get_min_timestep_stop_condition",
            "set_min_timestep_stop_condition",
            "min_timestep_stop_condition", 
            "The minimum timestep stop condition of this instance.",
            default_value = 1.0e-6 | units.s
        )
        
        object.add_method_parameter(
            "get_convective_overshoot_parameter",
            "set_convective_overshoot_parameter",
            "herwig_convective_overshoot_parameter", 
            "The convective overshoot parameter (Herwig 2000), f=0.016 is argued to be a reasonable value.",
            default_value = 0.0
        )
        
        object.add_method_parameter(
            "get_mixing_length_ratio",
            "set_mixing_length_ratio",
            "mixing_length_ratio", 
            "The mixing-length ratio (alpha).",
            default_value = 2.0
        )
        
        object.add_method_parameter(
            "get_semi_convection_efficiency",
            "set_semi_convection_efficiency",
            "semi_convection_efficiency", 
            "The efficiency of semi-convection, after Heger, Langer, & Woosley 2000 (ApJ), "
               "which goes back to Langer, Sugimoto & Fricke 1983 (A&A).",
            default_value = 0.0
        )
        
        object.add_method_parameter(
            "get_RGB_wind_scheme",
            "set_RGB_wind_scheme",
            "RGB_wind_scheme", 
            "The mass loss scheme for RGB stars: ''(=no automatic wind), 'Reimers', "
               "'Blocker', 'de Jager', 'van Loon', 'Nieuwenhuijzen', 'Kudritzki', 'Vink' or 'Dutch'",
            default_value = ''
        )
        
        object.add_method_parameter(
            "get_AGB_wind_scheme",
            "set_AGB_wind_scheme",
            "AGB_wind_scheme", 
            "The mass loss scheme for AGB stars: ''(=no automatic wind), 'Reimers', "
               "'Blocker', 'de Jager', 'van Loon', 'Nieuwenhuijzen', 'Kudritzki', 'Vink' or 'Dutch'",
            default_value = ''
        )
        
        object.add_method_parameter(
            "get_reimers_wind_efficiency",
            "set_reimers_wind_efficiency",
            "reimers_wind_efficiency", 
            "The Reimers mass loss efficiency. Only used if (RGB/AGB_wind_scheme == 'Reimers').",
            default_value = 0.5
        )
        object.add_method_parameter(
            "get_blocker_wind_efficiency",
            "set_blocker_wind_efficiency",
            "blocker_wind_efficiency", 
            "The Blocker mass loss efficiency. Only used if (RGB/AGB_wind_scheme == 'Blocker').",
            default_value = 0.1
        )
        object.add_method_parameter(
            "get_de_jager_wind_efficiency",
            "set_de_jager_wind_efficiency",
            "de_jager_wind_efficiency", 
            "The de Jager mass loss efficiency. Only used if (RGB/AGB_wind_scheme == 'de Jager').",
            default_value = 0.8
        )
        object.add_method_parameter(
            "get_dutch_wind_efficiency",
            "set_dutch_wind_efficiency",
            "dutch_wind_efficiency", 
            "The Dutch mass loss efficiency. Only used if (RGB/AGB_wind_scheme == 'Dutch').",
            default_value = 0.8
        )
        object.add_method_parameter(
            "get_van_Loon_wind_eta",
            "set_van_Loon_wind_eta",
            "van_loon_wind_efficiency", 
            "The van Loon mass loss efficiency. Only used if (RGB/AGB_wind_scheme == 'van Loon').",
            default_value = 0.0
        )
        object.add_method_parameter(
            "get_Kudritzki_wind_eta",
            "set_Kudritzki_wind_eta",
            "kudritzki_wind_efficiency", 
            "The Kudritzki mass loss efficiency. Only used if (RGB/AGB_wind_scheme == 'Kudritzki').",
            default_value = 0.0
        )
        object.add_method_parameter(
            "get_Nieuwenhuijzen_wind_eta",
            "set_Nieuwenhuijzen_wind_eta",
            "nieuwenhuijzen_wind_efficiency", 
            "The Nieuwenhuijzen mass loss efficiency. Only used if (RGB/AGB_wind_scheme == 'Nieuwenhuijzen').",
            default_value = 0.0
        )
        object.add_method_parameter(
            "get_Vink_wind_eta",
            "set_Vink_wind_eta",
            "vink_wind_efficiency", 
            "The Vink mass loss efficiency. Only used if (RGB/AGB_wind_scheme == 'Vink').",
            default_value = 0.0
        )
        object.add_boolean_parameter(
            "get_stabilize_new_stellar_model_flag",
            "set_stabilize_new_stellar_model_flag",
            "stabilize_new_stellar_model_flag",
            "Flag specifying whether to stabilize any loaded stellar models first.",
            default_value = True
        )
        
        
        
    def define_particle_sets(self, object):
        object.define_set('particles', 'index_of_the_star')
        object.set_new('particles', 'new_particle_method')
        object.set_delete('particles', 'delete_star')
        
        object.add_getter('particles', 'get_radius', names = ('radius',))
        object.add_getter('particles', 'get_stellar_type', names = ('stellar_type',))
        object.add_getter('particles', 'get_mass', names = ('mass',))
        object.add_getter('particles', 'get_core_mass', names = ('core_mass',))
        object.add_getter('particles', 'get_mass_loss_rate', names = ('wind',))
        object.add_getter('particles', 'get_age', names = ('age',))
        object.add_getter('particles', 'get_time_step', names = ('time_step',))
        object.add_setter('particles', 'set_time_step', names = ('time_step',))
        object.add_getter('particles', 'get_luminosity', names = ('luminosity',))
        object.add_getter('particles', 'get_temperature', names = ('temperature',))
        
        object.add_getter('particles', 'get_manual_mass_transfer_rate', names = ('mass_change',))
        object.add_setter('particles', 'set_manual_mass_transfer_rate', names = ('mass_change',))
        
        object.add_method('particles', 'get_accrete_same_as_surface')
        object.add_method('particles', 'set_accrete_same_as_surface')
        object.add_method('particles', 'get_accrete_composition_non_metals')
        object.add_method('particles', 'set_accrete_composition_non_metals')
        object.add_method('particles', 'get_accrete_composition_metals_identifier')
        object.add_method('particles', 'set_accrete_composition_metals_identifier')
        object.add_method('particles', 'get_accrete_composition_metals')
        object.add_method('particles', 'set_accrete_composition_metals')
        
        object.add_method('particles', 'evolve_one_step')
        object.add_method('particles', 'evolve_for')
        object.add_method('particles', 'write_star_to_file')
        InternalStellarStructure.define_particle_sets(self, object)
#~            self, 
#~            object, 
#~            set_name = 'particles'
#~        )
        object.add_method('particles', 'get_mass_profile')
#~        object.add_method('particles', 'set_mass_profile')
        object.add_method('particles', 'get_cumulative_mass_profile')
        object.add_method('particles', 'get_luminosity_profile')
#~        object.add_method('particles', 'set_luminosity_profile')
        object.add_method('particles', 'get_entropy_profile')
        object.add_method('particles', 'get_thermal_energy_profile')
        object.add_method('particles', 'get_brunt_vaisala_frequency_squared_profile')
#~        object.add_method('particles', 'get_IDs_of_species')
#~        object.add_method('particles', 'get_masses_of_species')
#~        object.add_method('particles', 'get_number_of_backups_in_a_row')
#~        object.add_method('particles', 'reset_number_of_backups_in_a_row')
            
    def define_state(self, object):
        StellarEvolution.define_state(self, object)
        object.add_method('EDIT', 'finalize_stellar_model')
        object.add_method('UPDATE', 'finalize_stellar_model')
        object.add_transition('RUN', 'UPDATE', 'finalize_stellar_model', False)
        object.add_method('EDIT', 'new_particle_method')
        object.add_method('UPDATE', 'new_particle_method')
        object.add_transition('RUN', 'UPDATE', 'new_particle_method', False)
    
    def define_errorcodes(self, object):
        InternalStellarStructure.define_errorcodes(self, object)
        object.add_errorcode(-1, 'Something went wrong...')
        object.add_errorcode(-4, 'Not implemented.')
        object.add_errorcode(-11, 'Evolve terminated: Unspecified stop condition reached.')
        object.add_errorcode(-12, 'Evolve terminated: Maximum age reached.')
        object.add_errorcode(-13, 'Evolve terminated: Maximum number of iterations reached.')
        object.add_errorcode(-14, 'Evolve terminated: Maximum number of backups reached.')
        object.add_errorcode(-15, 'Evolve terminated: Minimum timestep limit reached.')
    
    def define_methods(self, object):
        InternalStellarStructure.define_methods(self, object)
        StellarEvolution.define_methods(self, object)
        object.add_method(
            "new_particle_method",
            (units.MSun, object.NO_UNIT, object.NO_UNIT),
            (object.INDEX, object.ERROR_CODE)
        )
        object.add_method(
            "set_time_step", 
            (object.INDEX, units.yr), 
            (object.ERROR_CODE,)
        )
        object.add_method(
            "get_core_mass",
            (object.INDEX,),
            (units.MSun, object.ERROR_CODE,)
        )
        object.add_method(
            "get_mass_loss_rate",
            (object.INDEX,),
            (units.g / units.s, object.ERROR_CODE,)
        )
        object.add_method(
            "get_manual_mass_transfer_rate",
            (object.INDEX,),
            (units.MSun / units.yr, object.ERROR_CODE,)
        )
        object.add_method(
            "set_manual_mass_transfer_rate",
            (object.INDEX, units.MSun / units.yr),
            (object.ERROR_CODE,)
        )
        object.add_method(
            "get_number_of_backups_in_a_row", 
            (object.INDEX,), 
            (object.NO_UNIT, object.ERROR_CODE,)
        )
        object.add_method(
            "reset_number_of_backups_in_a_row", 
            (object.INDEX,), 
            (object.ERROR_CODE,)
        )
        object.add_method(
            "get_mass_fraction_at_zone", 
            (object.INDEX,object.NO_UNIT,), 
            (object.NO_UNIT, object.ERROR_CODE,)
        )
        object.add_method(
            "set_mass_fraction_at_zone", 
            (object.INDEX, object.NO_UNIT, object.NO_UNIT,), 
            (object.ERROR_CODE,)
        )
        object.add_method(
            "get_luminosity_at_zone", 
            (object.INDEX,object.NO_UNIT,), 
            (units.erg/units.s, object.ERROR_CODE,)
        )
        object.add_method(
            "set_luminosity_at_zone", 
            (object.INDEX, object.NO_UNIT, units.erg/units.s,), 
            (object.ERROR_CODE,)
        )
        object.add_method(
            "get_entropy_at_zone", 
            (object.INDEX,object.NO_UNIT,), 
            (units.erg/units.K, object.ERROR_CODE,)
        )        
        object.add_method(
            "get_thermal_energy_at_zone", 
            (object.INDEX,object.NO_UNIT,), 
            (units.erg/units.g, object.ERROR_CODE,)
        )        
        object.add_method(
            "erase_memory", 
            (object.INDEX,), 
            (object.ERROR_CODE,),
            public_name = "_erase_memory"
        )
        object.add_method(
            "new_stellar_model", 
            (units.MSun, units.cm, units.g / units.cm**3, units.K, units.erg / units.s, 
                object.NO_UNIT, object.NO_UNIT, object.NO_UNIT, object.NO_UNIT, object.NO_UNIT, 
                object.NO_UNIT, object.NO_UNIT, object.NO_UNIT, object.NO_UNIT,), 
            (object.ERROR_CODE,)
        )
        object.add_method(
            "finalize_stellar_model", 
            (units.yr,), 
            (object.INDEX, object.ERROR_CODE,)
        )
        
        object.add_method(
            "get_max_age_stop_condition", 
            (), 
            (units.yr, object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "set_max_age_stop_condition", 
            (units.yr, ), 
            (object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "get_min_timestep_stop_condition", 
            (), 
            (units.s, object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "set_min_timestep_stop_condition", 
            (units.s, ), 
            (object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "get_max_iter_stop_condition", 
            (), 
            (object.NO_UNIT, object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "set_max_iter_stop_condition", 
            (object.NO_UNIT, ), 
            (object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "get_mixing_length_ratio", 
            (), 
            (object.NO_UNIT, object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "set_mixing_length_ratio", 
            (object.NO_UNIT, ), 
            (object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "get_semi_convection_efficiency", 
            (), 
            (object.NO_UNIT, object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "set_semi_convection_efficiency", 
            (object.NO_UNIT, ), 
            (object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "get_RGB_wind_scheme", 
            (), 
            (object.NO_UNIT, object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "set_RGB_wind_scheme", 
            (object.NO_UNIT, ), 
            (object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "get_AGB_wind_scheme", 
            (), 
            (object.NO_UNIT, object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "set_AGB_wind_scheme", 
            (object.NO_UNIT, ), 
            (object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "get_reimers_wind_efficiency", 
            (), 
            (object.NO_UNIT, object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "set_reimers_wind_efficiency", 
            (object.NO_UNIT, ), 
            (object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "get_blocker_wind_efficiency", 
            (), 
            (object.NO_UNIT, object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "set_blocker_wind_efficiency", 
            (object.NO_UNIT, ), 
            (object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "get_de_jager_wind_efficiency", 
            (), 
            (object.NO_UNIT, object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "set_de_jager_wind_efficiency", 
            (object.NO_UNIT, ), 
            (object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "get_dutch_wind_efficiency", 
            (), 
            (object.NO_UNIT, object.ERROR_CODE,)
        )
        
    
        object.add_method(
            "set_dutch_wind_efficiency", 
            (object.NO_UNIT, ), 
            (object.ERROR_CODE,)
        )
        
    
    def initialize_module_with_default_parameters(self):
        self.parameters.set_defaults()
        self.initialize_code()
        
    def initialize_module_with_current_parameters(self):
        self.initialize_code()
    
    def commit_parameters(self):
        self.parameters.send_not_set_parameters_to_code()
        self.parameters.send_cached_parameters_to_code()
        self.overridden().commit_parameters()
        
    def get_mass_profile(self, indices_of_the_stars, number_of_zones = None):
        indices_of_the_stars = self._check_number_of_indices(indices_of_the_stars, action_string = "Querying mass profiles")
        if number_of_zones is None:
            number_of_zones = self.get_number_of_zones(indices_of_the_stars)
        return self.get_mass_fraction_at_zone([indices_of_the_stars]*number_of_zones, range(number_of_zones) | units.none)
    
    def get_cumulative_mass_profile(self, indices_of_the_stars, number_of_zones = None):
        frac_profile = self.get_mass_profile(indices_of_the_stars, number_of_zones = number_of_zones)
        return frac_profile.cumsum()
    
    def set_mass_profile(self, indices_of_the_stars, values, number_of_zones = None):
        indices_of_the_stars = self._check_number_of_indices(indices_of_the_stars, action_string = "Setting mass profiles")
        if number_of_zones is None:
            number_of_zones = self.get_number_of_zones(indices_of_the_stars)
        self._check_supplied_values(len(values), number_of_zones)
        self.set_mass_fraction_at_zone([indices_of_the_stars]*number_of_zones, range(number_of_zones) | units.none, values)
        if hasattr(self, "_erase_memory"):
            self._erase_memory(indices_of_the_stars)
    
    def get_luminosity_profile(self, indices_of_the_stars, number_of_zones = None):
        indices_of_the_stars = self._check_number_of_indices(indices_of_the_stars, action_string = "Querying luminosity profiles")
        if number_of_zones is None:
            number_of_zones = self.get_number_of_zones(indices_of_the_stars)
        return self.get_luminosity_at_zone([indices_of_the_stars]*number_of_zones, range(number_of_zones) | units.none)
    
    def set_luminosity_profile(self, indices_of_the_stars, values, number_of_zones = None):
        indices_of_the_stars = self._check_number_of_indices(indices_of_the_stars, action_string = "Setting luminosity profiles")
        if number_of_zones is None:
            number_of_zones = self.get_number_of_zones(indices_of_the_stars)
        self._check_supplied_values(len(values), number_of_zones)
        self.set_luminosity_at_zone([indices_of_the_stars]*number_of_zones, range(number_of_zones) | units.none, values)
        if hasattr(self, "_erase_memory"):
            self._erase_memory(indices_of_the_stars)

    def get_entropy_profile(self, indices_of_the_stars, number_of_zones = None):
        indices_of_the_stars = self._check_number_of_indices(indices_of_the_stars, action_string = "Querying entropy profiles")
        if number_of_zones is None:
            number_of_zones = self.get_number_of_zones(indices_of_the_stars)
        return self.get_entropy_at_zone([indices_of_the_stars]*number_of_zones, range(number_of_zones) | units.none)
    
    def get_thermal_energy_profile(self, indices_of_the_stars, number_of_zones = None):
        indices_of_the_stars = self._check_number_of_indices(indices_of_the_stars, action_string = "Querying thermal energy profiles")
        if number_of_zones is None:
            number_of_zones = self.get_number_of_zones(indices_of_the_stars)
        return self.get_thermal_energy_at_zone([indices_of_the_stars]*number_of_zones, range(number_of_zones) | units.none)

    def get_brunt_vaisala_frequency_squared_profile(self, indices_of_the_stars, number_of_zones = None):
        indices_of_the_stars = self._check_number_of_indices(indices_of_the_stars, action_string = "Querying brunt-vaisala-frequency-squared profiles") 
        if number_of_zones is None:
            number_of_zones = self.get_number_of_zones(indices_of_the_stars)
        return self.get_brunt_vaisala_frequency_squared_at_zone([indices_of_the_stars]*number_of_zones, range(number_of_zones) | units.none)
    
    def new_particle_from_model(self, internal_structure, current_age, key=None):
        if isinstance(internal_structure, dict):
            if "dmass" in internal_structure:
                mass_profile = internal_structure['dmass'][::-1]
            else:
                cumulative_mass_profile = [0.0] | units.MSun
                cumulative_mass_profile.extend(internal_structure['mass'])
                mass_profile = (cumulative_mass_profile[1:] - cumulative_mass_profile[:-1])[::-1]
            self.new_stellar_model(
                mass_profile,
                internal_structure['radius'][::-1],
                internal_structure['rho'][::-1],
                internal_structure['temperature'][::-1],
                internal_structure['luminosity'][::-1],
                internal_structure['X_H'][::-1],
                internal_structure['X_He'][::-1],
                internal_structure['X_C'][::-1],
                internal_structure['X_N'][::-1],
                internal_structure['X_O'][::-1],
                internal_structure['X_Ne'][::-1],
                internal_structure['X_Mg'][::-1],
                internal_structure['X_Si'][::-1],
                internal_structure['X_Fe'][::-1]
            )
        else:
            if hasattr(internal_structure, "dmass"):
                mass_profile = internal_structure.dmass[::-1]
            else:
                cumulative_mass_profile = [0.0] | units.MSun
                cumulative_mass_profile.extend(internal_structure.mass)
                mass_profile = (cumulative_mass_profile[1:] - cumulative_mass_profile[:-1])[::-1]
            self.new_stellar_model(
                mass_profile,
                internal_structure.radius[::-1],
                internal_structure.rho[::-1],
                internal_structure.temperature[::-1],
                internal_structure.luminosity[::-1],
                internal_structure.X_H[::-1],
                internal_structure.X_He[::-1],
                internal_structure.X_C[::-1],
                internal_structure.X_N[::-1],
                internal_structure.X_O[::-1],
                internal_structure.X_Ne[::-1],
                internal_structure.X_Mg[::-1],
                internal_structure.X_Si[::-1],
                internal_structure.X_Fe[::-1]
            )
        tmp_star = datamodel.Particle(key=key)
        tmp_star.age_tag = current_age
        return self.imported_stars.add_particle(tmp_star)

