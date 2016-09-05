package main

import (
	"os"
	"strings"

	"github.com/urfave/cli"
)

func main() {
	app := cli.NewApp()
	app.Name = "barcelona-run"
	app.Version = "0.0.1"
	app.Commands = []cli.Command{
		{
			Name: "load-env-and-run",
			Flags: []cli.Flag{
				cli.StringFlag{
					Name:  "region",
					Usage: "AWS Region",
				},
				cli.StringFlag{
					Name:  "bucket-name",
					Usage: "S3 Bucket Name",
				},
				cli.StringSliceFlag{
					Name:  "environment, e",
					Usage: "<ENV_NAME>=<S3_PATH>",
				},
			},
			Action: func(c *cli.Context) error {
				m := make(map[string]string)
				for _, e := range c.StringSlice("environment") {
					pair := strings.Split(e, "=")
					m[pair[0]] = pair[1]
				}
				loadEnvAndRun(c.String("region"), c.String("bucket-name"), m, c.Args())
				return nil
			},
		},
		{
			Name: "watch-interactive-session",
			Action: func(c *cli.Context) error {
				watchInteractiveSession()
				return nil
			},
		},
	}

	app.Run(os.Args)
}
