const { ECSClient, RunTaskCommand } = require("@aws-sdk/client-ecs");

var util = require('util');

exports.handler = async function(input, context) {
  console.log(util.inspect(input, {showHidden: false, depth: null}));
  console.log(context);

  var ecs = new ECSClient();
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
  };

  console.log(util.inspect(params, {depth: null}));

  const command = new RunTaskCommand(params);
  const response = await ecs.send(command);

  console.log(util.inspect(response, {depth: null}));
};
