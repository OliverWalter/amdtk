from distutils.core import setup
from distutils.extension import Extension
import numpy as np

try:
    from Cython.Build import cythonize
    extensions = cythonize([Extension('amdtk.models.hmm_graph_utils',
                                      ['amdtk/models/hmm_graph_utils.pyx'],
                                      include_dirs=[np.get_include()])])
except ImportError:
    extensions = [Extension('amdtk.models.hmm_graph_utils',
                            ['amdtk/models/hmm_graph_utils.c'],
                            include_dirs=[np.get_include()])]

setup(
    ext_modules = extensions
)
