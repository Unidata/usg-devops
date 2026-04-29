# Usage Monitoring

## Dependencies

Create a conda environment with the necessary additional dependencies with:

`conda env update -f environment.yml`

## Usage

For usage run `python usage_monitoring.py`. When running this script, you will
need to `source` a valid `openrc.sh` or have a valid `clouds.yaml` in `~/.config/openstack/`.

See the [Jetstream2 docs](https://docs.jetstream-cloud.org/ui/cli/auth/) for
information on how to acquire an `openrc.sh` or `clouds.yaml` file.

### Installing

Run the included `install.sh` script. This will create the appropriate directories if necessary and soft/symlink the appropriate files. To "uninstall" the script, simply remove the symlinks.

Finally, ensure that `~/.local/bin` is in your `PATH`.

### Activating the Environment

Activate your environment: `conda activate usage-monitoring` then run:
`python usage_monitoring.py [options]`

### Without Activating the Environment

If you would like to run the `usage_monitoring.py` script without activating the
environment, use `conda run`, as in `usage_monitoring.sh`:

`conda run -n usage-monitoring python usage_monitoring.py [options]`

Additionally, if you've configured your shell to include `~/.local/bin` in your `PATH`, you can run `usage_monitoring.py` as an executable, as the script includes the appropriate "hashbang" (a.k.a. "shebang" `#!`):

`usage_monitoring.py [options]`

# Cron

To collect usage data on a daily basis, run the wrapper script (after setting
the appropriate environment variables) as a cron job by adding this to your
`crontab`:

```shell
@daily bash /path/to/usage_monitoring.sh
```

For more fine grained scheduling, see `man 5 crontab`.
