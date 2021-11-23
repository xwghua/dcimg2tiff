# dcimg2tiff
### Introduction
This is a program to transform Hamamatsu dcimg files to multipage tif files.\
<i>\[NOTE\] To avoid large file errors, this program limits the total pixel number of the file within 2^31.</i>
### Requirements
- Python 3.5+
- numpy (```pip install numpy```)
- tifffile (```pip install tifffile```)
- dcimg (```pip install dcimg```)
- rich (```pip install rich```)
### Usage
```python
dcimg2tiff(scrname,destfolder)
```

`scrname` The filename of the dcimg file.
`destfolder` The destination folder to store tif files.
