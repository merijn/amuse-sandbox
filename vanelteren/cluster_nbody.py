import sys
import unittest
import numpy 
import random
import collections
import os

from amuse.io import store
from amuse.units import nbody_system
from amuse.units import units
from amuse.community.hermite0.interface import Hermite
from amuse.community.bhtree.interface import BHTree
from amuse.community.phiGRAPE.interface import PhiGRAPE
from amuse.datamodel import particle_attributes
from amuse.rfi.core import is_mpd_running
from amuse.ic.plummer import new_plummer_model
def print_log(time, gravity, particles, total_energy_at_t0):
    kinetic_energy = gravity.kinetic_energy
    potential_energy = gravity.potential_energy
    total_energy_at_this_time = kinetic_energy + potential_energy
    print "T     : ", str(time)
    print "ERROR : ", (total_energy_at_this_time - total_energy_at_t0) / total_energy_at_t0
    print "KE    : ", kinetic_energy 
    print "PE    : ", potential_energy
    print "KE/PE : ", kinetic_energy / potential_energy
    print "KE+PE : ", kinetic_energy + potential_energy
    
    #print  "center of mass:" , particles.center_of_mass()
    #print  "center of mass velocity:" , particles.center_of_mass_velocity()
    
def simulate_small_cluster(number_of_stars, end_time = 40 | nbody_system.time, number_of_workers = 1):
    numpy.random.seed()
    
    particles = new_plummer_model(number_of_stars)
    particles.scale_to_standard()
   
    #gravity = PhiGRAPE(PhiGRAPE.NBODY)
    gravity = Hermite(
        number_of_workers = number_of_workers, 
        #debugger = "xterm",
        #redirection = "none"
    )
    gravity.initialize_code()
    #gravity.parameters.epsilon_squared = 0.15 | nbody_system.length ** 2
    
    particles.radius = 0.0 | nbody_system.length
    print  "center of mass:", particles.center_of_mass()
    
    gravity.particles.add_particles(particles)
    from_model_to_gravity = particles.new_channel_to(gravity.particles)
    from_gravity_to_model = gravity.particles.new_channel_to(particles)
    
    gravity.commit_particles()
    print "1"  
    time = 0.0 | end_time.unit
        
    
    output_file = "nbody.hdf5"
    if os.path.exists(output_file):
        os.remove(output_file)
    
    storage = store.StoreHDF(output_file)

    storage.store(particles.savepoint(time))
    
    total_energy_at_t0 = gravity.kinetic_energy + gravity.potential_energy
    
    print "evolving the model until t = " + str(end_time)
    while time < end_time:
        time += 0.1 | end_time.unit
        
        print "gravity evolve step starting"
        gravity.evolve_model(time)
        print "gravity evolve step done"
        
        from_gravity_to_model.copy()

        storage.store(particles.savepoint(time))
        
        print_log(time, gravity, particles, total_energy_at_t0)
   
    gravity.stop()
    
    
if __name__ == '__main__':
    simulate_small_cluster(
        int(sys.argv[1]), 
        int(sys.argv[2]) | nbody_system.time,
        int(sys.argv[3])
    )
