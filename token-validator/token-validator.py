#!/usr/bin/env python
import argparse
import logging
import sys, os
import requests
import time
import redis

def validate_token(podinfo_url, redis_url):
    # epoch_time as key, token as value
    data = int(time.time())
    # get token
    logging.info('Get toke from podinfo [%s]', podinfo_url)
    response = requests.post(podinfo_url + '/token', data=data,
                             headers={'Content-Type': 'application/x-www-form-urlencoded'})
    if response.status_code != '200':
        logging.error('Failed to get token')
        sys.exit(1)
    token = response.json()['token']

    # validate token
    logging.info('Validating token [%s] against podinfo', token)
    response = requests.get(podinfo_url + '/token/validate', headers={
        'Authorization': 'Bearer ' + token,
    })
    if response.status_code != '200':
        logging.error('Can\'t validate token')
        sys.exit(1)

    # validate with redis
    if not redis_url:
        logging.warning('Running without Redis url')
        sys.exit(0)

    logging.info('Validate if token on redis [%s]', redis_url)
    r = redis.Redis(host=redis_url, port=6379, decode_responses=True)
    if not r:
        logging.error('Failed to validate token against Redis')
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", help="log level", default="info")
    parser.add_argument("--podinfo_url", help="Pod info svc", default=os.environ.get('PODINFO_URL'))
    parser.add_argument("--redis_url", help="Redis svc, if deployed", default=os.environ.get('REDIS_URL'))
    args = parser.parse_args()
    podinfo_url = args.podinfo_url
    if not podinfo_url:
        exit(parser.print_usage())

    redis_url = args.redis_url

    # create logger
    FORMAT = '%(asctime)s %(levelname)s: %(message)s'
    logger = logging.getLogger()
    logger.setLevel(args.log.upper())
    # create console handler and set log level
    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(logging.Formatter(FORMAT))
    logger.addHandler(ch)

    validate_token(podinfo_url, redis_url)