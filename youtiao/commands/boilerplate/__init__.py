# -*- coding: utf8 -*-

import os
import shutil
from pathlib import Path

import click

from youtiao import templates
from youtiao.commands.boilerplate.utils import render_templates
from youtiao.commands.protoc import proto_compile

SERVICE_TYPES = {
    '1': 'HTTP server',
    '2': 'gGRPC server',
}
TEMPLATE_PATH = os.path.dirname(templates.__file__)
TEMPLATE_DIR = {
    ('python', 'http'): os.path.join(TEMPLATE_PATH, 'py', 'http'),
    ('python', 'grpc'): os.path.join(TEMPLATE_PATH, 'py', 'grpc'),
}


@click.command()
@click.option('--language', type=click.Choice(['python']), default='python', help='programming language')
@click.option('--project-dir', required=True, type=click.Path(exists=True, file_okay=False, resolve_path=True))
@click.option('--name', type=str, prompt='Service name ?', help='service name')
@click.option('--mode', type=click.Choice(['1', '2']), prompt='Service type [1] HTTP [2] gRPC ?', help='service type')
def init_project(language, project_dir, name, mode):
    """Generate Python service boilerplate"""
    project_path = os.path.join(project_dir, name)
    if os.path.exists(project_path):
        click.secho('Folder {} already existed'.format(project_path), fg='red')
        raise click.Abort

    click.secho('Project directory: {}'.format(project_path), bold=True)
    click.secho('Project name: {}'.format(name), bold=True)
    click.secho('Service type: {}'.format(SERVICE_TYPES[mode]), bold=True)
    if click.confirm('Confirm project info and continue?', abort=True):
        click.echo('Start to generate project boilerplate...')

    render_context = {
        'app_name': name,
    }

    try:
        if language == 'python' and mode == '1':
            template_dir = TEMPLATE_DIR[('python', 'http')]
            for rendered_file in render_templates(template_dir, project_path, render_context):
                click.secho('Create file: {}'.format(str(rendered_file)))
            # mv dirname
            shutil.move(os.path.join(project_path, 'app'), os.path.join(project_path, name))

        elif language == 'python' and mode == '2':
            template_dir = TEMPLATE_DIR[('python', 'grpc')]
            for rendered_file in render_templates(template_dir, project_path, render_context):
                click.secho('Create file: {}'.format(str(rendered_file)))
            # mv dirname
            shutil.move(os.path.join(project_path, 'app'), os.path.join(project_path, name))
            # mv proto file
            shutil.move(os.path.join(project_path, name, 'proto/app.proto'),
                        os.path.join(project_path, name, 'proto/{}.proto'.format(name)))

            click.secho('Compile proto file')
            proto_compile(os.path.join(project_path, name, 'proto', '{}.proto'.format(name)),
                          os.path.join(project_path, name, 'proto'))

        else:
            raise Exception('Programming language {} or servie type {} not supported'.format(language, mode))

    except Exception as e:
        print(e)
        click.secho('Remove project folder', fg='red')
        shutil.rmtree(project_path)
        raise click.Abort

