"""
 run script for clustergas runs

"""

import numpy
import clustergas_gadget as clustergas
from amuse.units import units
from amuse.community.fi.interface import Fi
from amuse.community.octgrav.interface import Octgrav
from amuse.community.gadget2.interface import Gadget2
from amuse.community.bhtree.interface import BHTree
from amuse.community.phiGRAPE.interface import PhiGRAPE
from SSEplus import SSEplus

#nice big star with 100 stars
#numpy.random.seed(123489)

#best guess inti's original seed
numpy.random.seed(123491)

clustergas.clustergas(sfeff=0.3, 
                    Nstar=1000,
                    Ngas=100000,
                    Rscale=0.5 | units.parsec,
                    runid="cl_Ns1k_Ng100k_sf03_sn001_R05",
                    feedback_efficiency=0.01,
		                dt_plot=0.01 | units.Myr,

		    #LGM
                    grav_code=PhiGRAPE,
                    grav_code_extra=dict(mode='normal',channel_type="sockets"),

		    #VU
                    gas_code=Gadget2,
                    gas_code_extra=dict(mode='nogravity', output_directory='output',redirection="none",channel_type="sockets", number_of_workers=3, number_of_nodes=1,use_gl=False),

                    #UVA
                    se_code=SSEplus,
                    se_code_extra=dict(channel_type="sockets"),

                    #DELFT
                    grav_couple_code=Fi,
                    grav_couple_code_extra=dict(mode="openmp",channel_type="sockets")
)


#clustergas.clustergas_restart(
#                   "test",
#                   250,newid='test_restart')

