
import numpy

from amuse.units import units,constants,nbody_system

from amuse.io import read_set_from_file

from filters3 import filter_band_flux,filter_data
from xyz import xyz_data
from blackbody import B_lambda

from amuse.community.fi.interface import FiMap

from numpy.fft import fft2, ifft2
from numpy import log

import Image

import logging
#logging.basicConfig(level=logging.DEBUG)

from color_converter import ColorConverter,XYZ_to_sRGB_linear,sRGB_linear_to_sRGB


def Convolve(image1, image2, MinPad=True, pad=True):
  """ Not so simple convolution """
  #Just for comfort:
  FFt = fft2
  iFFt = ifft2
    
	#The size of the images:
  r1,c1 = image1.shape
  r2,c2 = image2.shape
  
	#MinPad results simpler padding,smaller images:
  if MinPad:
    r = r1+r2
    c = c1+c2
  else:
    #if the Numerical Recipies says so:
    r = 2*max(r1,r2)
    c = 2*max(c1,c2)
    
	#For nice FFT, we need the power of 2:
  if pad:
    pr2 = int(log(r)/log(2.0) + 1.0 )
    pc2 = int(log(c)/log(2.0) + 1.0 )
    rOrig = r
    cOrig = c
    r = 2**pr2
    c = 2**pc2
	
#numpy fft has the padding built in, which can save us some steps
#here. The thing is the s(hape) parameter:
#fftimage = FFt(image1,s=(r,c)) * FFt(image2,s=(r,c))
  fftimage = FFt(image1, s=(r,c))*FFt(image2[::-1,::-1],s=(r,c))
  
  if pad:
    return (iFFt(fftimage))[:rOrig,:cOrig].real
  else:
    return (iFFt(fftimage)).real

def calculate_effective_temperature(luminosity, radius):
    return ((luminosity/(constants.four_pi_stefan_boltzmann*radius**2))**.25).in_(units.K)

import pyfits

psf=dict()

for band in "ubvri":
  for i in range(1):
    f=pyfits.open(band+"%2.2i.fits"%i)
    psf[band+str(i)]=numpy.array(f[0].data)

def rgb_frame(stars, dryrun=False,vmax=None,percentile=0.9995,multi_psf=False,
        sourcebands="ubvri",image_width=12| units.parsec,image_size=[1024,576]):
    
    print "luminosities..",

    for band in sourcebands:
      for star in stars:
        setattr(star,band+"_band", 4*numpy.pi*star.radius**2*filter_band_flux("bess-"+band+".pass", lambda x: B_lambda(x,star.temperature)) )

    print "..raw images..",
        
    conv = nbody_system.nbody_to_si(stars.total_mass(),image_width)
    mapper=FiMap(conv)#,mode="openmp",redirection="none")
    
    mapper.parameters.image_width=image_width
    mapper.parameters.image_size=image_size
        
    mapper.particles.add_particles(stars)
      
    raw_images=dict()
    for band in sourcebands:  
      mapper.particles.weight=getattr(stars, band+"_band").value_in(units.LSun)
      im=mapper.image.pixel_value
      raw_images[band]=im
    
    mapper.stop()
    
    convolved_images=dict()
    
    print "..convolving..",
    
    if multi_psf:
      a=numpy.arange(image_size[0])/float(image_size[0]-1)
      b=numpy.arange(image_size[1])/float(image_size[1]-1)
      w1=numpy.outer(a,b)
      w2=numpy.outer(1.-a,b)
      w3=numpy.outer(a,1.-b)
      w4=numpy.outer(1.-a,1.-b)
      for key,val in raw_images.items():
        xpad,ypad=psf[key+'0'].shape
        im1=Convolve( val ,psf[key+'0'])[xpad/2:-xpad/2,ypad/2:-ypad/2]
        im2=Convolve( val ,psf[key+'1'])[xpad/2:-xpad/2,ypad/2:-ypad/2]
        im3=Convolve( val ,psf[key+'2'])[xpad/2:-xpad/2,ypad/2:-ypad/2]
        im4=Convolve( val ,psf[key+'3'])[xpad/2:-xpad/2,ypad/2:-ypad/2]
        convolved_images[key]=w1*im1+w2*im2+w3*im3+w4*im4
    else:
      for key,val in raw_images.items():
        xpad,ypad=psf[key+'0'].shape
        im1=Convolve( val ,psf[key+str(0)])[xpad/2:-xpad/2,ypad/2:-ypad/2]
        convolved_images[key]=im1
              
    print "..conversion to rgb"
        
    source= [ filter_data['bess-'+x+'.pass'] for x in sourcebands ]
    
    target= [ xyz_data['x'],xyz_data['y'],xyz_data['z']]
    
    conv=ColorConverter(source,target)
        
    ubv=numpy.array( [ convolved_images[x] for x in sourcebands ] )
    
    xyz=numpy.tensordot(conv.conversion_matrix,ubv,axes=(1,0))
        
    conv_xyz_to_lin=XYZ_to_sRGB_linear()
    
    srgb_l=numpy.tensordot(conv_xyz_to_lin.conversion_matrix,xyz,axes=(1,0))
        
    if dryrun or vmax is None:
      flat_sorted=numpy.sort(srgb_l.flatten())
      n=len(flat_sorted)
      vmax=flat_sorted[1.-3*(1.-percentile)*n]
      print "vmax:", vmax
    if dryrun:
      return vmax
    
    conv_lin_to_sRGB=sRGB_linear_to_sRGB()
    
    srgb=conv_lin_to_sRGB.convert(srgb_l/vmax)

    r=srgb[0,:,:].transpose()
    r=(r*255).astype('uint8')
    r=Image.fromarray(r)
    
    g=srgb[1,:,:].transpose()
    g=(g*255).astype('uint8')
    g=Image.fromarray(g)
    
    b=srgb[2,:,:].transpose()
    b=(b*255).astype('uint8')
    b=Image.fromarray(b)
        
    imrgb=Image.merge('RGB', (r,g,b))
    
    image = dict(
    pixels=imrgb.tostring(),
    size=imrgb.size,
    mode=imrgb.mode)
        
    return vmax,image
