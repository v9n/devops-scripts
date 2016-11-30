// dependencies
var async = require('async')
var AWS = require('aws-sdk')
var util = require('util')
var crypto = require('crypto')

var opsworks = new AWS.OpsWorks()
var s3       = new AWS.S3()

var fastly = require('fastly')('yourapikey');

fastly.request('GET', '/content/edge_check?url=mysite.com/foo', function (err, obj) {
})


function extend(target) {
  var sources = [].slice.call(arguments, 1);
  sources.forEach(function (source) {
    for (var prop in source) {
      target[prop] = source[prop];
    }
  });
  return target;
}

function findInstances(autoscalingGroupName, cb) {
  var params = {
    //DryRun: true || false,
    Filters: [
      {
      Name: 'aws:autoscaling:groupName',
      Values: [
        autoscalingGroupName,
      ]
    },
    ],
    MaxResults: 0,
  }

  ec2.describeInstances(params, function(err, data) {
    if (err) console.log(err, err.stack); // an error occurred
    else {
      cb(data.Instances)
    }
  })
}

function cloneFastlyConfig(name) {
}

function activateFastlyConfig(name) {
}

function syncFastlyConfig(name, nodes) {
  cloneFastlyConfig(function(config) {
    // Add node into group
    activateFastlyConfig(config)
  })
}

function handler(event, context, callback) {
  autoscaling_group = 'ag'
  findInstances(autoscaling_group, function(node) {
    syncFastlyConfig(name, nodes)
  })
}

exports.getParams = generateOpsWorksParam
exports.createPayload = createPayload
exports.handler = handler
