var AWS = require('aws-sdk');
var util = require('util');

exports.handler = function(input, context) {
  console.log(util.inspect(input, {showHidden: false, depth: null}))
  console.log(context)

  var ecs = new AWS.ECS();
  var params = {
    cluster: input.cluster,
    taskDefinition: input.task_family,
    overrides: {
      containerOverrides: [
        {
          name: input.task_family,
          command: input.command
        }
      ]
    }
  }

  console.log(util.inspect(params, {depth: null}))
  ecs.runTask(params, function(err, data) {
    console.log(util.inspect(err, {depth: null}))
    console.log(util.inspect(data, {depth: null}))
  })
}
