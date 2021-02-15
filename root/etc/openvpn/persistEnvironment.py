import argparse
import os

parser = argparse.ArgumentParser(
    description='Store env vars into runnable .sh file with export statements',
)
parser.add_argument(
    'env_var_script_file',
    type=str,
    help='Path to variables-script.sh',
)

args = parser.parse_args()

wanted_variables = {
    'OPENVPN_PROVIDER',
    'ENABLE_UFW',
    'PUID',
    'PGID',
    'DROP_DEFAULT_ROUTE',
    'DISABLE_PORT_UPDATER',
    'LOCAL_NETWORK',
    'UFW_EXTRA_PORTS',
    'UFW_ALLOW_GW_NET',
    'CHOSEN_OPENVPN_CONFIG',
}

variables_to_persist = {}

for env_var in os.environ:
    if env_var in wanted_variables:
        variables_to_persist[env_var] = os.environ.get(env_var)


# Dump resulting settings to file
with open(args.env_var_script_file, 'w') as script_file:
    for var_name, var_value in variables_to_persist.items():
        script_file.write(
            'export {env_var}={env_var_value}\n'.format(
                env_var=var_name,
                env_var_value=var_value,
            ),
        )
