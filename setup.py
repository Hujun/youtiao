# -*- coding: utf8 -*-

import io
import os
import sys
from shutil import rmtree
from setuptools import setup, find_packages, Command
import subprocess
from pathlib import Path


__version__ = '{major_version}.{minor_version}.{patch_version}'.format(
    major_version=0,
    minor_version=0,
    patch_version=2,
)
pwd_path = os.path.abspath(os.path.dirname(__file__))
with io.open(os.path.join(pwd_path, 'README.rst'), encoding='utf-8') as f:
    readme = '\n' + f.read()


class PackageCommand(Command):
    """Support setup.py package"""

    description = 'Build package.'
    user_options = [
        ('with-deps', None, 'package with all wheel packages of dependencies'),
    ]

    def initialize_options(self):
        """Set default values for options"""
        self.with_deps=False

    def finalize_options(self):
        """Post-process options"""
        if self.with_deps:
            self.with_deps=True

    def run(self):
        """Run command"""
        clear_files = [
            os.path.join(pwd_path, 'build'),
            os.path.join(pwd_path, 'dist'),
            os.path.join(pwd_path, '*/*.egg-info'),
            os.path.join(pwd_path, 'Youtiao.egg-info'),
        ]
        for cf in clear_files:
            print('rm {}'.format(cf))
            subprocess.run(['rm', '-rf', cf])

        # make sure that wheel is installed
        subprocess.run(['python', 'setup.py', 'bdist', 'bdist_wheel', '--universal'])

        if self.with_deps:
            rqm_path = os.path.join(pwd_path, 'requirements.txt')
            wheels_path = os.path.join(pwd_path, 'wheels')
            subprocess.run(['rm', '-rf', wheels_path])
            subprocess.run(['mkdir', '-p', wheels_path])
            subprocess.run('pip wheel --wheel-dir={} -r {}'.format(wheels_path, rqm_path), shell=True)

        sys.exit(0)


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
        'package': PackageCommand,
    },
)
