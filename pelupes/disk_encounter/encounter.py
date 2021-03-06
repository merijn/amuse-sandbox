import os
from socket import gethostname
import numpy
import time

import matplotlib
#matplotlib.use('Agg')
from matplotlib import pyplot

from amuse.community.twobody.twobody import TwoBody
from amuse.units import units
from amuse.units import nbody_system
from amuse.units import constants
from amuse.datamodel import Particles
#from amuse.community.fi.interface import Fi
from amuse.ext.protodisk import ProtoPlanetaryDisk
from amuse.io import write_set_to_file,read_set_from_file

from fast import FAST
from directsum import directsum
from boxedfi import BoxedFi as Fi

from amuse.datamodel.rotation import rotate

def encounter(interface,m1=1.|units.MSun,m2=.5| units.MSun,r1=None,r2=None,
     ecc=1.1,Rimpact=500. | units.AU,Rstart=None,inclination=0):

  rp=Rimpact
  mu=constants.G*(m1+m2)
  vp=(mu/Rimpact*(1+ecc))**0.5

  h=rp*vp
  p=h*h/mu

  a=p/(1-ecc**2)

  f1=m2/(m1+m2)
  f2=m1/(m1+m2)

  r0=rp

  print 'semimajor axis:', a.in_(units.AU)
  print 'impact parameter:',r0.in_(units.AU)
  
  v0=vp

  bin=Particles(2)

  bin[0].mass=m1
  bin[0].x=r0*f1
  bin[0].vy=v0*f1
  bin[1].mass=m2
  bin[1].x=-r0*f2
  bin[1].vy=-v0*f2

  bin.y=0*r0
  bin.z=0.*r0
  bin.vx=0*v0
  bin.vz=0.*v0

  rotate(bin,0,numpy.pi*inclination/180.,0)

  if r1 is None:
    bin[0].radius=(1.|units.RSun)*(m1/(1.|units.MSun))**(1./3.)
  else:
    bin[0].radius=r1
  if r2 is None:
    bin[1].radius=(1.|units.RSun)*(m2/(1.|units.MSun))**(1./3.)
  else:
    bin[1].radius=r2

  convert=nbody_system.nbody_to_si(1.|units.MSun,100.|units.AU)
  if Rstart is None:
      nb = interface(convert,redirection="none")
      bin=nb.particles.add_particles(bin)
    
      print (bin[1].position-bin[0].position).length().in_(units.AU)
    
      nb.evolve_model(-2.e3 | units.yr)
     
      print "initial sep:",(bin[1].position-bin[0].position).length().in_(units.AU)
      bin=bin.copy()
  else:
      raise Exception("not implemented")

  bin.position-=bin[0].position
  bin.velocity-=bin[0].velocity

  nb=interface(convert,redirection="none")
  nb.particles.add_particles(bin)

  return nb

def sphdisc(interface,N=10000,Mstar=1| units.MSun, Rmin=1.|units.AU,
              Rmax=10|units.AU, q_out=1.5, discfraction=0.1,densitypower=1,dt_sph=1|units.day):

    convert=nbody_system.nbody_to_si(Mstar, 1.| Rmin.unit)
    proto=ProtoPlanetaryDisk(N,convert_nbody=convert,densitypower=densitypower,
                               Rmin=Rmin.number,Rmax=Rmax.number,q_out=q_out,
                               discfraction=discfraction)
    gas=proto.result
    gas.h_smooth=.1 | units.AU
    gas.u0=gas.u.copy()

    print Rmax,Rmin
    convert=nbody_system.nbody_to_si(Mstar, Rmax)
    print convert.to_nbody(1.e-13 |units.g/units.cm**3),gas.total_mass().in_(units.MSun)
    sph=interface(convert,mode="openmp",redirection='none')

    sph.parameters.use_hydro_flag=True
    sph.parameters.radiation_flag=False
    sph.parameters.self_gravity_flag=True
    sph.parameters.gamma=1.
    sph.parameters.isothermal_flag=True
    sph.parameters.integrate_entropy_flag=False
    sph.parameters.timestep=dt_sph  
    sph.parameters.verbosity=0
    sph.parameters.courant=0.2    

#    print sph.parameters
#    print sph.parameters.periodic_box_size.in_(units.AU)
    print 'disc mass:',gas.mass.sum().in_(units.MSun)

#    pyplot.plot(gas.x.number,((2|units.amu)*gas.u/(constants.kB)).value_in(units.K),'r+')
#    pyplot.show()
#    raise

    sph.gas_particles.add_particles(gas)

    return sph,gas

def make_map(sph,N=100,L=1,poffset=[0,0,0]|units.AU,
     voffset=[0,0,0]| units.kms):

    x,y=numpy.indices( ( N+1,N+1 ))

    x=L*(x.flatten()-N/2.)/N
    y=L*(y.flatten()-N/2.)/N
    z=x*0.

    vx=0.*x
    vy=0.*x
    vz=0.*x

    x=units.AU(x)+poffset[0]
    y=units.AU(y)+poffset[1]
    z=units.AU(z)+poffset[2]
    vx=units.kms(vx)+voffset[0]
    vy=units.kms(vy)+voffset[1]
    vz=units.kms(vz)+voffset[2]

    rho,rhovx,rhovy,rhovz,rhoe=sph.get_hydro_state_at_point(x,y,z,vx,vy,vz)
    rho=rho.reshape((N+1,N+1))

    return numpy.transpose(rho)

def make_phi_map(sph,N=100,Rrange=(0.3,2),phioffset=0.,poffset=[0,0,0]|units.AU,
     voffset=[0,0,0]| units.kms):

    phi,r=numpy.mgrid[0:2*numpy.pi:N*1j,Rrange[0]:Rrange[1]:N*1j] 
    phi=phi.flatten()
    r=r.flatten()

    x,y=r*numpy.cos(phi+phioffset),r*numpy.sin(phi+phioffset)
    z=x*0.

    vx=0.*x
    vy=0.*x
    vz=0.*x

    x=units.AU(x)+poffset[0]
    y=units.AU(y)+poffset[1]
    z=units.AU(z)+poffset[2]
    vx=units.kms(vx)+voffset[0]
    vy=units.kms(vy)+voffset[1]
    vz=units.kms(vz)+voffset[2]

    rho,rhovx,rhovy,rhovz,rhoe=sph.get_hydro_state_at_point(x,y,z,vx,vy,vz)
    rho=rho.reshape((N,N))

    return numpy.transpose(rho)

def output_maps(tnow,bin,disc,Lmap,i,outputdir='./',Pplanet=None):
  L=Lmap.value_in(units.AU)
  poffset=bin.particles[0].position
  voffset=bin.particles[0].velocity
  rho=make_map(disc,N=200,L=L,poffset=poffset,voffset=voffset)
  f=pyplot.figure(figsize=(8,8))
  print rho.min().value_in(units.g/units.cm**3),rho.max().value_in(units.g/units.cm**3)
  pyplot.imshow(numpy.log10(1.e-18+rho.value_in(units.g/units.cm**3)),
          extent=[-L/2,L/2,-L/2,L/2],vmin=-16,vmax=-12.,origin='lower')    
  pyplot.plot((bin.particles.x-poffset[0]).value_in(units.AU),
                  (bin.particles.y-poffset[1]).value_in(units.AU),'g+',mew=2.)
  pyplot.xlim(-L/2,L/2)
  pyplot.ylim(-L/2,L/2)
  pyplot.title("%8.4f yr"%tnow.value_in(units.yr))
  pyplot.xlabel('AU')
  pyplot.savefig(outputdir+'/map/map%6.6i.png'%i)
  f.clear()
  pyplot.close(f)

  if Pplanet is None:
    offset=0.
  else:  
    offset=numpy.mod(2*numpy.pi*tnow.value_in(units.day)/Pplanet.value_in(units.day),2*numpy.pi)

  r1=Lmap.value_in(units.AU)/40.
  r2=Lmap.value_in(units.AU)/2.
  rho=make_phi_map(disc,N=200,Rrange=[r1,r2],phioffset=offset,poffset=poffset,voffset=voffset)
  f=pyplot.figure(figsize=(10,6))
  pyplot.imshow(numpy.log10(1.e-15+rho.value_in(units.g/units.cm**3)),
          extent=[0,2.,r1/r2,1],vmin=-16.,vmax=-12.,origin='lower')    
  x=(bin.particles.x-poffset[0]).value_in(units.AU)
  y=(bin.particles.y-poffset[1]).value_in(units.AU)
  r=(x**2+y**2)**0.5
  phi=numpy.arctan2(y,x)-offset
  phi=numpy.mod(phi,2*numpy.pi)
  pyplot.plot(phi/numpy.pi,r/r2,'g+',mew=2.)
  pyplot.title("%8.4f yr"%tnow.value_in(units.yr))
  pyplot.xlabel('phi')
  pyplot.ylabel('R')
  pyplot.xlim(0,2.)
  pyplot.ylim(0.,1.)
  pyplot.tight_layout()
  pyplot.savefig(outputdir+'/map/phi-%6.6i.png'%i)
  f.clear()
  pyplot.close(f)


def handle_eos(gas,memgas,rhotrans=(1.e-5 | units.g/units.cm**3), gamma=1.4):
  channel=gas.new_channel_to(memgas)
  channel.copy_attribute("rho")
  a=memgas.select_array(lambda rho: rho> rhotrans,["rho"])
  a.u=a.u0*(a.rho/rhotrans)**gamma
  a=memgas.select_array(lambda rho: rho<= rhotrans,["rho"])
  a.u=a.u0
  channel=memgas.new_channel_to(gas)
  channel.copy_attribute("u")

def sink_particles(sinks,sources,Raccretion=0.1 | units.AU):
  closest=numpy.array([-1]*len(sources))
  mind2=(numpy.array([Raccretion.number]*len(sources)) | Raccretion.unit)**2
  for i,s in enumerate(sinks):
     xs,ys,zs=s.x,s.y,s.z
     d2=(sources.x-xs)**2+(sources.y-ys)**2+(sources.z-zs)**2
     select=numpy.where( d2<mind2 )[0]
     mind2[select]=d2[select]
     closest[select]=i

  to_remove=Particles(0)
  for i,s in enumerate(sinks):
     insink=numpy.where(closest == i)[0]
     if len(insink) > 0:
       cm=s.position*s.mass
       p=s.velocity*s.mass
       insinkp=Particles(0)
       for ip in insink:
         insinkp.add_particle(sources[ip])
       s.mass+=insinkp.total_mass()
       s.position=(cm+insinkp.center_of_mass()*insinkp.total_mass())/s.mass
       s.velocity=(p+insinkp.total_momentum())/s.mass
# we lose angular momentum !    
       to_remove.add_particles(insinkp)   
       print len(insinkp),"particles accrete on star", i
  if len(to_remove)>0:
    sources.remove_particles(to_remove)

def encounter_disc_run(tend=10. | units.yr,       # simulation time
                          Ngas=10000,                # number of gas particles
                          m1=1. | units.MSun,        # primary mass
                          m2=1. | units.MSun,        # secondary mass
                          r1=1. | units.RSun,        # primary radius
                          r2=1. | units.RSun,        # secondary radius
                          ecc=1.,                    # encounter orbit eccentricity
                          Rimpact=200. | units.AU,   # encounter impact parameter (pericenter dist)
                          inclination=20,            # inclination in deg.
                          Rstart=500 | units.AU,
                          Rmin=10. | units.AU,       # inner edge of initial disk 
                          Rmax=300.0 |units.AU,        # out edge of initial disk
                          q_out=12.,                 # outer disk Toomre Q parameter
                          discfraction=0.5,         # disk mass fraction
                          Raccretion=0.1 | units.AU, # accretion radius for sink particle
                          dt_int=10.|units.day,       # timestep for gas - binary grav interaction (bridge timestep)
                          Pplanet=None,              # period of planet (makes the r-phi map rotate with this period)
                          densitypower=1.,           # surface density powerlaw
                          eosfreq=2,                 # times between EOS updates/sink particle checks
                          mapfreq=1,                 # time between maps ( in units of dt=eosfreq*dt_int)
                          Lmap=600. | units.AU,        # size of map
                          outputfreq=20,             # output snapshot frequency (every ... dt=eosfreq*dt_int)
                          outputdir='./',            # output directory
                          label='anonymous',         # label for run (only for terminal output)
                          overwrite=False
                          ):

  if outputdir=='./':
    outputdir=os.getcwd()
  
  print "output directory of run "+label+" is:", outputdir  
  
  if overwrite and outputdir !=os.getcwd():
    import shutil
    shutil.rmtree(outputdir)
  
  if outputdir !=os.getcwd():
    os.mkdir(outputdir)
  os.mkdir(outputdir+'/map')
  os.mkdir(outputdir+'/snap')
  
  print "Rimpact:", Rimpact.in_(units.AU)
  print "disc inner edge:", Rmin.in_(units.AU)
  print "disc outer edge:", Rmax.in_(units.AU)

  enc=encounter(TwoBody,m1=m1*(1+discfraction),m2=m2,r1=r1,r2=r2,ecc=ecc,Rimpact=Rimpact,inclination=inclination)
  enc.particles[0].mass=m1
  
  disc,gas=sphdisc(Fi,Ngas,m1,Rmin=Rmin, Rmax=Rmax,
                     q_out=q_out, discfraction=discfraction,densitypower=densitypower,dt_sph=dt_int)
    
  directsum_disc=directsum( (disc,) )
    
  bridge=FAST(verbose=False)
  bridge.set_timestep(dt_int)
  bridge.add_system(enc, (directsum_disc,), False)
  bridge.add_system(disc, (enc,), False)

  tnow=0. |  units.day  
  dt=eosfreq*dt_int

  print "bridge timestep=", dt_int.in_(units.day)
  print "eos timestep=", dt.in_(units.day)
  print "map timestep=", (dt*mapfreq).in_(units.day)
  print "snap timestep=", (dt*outputfreq).in_(units.day)

  i=0
  time_begin=time.time()

  while tnow < tend-dt/2:

    if i%outputfreq==0:
      write_set_to_file(enc.particles,outputdir+'/snap/bin-%6.6i'%(i),'amuse')
      write_set_to_file(disc.gas_particles,outputdir+'/snap/disc-%6.6i'%(i),'amuse')

    tnow+=dt
    i+=1
    handle_eos(disc.particles,gas,rhotrans=(1.e-5 | units.g/units.cm**3))
    sink_particles(enc.particles,disc.particles,Raccretion=Raccretion)
    bridge.evolve_model(tnow)
    
    frac=(tnow/tend)
    time_now=time.time()
    print 'sim '+label+' reached:',"%8.4f yr"%tnow.value_in(units.yr), ": %4.2f%%, ETA: %6.2f hours"%(100*frac, (time_now-time_begin)/frac*(1-frac)/3600)

    if i%mapfreq==0:
      output_maps(tnow,enc,disc,Lmap,i,outputdir,Pplanet)
    
  return gethostname(),outputdir       

if __name__=="__main__":

  encounter_disc_run(  tend=3000. | units.yr,        # simulation time
                          Ngas=50000,                 # number of gas particles
                          m1=1. | units.MSun,      # primary mass
                          m2=0.5 | units.MSun,      # secondary mass
                          r1=1. | units.RSun,      # primary radius
                          r2=None,      # secondary radius
                          ecc=1.1,                 # binary orbit eccentricity
                          inclination=10,           # inclination angle
                          Rimpact=500. | units.AU,   # impact parameter
                          Rmin=10. | units.AU,                    # inner edge of initial disk (in AU or (w/o units) in a_binary)  
                          Rmax=300. | units.AU,                     # outer edge of initial disk (in AU or (w/o units) in a_binary)
                          q_out=2.,                   # outer disk Toomre Q parameter
                          discfraction=0.5,           # disk mass fraction
                          Raccretion=1. | units.AU,   # accretion radius for sink particle
                          dt_int=50. | units.day,       # timestep for gas - binary grav interaction (bridge timestep)
                          Pplanet=None, # period of planet (makes the r-phi map rotate with this period)
                          densitypower=1.75,             # surface density powerlaw
                          eosfreq=4,                   # times between EOS updates/sink particle checks
                          mapfreq=4,                   # time between maps ( in units of dt=eosfreq*dt_int)
                          Lmap=1600. | units.AU,          # size of map
                          outputfreq=400,              # output snapshot frequency (every ... dt=eosfreq*dt_int)
                          outputdir='./r1',           # output directory
                          label='X002',                  # label for run (only for terminal output)
                          overwrite=True
                          )
# mencoder "mf://map*.png" -mf fps=20 -ovc x264 -o movie.avi
