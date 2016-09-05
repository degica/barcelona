package main

import "testing"

type s3ClientMock struct {
}

func (c *s3ClientMock) GetValue(path string) (string, error) {
	return path + " value", nil
}

func TestGetValue(t *testing.T) {
	cli := &s3ClientMock{}
	envMap := map[string]string{
		"ABC": "path/to/ABC",
		"DEF": "path/to/DEF",
	}
	res, err := getValues(cli, envMap)
	if err != nil {
		t.Fatalf("err: %s", err)
	}
	if len(res) != 2 {
		t.Fatalf("expected 2, actual: %d", len(res))
	}
	if res["ABC"] != "path/to/ABC value" {
		t.Fatalf("expected \"path/to/ABC value\", actual: %s", res["ABC"])
	}
	if res["DEF"] != "path/to/DEF value" {
		t.Fatalf("expected \"path/to/DEF value\", actual: %s", res["DEF"])
	}
}
