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
		err = os.Setenv(k, v)
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
