from os.path import basename
from numpy import ceil,log2,floor
from tifffile import TiffWriter
from dcimg import *
from rich.progress import track

def dcimg2tiff(scrname,destfolder):
	filename = basename(scrname)
	destname = destfolder+filename[:-6]
	print('[NOTE] Files will be saved in ',destname+'(*).tif')
	if filename[-6:]!='.dcimg':
		print('[ERR] File \"',filename,'\" should be in *.dcimg format.')
		return
	else:
		scrfile = DCIMGFile(scrname)
		print('========== Reading succeeded! ==========')
		tifnum = int(ceil(2**((log2(scrfile.shape[0])+log2(scrfile.shape[1])+log2(scrfile.shape[2]))-31)))
		pagenum = int(floor(2**(31-log2(scrfile.shape[1])-log2(scrfile.shape[2]))))-1
		print('File in shape ',scrfile.shape,', tif numbers: ',tifnum,', page numbers: ',pagenum)
		for tifind in range(tifnum):
			destname_ind = destname + '('+str(tifind+1)+').tif'
			with TiffWriter(destname_ind) as tif:
				for pageind in track(range(pagenum), description=filename+'('+str(tifind+1)+'):'):
					if pagenum*tifind+pageind<scrfile.shape[0]:
						tif.write(scrfile[pagenum*tifind+pageind,:,:],contiguous=True)
					else:
						break



if __name__ == '__main__':
	scrname = 'Z:\\test.dcimg'
	destfolder = 'Z:test\\rawtif\\'
	dcimg2tiff(scrname,destfolder)
