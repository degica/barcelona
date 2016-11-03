package main

import (
	"io/ioutil"
	"os"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
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

func newSession(region string) (*session.Session, error) {
	if keyId := os.Getenv("AWS_ACCESS_KEY_ID"); len(keyId) > 0 {
		secretKey := os.Getenv("AWS_SECRET_ACCESS_KEY")
		if err := os.Unsetenv("AWS_ACCESS_KEY_ID"); err != nil {
			return nil, err
		}
		if err := os.Unsetenv("AWS_SECRET_ACCESS_KEY"); err != nil {
			return nil, err
		}

		sess, err := session.NewSession(&aws.Config{Region: &region})
		if err != nil {
			return nil, err
		}

		if os.Setenv("AWS_ACCESS_KEY_ID", keyId) != nil {
			return nil, err
		}
		if os.Setenv("AWS_SECRET_ACCESS_KEY", secretKey) != nil {
			return nil, err
		}
		return sess, err
	} else {
		sess, err := session.NewSession(&aws.Config{Region: &region})
		if err != nil {
			return nil, err
		}
		return sess, err
	}
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
