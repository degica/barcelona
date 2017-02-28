'use strict';

const url = require('url');
const https = require('https');

function postMessage(message, callback) {
  const body = JSON.stringify(message);
  const options = url.parse(process.env.ENDPOINT);
  options.method = 'POST';
  options.headers = {'Content-Type': 'application/json'};

  const postReq = https.request(options, (res) => {
    const chunks = [];
    res.setEncoding('utf8');
    res.on('data', (chunk) => chunks.push(chunk));
    res.on('end', () => {
      if (callback) {
        callback({
          body: chunks.join(''),
          statusCode: res.statusCode,
          statusMessage: res.statusMessage
        });
      }
    });
    return res;
  });

  postReq.write(body);
  postReq.end();
}

exports.handler = (event, context, callback) => {
  const sns = event.Records[0].Sns;
  const message = JSON.parse(sns.Message);

  let slackMessage = {
    username: "Barcelona",
    attachments: [
      {
        fallback: message.text,
        pretext: sns.Subject,
        text: `[${process.env.DISTRICT}] ${message.text}`,
        color: message.level
      }
    ]
  }

  postMessage(slackMessage, (response) => {callback(null);});
};
