# -*- coding: utf8 -*-

import json
from typing import Dict
from time import sleep
from copy import deepcopy

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
                sleep(2)
                retry += 2
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
            sleep(2)
            retry += 2
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

