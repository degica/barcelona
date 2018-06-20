package main

import (
	"os"
	"os/exec"
	"syscall"
)

func getValues(c S3Client, m map[string]string) (map[string]string, error) {
	envMap := make(map[string]string)
	for name, path := range m {
		value, err := c.GetValue(path)
		if err != nil {
			return nil, err
		}
		envMap[name] = string(value)
	}
	return envMap, nil
}

func loadEnvAndRun(region string, bucket string, envs map[string]string, command []string) {
	cli, err := NewS3Client(region, bucket)
	if err != nil {
		panic(err)
	}

	kv, err := getValues(cli, envs)
	if err != nil {
		panic(err)
	}

	for k, v := range kv {
		kk, vv, err := resolveTransitSecret(k, v)
		if err != nil {
			panic(err)
		}
		err = os.Setenv(kk, vv)
		if err != nil {
			panic(err)
		}
	}

	comm, err := exec.LookPath(command[0])
	if err != nil {
		panic(err)
	}
	syscall.Exec(comm, command, os.Environ())
}

type TransitResolver interface {
	Resolve(key string, body string) (string, string, error)
}

type transitResolver struct {
	kms *kms.Kms
	cmk string
}

func NewTransitResolver(cmk string) (TransitResolver, error) {
	session, err := newSession(region)
	if err != nil {
		return nil, err
	}

	resolver := &transitResolver{
		kms: kms.New(session),
		cmk: cmk,
	}

	return resolver, nil
}

// Takes key and value
// Returns unprefixed key and decrypted body or just arguments as-is if not encrypted
func (r *transitResolver) resolveTransitSecret(key string, body string) (string, string, error) {
	// TODO
	return key, body, nil
}
