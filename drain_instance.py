import boto3
import json
import os
import time
import random

from botocore.config import Config
from botocore.exceptions import ClientError

session = boto3.session.Session()
config = Config(
    retries = {
        'max_attempts': 4,
        'mode': 'standard'
    }
)

ecs = session.client(service_name='ecs', config=config)

clusterName = os.environ["CLUSTER_NAME"]

def ciFor(ec2Id):
    paginator = ecs.get_paginator('list_container_instances')
    for page in paginator.paginate(cluster=clusterName):
        descResp = ecs.describe_container_instances(cluster=clusterName, containerInstances=page['containerInstanceArns'])
        for ci in descResp['containerInstances']:
            if ci['ec2InstanceId'] == ec2Id:
                return ci['containerInstanceArn'], ci['status']

    return None, None

def taskExists(clusterName, ciId):
    running_tasks = ecs.list_tasks(cluster=clusterName, containerInstance=ciId, desiredStatus='RUNNING')['taskArns']
    if (len(running_tasks) > 0):
        return True

    # Assume there are not more than 100 tasks in a container
    stopping_tasks = ecs.list_tasks(cluster=clusterName, containerInstance=ciId, desiredStatus='STOPPED')['taskArns']
    for task_arn in stopping_tasks:
        response = ecs.describe_tasks(
            cluster=clusterName,
            tasks=[task_arn]
        )
        status = response['tasks'][0]['lastStatus']
        if status != 'STOPPED':
            return True

    print('No tasks, will proceed terminating the instance')
    return False

def lambda_handler(event, context):
    msg = json.loads(event['Records'][0]['Sns']['Message'])
    ec2Id = msg['EC2InstanceId']
    asgName = msg['AutoScalingGroupName']
    lifecycleHookName = msg['LifecycleHookName']
    topicArn = event['Records'][0]['Sns']['TopicArn']

    if msg['LifecycleTransition'] != 'autoscaling:EC2_INSTANCE_TERMINATING':
        return

    # wait for random time to avoid ThrottlingException of AWS API call
    sec = random.uniform(0, 5)
    time.sleep(sec)

    try:
        ciId, status = ciFor(ec2Id)
        if ciId == None:
            return
        if status != 'DRAINING':
            ecs.update_container_instances_state(cluster=clusterName,containerInstances=[ciId],status='DRAINING')

        if taskExists(clusterName, ciId):
            time.sleep(5)
            session.client('sns', config=config).publish(TopicArn=topicArn, Message=json.dumps(msg), Subject='Invoking lambda again')
        else:
            session.client('autoscaling', config=config).complete_lifecycle_action(LifecycleHookName=lifecycleHookName, AutoScalingGroupName=asgName, LifecycleActionResult='CONTINUE', InstanceId=ec2Id)
    except ClientError as exception_obj:
        if exception_obj.response['Error']['Code'] == 'ThrottlingException':
            sec = random.uniform(3, 5)
            time.sleep(sec)
            session.client('sns').publish(TopicArn=topicArn, Message=json.dumps(msg), Subject='Invoking lambda again')
        else:
            raise
