# -*- coding: utf8 -*-

import click

from youtiao.commands.protoc import protoc
from youtiao.commands.rancher import deploy
from youtiao.commands.docker import build
from youtiao.commands.boilerplate import init_project


@click.group()
def cli():
    """Micro Service Toolkit"""
    pass


cli.add_command(protoc)
cli.add_command(deploy, name='rancher_deploy')
cli.add_command(build, name='build_image')
cli.add_command(init_project, name='init')


if __name__ == '__main__':
    cli()
