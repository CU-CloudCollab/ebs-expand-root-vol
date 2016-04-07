#!/usr/bin/env ruby
#
# Functionality to expand the root EBS volume for an AWS EC2 instance.
# See README.md
#
require 'aws-sdk'

class ExpandRootVol

  def ExpandRootVol.expand(region, instanceID, targetSizeGiB, cleanupSnapshot=false, cleanupOriginalVolume=false)

    ec2 = Aws::EC2::Resource.new(region: region)

    i = ec2.instance(instanceID)

    rootDeviceName = i.root_device_name
    rootDeviceType = i.root_device_type
    originalInstanceState = i.state.name

    puts "Growing root volume on instance #{i.instance_id}"
    puts "rootDeviceName: #{rootDeviceName}"
    puts "rootDeviceType: #{rootDeviceType}"
    puts "originalInstanceState: #{originalInstanceState}"
    puts "cleanupSnapshot: #{cleanupSnapshot}"
    puts "cleanupOriginalVolume: #{cleanupOriginalVolume}"

    if rootDeviceType != "ebs"
      raise "Root device (#{rootDeviceName}) is not an ebs volume. It is #{rootDeviceType}."
    end

    targetVolume = nil
    deleteOnTermination = false

    i.volumes.each do | v |
      # p "-----------------------------------"
      # p v.inspect

      v.attachments.each do | a |
        # p "-----------------------------------"
        # p a.inspect
        if a.device == rootDeviceName
          targetVolume = v
          deleteOnTermination = a.delete_on_termination
          break
        end
      end
      break if !targetVolume.nil?
    end

    if targetVolume.nil?
      raise "No root volume identified for instance #{i.instance_id}"
    elsif targetVolume.size >= targetSizeGiB
      raise "New root volume size #{targetSizeGiB} must be greater than current root volume size (#{targetVolume.size})."
    # elsif !["io1", "gp2"].include? targetVolume.volume_type
    #   raise "This operation cannot be performed on current root volume type (#{targetVolume.volume_type})"
    end

    if deleteOnTermination
      # see http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Client.html#modify_instance_attribute-instance_method
      puts "Warning. This function does not duplicate the delete_on_termination setting."
    end

    puts "Original root volume size: #{targetVolume.size}"
    puts "Original root volume delete on termination: #{deleteOnTermination}"

    if originalInstanceState == "running"
      i.stop
      puts "Waiting for instance to stop ..."
      i.wait_until_stopped
    end

    # tag the volume before detaching it
    targetVolume.create_tags({
      tags: [
        {
          key: "Name",
          value: "instance-root-size: #{i.instance_id}-#{rootDeviceName}-#{targetVolume.size}GiB",
        },
      ],
      })

    puts "Detach root volume from instance."
    resp = targetVolume.detach_from_instance({ instance_id: i.instance_id})

    snapshot = targetVolume.create_snapshot({
      description: "instance-root-volume: #{i.instance_id}-#{rootDeviceName}-#{targetVolume.volume_id}"
      })
    puts "Waiting for snapshot to complete ..."
    snapshot.wait_until_completed

    properties = {
     size: targetSizeGiB,
     snapshot_id: snapshot.snapshot_id,
     availability_zone: targetVolume.availability_zone, # required
     volume_type: targetVolume.volume_type, # accepts standard, io1, gp2
     encrypted: targetVolume.encrypted,
     kms_key_id: targetVolume.kms_key_id
    }
    if targetVolume.volume_type == "io1"
      properties[:iops] = targetVolume.iops
    end

    puts "Creating new volume (#{targetSizeGiB}GiB)"
    newVolume = ec2.create_volume(properties)
    newVolume.create_tags({
      tags: [{
          key: "Name",
          value: "instance-root-size: #{i.instance_id}-#{rootDeviceName}-#{newVolume.size}GiB",
        }]
      })

    newVolume.wait_until { | v |
      puts "Waiting for new volume to become available."
      v.state == "available"
    }

    puts "Attach new volume to instance."
    resp = newVolume.attach_to_instance({
      instance_id: i.instance_id,
      device: rootDeviceName
    })

    if originalInstanceState == "running"
      puts "Original instance was running. Starting instance, but not waiting for start to complete."
      i.start
    end

    if cleanupSnapshot
      puts "Cleanup. Deleting snapshot #{snapshot.snapshot_id}."
      snapshot.delete
    end
    if cleanupOriginalVolume
      puts "Cleanup. Deleting original volume #{targetVolume.volume_id}."
      targetVolume.delete
    end

  end

end
