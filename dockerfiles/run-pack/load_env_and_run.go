package main

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"

	"github.com/aws/aws-sdk-go/service/kms"
	"github.com/aws/aws-sdk-go/service/kms/kmsiface"
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
		resolver, err := NewTransitResolver(region)
		if err != nil {
			panic(err)
		}
		kk, vv, err := resolver.ResolveSecret(k, v)
		fmt.Println(kk)
		fmt.Println(vv)
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

type TransitResolver struct {
	kmsCli kmsiface.KMSAPI
	region string
}

func NewTransitResolver(region string) (*TransitResolver, error) {
	session, err := newSession(region)
	if err != nil {
		return nil, err
	}

	resolver := &TransitResolver{
		kmsCli: kms.New(session),
		region: region,
	}

	return resolver, nil
}

// Takes key and value
// Returns unprefixed key and decrypted body or just arguments as-is if not encrypted
func (r *TransitResolver) ResolveSecret(key string, body string) (string, string, error) {
	if strings.HasPrefix(key, "__BCN_TRANSIT__") {
		key = strings.TrimPrefix(key, "__BCN_TRANSIT__")
		// bcn:transit:v1:<Base64 encoded encrypted data key>:<Base64 encoded encrypted value>
		vs := strings.SplitN(body, ":", 5)
		if len(vs) != 5 {
			return "", "", nil
		}

		encryptedDataKey, err := base64.StdEncoding.DecodeString(vs[3])
		if err != nil {
			return "", "", err
		}

		decOut, err := r.kmsCli.Decrypt(&kms.DecryptInput{
			CiphertextBlob: encryptedDataKey,
		})

		if err != nil {
			return "", "", err
		}

		block, err := aes.NewCipher(decOut.Plaintext)
		if err != nil {
			return "", "", err
		}

		aesgcm, err := cipher.NewGCM(block)
		if err != nil {
			return "", "", err
		}

		ciphertext, err := base64.StdEncoding.DecodeString(vs[4])
		if err != nil {
			return "", "", err
		}
		nonce := ciphertext[:12] // First 12 bytes are nonce
		cipherbody := ciphertext[12:]

		plaintext, err := aesgcm.Open(nil, nonce, cipherbody, []byte(""))
		if err != nil {
			return "", "", err
		}

		body = string(plaintext)
	}
	return key, body, nil
}
