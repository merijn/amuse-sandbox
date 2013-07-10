import plummer2d
import time
import numpy

from amuse.units import nbody_system
from amuse.units import quantities

from amuse.community.hermite0.interface import Hermite
from amuse.community.kepler.interface import Kepler
from amuse.community.smalln.interface import SmallN
from amuse.couple import encounters

from stompest.config import StompConfig
from stompest.sync import Stomp

import json

from optparse import OptionParser

    
def run_hermite(client, queue, seed):
    print "starting... 1"
    
    if seed > 0:
        numpy.random.seed(seed)
    
    scale =  1 | nbody_system.length
    scalev = 1 | nbody_system.speed
    model = plummer2d.new_plummer_model_2D(20)
    
    kepler = Kepler()
    kepler.initialize_code()
    
    smalln = SmallN()
    smalln.parameters.timestep_parameter = 0.1
    smalln.parameters.cm_index = 2001
    
        
    encounter_code = encounters.HandleEncounter(
        kepler_code =  kepler,
        resolve_collision_code = smalln,
        interaction_over_code = None
    )
    
    gravity_code = Hermite()
    code = encounters.Multiples(
        gravity_code = gravity_code,
        handle_encounter_code = encounter_code
    )
    model.radius = 0.007 | nbody_system.length
    code.particles.add_particles(model)
    end_time = 10 | nbody_system.time
    code.commit_particles()
    stopping_condition = code.stopping_conditions.encounter_detection
    stopping_condition.enable()
    
    try:
        t = 0.0 * end_time
        dt = end_time / 1000.0
        while t < end_time:
            code.evolve_model(t)
            if stopping_condition.is_set():
                before = []
                after = []
                model = stopping_condition.particles(0)[0]
                for p in model.particles_before_evolve:
                    before.append(
                        {
                            'key': str(p.key),
                            'x' : p.x / scale,
                            'y' : p.y / scale,
                            'vx' : p.vx / scalev,
                            'vy' : p.vy / scalev
                        }
                    ) 
                for p in model.particles_after_evolve:
                    after.append(
                        {
                            'key':str(p.key),
                            'x' : p.x / scale,
                            'y' : p.y / scale,
                            'vx' : p.vx / scalev,
                            'vy' : p.vy / scalev
                        }
                    )
                
                message = {
                    'type' : 'encounter',
                    'time-str' : str(code.model_time),
                    'time-value' : code.model_time.value_in(nbody_system.time),
                    'before' : before,
                    'after' : after,
                }
                client.send(queue, json.dumps(message))
                t = code.model_time
            else:
                t += dt
            
            print t
            
            
            particles = code.all_singles
            message = {
                'type' : 'particles',
                'time-str' : str(code.model_time),
                'time-value' : code.model_time.value_in(nbody_system.time),
                'x' : list(particles.x / scale),
                'y' : list(particles.y / scale)
            }
            client.send(queue, json.dumps(message))
                
    finally:
        print "stopping..."
        gravity_code.stop()
        kepler.stop()
        smalln.stop()
        print "done"
       
def new_option_parser():
    result = OptionParser()
    result.add_option(
        "-q", "--queue", 
        default = "plummer",
        dest="queue_name",
        help="name of the message queue to report on",
        type="string"
    )
    result.add_option(
        "-s", "--seed", 
        default = -1,
        dest="seed",
        help="random seed to use",
        type="int"
    )
    return result
if  __name__ == '__main__':
    
    options, arguments = new_option_parser().parse_args()

    stomp_config = StompConfig('tcp://localhost:61613', login='guest', passcode='password')
    stomp_queue = '/queue/' + options.queue_name

    client = Stomp(stomp_config)
    client.connect()
    
    run_hermite(client, stomp_queue, options.seed)

    client.disconnect()