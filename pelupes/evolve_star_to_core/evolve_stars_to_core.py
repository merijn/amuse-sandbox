from job_server import JobServer
from optparse import OptionParser

import numpy

from evolve_star_to_core import evolve_star_to_core_mass

channel_type="mpi"
hosts=["paddegat"]*2+["koppoel"]+["biesbosch"]

def new_option_parser():
    result = OptionParser()
    result.add_option("-H", dest="H_abundance_limit", type="float",
                      default = 1.0e-9,
                      help="Hydrogen abundance limit for core [1.e-9]")
    result.add_option("-m", dest="Mcore", type="float",default = 0.60,
                      help="core mass [0.6] MSun")
    result.add_option("-z", dest="z", type="float", default = 0.02,
                      help="Stellar metalicity [0.02]")
    result.add_option("-l", dest="minMZAMS", type="float",default = 3.0,
                      help="minimum Stellar mass [3.0] MSun")
    result.add_option("-u", dest="maxMZAMS", type="float",default = 3.0,
                      help="maximum Stellar mass [3.0] MSun")
    result.add_option("-d", dest="dM", type="float",default = 1.0,
                      help="Stellar mass step [1.0] MSun")
    return result

def evolve_stars_to_core_mass(minMZAMS,maxMZAMS,dM, Mcore, z, H_abundance_limit):
  
  jobserver=JobServer(channel_type=channel_type, hosts=hosts)
  
  M=minMZAMS
  while M<=maxMZAMS:
    jobserver.submit_job( evolve_star_to_core_mass, (M,Mcore, z, H_abundance_limit))
    M+=dM
    
   
  while jobserver.wait():
    job=jobserver.last_finished_job
    result = job.result
    if len(result)<4:
      print "For ZAMS star of M=",job.args[0]," failure",result
    else:
      t, Mt, Rt, Mtcore =result
      print "For ZAMS star of M=", job.args[0], "at T=", t, "M=", Mt, "R=", Rt, "Mc=", Mtcore 
     
if __name__ in ('__main__', '__plot__'):
    o, arguments  = new_option_parser().parse_args()
    evolve_stars_to_core_mass(**o.__dict__)
