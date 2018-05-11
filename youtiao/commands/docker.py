# -*- encoding: utf8 -*-

import click
import docker

@click.command()
@click.option('--project-name', type=str, required=True, help='project name')
# name of git branch or tag
@click.option('--commit-ref-name', type=str, required=True, help='name of git branch or tag')
# git commit hash
@click.option('--commit-sha', type=str, required=True, help='git commit hash')
@click.option('--workdir', type=click.Path(exists=True, file_okay=False, resolve_path=True), required=True)
@click.option('--registry-url', type=str, help='Docker registry URL', default=None)
def build(project_name, commit_ref_name, commit_sha, workdir, registry_url):
    """Build docker image"""
    repo_name = '{}/{}'.format(project_name.lower(), commit_ref_name)
    if registry_url is not None:
        repo_name = '{}/{}'.format(registry_url, repo_name)
    build_full_tag = '{}:{}'.format(repo_name, commit_sha)
    docker_cli = docker.from_env()
    click.secho('Building image {}'.format(build_full_tag))
    new_image, _ = docker_cli.images.build(path=workdir, tag=build_full_tag, rm=True)
    # tag as latest
    new_image.tag(repo_name, tag='latest')
    click.secho('Image built {}'.format(new_image.id))
    image_list = docker_cli.images.list(
        name=repo_name,
        filters={'before': build_full_tag},
        #  all=True
    )
    for img in image_list:
        # delete old images
        click.secho('Delete old image of {}'.format(img.id))
        docker_cli.images.remove(image=img.short_id, force=True)

    return new_image.short_id

