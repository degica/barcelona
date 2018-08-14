package main

import (
	"io/ioutil"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/s3"
)

type S3Client interface {
	GetValue(path string) (string, error)
}

type s3Client struct {
	svc        *s3.S3
	bucketName string
}

func NewS3Client(region string, bucket string) (S3Client, error) {
	session, err := newSession(region)
	if err != nil {
		return nil, err
	}

	svc := s3.New(session)
	client := &s3Client{
		svc:        svc,
		bucketName: bucket,
	}
	return client, nil
}

func (c *s3Client) GetValue(path string) (string, error) {
	params := &s3.GetObjectInput{
		Bucket: aws.String(c.bucketName),
		Key:    &path,
	}
	resp, err := c.svc.GetObject(params)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	return string(body), nil
}
