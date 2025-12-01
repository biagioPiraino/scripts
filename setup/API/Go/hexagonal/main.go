package main

import (
	"log"
	"os"
	"os/exec"
	"path"
)

func main() {
	if len(os.Args) < 3 {
		log.Fatal("expecting <app_name> and <folder_target> params")
	}

	appName := os.Args[1]
	folderTarget := os.Args[2]
	filepath := path.Join(folderTarget, appName)

	// app folder
	makeDirectory(filepath)

	// cmd folder
	cmdFolder := path.Join(filepath, "cmd/api")

	// core folders
	intCoreDomainFolder := path.Join(filepath, "internal/core/domain")
	intCorePortsFolder := path.Join(filepath, "internal/core/ports")
	intCoreServicesFolder := path.Join(filepath, "internal/core/services")
	intCoreUtilsFolder := path.Join(filepath, "internal/core/utils")

	makeDirectory(cmdFolder)
	makeDirectory(intCoreDomainFolder)
	makeDirectory(intCorePortsFolder)
	makeDirectory(intCoreServicesFolder)
	makeDirectory(intCoreUtilsFolder)

	// adapters folders
	handlersFolder := path.Join(filepath, "internal/adapters/handlers/http")
	repositoryFolder := path.Join(filepath, "internal/adapters/repository/postgres")
	cacheFolder := path.Join(filepath, "internal/adapters/cache/redis")
	loggerFolder := path.Join(filepath, "internal/adapters/platform/logger")

	makeDirectory(handlersFolder)
	makeDirectory(repositoryFolder)
	makeDirectory(cacheFolder)
	makeDirectory(loggerFolder)

	// initialise golang module
	moduleName := "github.com/biagioPiraino/" + appName
	cmd := exec.Command("go", "mod", "init", moduleName)
	cmd.Dir = filepath

	if _, err := cmd.Output(); err != nil {
		log.Fatal(err)
	}
}

func makeDirectory(filepath string) {
	if err := os.MkdirAll(filepath, 0750); err != nil {
		log.Fatal("error creating folder target")
	}
}
