# -*- coding: utf8 -*-

import json
from typing import Dict
from time import sleep
from copy import deepcopy

import click
import requests


class RancherClient(object):
    def __init__(self, endpoint_url: str, key: str, secret: str):
        """
        Args:
            endpoint_url (str): rancher server API endpoint URL
            key (str): rancher account or environment API access key
            secret (str): rancher account or environment API secret corresponding to the access key
        """
        self.endpoint_url = endpoint_url
        self.s = requests.Session()
        self.s.auth = (key, secret)
        # timeout in second for retry
        self.timeout = 60
        self.sleep_step = 2

    def environment_id(self, name: str=None) -> str:
        """
        Get rancher environement ID. If using account key, return the environment ID specified by `name`.

        Args:
            name (str): name for the environment requested (only useful for account key)

        Returns:
            environment ID in string
        """
        if not name:
            r = self.s.get('{}/projects'.format(self.endpoint_url), params={'limit': 1000})
        else:
            r = self.s.get('{}/projects'.format(self.endpoint_url), params={'limit': 1000, 'name': name})
        r.raise_for_status()
        data = r.json()['data']
        if data:
            return data[0]['id']
        return None

    def service_info(self, environment_id: str, stack_name: str, service_name: str) -> Dict:
        """
        Get rancher service info by given environment id and service name.

        Args:
            environment_id (str): defined environment id in rancher
            stack_name (str): defined stack name in rancher
            service_name (str): defined service name in rancher

        Returns:
            service info in json
        """
        if not environment_id:
            raise Exception('Empty rancher environment ID')
        r = self.s.get('{}/projects/{}/stacks'.format(self.endpoint_url, environment_id),
                       params={'limit': 1000, 'name': stack_name})
        r.raise_for_status()
        data = r.json()['data']

        if not data:
            # stack not found
            raise Exception('Stack {} not found'.format(stack_name))
            return None

        stack_info = deepcopy(data[0])

        r = self.s.get('{}/projects/{}/services'.format(self.endpoint_url, environment_id),
                       params={'name': service_name})
        r.raise_for_status()
        data = r.json()['data']
        if not data:
            # service not found
            return None
        for service_info in data:
            if service_info['stackId'] == stack_info['id']:
                return service_info
        return None


    def service_finish_upgrade(self, environment_id: str, service_id: str) -> Dict:
        """
        Finish service upgrade when service is in `upgraded` state.

        Args:
            environment_id (str): defined environment id in rancher
            service_id (str): defined environment id in rancher

        Returns:
            service info in json
        """
        r = self.s.get('{}/projects/{}/services/{}'.format(self.endpoint_url, environment_id, service_id))
        r.raise_for_status()
        data = r.json()
        if data.get('type') == 'error':
            raise Exception(json.dumps(data))
        if data['state'] == 'active':
            return data

        if data['state'] == 'upgrading':
            retry = 0
            while data['state'] != 'upgraded':
                sleep(self.sleep_step)
                retry += self.sleep_step
                if retry > self.timeout:
                    raise Exception('Timeout of rancher finish upgrade service {}'.format(service_id))
                r = self.s.get('{}/projects/{}/services/{}'.format(self.endpoint_url, environment_id, service_id))
                r.raise_for_status()
                data = r.json()

        if data['state'] != 'upgraded':
            raise Exception('Unable to finish upgrade service in state of {}'.format(data['state']))
        r = self.s.post('{}/projects/{}/services/{}/'.format(self.endpoint_url, environment_id, service_id),
                        params={'action': 'finishupgrade'})
        r.raise_for_status()

        # wait till service finish upgrading
        retry = 0
        while data['state'] != 'active':
            sleep(self.sleep_step)
            retry += self.sleep_step
            if retry > self.timeout:
                raise Exception('Timeout of rancher finish upgrade service {}'.format(service_id))
            r = self.s.get('{}/projects/{}/services/{}'.format(self.endpoint_url, environment_id, service_id))
            r.raise_for_status()
            data = r.json()

        return data

    def service_upgrade(self, environment_id: str, service_id: str, batch_size: int=1,
                        batch_interval: int=2, sidekicks: bool=False, start_before_stopping: bool=False) -> Dict:
        """
        Upgrade service

        Args:
            environment_id (str): defined environment id in rancher
            service_id (str): defined environment id in rancher
            batch_size (int): number of containers to upgrade at once
            batch_interval (int): interval (in second) between upgrade batches
            sidekicks (bool): upgrade sidekicks services at the same time
            start_before_stopping (bool): start new containers before stopping the old ones

        Returns:
            service info in json
        """
        r = self.s.get('{}/projects/{}/services/{}'.format(self.endpoint_url, environment_id, service_id))
        r.raise_for_status()
        data = r.json()
        if data.get('type') == 'error':
            raise Exception(json.dumps(data))
        if data['state'] != 'active':
            raise Exception('Service {} in state of {}, cannot upgrade'.format(service_id, data['state']))

        upgrade_input = {'inServiceStrategy': {
            'batchSize': batch_size,
            'intervalMillis': batch_interval * 1000,
            'startFirst': start_before_stopping,
            'launchConfig': data['launchConfig'],
            'secondaryLaunchConfigs': [],
        }}
        if sidekicks:
            upgrade_input['inServiceStrategy']['secondaryLaunchConfigs'] = data['secondaryLaunchConfigs']

        r = self.s.post('{}/projects/{}/services/{}/'.format(self.endpoint_url, environment_id, service_id),
                        params={'action': 'upgrade'}, json=upgrade_input)
        r.raise_for_status()

        return r.json()


@click.command()
@click.option('--rancher-url', required=True, help='rancher server API endpoint URL')
@click.option('--rancher-key', required=True, help='rancher account or environment API access key')
@click.option('--rancher-secret', required=True, help='rancher account or environment API secret corresponding to the access key')
@click.option('--rancher-env', default=None, help='used to specify environemnt if account key is provided')
@click.option('--stack', required=True, help='stack name defined in rancher')
@click.option('--service', required=True, help='service name defined in rancher')
@click.option('--batch-size', default=1, help='number of containers to upgrade at once')
@click.option('--batch-interval', default=2, help='interval (in second) between upgrade batches')
@click.option('--sidekicks/--no-sidekicks', default=False, help='upgrade sidekicks services at the same time')
@click.option('--start-before-stopping/--no-start-before-stopping', default=False,
              help='start new containers before stopping the old ones')
def deploy(rancher_url, rancher_key, rancher_secret, rancher_env, stack, service,
                   batch_size, batch_interval, sidekicks, start_before_stopping):
    """Deploy using rancher (v1.6) API (v2.0 beta)"""
    rancher_cli = RancherClient(rancher_url, rancher_key, rancher_secret)
    env_id = rancher_cli.environment_id(rancher_env)
    if not env_id:
        raise click.Abort('Environment {} not found in rancher'.format(rancher_env))
    service_info = rancher_cli.service_info(env_id, stack, service)
    if not service_info:
        click.secho('Service {} not found in rancher'.format(service), fg='red')
        raise click.Abort
    service_id = service_info['id']
    click.secho('Check and finish service upgrade')
    service_info = rancher_cli.service_finish_upgrade(env_id, service_id)
    click.secho('Service info:')
    click.secho(json.dumps(service_info))

    # do upgrade
    rancher_cli.service_upgrade(env_id, service_id, batch_size, batch_interval, sidekicks, start_before_stopping)
    click.secho('Waiting for upgrade finish')
    service_info = rancher_cli.service_finish_upgrade(env_id, service_id)

    click.secho('Service {} deploy complete on {}'.format(service_info['name'], rancher_url))
    return service_info


