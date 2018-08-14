package main

import (
	"os"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
)

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

		if err = os.Setenv("AWS_ACCESS_KEY_ID", keyId); err != nil {
			return nil, err
		}
		if err = os.Setenv("AWS_SECRET_ACCESS_KEY", secretKey); err != nil {
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
