#! /usr/bin/env -S conda run -n usage-monitoring python

from subprocess import run, CalledProcessError
from os.path import isfile, expanduser

import argparse

from datetime import datetime, UTC, timedelta
import json
import csv
import pandas as pd
import requests
from matplotlib import pyplot as plt

def load_config(config_path):
    try:
        with open(expanduser(config_path)) as config:
            c = json.load(config)
            c['token_file'] = expanduser(c['token_file'])
            c['data_file'] = expanduser(c['data_file'])
            c['test_csv_file'] = expanduser(c['test_csv_file'])
            return c
    except FileNotFoundError:
        print(f'File {config_path} not found! Exiting ...')
        exit(1)

def create_os_token(token_file):
    try:
        token = run(
            ['openstack', 'token', 'issue', '-f', 'json'],
            capture_output=True,
            check=True
        )
    except CalledProcessError as ex:
        print(
            f'{ex}\n',
            f'STDOUT: {ex.stdout.decode()}\n',
            f'STDERR: {ex.stderr.decode()}\n'
            'It is possible that a valid openrc.sh was not sourced. Exiting ...'
        )
        exit(1)
    with open(token_file, 'w') as f:
        f.write(token.stdout.decode())

def token_expired(token_file):
    with open(token_file, 'r') as f:
        expires_str = json.load(f)['expires']
        date_format = '%Y-%m-%dT%H:%M:%S+0000'
        expire = datetime.strptime(expires_str, date_format).timestamp()
        now = datetime.now(UTC).timestamp()
        expire < now    

def get_os_token(token_file, force_new_token=False):
    if not isfile(token_file) or force_new_token or token_expired(token_file):
        create_os_token(token_file)
    with open(token_file, 'r') as f:
        return json.load(f)['id']

def query_accounting_api(token):
    url = 'https://js2.jetstream-cloud.org:9001'
    headers = { 'X-Auth-Token': f'{token}' }
    response = requests.get(url, headers=headers)
    try:
        response.raise_for_status()
    except Exception as ex:
        print(ex)
        exit(1)
    query = json.loads(response.text)
    return query

def get_js2_resources(query,allocation_resources):
    now = datetime.now()
    date_format = '%Y-%m-%d'
    all_resources = [ 
            resource for resource in query 
            if datetime.strptime(resource['start_date'],date_format) < now 
            and datetime.strptime(resource['end_date'],date_format) > now
        ]
    desired_resources = [
            resource for resource in all_resources
            if resource['resource'] in allocation_resources
        ]
    return desired_resources

def write_resource_csv(resources, data_file):
    '''Write the resource info into data_file with the csv format:
    timestamp,resource,service_units_used,service_units_allocated,start_date,end_date

    resources may be a dictionary or a list of dictionaries with the following keys:
        resource, service_units_used, service_units_allocated, start_date, end_date
    '''

    fieldnames = [
            'timestamp', 'resource', 'service_units_used',
            'service_units_allocated', 'start_date', 'end_date'
        ]
    now = datetime.now(UTC).timestamp()

    # Create file and write headers if it doesn't exist
    if not isfile(data_file):
        with open(data_file, 'w') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()

    with open(data_file, 'a') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        for resource in resources:
            writer.writerow({'timestamp': now,
                             'resource': resource['resource'],
                             'service_units_used': resource['service_units_used'],
                             'service_units_allocated': resource['service_units_allocated'],
                             'start_date': resource['start_date'],
                             'end_date': resource['end_date']})
    return 0

def read_resource_csv(data_file):
    '''Read in the resource info from data_file to be used in visualization, plotting, etc.
    File is in the following csv format:
    timestamp,resource,service_units_used,service_units_allocated,start_date,end_date
    '''
    return pd.read_csv(data_file)

def get_data_by_resource(resources, resource_type):
    '''
    resources -- pandas dataframe
    resource_type -- string
    '''
    return resources.loc[resources['resource'] == resource_type]

def get_usage_rates(data,days):
    '''
    data -- A list of dictionaries as returned by get_data_by_resource
    days -- int number of days from which to calculate the rate
    '''
    timestamps = pd.array(data['timestamp'])
    sus_used = pd.array(data['service_units_used'])

    date2 = timestamps[-1]
    delta = timedelta(days=days).total_seconds()

    dt1 = 9999999999999
    idate2 = -1
    date1 = date2 - delta
    idate1 = 0

    # Get the entry that's closest to date1, i.e. "days" number of days before date2
    # The strategy is to take the difference between the nominal date1 timestamp and each timestamp, then choose the minimum
    # We leave out timestamps[-1] (date2) to ensure date1 != date2, resulting in a NaN when rates are calculated
    for i,ts in enumerate(timestamps[:-2]):
        if abs(date1 - ts) < dt1:
            dt1 = date1 - ts
            idate1 = i

    # Rate at which SUs are used (should be positive, i.e. 1000 SU/s)
    rate_second = (sus_used[idate2] - sus_used[idate1])/(timestamps[idate2] - timestamps[idate1])
    rate_hour = 3600*rate_second
    rate_day = 24*rate_hour
    return {'rate_second': rate_second,
            'rate_hour': rate_hour,
            'rate_day': rate_day,
            'rate_start_date': datetime.fromtimestamp(timestamps[idate1]),
            'rate_end_date': datetime.fromtimestamp(date2)}


def usage_analysis(data,days_prior):
    '''Basic analysis of usage data between now and each value of days_prior
    
    Arguments:
        data -- pandas dataframe: as returned by get_data_by_resource()
        days_prior -- Int: or list of ints of days before "now" on which to perform analysis

    Returns:
        analysis -- array of Dicts with the following keys:
            analysis_start -- datetime
            analysis_end -- datetime
            resource -- string: the resource being analyzed
            daily_usage_rate -- float: rate of SU usage for the given resource
            hourly_usage_rate -- float: rate of SU usage for the given resource
            current_usage -- float: current SUs used
            total_allocated -- float: the total number of SUs allocated
            remaining_sus -- float: SUs remaining
            exhausted_date -- datetime: date when SUs are predicted to be exhausted
                based on current_usage and usage_rage
            end_date_sus -- float: can be + or -; number of SUs remaining (or in
                deficit) should usage_rate be constant until the end_date of the
                resource described by data
            break_even_daily_usage_rate -- float: the usage rate necessary so
                that the exhausted_date is the end_date of the resource
                described by data
            break_even_hourly_usage_rate -- float: the usage rate necessary so
                that the exhausted_date is the end_date of the resource
                described by data
            break_even_daily_delta -- float:
                break_even_daily_usage_rate - daily_usage_rate
            break_even_hourly_delta -- float:
                break_even_hourly_usage_rate - hourly_usage_rate
            break_even_m3_med_equivalents -- float: 
                the break_even_hourly_usage_rate expressed as an amount of
                m3.medium instances (8 SU/hr)
    '''

    if not isinstance(days_prior, (int, list)):
        raise ValueError

    # Make list if single value is passed to function
    if isinstance(days_prior, int):
        days_prior = [ days_prior ]

    analysis = []
    for day in days_prior:

        # Analysis done using a line given by:
        # sus_used - total_allocated = usage_rate*(timestamp - now)
        # Or, for ease of reading:
        # s2 - s1 = r*(t2 - t1)
        #
        # Where sus_used and timestamp are the dependent and independent
        # variables, respectively
        #
        # timestamp is in seconds since the beginning of the Unix epoch

        # Re-used in many calcs
        usage_rates = get_usage_rates(data,day)
        r = usage_rates['rate_second']
        tot_sus = data['service_units_allocated'].iloc[-1]
        cur_sus = data['service_units_used'].iloc[-1]
        cur_ts = data['timestamp'].iloc[-1]

        remaining_sus = tot_sus - cur_sus

        # tot_sus - s1 = remaining_sus = r*(t2 - t1) --> t2 = remaining_sus/r + t1
        exhausted_ts = remaining_sus/r + cur_ts
        try:
            exhausted_date = datetime.fromtimestamp(exhausted_ts)
        except OverflowError:
            exhausted_date = None

        # s2 - s1 = r*(t2 - t1) --> s2 = r*(t2 - t1) + s1
        date_format = '%Y-%m-%d'
        end_date_ts = datetime.strptime(data['end_date'].iloc[-1],date_format).timestamp()
        end_date_sus_used = r*(end_date_ts - cur_ts) + cur_sus
        end_date_sus = tot_sus - end_date_sus_used

        # s2 - s1 = r*(t2 - t1) --> r = -(s2-s1)/(t2 - t1)
        break_even_second_usage_rate = remaining_sus/(end_date_ts - cur_ts)
        break_even_hourly_usage_rate = 3600*break_even_second_usage_rate
        break_even_daily_usage_rate = 24*break_even_hourly_usage_rate

        break_even_hourly_delta = break_even_hourly_usage_rate - usage_rates['rate_hour']
        break_even_daily_delta = break_even_daily_usage_rate - usage_rates['rate_day']

        analysis.append({
            'analysis_start': usage_rates['rate_start_date'],
            'analysis_end': usage_rates['rate_end_date'],
            'resource': data['resource'].iloc[-1],
            'daily_usage_rate': usage_rates['rate_day'],
            'hourly_usage_rate': usage_rates['rate_hour'],
            'current_usage': cur_sus,
            'total_allocated': tot_sus,
            'remaining_sus': remaining_sus,
            'exhausted_date': exhausted_date,
            'end_date_sus': end_date_sus,
            'break_even_daily_usage_rate': break_even_daily_usage_rate,
            'break_even_hourly_usage_rate': break_even_hourly_usage_rate,
            'break_even_daily_delta': break_even_daily_delta,
            'break_even_hourly_delta': break_even_hourly_delta,
            'break_even_m3_med_equivalents': break_even_hourly_delta/8.0,
        })

    return analysis

def generate_usage_plot(resources, analyses, allocation_resources):
    fig, ax = plt.subplots()
    for resource_type in allocation_resources:
        data = get_data_by_resource(resources, resource_type)
        if data.empty:
            print(f'No available data for {resource_type}')
            continue

        timestamps = pd.array(data['timestamp'])
        dates = [ datetime.fromtimestamp(ts) for ts in timestamps ]

        sus_used = pd.array(data['service_units_used'])
        sus_remaining = data['service_units_allocated'].iloc[-1] - sus_used

        ax.plot(dates, sus_remaining)

    plt.show()
    return 0

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-n', '--force-new-token', help='Force the creation of a new openstack token before query', action='store_true')
    parser.add_argument('-w', '--write', help='Query Jetstream2 for new allocation data and write to data file', action='store_true')
    parser.add_argument('-c', '--dump-csv', help='Dump the data from data_file in csv format', action='store_true')
    parser.add_argument('-j', '--dump-json', help='Dump the data from data_file in json format', action='store_true')
    parser.add_argument('-p', '--plot', help='Generate an interactive plot of SU usage data', action='store_true')
    parser.add_argument('-a', '--analysis-days', help='Days prior for which to perform an analysis', action='extend', nargs='+', type=int)
    parser.add_argument('-d', '--devel', help='Use test_csv_file for development work', action='store_true')
    parser.add_argument('--config', help='Configuration file path', type=str, default="~/.config/usage-monitoring/config.json")
    args = vars(parser.parse_args())

    c = load_config(args['config'])

    if not any([ args[key] for key in args.keys() ]):
        parser.parse_args(['--help'])

    if args['devel']:
        c['data_file'] = c['test_csv_file']

    if args['write']:
        token = get_os_token(c['token_file'],force_new_token=args['force_new_token'])
        query = query_accounting_api(token)
        resources = get_js2_resources(query,c['allocation_resources'])
        write_resource_csv(resources, c['data_file'])

    if args['dump_csv']:
        dump = run(
            ['cat', f'{c['data_file']}'],
            check=True
        )

    if args['dump_json']:
        resources = read_resource_csv(c['data_file'])
        print(resources.to_json(orient='records', indent=2))

    if args['analysis_days']:
        # Get resources
        resources = read_resource_csv(c['data_file'])

        analyses = []
        # Loop over resources to get each type of data found in allocation_resources
        for resource_type in c['allocation_resources']:
            data = get_data_by_resource(resources, resource_type)
            if data.empty:
                print(f'No available data for {resource_type}. Skipping ...')
                continue
            if len(data) < 2:
                print(f'Not enough data for {resource_type}: len(data) = {len(data)}. Skipping ...')
            # Perform analysis (usage rates, "forecast", )
            analyses.append(usage_analysis(data,args['analysis_days']))

        print(json.dumps(analyses, indent=2, default=str))

    if args['plot']:
        if 'analyses' not in locals():
            analyses = None
        resources = read_resource_csv(c['data_file'])
        generate_usage_plot(resources, analyses, c['allocation_resources'])

if __name__ == "__main__":
    main()
