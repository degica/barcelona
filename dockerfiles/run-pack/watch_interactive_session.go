package main

import (
	"log"
	"os"
	"time"

	ps "github.com/mitchellh/go-ps"
)

func otherSessionRunning(processes []ps.Process) (ps.Process, error) {
	for _, p := range processes {
		// pid == 1: the process was spawned by `docker run` command
		// ppid == 0: the process was spwaned by docker daemon
		// so if the process is pid != 1 && ppid == 0
		// the process was spawned by docker daemon but not `docker run`
		// which means `docker exec`
		if p.Pid() != 1 && p.PPid() == 0 {
			return p, nil
		}

	}

	return nil, nil
}

func watchInteractiveSession() {
	log.Println("Interactive run watcher started")

	startTimeout := time.After(30 * time.Second)
	runTimeout := time.After(24 * time.Hour)
	tick := time.Tick(5 * time.Second)
	sessionStarted := false
	for {
		select {
		case <-tick:
			processes, err := ps.Processes()
			if err != nil {
				log.Fatalf("error: %s", err)
			}
			p, err := otherSessionRunning(processes)
			if err != nil {
				log.Fatalf("error: %s", err)
			}

			if sessionStarted && p == nil {
				// session has started and already finished
				log.Println("Interactive session successfully finished")
				os.Exit(0)
			} else if !sessionStarted && p != nil {
				// session has just started so mark the flag
				log.Println("Interactive session has started")
				sessionStarted = true
			}
		case <-startTimeout:
			if !sessionStarted {
				log.Println("Interactive session has not started for 30 seconds")
				os.Exit(2)
			}
		case <-runTimeout:
			log.Println("Interactive session has run for over 24 hours")
			os.Exit(2)
		}
	}
}
