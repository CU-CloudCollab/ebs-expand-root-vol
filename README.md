# ebs-expand-root-vol

Ruby functionality to expand the root EBS volume for an AWS EC2 instance.

## Running from the command line

* See command line options
```
$ ./go.rb -h
Usage: go.rb [options]
    -r, --region region              (required) AWS region
    -i, --instance instance-id       (required) instance ID
    -s, --size size                  (required) new size (Gib)
    -n, --cleansnap                  cleanup snapshot (defaults to false)
    -v, --cleanvol                   cleanup original volume (defaults to false)
    -h, --help                       displays this help
```    

## Process

1. gather information about existing root device (root device mapping, root device type, current root volume size, current instance state)
1. stop the instance, if it is running
1. detach root volume from instance
1. create snapshot of root volume
1. create new volume with new size
1. attach the volume to the instance
1. restart the instance, if it was running to begin with
1. [optional] cleanup snapshot and original volume

## Dependencies

* AWS credentials configured in ~/.aws or environment variables
  * http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-config-files
* Gems used: aws-sdk (v2)
  * http://docs.aws.amazon.com/sdkforruby/api/#Installation

## Inputs

* instance ID of target instance
* AWS region
* new root volume size (in GiB)
* (optional) flags indicating whether to cleanup (i.e., delete) the snapshot that was created and the original volume

## Limitations

* Target instance must be EBS-backed.
* Target instance must be linux and not all linux flavors have been tested.
* Target root volume size must be greater than the current root volume size.
* The new root volume created is the same as the original, except for size. EBS volume type (standard, general purpose SSD, provisioned IOPS SS) and encryption information is carried to the new root volume.

## Known Issues

* Current code does not duplicate the `delete_on_termination` setting of the existing root volume. All new root volumes will be attached with `delete_on_termination = false`
* Code needs to be made command-line-ready.
