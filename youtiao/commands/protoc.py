# -*- coding: utf8 -*-

from pkg_resources import resource_filename
from pathlib import Path
from typing import Tuple

import click

from grpc_tools import _protoc_compiler


def proto_compile(proto_path: str, output_path: str) -> Tuple[Path, Path]:
    """compile .proto file

    Args:
        proto_path (str): proto file path
        output_path (str): output files directory

    Returns:
        tuple of paths for pb2 python file and pb2 grpc file

    Raises:
        FileNotFoundError
    """
    proto_path = str(proto_path)
    output_path = str(output_path)
    if not Path(proto_path).is_file():
        raise FileNotFoundError('proto file not found')
    if not Path(output_path).is_dir():
        raise FileNotFoundError('output dir not found')
    args = [
        resource_filename('grpc_tools', 'protoc.py'),
        '-I{}'.format(output_path),
        '--python_out={}'.format(output_path),
        '--grpc_python_out={}'.format(output_path),
        proto_path,
        '-I{}'.format(resource_filename('grpc_tools', '_proto')),
    ]
    return _protoc_compiler.run_main([arg.encode() for arg in args])


@click.command()
@click.option('--proto-path', required=True, type=click.Path(exists=True, dir_okay=False, resolve_path=True),
              help='path of protobuf file')
@click.option('--out', type=click.Path(exists=True, file_okay=False, resolve_path=True),
              help='output files location', default=None)
def protoc(proto_path, out):
    """Shortcut of grpc_tools.protoc to compile .proto file."""
    if out is None:
        out, _ = os.path.split(proto_path)
    proto_compile(proto_path, out)

