# -*- coding: utf8 -*-

import io
import os
import sys
from shutil import rmtree

from setuptools import setup, find_packages, Command


__version__ = '{major_version}.{minor_version}.{patch_version}'.format(
    major_version=0,
    minor_version=0,
    patch_version=1,
)
pwd_path = os.path.abspath(os.path.dirname(__file__))
with io.open(os.path.join(pwd_path, 'README.rst'), encoding='utf-8') as f:
    readme = '\n' + f.read()

class UploadCommand(Command):
    """Support setup.py upload."""

    description = 'Build and publish the package.'
    user_options = []

    @staticmethod
    def status(s):
        """Prints things in bold."""
        print('\033[1m{0}\033[0m'.format(s))

    def initialize_options(self):
        pass

    def finalize_options(self):
        pass

    def run(self):
        try:
            self.status('Removing previous builds...')
            rmtree(os.path.join(pwd_path, 'dist'))
        except OSError:
            pass

        self.status('Building Source and Wheel (universal) distribution...')
        os.system('{0} setup.py sdist bdist_wheel --universal'.format(sys.executable))

        self.status('Uplading the package to PyPi vis Twine...')
        os.system('twine upload dist/*')

        sys.exit()


setup(
    name='Youtiao',
    version=__version__,
    description='Micro Service Scaffold Generator and Toolkit',
    long_description=readme,
    packages=find_packages(exclude=['build', 'docs', 'tests']),
    python_requires='>=3.6.0',
    package_data={
        'templates': [
            'templates/*/*',
            'templates/py/*/*',
            'templates/py/http/*',
            'templates/py/http/*/*',
            'templates/py/grpc/*',
            'templates/py/grpc/*/*',
        ],
    },
    author='HJ',
    author_email='hujun.qu@gmail.com',
    url='https://github.com/Hujun/youtiao',
    license='MIT',
    include_package_data=True,
    install_requires=[
        'click',
        'colorama',
        'jinja2',
        'grpcio-tools',
        'docker',
        'requests',
    ],
    entry_points={
        'console_scripts': [
            'youtiao=youtiao:cli',
        ],
    },
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'Topic :: Software Development :: Build Tools',
        'Topic :: Utilities',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3.6',
    ],
    cmdclass={
        'upload': UploadCommand,
    },
)
