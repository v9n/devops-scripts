// dependencies
var async = require('async')
var AWS = require('aws-sdk')
var util = require('util')
var crypto = require('crypto')

var opsworks = new AWS.OpsWorks()
var s3       = new AWS.S3()

function extend(target) {
    var sources = [].slice.call(arguments, 1);
    sources.forEach(function (source) {
        for (var prop in source) {
            target[prop] = source[prop];
        }
    });
    return target;
}

function generateOpsWorksParam(opt) {
  const params = {
    InstanceType: 't2.small',
    LayerIds: [
      '####',
    ],
    StackId: '####',
    SubnetId: '####',
    AmiId: '####',
    Architecture: 'x86_64',
    SshKeyName: '####',
    Os: 'Custom',
  }

  return extend({}, params, opt)
}

function createPayload(hostname, option, cb) {
  var signedUrl = s3.getSignedUrl('getObject', option)
  console.log('The URL is', signedUrl)

  var params = {
    Bucket: '####',
    Key: hostname,
    Body: signedUrl,
    //ServerSideEncryption: 'AES256',
    StorageClass: 'STANDARD',
  }

  s3.putObject(params, function(err, data) {
    if (err) {
      cb(err)
      return
    }
    cb(null, data)
  })
}

function launch(hostname, src, callback) {
  var srcBucket = src.bucket
  var srcKey    = src.key
  var output = []

  var params = generateOpsWorksParam({Hostname: hostname})

  console.log("params", params)
  console.log("Hostname", hostname)

  //@TODO use waterfall
  opsworks.createInstance(params, function(err, data) {
    if (err) {
      console.log(err)
      console.log(err.stack)
      output.push("Fail to create instance")
      callback("fail to launch instance", output.join("\n"))
      return
    }
    console.log("Instance Data", data)
    output.push("Instance ID", data.InstanId)
    output.push("Hostname", hostname)
    output.push("url", srcKey)

    opsworks.startInstance(data, function (err, data) {
      createPayload(hostname, {Bucket: srcBucket, Key: srcKey, Expires: 60 * 60 * 24}, function (err, data) {
        if (err) {
          callback("Fail to create payload", output.join("\n"))
        }

        callback(null, output.join("\n"))
      })
    })
  })

}

function handler(event, context, callback) {
  // Read options from the event.
  console.log("Reading options from event:\n", util.inspect(event, {depth: 5}))
  var srcBucket = event.Records[0].s3.bucket.name
  // Object key may have spaces or unicode non-ASCII characters.
  var srcKey    =
    decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, " "))

  console.log("Launch instance to process " + srcBucket + "/" + srcKey)

  hostname = "spark-" + crypto.createHash('md5').update(srcKey + (new Date().getTime())).digest('hex')
  launch(hostname, {bucket: srcBucket, key: srcKey}, callback)
}

exports.getParams = generateOpsWorksParam
exports.createPayload = createPayload
exports.handler = handler
